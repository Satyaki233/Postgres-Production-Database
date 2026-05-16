#!/usr/bin/env bash
# Unified restore script for the warehouse database.
# Every destructive action requires --confirm. Without it, prints what would run.
#
# Usage:
#   bash scripts/backup/restore.sh --list-backups
#   bash scripts/backup/restore.sh --from-dump   [--dir PATH] [--schema SCHEMA] [--dry-run] [--confirm]
#   bash scripts/backup/restore.sh --from-basebackup [--dir PATH] [--dry-run] [--confirm]
#
# --from-dump
#   Restores one or all schemas from a pg_dump (custom format).
#   The database stays ONLINE — other schemas remain accessible.
#   --schema mars   Restore only the marts schema (fastest, most common)
#   --schema all    Restore marts + staging + raw (full restore)
#
# --from-basebackup
#   Restores full PGDATA from a physical pg_basebackup.
#   Stops all services, replaces the Docker volume, and restarts.
#   Used when the container itself is corrupted or the volume is damaged.
#
# --dry-run
#   Prints exactly what would run. Makes zero changes.
#
# --confirm
#   Required for all destructive actions (DROP, volume replacement).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
ENV_FILE="$PROJECT_DIR/.env"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

: "${POSTGRES_USER:?POSTGRES_USER not set in .env}"
: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD not set in .env}"
: "${POSTGRES_DB:=warehouse}"
: "${BACKUP_DIR:=$PROJECT_DIR/backups}"
: "${CONTAINER:=postgres_production}"
: "${COMPOSE_PROJECT:=postgresproductiondatabase}"

RESTORE_MODE=""
RESTORE_DIR=""
RESTORE_SCHEMA="marts"
DRY_RUN=false
CONFIRMED=false

# ── Parse arguments ────────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
  case "$1" in
    --list-backups)    RESTORE_MODE="list" ;;
    --from-dump)       RESTORE_MODE="dump" ;;
    --from-basebackup) RESTORE_MODE="basebackup" ;;
    --dir)             RESTORE_DIR="$2"; shift ;;
    --schema)          RESTORE_SCHEMA="$2"; shift ;;
    --dry-run)         DRY_RUN=true ;;
    --confirm)         CONFIRMED=true ;;
    *)                 echo "Unknown option: $1"; exit 1 ;;
  esac
  shift
done

[[ -z "$RESTORE_MODE" ]] && {
  echo "Usage: $0 [--list-backups | --from-dump | --from-basebackup] [options]"
  echo "Run with no extra options to see available backups."
  exit 1
}

# ── List available backups ─────────────────────────────────────────────────────

if [[ "$RESTORE_MODE" == "list" ]]; then
  echo ""
  echo "=== pg_dump backups ==="
  found=0
  while IFS= read -r d; do
    [[ -d "$d" ]] || continue
    size=$(du -sh "$d" | cut -f1)
    mode=$(grep "^mode=" "$d/MANIFEST" 2>/dev/null | cut -d= -f2 || echo "unknown")
    echo "  $(basename "$d")  [${size}]  mode=${mode}"
    found=1
  done < <(ls -1dt "$BACKUP_DIR/dumps/daily/20"* 2>/dev/null)
  [[ $found -eq 0 ]] && echo "  None found — run daily_dump.sh to create one"

  echo ""
  echo "=== pg_basebackups ==="
  found=0
  while IFS= read -r d; do
    [[ -d "$d" ]] || continue
    size=$(du -sh "$d" | cut -f1)
    echo "  $(basename "$d")  [${size}]"
    found=1
  done < <(ls -1dt "$BACKUP_DIR/basebackup/20"* 2>/dev/null)
  [[ $found -eq 0 ]] && echo "  None found — run weekly_basebackup.sh to create one"
  echo ""
  exit 0
fi

# ── Resolve default restore directory ─────────────────────────────────────────

if [[ -z "$RESTORE_DIR" ]]; then
  if [[ "$RESTORE_MODE" == "dump" ]]; then
    RESTORE_DIR=$(ls -1dt "$BACKUP_DIR/dumps/daily/20"* 2>/dev/null | head -1 || true)
    [[ -z "$RESTORE_DIR" ]] && { echo "No dumps found. Run daily_dump.sh first."; exit 1; }
    echo "No --dir specified. Using latest dump: $RESTORE_DIR"
  elif [[ "$RESTORE_MODE" == "basebackup" ]]; then
    RESTORE_DIR=$(ls -1dt "$BACKUP_DIR/basebackup/20"* 2>/dev/null | head -1 || true)
    [[ -z "$RESTORE_DIR" ]] && { echo "No basebackups found. Run weekly_basebackup.sh first."; exit 1; }
    echo "No --dir specified. Using latest basebackup: $RESTORE_DIR"
  fi
fi

[[ -d "$RESTORE_DIR" ]] || { echo "ERROR: $RESTORE_DIR does not exist."; exit 1; }

# ── Restore from pg_dump ───────────────────────────────────────────────────────

if [[ "$RESTORE_MODE" == "dump" ]]; then
  echo ""
  echo "=== RESTORE FROM PG_DUMP ==="
  echo "Source:  $RESTORE_DIR"
  echo "Schema:  $RESTORE_SCHEMA"
  echo ""

  if [[ "$RESTORE_SCHEMA" == "all" ]]; then
    SCHEMAS_TO_RESTORE=()
    for f in "$RESTORE_DIR"/*.dump; do
      [[ -f "$f" ]] && SCHEMAS_TO_RESTORE+=("$(basename "$f" .dump)")
    done
  else
    SCHEMAS_TO_RESTORE=("$RESTORE_SCHEMA")
    [[ -f "$RESTORE_DIR/${RESTORE_SCHEMA}.dump" ]] || {
      echo "ERROR: $RESTORE_DIR/${RESTORE_SCHEMA}.dump not found."
      echo "Available dumps: $(ls "$RESTORE_DIR"/*.dump 2>/dev/null | xargs -n1 basename | tr '\n' ' ')"
      exit 1
    }
  fi

  echo "Schemas to restore: ${SCHEMAS_TO_RESTORE[*]}"
  echo ""
  echo "Steps that will execute:"
  for schema in "${SCHEMAS_TO_RESTORE[@]}"; do
    echo "  1. DROP SCHEMA IF EXISTS $schema CASCADE"
    echo "  2. CREATE SCHEMA $schema"
    echo "  3. pg_restore --jobs=4 --schema=$schema (from ${schema}.dump)"
    echo "  4. GRANT permissions on $schema to warehouse_developer, warehouse_analyst"
  done
  echo ""

  if $DRY_RUN; then
    echo "[DRY RUN] No changes made. Remove --dry-run and add --confirm to execute."
    exit 0
  fi

  if ! $CONFIRMED; then
    echo "ERROR: This will DROP and recreate schema(s) in the live database."
    echo "       Verify the backup first: bash scripts/backup/verify_backup.sh --latest-dump"
    echo "       Then re-run with --confirm to proceed."
    exit 1
  fi

  for schema in "${SCHEMAS_TO_RESTORE[@]}"; do
    dump_file="$RESTORE_DIR/${schema}.dump"
    echo ""
    echo "--- Restoring schema: $schema ---"

    docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" "$CONTAINER" \
      psql --username="$POSTGRES_USER" --dbname="$POSTGRES_DB" \
      -c "DROP SCHEMA IF EXISTS $schema CASCADE; CREATE SCHEMA $schema;"

    docker exec -i -e PGPASSWORD="$POSTGRES_PASSWORD" "$CONTAINER" \
      pg_restore \
        --username="$POSTGRES_USER" \
        --host=127.0.0.1 \
        --dbname="$POSTGRES_DB" \
        --schema="$schema" \
        --jobs=4 \
        --no-password \
      < "$dump_file"

    docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" "$CONTAINER" \
      psql --username="$POSTGRES_USER" --dbname="$POSTGRES_DB" \
      -c "GRANT USAGE ON SCHEMA $schema TO warehouse_developer, warehouse_analyst;
          GRANT ALL ON ALL TABLES IN SCHEMA $schema TO warehouse_developer;
          GRANT SELECT ON ALL TABLES IN SCHEMA $schema TO warehouse_analyst;
          ALTER DEFAULT PRIVILEGES IN SCHEMA $schema
            GRANT SELECT ON TABLES TO warehouse_analyst;
          ALTER DEFAULT PRIVILEGES IN SCHEMA $schema
            GRANT ALL ON TABLES TO warehouse_developer;"

    echo "  Schema $schema restored and permissions re-applied."
  done

  echo ""
  echo "=== pg_dump restore complete ==="
  echo "Run a row count check:"
  echo "  psql -h 127.0.0.1 -p 5434 -U $POSTGRES_USER -d $POSTGRES_DB \\"
  echo "    -c \"SELECT schemaname, relname, n_live_tup FROM pg_stat_user_tables WHERE schemaname='marts' ORDER BY n_live_tup DESC;\""
fi

# ── Restore from pg_basebackup ─────────────────────────────────────────────────

if [[ "$RESTORE_MODE" == "basebackup" ]]; then
  VOLUME_NAME="${COMPOSE_PROJECT}_postgres_data"

  echo ""
  echo "=== RESTORE FROM PG_BASEBACKUP ==="
  echo "Source: $RESTORE_DIR"
  echo ""
  echo "WARNING: This will:"
  echo "  1. docker compose down (stops ALL 5 services)"
  echo "  2. docker volume rm $VOLUME_NAME"
  echo "  3. docker volume create $VOLUME_NAME"
  echo "  4. Extract base.tar.gz + pg_wal.tar.gz into the new volume"
  echo "  5. docker compose up -d (restarts all services)"
  echo ""
  echo "Estimated time: 10–20 minutes"
  echo ""

  if $DRY_RUN; then
    echo "[DRY RUN] No changes made. Remove --dry-run and add --confirm to execute."
    exit 0
  fi

  if ! $CONFIRMED; then
    echo "ERROR: This will DESTROY and replace the current database volume."
    echo "       Verify the backup first: bash scripts/backup/verify_backup.sh --latest-basebackup"
    echo "       Then re-run with --confirm to proceed."
    exit 1
  fi

  echo "Step 1: Stopping all services..."
  docker compose -f "$PROJECT_DIR/docker-compose.yml" down

  echo "Step 2: Removing volume $VOLUME_NAME ..."
  docker volume rm "$VOLUME_NAME" || true

  echo "Step 3: Recreating volume..."
  docker volume create "$VOLUME_NAME"

  echo "Step 4: Extracting base.tar.gz into volume..."
  docker run --rm \
    -v "${VOLUME_NAME}:/var/lib/postgresql/data" \
    -v "$RESTORE_DIR:/backup:ro" \
    postgres:16 \
    bash -c "
      mkdir -p /var/lib/postgresql/data/pgdata &&
      tar -xzf /backup/base.tar.gz -C /var/lib/postgresql/data/pgdata &&
      chown -R postgres:postgres /var/lib/postgresql/data
    "

  echo "Step 5: Extracting WAL segments..."
  docker run --rm \
    -v "${VOLUME_NAME}:/var/lib/postgresql/data" \
    -v "$RESTORE_DIR:/backup:ro" \
    postgres:16 \
    bash -c "
      if [[ -f /backup/pg_wal.tar.gz ]]; then
        mkdir -p /var/lib/postgresql/data/pgdata/pg_wal &&
        tar -xzf /backup/pg_wal.tar.gz -C /var/lib/postgresql/data/pgdata/pg_wal &&
        chown -R postgres:postgres /var/lib/postgresql/data
      else
        echo 'WARNING: pg_wal.tar.gz not found — WAL not restored'
      fi
    "

  echo "Step 6: Restarting all services..."
  docker compose -f "$PROJECT_DIR/docker-compose.yml" up -d

  echo ""
  echo "Waiting for PostgreSQL to become ready..."
  for i in $(seq 1 30); do
    if docker exec "$CONTAINER" pg_isready -U "$POSTGRES_USER" -q 2>/dev/null; then
      echo "PostgreSQL is ready."
      break
    fi
    printf "  (%d/30) waiting...\r" "$i"
    sleep 5
  done

  echo ""
  echo "=== pg_basebackup restore complete ==="
  echo "Verify with: bash scripts/backup/verify_backup.sh --latest-basebackup"
  echo "Check all services: docker compose ps"
fi

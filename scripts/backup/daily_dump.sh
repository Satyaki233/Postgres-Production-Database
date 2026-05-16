#!/usr/bin/env bash
# Daily logical pg_dump of the warehouse database.
# Runs pg_dump INSIDE the container to avoid pg14/pg16 version mismatch.
#
# Usage:
#   bash scripts/backup/daily_dump.sh [--marts-only | --full]
#
# --marts-only  Dump only the marts schema (default, ~9 GB, regenerable schemas skipped)
# --full        Dump all three schemas: marts, staging, raw
#
# Schedule via host crontab:
#   30 3 * * *  bash scripts/backup/daily_dump.sh --marts-only
#   0  4 * * 0  bash scripts/backup/daily_dump.sh --full   (Sunday full)

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
: "${KEEP_DAYS:=7}"

MODE="${1:---marts-only}"
TIMESTAMP=$(date +%Y-%m-%d_%H%M%S)
DUMP_DIR="$BACKUP_DIR/dumps/daily/$TIMESTAMP"
LOG_FILE="$BACKUP_DIR/dumps/daily/backup_${TIMESTAMP}.log"
START_TIME=$(date +%s)

mkdir -p "$DUMP_DIR"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

log "=== Daily pg_dump backup starting (mode: $MODE) ==="
log "Container: $CONTAINER | DB: $POSTGRES_DB | Target: $DUMP_DIR"

# ── Health check ───────────────────────────────────────────────────────────────

if ! docker exec "$CONTAINER" pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB" -q 2>/dev/null; then
  log "ERROR: PostgreSQL is not ready in $CONTAINER. Aborting."
  exit 1
fi

# ── Dump globals (roles, tablespaces) ─────────────────────────────────────────

log "Dumping globals (roles + tablespaces)..."
docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" "$CONTAINER" \
  pg_dumpall \
    --globals-only \
    --username="$POSTGRES_USER" \
    --host=127.0.0.1 \
  > "$DUMP_DIR/globals.sql"
log "  globals.sql: $(du -sh "$DUMP_DIR/globals.sql" | cut -f1)"

# ── Helper: dump one schema ────────────────────────────────────────────────────

dump_schema() {
  local schema="$1"
  local out="$DUMP_DIR/${schema}.dump"
  log "Dumping schema: $schema ..."
  docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" "$CONTAINER" \
    pg_dump \
      --username="$POSTGRES_USER" \
      --host=127.0.0.1 \
      --dbname="$POSTGRES_DB" \
      --schema="$schema" \
      --format=custom \
      --compress=9 \
      --no-password \
    > "$out" 2>> "$LOG_FILE"
  log "  ${schema}.dump: $(du -sh "$out" | cut -f1)"
}

# ── Schema dumps ───────────────────────────────────────────────────────────────

dump_schema "marts"

if [[ "$MODE" == "--full" ]]; then
  dump_schema "staging"
  dump_schema "raw"
fi

# ── Schema DDL-only dump ───────────────────────────────────────────────────────

log "Dumping schema DDL only (all schemas)..."
docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" "$CONTAINER" \
  pg_dump \
    --username="$POSTGRES_USER" \
    --host=127.0.0.1 \
    --dbname="$POSTGRES_DB" \
    --schema-only \
    --format=plain \
  > "$DUMP_DIR/schema_only.sql" 2>> "$LOG_FILE"
log "  schema_only.sql: $(du -sh "$DUMP_DIR/schema_only.sql" | cut -f1)"

# ── Write manifest ─────────────────────────────────────────────────────────────

PG_VER=$(docker exec "$CONTAINER" pg_dump --version 2>/dev/null | head -1)
DUMP_SIZE=$(find "$DUMP_DIR" -type f -ls | awk '{sum += $7} END {print sum+0}')
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

cat > "$DUMP_DIR/MANIFEST" <<MANIFEST
backup_type=logical_pg_dump
timestamp=$TIMESTAMP
mode=${MODE#--}
container=$CONTAINER
database=$POSTGRES_DB
pg_version=$PG_VER
duration_secs=$DURATION
total_size_bytes=$DUMP_SIZE
files=$(ls "$DUMP_DIR" | tr '\n' ' ')
MANIFEST

log "Manifest written."

# ── Rotation ───────────────────────────────────────────────────────────────────

log "Rotating dumps older than $KEEP_DAYS days..."
find "$BACKUP_DIR/dumps/daily" -maxdepth 1 -type d \
  -name "20*" \
  -mtime +"$KEEP_DAYS" \
  -exec rm -rf {} + 2>/dev/null || true
find "$BACKUP_DIR/dumps/daily" -maxdepth 1 -type f \
  -name "backup_*.log" \
  -mtime +"$KEEP_DAYS" \
  -delete 2>/dev/null || true

log "=== Daily pg_dump backup complete (${DURATION}s) ==="
log "Output: $DUMP_DIR | Size: $(du -sh "$DUMP_DIR" | cut -f1)"

# ── Log to backup_log table ────────────────────────────────────────────────────

docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" "$CONTAINER" \
  psql --username="$POSTGRES_USER" --dbname="$POSTGRES_DB" \
  -c "INSERT INTO public.backup_log (backup_type, status, size_bytes, duration_secs, notes)
      VALUES ('pg_dump_${MODE#--}', 'success', $DUMP_SIZE, $DURATION,
              'timestamp: $TIMESTAMP')" 2>/dev/null || \
  log "  (backup_log table not yet created — run init/04_backup_log.sql)"

# ── Offsite sync ───────────────────────────────────────────────────────────────

SYNC_SCRIPT="$SCRIPT_DIR/offsite_sync.sh"
if [[ -f "$SYNC_SCRIPT" ]] && [[ "${ENABLE_OFFSITE_SYNC:-true}" == "true" ]]; then
  log "Triggering offsite sync..."
  bash "$SYNC_SCRIPT" --dumps-only 2>&1 | tee -a "$LOG_FILE" || \
    log "WARNING: Offsite sync failed — backup is local only"
fi

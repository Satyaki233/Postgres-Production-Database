#!/usr/bin/env bash
# Physical pg_basebackup of the full PGDATA directory.
# Includes streamed WAL (--wal-method=stream) for a self-contained restore.
# Runs pg_basebackup INSIDE the container to avoid client version mismatch.
#
# Usage:
#   bash scripts/backup/weekly_basebackup.sh
#
# Schedule via host crontab (Sunday 1:30am, after pg_partman at 1am):
#   30 1 * * 0  bash scripts/backup/weekly_basebackup.sh

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
: "${KEEP_WEEKS:=2}"

TIMESTAMP=$(date +%Y-%m-%d_%H%M%S)
BB_DIR="$BACKUP_DIR/basebackup/$TIMESTAMP"
LOG_FILE="$BACKUP_DIR/basebackup/basebackup_${TIMESTAMP}.log"
START_TIME=$(date +%s)

mkdir -p "$BB_DIR"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

log "=== pg_basebackup starting ==="
log "Container: $CONTAINER | Target: $BB_DIR"
log "WARNING: This will take 10–20 minutes for a ~39 GB database."

# ── Health check ───────────────────────────────────────────────────────────────

if ! docker exec "$CONTAINER" pg_isready -U "$POSTGRES_USER" -q 2>/dev/null; then
  log "ERROR: PostgreSQL not ready. Aborting."
  exit 1
fi

# ── Run pg_basebackup inside container ────────────────────────────────────────
# Writes to a temp path inside the container, then we copy it out via docker cp.
# This avoids the pg14 host client / pg16 server version mismatch entirely.

CONTAINER_TMP="/tmp/basebackup_${TIMESTAMP}"

log "Running pg_basebackup (--wal-method=stream, --format=tar, --gzip)..."
docker exec \
  -e PGPASSWORD="$POSTGRES_PASSWORD" \
  "$CONTAINER" \
  pg_basebackup \
    --host=127.0.0.1 \
    --port=5432 \
    --username="$POSTGRES_USER" \
    --pgdata="$CONTAINER_TMP" \
    --format=tar \
    --gzip \
    --compress=6 \
    --wal-method=stream \
    --checkpoint=fast \
    --progress \
  2>> "$LOG_FILE"

log "pg_basebackup completed. Copying archives from container to host..."
docker cp "$CONTAINER:$CONTAINER_TMP/." "$BB_DIR/"

log "Cleaning up temp directory in container..."
docker exec "$CONTAINER" rm -rf "$CONTAINER_TMP"

# ── Write manifest ─────────────────────────────────────────────────────────────

PG_VERSION=$(docker exec "$CONTAINER" cat /var/lib/postgresql/data/pgdata/PG_VERSION 2>/dev/null || echo "unknown")
BB_SIZE=$(find "$BB_DIR" -type f -ls | awk '{sum += $7} END {print sum+0}')
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

cat > "$BB_DIR/MANIFEST" <<MANIFEST
backup_type=pg_basebackup
timestamp=$TIMESTAMP
container=$CONTAINER
pg_version=$PG_VERSION
pgdata_path=/var/lib/postgresql/data/pgdata
wal_method=stream
format=tar+gzip
duration_secs=$DURATION
total_size_bytes=$BB_SIZE
files=$(ls "$BB_DIR" | tr '\n' ' ')
MANIFEST

log "Manifest written."
log "Backup contents:"
ls -lh "$BB_DIR" | tee -a "$LOG_FILE"

# ── Update 'latest' symlink ────────────────────────────────────────────────────

LATEST_LINK="$BACKUP_DIR/basebackup/latest"
rm -f "$LATEST_LINK"
ln -s "$BB_DIR" "$LATEST_LINK"
log "Updated 'latest' symlink → $BB_DIR"

# ── Rotation: keep last $KEEP_WEEKS weekly backups ────────────────────────────

log "Rotating basebackups older than $((KEEP_WEEKS * 7)) days..."
find "$BACKUP_DIR/basebackup" -maxdepth 1 -type d \
  -name "20*" \
  -mtime +"$((KEEP_WEEKS * 7))" \
  -exec rm -rf {} + 2>/dev/null || true

log "=== pg_basebackup complete (${DURATION}s) ==="
log "Total backup size: $(du -sh "$BB_DIR" | cut -f1)"

# ── Log to backup_log table ────────────────────────────────────────────────────

docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" "$CONTAINER" \
  psql --username="$POSTGRES_USER" --dbname="$POSTGRES_DB" \
  -c "INSERT INTO public.backup_log (backup_type, status, size_bytes, duration_secs, notes)
      VALUES ('pg_basebackup', 'success', $BB_SIZE, $DURATION,
              'timestamp: $TIMESTAMP')" 2>/dev/null || \
  log "  (backup_log table not yet created — run init/04_backup_log.sql)"

# ── Offsite sync ───────────────────────────────────────────────────────────────

SYNC_SCRIPT="$SCRIPT_DIR/offsite_sync.sh"
if [[ -f "$SYNC_SCRIPT" ]] && [[ "${ENABLE_OFFSITE_SYNC:-true}" == "true" ]]; then
  log "Triggering offsite sync (basebackup + dumps)..."
  bash "$SYNC_SCRIPT" 2>&1 | tee -a "$LOG_FILE" || \
    log "WARNING: Offsite sync failed — backup is local only"
fi

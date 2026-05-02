#!/usr/bin/env bash
# Syncs local backups to S3 or Backblaze B2 using the AWS CLI.
# Backblaze B2 exposes an S3-compatible endpoint, so the same tool works for both.
#
# Prerequisites:
#   brew install awscli
#
# Required .env variables:
#   BACKUP_BUCKET      — S3 bucket name (e.g. "my-pg-dr-backups")
#
# For AWS S3 — also set one of:
#   AWS_PROFILE        — named profile from ~/.aws/credentials
#   AWS_ACCESS_KEY_ID + AWS_SECRET_ACCESS_KEY
#
# For Backblaze B2 — also set:
#   B2_ENDPOINT_URL    — e.g. "https://s3.us-west-004.backblazeb2.com"
#   AWS_ACCESS_KEY_ID  — B2 Application Key ID
#   AWS_SECRET_ACCESS_KEY — B2 Application Key
#
# Usage:
#   bash scripts/backup/offsite_sync.sh               # sync dumps + basebackups
#   bash scripts/backup/offsite_sync.sh --dumps-only  # sync dumps only
#   bash scripts/backup/offsite_sync.sh --dry-run     # show what would be synced

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

: "${BACKUP_DIR:=$PROJECT_DIR/backups}"
: "${BACKUP_BUCKET:?BACKUP_BUCKET not set in .env — set to your S3/B2 bucket name}"

MODE="${1:-}"
DRY_RUN_FLAG=""
[[ "$MODE" == "--dry-run" ]] && DRY_RUN_FLAG="--dryrun"

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
REMOTE_PREFIX="s3://${BACKUP_BUCKET}/postgres-dr"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [offsite_sync] $*"; }

# ── Build aws CLI command ──────────────────────────────────────────────────────

AWS_CMD=(aws)
[[ -n "${AWS_PROFILE:-}" ]] && AWS_CMD+=(--profile "$AWS_PROFILE")
[[ -n "${B2_ENDPOINT_URL:-}" ]] && AWS_CMD+=(--endpoint-url "$B2_ENDPOINT_URL")

# ── Verify aws CLI is available ────────────────────────────────────────────────

if ! command -v aws &>/dev/null; then
  log "ERROR: AWS CLI not found. Install with: brew install awscli"
  log "       Then configure credentials in ~/.aws/credentials or .env"
  exit 1
fi

# ── Sync function ──────────────────────────────────────────────────────────────

sync_dir() {
  local local_dir="$1"
  local remote_path="$2"
  local label="$3"

  if [[ ! -d "$local_dir" ]]; then
    log "SKIP: $label — directory does not exist: $local_dir"
    return
  fi

  local local_size
  local_size=$(du -sh "$local_dir" | cut -f1)
  log "Syncing $label ($local_size) → ${remote_path} ..."

  "${AWS_CMD[@]}" s3 sync \
    "$local_dir" \
    "$remote_path" \
    --delete \
    --storage-class STANDARD_IA \
    $DRY_RUN_FLAG \
    2>&1

  log "  $label sync complete."
}

# ── Run syncs ──────────────────────────────────────────────────────────────────

log "=== Offsite sync starting (target: $REMOTE_PREFIX) ==="
[[ -n "$DRY_RUN_FLAG" ]] && log "[DRY RUN MODE]"

sync_dir \
  "$BACKUP_DIR/dumps" \
  "$REMOTE_PREFIX/dumps" \
  "pg_dump backups"

if [[ "$MODE" != "--dumps-only" ]]; then
  sync_dir \
    "$BACKUP_DIR/basebackup" \
    "$REMOTE_PREFIX/basebackup" \
    "pg_basebackup"
fi

log "=== Offsite sync complete ==="
log "Remote location: $REMOTE_PREFIX"

#!/usr/bin/env bash
# Validates integrity of pg_dump and pg_basebackup files.
# Reads backup metadata and checks archives without restoring data.
#
# Usage:
#   bash scripts/backup/verify_backup.sh --latest-dump
#   bash scripts/backup/verify_backup.sh --latest-basebackup
#   bash scripts/backup/verify_backup.sh --dump /path/to/dump/dir
#   bash scripts/backup/verify_backup.sh --basebackup /path/to/backup/dir

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
: "${POSTGRES_USER:?POSTGRES_USER not set in .env}"
: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD not set in .env}"
: "${POSTGRES_DB:=warehouse}"
: "${CONTAINER:=postgres_production}"

MODE="${1:---latest-dump}"
BACKUP_PATH="${2:-}"
PASS=0
FAIL=0

pass() { echo "  [PASS] $*"; ((PASS++)) || true; }
fail() { echo "  [FAIL] $*"; ((FAIL++)) || true; }
info() { echo ""; echo "=== $* ==="; }

# ── Resolve target directory ───────────────────────────────────────────────────

case "$MODE" in
  --latest-dump)
    BACKUP_PATH=$(ls -1dt "$BACKUP_DIR/dumps/daily/20"* 2>/dev/null | head -1 || true)
    [[ -z "$BACKUP_PATH" ]] && { echo "No dumps found in $BACKUP_DIR/dumps/daily/"; exit 1; }
    echo "Verifying latest dump: $BACKUP_PATH"
    MODE="--dump"
    ;;
  --latest-basebackup)
    BACKUP_PATH=$(ls -1dt "$BACKUP_DIR/basebackup/20"* 2>/dev/null | head -1 || true)
    [[ -z "$BACKUP_PATH" ]] && { echo "No basebackups found in $BACKUP_DIR/basebackup/"; exit 1; }
    echo "Verifying latest basebackup: $BACKUP_PATH"
    MODE="--basebackup"
    ;;
  --dump|--basebackup)
    [[ -z "$BACKUP_PATH" ]] && { echo "Usage: $0 $MODE /path/to/backup/dir"; exit 1; }
    ;;
  *)
    echo "Usage: $0 [--latest-dump | --latest-basebackup | --dump DIR | --basebackup DIR]"
    exit 1
    ;;
esac

[[ -d "$BACKUP_PATH" ]] || { echo "ERROR: $BACKUP_PATH does not exist."; exit 1; }

# ── Verify pg_dump files ───────────────────────────────────────────────────────

if [[ "$MODE" == "--dump" ]]; then
  info "Verifying pg_dump backup: $BACKUP_PATH"

  # MANIFEST
  if [[ -f "$BACKUP_PATH/MANIFEST" ]]; then
    pass "MANIFEST file exists"
    echo ""
    cat "$BACKUP_PATH/MANIFEST" | sed 's/^/    /'
    echo ""
  else
    fail "MANIFEST file missing"
  fi

  # Each .dump file
  DUMP_COUNT=0
  for dump_file in "$BACKUP_PATH"/*.dump; do
    [[ -f "$dump_file" ]] || continue
    schema=$(basename "$dump_file" .dump)
    size=$(du -sh "$dump_file" | cut -f1)
    ((DUMP_COUNT++))

    size_bytes=$(stat -f%z "$dump_file" 2>/dev/null || stat -c%s "$dump_file" 2>/dev/null || echo 0)
    if [[ "$size_bytes" -gt 0 ]]; then
      pass "${schema}.dump is non-empty ($size)"
    else
      fail "${schema}.dump is empty"
      continue
    fi

    # Check PostgreSQL custom format magic bytes: first 5 bytes must be "PGDMP"
    # This is fast (reads only 5 bytes) and detects truncated/wrong-format files.
    magic=$(head -c 5 "$dump_file" 2>/dev/null | od -A n -t x1 | tr -d ' \n')
    if [[ "$magic" == "5047444d50"* ]]; then
      pass "${schema}.dump has valid PostgreSQL custom format magic (PGDMP)"
    else
      fail "${schema}.dump magic bytes invalid (expected PGDMP, got: $magic) — wrong format or corrupt"
    fi
  done

  if [[ $DUMP_COUNT -eq 0 ]]; then
    fail "No .dump files found in $BACKUP_PATH"
  fi

  # schema_only.sql
  if [[ -f "$BACKUP_PATH/schema_only.sql" ]]; then
    if grep -q "CREATE TABLE" "$BACKUP_PATH/schema_only.sql" 2>/dev/null; then
      pass "schema_only.sql contains CREATE TABLE statements"
    else
      fail "schema_only.sql does not contain expected DDL"
    fi
  else
    fail "schema_only.sql missing"
  fi

  # globals.sql
  if [[ -f "$BACKUP_PATH/globals.sql" ]]; then
    g_size=$(stat -f%z "$BACKUP_PATH/globals.sql" 2>/dev/null || stat -c%s "$BACKUP_PATH/globals.sql" 2>/dev/null || echo 0)
    if [[ "$g_size" -gt 0 ]]; then
      pass "globals.sql is non-empty"
    else
      fail "globals.sql is empty"
    fi
  else
    fail "globals.sql missing"
  fi
fi

# ── Verify pg_basebackup files ─────────────────────────────────────────────────

if [[ "$MODE" == "--basebackup" ]]; then
  info "Verifying pg_basebackup: $BACKUP_PATH"

  # MANIFEST
  if [[ -f "$BACKUP_PATH/MANIFEST" ]]; then
    pass "MANIFEST file exists"
    echo ""
    cat "$BACKUP_PATH/MANIFEST" | sed 's/^/    /'
    echo ""
  else
    fail "MANIFEST file missing"
  fi

  # base.tar.gz
  if [[ -f "$BACKUP_PATH/base.tar.gz" ]]; then
    size=$(du -sh "$BACKUP_PATH/base.tar.gz" | cut -f1)
    pass "base.tar.gz exists ($size)"

    if tar -tzf "$BACKUP_PATH/base.tar.gz" > /dev/null 2>&1; then
      pass "base.tar.gz passes tar integrity check"

      if tar -tzf "$BACKUP_PATH/base.tar.gz" 2>/dev/null | grep -q "^PG_VERSION$"; then
        pass "PG_VERSION found inside base.tar.gz"
      else
        fail "PG_VERSION NOT found inside base.tar.gz"
      fi

      if tar -tzf "$BACKUP_PATH/base.tar.gz" 2>/dev/null | grep -q "^postgresql.conf$"; then
        pass "postgresql.conf found inside base.tar.gz"
      else
        fail "postgresql.conf NOT found inside base.tar.gz"
      fi
    else
      fail "base.tar.gz failed tar integrity check — file may be corrupt or truncated"
    fi
  else
    fail "base.tar.gz does not exist"
  fi

  # pg_wal.tar.gz (present when --wal-method=stream was used)
  if [[ -f "$BACKUP_PATH/pg_wal.tar.gz" ]]; then
    size=$(du -sh "$BACKUP_PATH/pg_wal.tar.gz" | cut -f1)
    pass "pg_wal.tar.gz exists ($size)"
    if tar -tzf "$BACKUP_PATH/pg_wal.tar.gz" > /dev/null 2>&1; then
      pass "pg_wal.tar.gz passes tar integrity check"
    else
      fail "pg_wal.tar.gz failed tar integrity check"
    fi
  else
    fail "pg_wal.tar.gz missing — WAL not included (backup may not be self-contained)"
  fi
fi

# ── Summary ────────────────────────────────────────────────────────────────────

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Verification: $PASS passed, $FAIL failed"

if [[ $FAIL -gt 0 ]]; then
  echo "RESULT: BACKUP VERIFICATION FAILED"
  exit 1
else
  echo "RESULT: BACKUP VERIFIED SUCCESSFULLY"
  exit 0
fi

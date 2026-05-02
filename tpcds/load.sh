#!/bin/bash
# Bulk-load TPC-DS .dat files into the raw schema.
# Requires: psql, the warehouse DB must be up, and data/ must exist.
# Run from the project root: bash tpcds/load.sh
#
# Override connection defaults via env:
#   PGHOST   PGPORT   PGUSER   PGDATABASE

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$(dirname "$SCRIPT_DIR")/data"

: "${PGHOST:=127.0.0.1}"
: "${PGPORT:=5434}"
: "${PGUSER:=${POSTGRES_USER:-satyaki}}"
: "${PGDATABASE:=${POSTGRES_DB:-warehouse}}"

if [[ ! -d "$DATA_DIR" ]]; then
  echo "ERROR: $DATA_DIR not found. Run tpcds/generate.sh first."
  exit 1
fi

psql_exec() {
  psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" "$@"
}

# Pad every row to the table's declared column count, then COPY.
# This is needed because dsdgen's trailing-pipe stripping (in generate.sh)
# also removes the trailing pipe that represents a NULL last column on some rows.
copy_table() {
  local table="$1"
  local file="$DATA_DIR/${table}.dat"

  if [[ ! -f "$file" ]]; then
    echo "  SKIP: $file not found"
    return
  fi

  local ncols
  ncols=$(psql_exec -t -c "SELECT count(*) FROM information_schema.columns WHERE table_schema='raw' AND table_name='$table';" | tr -d ' \n')

  echo "  Loading raw.$table (${ncols} cols) ..."
  local tmp
  tmp="$(mktemp /tmp/${table}_XXXXXX.dat)"
  awk -v ncols="$ncols" 'BEGIN{FS=OFS="|"} { while (NF < ncols) $(NF+1)=""; print }' "$file" > "$tmp"
  psql_exec -c "\COPY raw.$table FROM '$tmp' WITH (FORMAT csv, DELIMITER '|', NULL '', QUOTE E'\x01')"
  rm -f "$tmp"
}

echo "=== TPC-DS SF10 Load ==="
echo "Host: $PGHOST:$PGPORT  DB: $PGDATABASE  User: $PGUSER"
echo ""

# Dimension tables first (facts reference them)
echo "--- Dimensions ---"
copy_table date_dim
copy_table time_dim
copy_table customer
copy_table customer_demographics
copy_table customer_address
copy_table item
copy_table store
copy_table promotion
copy_table household_demographics
copy_table web_site
copy_table web_page
copy_table warehouse
copy_table ship_mode
copy_table reason
copy_table income_band
copy_table call_center
copy_table catalog_page

echo ""
echo "--- Facts ---"
copy_table store_sales
copy_table store_returns
copy_table web_sales
copy_table web_returns
copy_table catalog_sales
copy_table catalog_returns
copy_table inventory

echo ""
echo "=== Load complete. Row counts ==="
psql_exec -c "
SELECT schemaname, relname, n_live_tup AS rows
FROM   pg_stat_user_tables
WHERE  schemaname = 'raw'
ORDER  BY n_live_tup DESC;
"

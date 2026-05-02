#!/bin/bash
# Build dsdgen and generate TPC-DS data at SF 10.
# Output goes to ../data/ (gitignored, ~10 GB).
# Run from the project root: bash tpcds/generate.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$PROJECT_DIR/data"
TPCDS_KIT_DIR="$SCRIPT_DIR/tpcds-kit"

# ── Clone (skip if already present) ──────────────────────────────────────────
if [[ ! -d "$TPCDS_KIT_DIR" ]]; then
  echo "Cloning tpcds-kit..."
  git clone --depth 1 https://github.com/gregrahn/tpcds-kit.git "$TPCDS_KIT_DIR"
else
  echo "tpcds-kit already cloned, skipping."
fi

# ── Build dsdgen ──────────────────────────────────────────────────────────────
if [[ ! -f "$TPCDS_KIT_DIR/tools/dsdgen" ]]; then
  echo "Building dsdgen..."

  # Newer Clang (macOS Xcode 15+) treats K&R implicit-int as a hard error.
  # Patch the Makefile to suppress those errors before building.
  if [[ "$(uname)" == "Darwin" ]]; then
    sed -i '' \
      's/-Wall/-Wall -Wno-implicit-int -Wno-deprecated-non-prototype/' \
      "$TPCDS_KIT_DIR/tools/Makefile"
    make -C "$TPCDS_KIT_DIR/tools" OS=MACOS
  else
    make -C "$TPCDS_KIT_DIR/tools" OS=LINUX
  fi

  echo "dsdgen built successfully."
else
  echo "dsdgen already built, skipping."
fi

# ── Generate data ─────────────────────────────────────────────────────────────
mkdir -p "$DATA_DIR"

# dsdgen cannot handle directory paths that contain spaces.
# Use a stable temp dir without spaces and move the files afterwards.
TEMP_DIR="/tmp/tpcds_sf10"
mkdir -p "$TEMP_DIR"

cd "$TPCDS_KIT_DIR/tools"

echo "Generating TPC-DS SF 10 data into $TEMP_DIR ..."
echo "This takes ~20-30 minutes."

./dsdgen \
  -scale 10 \
  -dir "$TEMP_DIR" \
  -force \
  -suffix .dat \
  -terminate n

# Strip trailing pipe delimiter that dsdgen appends to every row.
echo "Stripping trailing delimiters..."
if [[ "$(uname)" == "Darwin" ]]; then
  find "$TEMP_DIR" -name "*.dat" -exec sed -i '' 's/|$//' {} +
else
  find "$TEMP_DIR" -name "*.dat" -exec sed -i 's/|$//' {} +
fi

# Move generated files to the real data directory.
echo "Moving files to $DATA_DIR ..."
mv "$TEMP_DIR"/*.dat "$DATA_DIR/"

echo ""
echo "Done. Files in $DATA_DIR:"
ls -lh "$DATA_DIR"/*.dat

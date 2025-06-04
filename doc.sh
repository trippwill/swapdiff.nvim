#!/bin/sh
set -e

# Generate documentation for a Neovim plugin using vimcats.
# $ sh doc.sh path/to/outfile.txt path/to/filelist

VIMCATS_ARGS="${VIMCATS_ARGS:--fact}"
FILE_LIST="${2:-doclist}"
OUTPUT_FILE="${1:-doc/plugin.txt}"

if ! command -v vimcats >/dev/null 2>&1; then
  echo "vimcats is not installed."
  if ! command -v cargo >/dev/null 2>&1; then
    echo "cargo is not installed. Please install Rust and Cargo first."
    exit 1
  fi
  echo "Installing vimcats now..."
  cargo install vimcats --features=cli
fi

set --
while IFS= read -r file; do
  if [ -f "$file" ]; then
    set -- "$@" "$file"
  else
    echo "Warning: '$file' does not exist or is not a regular file."
  fi

done <"$FILE_LIST"

if [ $# -eq 0 ]; then
  echo "No valid files found in '$FILE_LIST'. Exiting."
  exit 1
fi

vimcats "$VIMCATS_ARGS" "$@" >"$OUTPUT_FILE"

less "$OUTPUT_FILE"

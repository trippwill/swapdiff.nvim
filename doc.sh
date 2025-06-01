#!/bin/sh

# Generate documentation for the swapdiff.nvim plugin using vimcats.
# $ sh doc.sh

OUTPUT_DIR="${OUTPUT_DIR:-$PWD/doc}"
OUTPUT_FILE="${OUTPUT_FILE:-$OUTPUT_DIR/swapdiff.nvim.txt}"
INPUT_DIR="${INPUT_DIR:-lua/swapdiff}"
INPUT_FILES="${INPUT_FILES:-types init handlers bufferline util log}"
VIMCATS_ARGS="${VIMCATS_ARGS:--fact}"

mkdir -p "$OUTPUT_DIR"

if ! command -v vimcats >/dev/null 2>&1; then
  echo "vimcats is not installed. Installing it now..."
  cargo install vimcats --features=cli
fi

set --
for file in $INPUT_FILES; do
  if [ -f "$INPUT_DIR/$file.lua" ]; then
    set -- "$@" "$INPUT_DIR/$file.lua"
  else
    echo "Warning: File $INPUT_DIR/$file.lua does not exist."
  fi
done

vimcats "$VIMCATS_ARGS" "$@" >"$OUTPUT_FILE"

less "$OUTPUT_FILE"

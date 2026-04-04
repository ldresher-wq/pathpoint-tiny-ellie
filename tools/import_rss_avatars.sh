#!/bin/zsh
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 <source_dir> [destination_dir]" >&2
  exit 1
fi

SOURCE_DIR="$1"
DEST_DIR="${2:-LilAgents/ExpertAvatars}"
TARGET_SIZE="${TARGET_SIZE:-256}"

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "Source directory not found: $SOURCE_DIR" >&2
  exit 1
fi

mkdir -p "$DEST_DIR"

normalize_name() {
  local input="$1"
  local name="${input%_pixel_art.png}"
  name="${name// /-}"
  name="${name//_/-}"
  name="$(printf '%s' "$name" | tr -s '-')"
  printf '%s_pixel_art.png' "$name"
}

count=0
for src in "$SOURCE_DIR"/*.png; do
  [[ -f "$src" ]] || continue

  local_name="$(basename "$src")"
  dest_name="$(normalize_name "$local_name")"
  dest_path="$DEST_DIR/$dest_name"

  cp "$src" "$dest_path"
  sips -Z "$TARGET_SIZE" "$dest_path" >/dev/null

  count=$((count + 1))
  printf 'Imported %s -> %s\n' "$local_name" "$dest_name"
done

printf 'Imported %d avatar(s) into %s at %sx%s\n' "$count" "$DEST_DIR" "$TARGET_SIZE" "$TARGET_SIZE"

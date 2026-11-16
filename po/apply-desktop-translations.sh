#!/usr/bin/env bash
# Write Name[<lang>]= (and other localized keys) into the menu entries under
# rootfs/ from po/*.po. The files are installed as-is by the ISO build, so the
# translations live in the files, like KDE's own .desktop files. Idempotent.
set -euo pipefail
cd "$(dirname "$0")/.."
grep -oP '^\[Desktop\]\s+\K.*' po/POTFILES.in | while read -r f; do
  tmp=$(mktemp)
  grep -vE '^(Name|GenericName|Comment|Keywords)\[' "$f" > "$tmp.src"
  msgfmt --desktop --template="$tmp.src" -d po -o "$tmp"
  if ! cmp -s "$tmp" "$f"; then cp "$tmp" "$f"; echo "updated $f"; fi
  rm -f "$tmp" "$tmp.src"
done

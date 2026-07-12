#!/usr/bin/env bash
# models/update.sh — Download/update every model in list.txt from HuggingFace (skips unchanged files).
#   ./models/update.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="$HOME/.local/bin:$PATH"

while IFS=$'\t' read -r folder repo file rename; do
    [[ -z "$folder" || "$folder" == \#* ]] && continue
    dest_dir="$SCRIPT_DIR/$folder"
    hf download "$repo" "$file" --local-dir "$dest_dir"

    # Optional 4th column: local filename, for repo files that would otherwise
    # collide (e.g. same basename across two repos landing in the same folder).
    [[ -n "$rename" ]] && mv -f "$dest_dir/$file" "$dest_dir/$rename"
done < "$SCRIPT_DIR/list.txt"

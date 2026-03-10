#!/bin/bash
# push.sh - Add HTML/MD files and push to GitHub Pages
# Usage: ./push.sh [file_or_folder...]
# No args = push all changes

cd "$(dirname "$0")"

if [ $# -gt 0 ]; then
    for f in "$@"; do
        cp -r "$f" . 2>/dev/null && echo "Added: $f"
    done
fi

git add -A
git commit -m "Update $(date '+%Y-%m-%d %H:%M')" 2>/dev/null
git push origin main
echo "Done! Site: https://williamlorder.github.io/reading-papers/"

#!/bin/bash
# Generate files.json manifest for the website
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$REPO_DIR"

echo "[" > files.json.tmp
FIRST=1

for section in Reading output markdown; do
    [ -d "$section" ] || continue
    find "$section" -type f \( -name "*.html" -o -name "*.htm" -o -name "*.md" \) | while read -r filepath; do
        # Skip katex/cm-fonts internal files
        echo "$filepath" | grep -qE "(katex|cm-fonts)/" && continue
        
        name=$(basename "$filepath")
        date=$(stat -f "%Sm" -t "%Y-%m-%d" "$filepath" 2>/dev/null || date +%Y-%m-%d)
        
        # Try extract date from filename
        fname_date=$(echo "$name" | grep -oE '[0-9]{4}[_年-][0-9]{1,2}[_月-][0-9]{1,2}' | head -1)
        if [ -n "$fname_date" ]; then
            y=$(echo "$fname_date" | grep -oE '^[0-9]{4}')
            m=$(echo "$fname_date" | sed 's/^[0-9]*[_年-]//' | grep -oE '^[0-9]*')
            d=$(echo "$fname_date" | grep -oE '[0-9]*$')
            date=$(printf "%s-%02d-%02d" "$y" "$m" "$d")
        fi
        
        if [ "$FIRST" = "1" ]; then
            FIRST=0
        else
            echo "," >> files.json.tmp
        fi
        printf '  {"section":"%s","path":"%s","name":"%s","date":"%s"}' "$section" "$filepath" "$name" "$date" >> files.json.tmp
    done
done

echo "" >> files.json.tmp
echo "]" >> files.json.tmp
mv files.json.tmp files.json

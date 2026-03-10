#!/bin/bash
# sync.sh - Real-time bidirectional sync for reading-papers
# Watches local for new files → auto push
# Polls remote for changes → auto pull

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$REPO_DIR"

POLL_INTERVAL=30  # seconds between remote checks

echo "📚 Reading Papers Sync started"
echo "   Local:  $REPO_DIR"
echo "   Remote: https://williamlorder.github.io/reading-papers/"
echo "   Watching for changes... (Ctrl+C to stop)"
echo ""

# Auto-push on local changes
do_push() {
    cd "$REPO_DIR"
    git add -A
    if ! git diff --cached --quiet 2>/dev/null; then
        git commit -m "Auto-sync $(date '+%Y-%m-%d %H:%M:%S')" > /dev/null 2>&1
        if git push origin main 2>/dev/null; then
            echo "$(date '+%H:%M:%S') ⬆ Pushed local changes"
        else
            echo "$(date '+%H:%M:%S') ⚠ Push failed, will retry"
        fi
    fi
}

# Auto-pull remote changes
do_pull() {
    cd "$REPO_DIR"
    git fetch origin main --quiet 2>/dev/null
    LOCAL=$(git rev-parse HEAD 2>/dev/null)
    REMOTE=$(git rev-parse origin/main 2>/dev/null)
    if [ "$LOCAL" != "$REMOTE" ]; then
        git pull --rebase origin main --quiet 2>/dev/null
        echo "$(date '+%H:%M:%S') ⬇ Pulled remote changes"
    fi
}

# Start fswatch in background for local changes
fswatch -o -e "\.git" -r "$REPO_DIR" | while read _; do
    sleep 2  # debounce
    do_push
done &
WATCH_PID=$!

# Poll remote periodically
while true; do
    do_pull
    sleep $POLL_INTERVAL
done &
POLL_PID=$!

# Cleanup on exit
trap "kill $WATCH_PID $POLL_PID 2>/dev/null; echo ''; echo 'Sync stopped.'; exit 0" INT TERM

# Keep alive
wait

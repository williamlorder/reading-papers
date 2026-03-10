#!/bin/bash
# sync-papers.sh - Real-time bidirectional sync for reading-papers

REPO_DIR="$HOME/WorkPlace/游戏/reading-papers"
cd "$REPO_DIR" || exit 1

POLL_INTERVAL=30

log() {
    echo "$(date '+%H:%M:%S') $1"
}

echo "📚 Reading Papers Sync started"
echo "   Local:  $REPO_DIR"
echo "   Remote: https://williamlorder.github.io/reading-papers/"
echo "   Watching for changes... (Ctrl+C to stop)"
echo ""

do_push() {
    cd "$REPO_DIR"
    # Regenerate files manifest for website
    bash "$REPO_DIR/gen-manifest.sh" 2>/dev/null
    git add -A
    if ! git diff --cached --quiet 2>/dev/null; then
        local files
        files=$(git diff --cached --name-only 2>/dev/null | grep -v '\.sync\.log' | head -5)
        git commit -m "Auto-sync $(date '+%Y-%m-%d %H:%M:%S')" > /dev/null 2>&1
        if git push origin main 2>&1 | tail -1; then
            log "⬆ Pushed: $files"
        else
            log "⚠ Push failed, will retry"
        fi
    fi
}

do_pull() {
    cd "$REPO_DIR"
    git fetch origin main --quiet 2>/dev/null
    LOCAL=$(git rev-parse HEAD 2>/dev/null)
    REMOTE=$(git rev-parse origin/main 2>/dev/null)
    if [ "$LOCAL" != "$REMOTE" ]; then
        git pull --rebase origin main --quiet 2>/dev/null
        log "⬇ Pulled remote changes"
    fi
}

# Cleanup on exit
cleanup() {
    [ -n "$WATCH_PID" ] && kill "$WATCH_PID" 2>/dev/null
    echo ""
    log "Sync stopped"
    exit 0
}
trap cleanup INT TERM

# fswatch detects changes → write to pipe → trigger push
fswatch --batch-marker=EOF -e "\.git" -e "\.sync" -r "$REPO_DIR" | while read line; do
    if [ "$line" = "EOF" ]; then
        sleep 2
        do_push
    fi
done &
WATCH_PID=$!

log "fswatch started (PID: $WATCH_PID)"

# Initial push of any pending changes
do_push

# Poll remote periodically
while true; do
    sleep "$POLL_INTERVAL"
    do_pull
done

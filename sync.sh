#!/bin/bash
# sync.sh - Real-time bidirectional sync for reading-papers
# Watches local for new files → auto push
# Polls remote for changes → auto pull

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$REPO_DIR"

POLL_INTERVAL=30  # seconds between remote checks
LOG="$REPO_DIR/.sync.log"

log() {
    local msg="$(date '+%Y-%m-%d %H:%M:%S') $1"
    echo "$msg" | tee -a "$LOG"
}

echo "📚 Reading Papers Sync started"
echo "   Local:  $REPO_DIR"
echo "   Remote: https://williamlorder.github.io/reading-papers/"
echo "   Log:    $LOG"
echo "   Watching for changes... (Ctrl+C to stop)"
echo ""
log "Sync started"

# Auto-push on local changes
do_push() {
    cd "$REPO_DIR"
    git add -A
    if ! git diff --cached --quiet 2>/dev/null; then
        local files=$(git diff --cached --name-only 2>/dev/null | head -5)
        git commit -m "Auto-sync $(date '+%Y-%m-%d %H:%M:%S')" > /dev/null 2>&1
        if git push origin main 2>/dev/null; then
            log "⬆ Pushed: $files"
        else
            log "⚠ Push failed, will retry"
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
        log "⬇ Pulled remote changes"
    fi
}

# Use a temp file to signal changes (avoids pipe subshell buffering)
TRIGGER="/tmp/sync-trigger-$$"

# fswatch writes to trigger file
fswatch -o -e "\.git" -r "$REPO_DIR" > "$TRIGGER" &
WATCH_PID=$!

# Main loop: check for local changes + poll remote
trap "kill $WATCH_PID 2>/dev/null; rm -f '$TRIGGER'; log 'Sync stopped'; echo ''; echo 'Sync stopped.'; exit 0" INT TERM

LAST_SIZE=0
while true; do
    # Check if fswatch detected changes
    if [ -f "$TRIGGER" ]; then
        CUR_SIZE=$(wc -c < "$TRIGGER" 2>/dev/null || echo 0)
        if [ "$CUR_SIZE" != "$LAST_SIZE" ]; then
            LAST_SIZE=$CUR_SIZE
            sleep 2  # debounce
            do_push
        fi
    fi

    # Poll remote every POLL_INTERVAL cycles (each cycle ~3s)
    COUNTER=${COUNTER:-0}
    COUNTER=$((COUNTER + 1))
    if [ $COUNTER -ge $((POLL_INTERVAL / 3)) ]; then
        do_pull
        COUNTER=0
    fi

    sleep 3
done

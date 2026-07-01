#!/usr/bin/env bash
# sync.sh — smart auto git-pull
#
# Active window (when you might be pushing from another laptop):
#   Weekday (Mon–Fri): 09:00–21:00
#   Weekend (Sat–Sun): 09:00–23:00
# Outside window: sleep until next window opens — no network calls at all.
# Inside window:  git fetch every 10 min; merge only when behind.

INTERVAL=600    # 10 min inside active window
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="$REPO_DIR/.sync.log"

log() { printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*" | tee -a "$LOG"; }

# Returns end hour for today (21 weekday / 23 weekend)
active_end_hour() {
    local dow; dow=$(date +%u)   # 1=Mon … 7=Sun
    if (( dow >= 6 )); then echo 23; else echo 21; fi
}

# Seconds until 09:00 tomorrow
secs_until_tomorrow_9() {
    local tomorrow_9; tomorrow_9=$(date -d 'tomorrow 09:00' +%s)
    echo $(( tomorrow_9 - $(date +%s) ))
}

in_active_window() {
    local hour; hour=$(( 10#$(date +%H) ))
    local end; end=$(active_end_hour)
    (( hour >= 9 && hour < end ))
}

cd "$REPO_DIR"
log "sync: started  weekday 09–21  weekend 09–23  interval=${INTERVAL}s"

while true; do
    if ! in_active_window; then
        local wait; wait=$(secs_until_tomorrow_9)
        log "sync: off-hours — sleeping ${wait}s until 09:00"
        sleep "$wait"
        continue
    fi

    if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
        log "sync: local changes present — skipping"
        sleep "$INTERVAL"
        continue
    fi

    if git fetch origin main --quiet 2>/dev/null; then
        local_hash=$(git rev-parse HEAD 2>/dev/null)
        remote_hash=$(git rev-parse origin/main 2>/dev/null)
        if [[ "$local_hash" != "$remote_hash" ]]; then
            log "sync: behind remote → pulling"
            git merge --ff-only origin/main >> "$LOG" 2>&1 \
                && log "sync: pulled OK" \
                || log "sync: merge failed (diverged?)"
        fi
    else
        log "sync: fetch failed (offline?)"
    fi

    sleep "$INTERVAL"
done

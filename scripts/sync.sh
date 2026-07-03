#!/usr/bin/env bash
# Auto pull during the hours when this repo may be edited from another machine.
#
# Window:
#   Mon-Fri  09:00-21:00
#   Sat-Sun  09:00-23:00
#
# Outside the window, the script sleeps until the next 09:00 and makes no
# network calls. Inside the window, it fetches every INTERVAL seconds and only
# fast-forwards when the local worktree is clean.

set -euo pipefail

INTERVAL="${INTERVAL:-600}"
LOG_RETAIN_DAYS="${LOG_RETAIN_DAYS:-6}" # keep today plus the previous 6 days
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="$REPO_DIR/.sync.log"

log() {
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG"
}

trim_log() {
    [[ -f "$LOG" ]] || return 0

    local cutoff start tmp
    cutoff="$(date -d "${LOG_RETAIN_DAYS} days ago" '+%Y-%m-%d')"
    start="$(awk -v c="$cutoff" '
        match($0, /^\[([0-9]{4})-([0-9]{2})-([0-9]{2})/, a) {
            if (a[1] "-" a[2] "-" a[3] >= c) { print NR; exit }
        }
    ' "$LOG")"

    if [[ -n "$start" && "$start" -gt 1 ]]; then
        tmp="$(mktemp)"
        tail -n +"$start" "$LOG" > "$tmp"
        mv "$tmp" "$LOG"
    fi
}

active_end_hour() {
    local dow
    dow="$(date +%u)" # 1=Mon ... 7=Sun
    if (( dow >= 6 )); then
        echo 23
    else
        echo 21
    fi
}

in_active_window() {
    local hour end
    hour=$((10#$(date +%H)))
    end="$(active_end_hour)"
    (( hour >= 9 && hour < end ))
}

seconds_until_next_window() {
    local now target
    now="$(date +%s)"
    if (( 10#$(date +%H) < 9 )); then
        target="$(date -d 'today 09:00' +%s)"
    else
        target="$(date -d 'tomorrow 09:00' +%s)"
    fi
    echo $(( target - now ))
}

worktree_clean() {
    [[ -z "$(git status --porcelain --untracked-files=all)" ]]
}

sync_once() {
    trim_log

    if ! in_active_window; then
        log "sync: off-hours"
        return 0
    fi

    if ! worktree_clean; then
        log "sync: local changes present; skipping"
        return 0
    fi

    if ! git fetch origin main --quiet; then
        log "sync: fetch failed"
        return 0
    fi

    local local_hash remote_hash base_hash
    local_hash="$(git rev-parse HEAD)"
    remote_hash="$(git rev-parse origin/main)"
    base_hash="$(git merge-base HEAD origin/main)"

    if [[ "$local_hash" == "$remote_hash" ]]; then
        log "sync: up to date"
    elif [[ "$local_hash" == "$base_hash" ]]; then
        log "sync: behind remote; fast-forwarding"
        git merge --ff-only origin/main >> "$LOG" 2>&1 \
            && log "sync: pulled OK" \
            || log "sync: fast-forward failed"
    else
        log "sync: diverged; manual intervention needed"
    fi
}

main() {
    cd "$REPO_DIR"

    if [[ "${1:-}" == "--once" ]]; then
        sync_once
        return 0
    fi

    log "sync: started weekday 09-21 weekend 09-23 interval=${INTERVAL}s"
    while true; do
        if in_active_window; then
            sync_once
            sleep "$INTERVAL"
        else
            local wait
            wait="$(seconds_until_next_window)"
            log "sync: off-hours; sleeping ${wait}s until next 09:00"
            sleep "$wait"
        fi
    done
}

main "$@"

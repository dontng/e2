#!/bin/bash
# auto-review.sh — Autonomous English correction agent (Dell WSL2 daemon)
#
# Polls repo (default 10 min), git pull, runs Cursor Agent for each pending day:
#   批改 src → fool 拆解 → probe 内功诊断（仅田静每日一句）
# Push only after all three are verified complete.
#
# Usage:
#   ./auto-review.sh                      # default 10-minute poll
#   POLL_INTERVAL=600 ./auto-review.sh    # explicit interval (seconds)
#   ./auto-review.sh --once               # scan once and exit
#
# Requires: Cursor CLI (`agent`), CURSOR_API_KEY or `agent login`
# Model: AGENT_MODEL (default sonnet-4.6 = Claude 4.6 Sonnet)

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$REPO_DIR/.auto-review.log"
PROCESSING_LOCK_FILE="$REPO_DIR/.auto-review-processing"
PUSH_PENDING_FILE="$REPO_DIR/.auto-review-push-pending"
POLL_INTERVAL="${POLL_INTERVAL:-600}"    # 10 minutes
LOG_RETAIN_DAYS="${LOG_RETAIN_DAYS:-7}"
ONCE_MODE=false

# Cursor Agent CLI — pinned model; override on Dell: AGENT_MODEL=... ./auto-review.sh
# List account models: agent models
AGENT_BIN="${AGENT_BIN:-agent}"
AGENT_MODEL="${AGENT_MODEL:-sonnet-4.6}"

[[ "${1:-}" == "--once" ]] && ONCE_MODE=true

# stdout may already be LOG_FILE (nohup ... >> .auto-review.log 2>&1) —
# in that case tee-ing to the file again would write every line twice.
# Must inspect /proc/$$/fd/1 (the script's stdout), not /proc/self/fd/1:
# inside $(...) fd 1 is the capture pipe and would never match.
stdout_is_log() {
    [[ "$(readlink -f /proc/$$/fd/1 2>/dev/null)" == "$(readlink -f "$LOG_FILE")" ]]
}

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    if stdout_is_log; then echo "$msg"; else echo "$msg" | tee -a "$LOG_FILE"; fi
}

tee_log() { if stdout_is_log; then cat; else tee -a "$LOG_FILE"; fi; }

# shellcheck source=scripts/console.sh
source "$REPO_DIR/scripts/console.sh"
# shellcheck source=scripts/nav.sh
source "$REPO_DIR/scripts/nav.sh"
# shellcheck source=scripts/probe.sh
source "$REPO_DIR/scripts/probe.sh"

agent_rate_limited() {
    grep -qiE "rate.?limit|usage.?limit|too many request|quota|overloaded|529|429" "$1"
}

# Run Cursor Agent headless. Return 0 success, 1 error, 2 rate limit.
run_agent() {
    local prompt="$1"
    if ! command -v "$AGENT_BIN" &>/dev/null; then
        log "ERROR: $AGENT_BIN not found — install: curl https://cursor.com/install -fsS | bash"
        return 1
    fi
    local tmpout exit_code=0
    tmpout=$(mktemp)
    log "Agent model: $AGENT_MODEL"
    "$AGENT_BIN" -p --force --trust --workspace "$REPO_DIR" --model "$AGENT_MODEL" \
        "$prompt" > "$tmpout" 2>&1 || exit_code=$?
    cat "$tmpout" | tee_log
    if [[ $exit_code -ne 0 ]]; then
        if agent_rate_limited "$tmpout"; then
            log "Rate limit (exit $exit_code) — will back off"
            rm -f "$tmpout"
            return 2
        fi
        log "ERROR: agent exited $exit_code"
        rm -f "$tmpout"
        return 1
    fi
    rm -f "$tmpout"
    return 0
}

# Drop log lines with timestamps older than LOG_RETAIN_DAYS
trim_log() {
    local log_file="$1"
    [[ -f "$log_file" ]] || return 0
    local cutoff
    cutoff=$(date -d "${LOG_RETAIN_DAYS} days ago" '+%Y-%m-%d')
    local start
    start=$(awk -v c="$cutoff" '
        match($0, /\[([0-9]{4})[\/\-]([0-9]{2})[\/\-]([0-9]{2})/, a) {
            if (a[1] "-" a[2] "-" a[3] > c) { print NR; exit }
        }
    ' "$log_file")
    if [[ -n "$start" && "$start" -gt 1 ]]; then
        local tmp; tmp=$(mktemp)
        tail -n +"$start" "$log_file" > "$tmp" && mv "$tmp" "$log_file"
    fi
}

# Processing lock: signals that a correction/fool cycle is actively running.
# try_push checks this before pushing.
# The lock file contains the PID of auto-review.sh so stale locks (process dead) are ignored.
set_processing_lock()   { echo $$ > "$PROCESSING_LOCK_FILE"; }
clear_processing_lock() { rm -f "$PROCESSING_LOCK_FILE"; }
processing_locked() {
    [[ -f "$PROCESSING_LOCK_FILE" ]] || return 1
    local pid
    pid=$(cat "$PROCESSING_LOCK_FILE" 2>/dev/null) || return 1
    [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

# Push pending flag: set the moment uncorrected/fool-missing files are first detected.
# This is the "wakeup" signal — try_push stays active across idle cycles until push succeeds.
mark_push_pending()  { touch "$PUSH_PENDING_FILE"; }
clear_push_pending() { rm -f "$PUSH_PENDING_FILE"; }
push_pending()       { [[ -f "$PUSH_PENDING_FILE" ]]; }

# Interruptible sleep: studio touches WAKE_FILE after a save, cutting the wait
# from a full poll interval down to ≤15s.
WAKE_FILE="$REPO_DIR/.auto-review-wake"
poll_sleep() {
    local remaining="$1" step=15
    while (( remaining > 0 )); do
        if [[ -f "$WAKE_FILE" ]]; then
            rm -f "$WAKE_FILE"
            log "Wake signal — scanning immediately"
            return 0
        fi
        sleep "$(( remaining < step ? remaining : step ))"
        remaining=$(( remaining - step ))
    done
    return 0
}

# Return non-zero if git is locked by another process (user's manual git op in progress)
git_is_busy() {
    [[ -f "$REPO_DIR/.git/index.lock" ]] || [[ -f "$REPO_DIR/.git/MERGE_HEAD" ]] || [[ -f "$REPO_DIR/.git/rebase-merge" ]]
}

# Check a single file: returns 0 if it still needs review, 1 if already done
needs_review() {
    local f="$1"
    local translation correction
    translation=$(awk '
        /^## 我的理解和翻译/ { found=1; next }
        found && /^## /     { exit }
        found               { print }
    ' "$f" | grep -v '^[[:space:]]*$' || true)

    correction=$(awk '
        /^## 批改/      { found=1; next }
        found && /^## / { exit }
        found           { print }
    ' "$f" | grep -v '^[[:space:]]*$' || true)

    [[ -n "$translation" && -z "$correction" ]]
}

# Returns 0 if 批改 section has content — the file has been corrected.
# Guards fool generation: a freshly created (empty) day file must not be decomposed.
has_correction() {
    awk '/^## 批改/{f=1;next} f&&/^## /{exit} f' "$1" | grep -q '[^[:space:]]'
}

# Returns 0 if fool needs to be generated: fool file missing or has no entries.
# Deliberately does NOT re-trigger on source file edits — fool is generated once and kept.
needs_fool() {
    local source_file="$1"
    local fool_path="$2"
    [[ ! -f "$fool_path" ]] && return 0
    ! grep -q '^### fool-' "$fool_path"
}

# Find markdown files where 我的理解和翻译 has content but 批改 is empty
find_uncorrected() {
    find "$REPO_DIR/src" -name "*.md" -print0 | while IFS= read -r -d '' f; do
        if needs_review "$f"; then
            echo "$f"
        fi
    done
}

# Find day files needing any step of the pipeline (批改 / fool / probe)
find_pipeline_pending() {
    find "$REPO_DIR/src" -name "*-day*.md" -print0 | while IFS= read -r -d '' f; do
        day_paths "$f"
        if needs_review "$f"; then
            echo "$f"
        elif has_correction "$f" && needs_fool "$f" "$FOOL_PATH"; then
            echo "$f"
        elif has_correction "$f" && has_score "$f" && ! probe_complete "$PROBE_PATH"; then
            echo "$f"
        fi
    done
}

# Find corrected days whose probe is still incomplete (push gate)
find_probe_incomplete() {
    find "$REPO_DIR/src" -name "*-day*.md" -print0 | while IFS= read -r -d '' f; do
        day_paths "$f"
        if ! needs_review "$f" && has_correction "$f" && has_score "$f" && ! probe_complete "$PROBE_PATH"; then
            echo "$f"
        fi
    done
}

# Find probe files that need legacy migration (Q&A / 待诊断)
find_probe_needs_diagnose() {
    find "$REPO_DIR/src" -name "*-day*.md" -print0 | while IFS= read -r -d '' f; do
        day_paths "$f"
        if ! needs_review "$f" && has_score "$f" && needs_probe_diagnose "$PROBE_PATH"; then
            echo "$f"
        fi
    done
}

# Find files with ungraded 复习区 retranslations (main correction must already be done)
find_redo_pending() {
    find "$REPO_DIR/src" -name "*.md" -print0 | while IFS= read -r -d '' f; do
        if ! needs_review "$f" && needs_redo "$f"; then
            echo "$f"
        fi
    done
}

# Find corrected source files whose fool is missing (push gate / catch-up)
find_fool_missing() {
    find "$REPO_DIR/src" -name "*.md" -print0 | while IFS= read -r -d '' f; do
        day_paths "$f"
        if ! needs_review "$f" && has_correction "$f" && needs_fool "$f" "$FOOL_PATH"; then
            echo "$f"
        fi
    done
}

# Returns 0 if 复习区 has at least one block with 我的重译 filled but 复习批改 empty.
# Logic lives in scripts/review.py — single owner of 复习区 parsing.
needs_redo() {
    python3 "$REPO_DIR/scripts/review.py" pending "$1"
}

# Agent-call guard: skip re-invoke until file changes
declare -A _FAILED_HASH
guard_hit()  { [[ "${_FAILED_HASH[$1:$2]:-}" == "$(md5sum "$2" | awk '{print $1}')" ]]; }
guard_mark() { _FAILED_HASH[$1:$2]=$(md5sum "$2" | awk '{print $1}'); }

day_pipeline_verified() {
    local f="$1"
    day_paths "$f"
    has_correction "$f" && has_score "$f" \
        && ! needs_fool "$f" "$FOOL_PATH" \
        && probe_complete "$PROBE_PATH"
}

# shellcheck source=scripts/day-pipeline-prompt.sh
source "$REPO_DIR/scripts/day-pipeline-prompt.sh"

# Unified 批改 → fool → probe. Return 0 success, 1 error, 2 rate limit.
process_day_file() {
    local file="$1"
    day_paths "$file"
    local rel="$DAY_REL"
    mkdir -p "$(dirname "$FOOL_PATH")" "$(dirname "$PROBE_PATH")"
    log "Day pipeline: $rel → 批改·fool·probe"
    local prompt
    prompt=$(build_day_pipeline_prompt "$file" "$FOOL_PATH" "$PROBE_PATH")
    local rc=0
    run_agent "$prompt" || rc=$?
    [[ $rc -ne 0 ]] && return "$rc"
    if day_pipeline_verified "$file"; then
        log "Pipeline verified: $rel"
        return 0
    fi
    log "ERROR: pipeline incomplete after agent for $rel"
    return 1
}

# Legacy probe only (Q&A → 新格式). Return 0 success, 1 error, 2 rate limit.
probe_migrate_file() {
    local source_file="$1"
    local probe_path="$2"
    local rel="${source_file#$REPO_DIR/}"
    log "Probe migrate: $rel"
    mkdir -p "$(dirname "$probe_path")"
    local prompt
    prompt=$(build_probe_migrate_prompt "$source_file" "$probe_path")
    local rc=0
    run_agent "$prompt" || rc=$?
    [[ $rc -ne 0 ]] && return "$rc"
    if probe_complete "$probe_path"; then
        log "Probe migrate verified: ${probe_path#$REPO_DIR/}"
        return 0
    fi
    log "ERROR: probe migrate incomplete for $rel"
    return 1
}

# Grade filled 复习区 retranslations. Return 0 on success, 1 on error, 2 on rate limit.
redo_review_file() {
    local file="$1"
    local rel="${file#$REPO_DIR/}"
    log "Grading 复习区: $rel"
    run_agent "你是复习批改老师。只处理「## 复习区」。

Read：$REPO_DIR/src/STANDARDS.md §9
文件：$file

约束：只在「**复习批改：**」空白处写入；其余不得改动（含 <!-- review-meta -->）。

找到「**我的重译：**」已填、「**复习批改：**」为空的块，写入：
- **过程对比**（2-3 行）
- 仍存错误（最多 5 条）或肯定
- 末行：**复习评分：X / 10**（首译 Y / 10，↑/→/↓）

直接编辑文件，不要输出其他内容。"
}

batch_commit() {
    cd "$REPO_DIR"

    git add src/ fool/ console/ probe/ "$LOG_FILE"

    if git diff --cached --quiet; then
        log "No changes staged, skipping commit"
        return
    fi

    # Derive label from fool files actually written — ground truth of what's done
    local label
    label=$(git diff --cached --name-only -- fool/ \
        | xargs -I{} basename {} .md \
        | paste -sd ', ')
    [[ -z "$label" ]] && label=$(git diff --cached --name-only -- probe/ \
        | grep -E '\-probe\.md$' \
        | xargs -I{} basename {} -probe.md \
        | paste -sd ', ')
    [[ -z "$label" ]] && label=$(git diff --cached --name-only -- src/ \
        | xargs -I{} basename {} .md \
        | paste -sd ', ')
    [[ -z "$label" ]] && label="batch"

    git commit -m "批改+愚者+probe $label"
    log "Committed: $label"
}

# Push gate: push only when 批改 + fool + probe are all verified complete.
try_push() {
    local reason="${1:-}"

    push_pending || return 0

    if processing_locked; then
        local locked_pid; locked_pid=$(cat "$PROCESSING_LOCK_FILE" 2>/dev/null)
        log "Push pending${reason:+ [$reason]}: pipeline in progress (pid $locked_pid) — waiting"
        return
    fi

    local uncorrected fool_missing probe_incomplete pipeline_left count
    uncorrected=$(find_uncorrected || true)
    if [[ -n "$uncorrected" ]]; then
        count=$(echo "$uncorrected" | wc -l)
        log "Push pending${reason:+ [$reason]}: $count uncorrected file(s) remain"
        return
    fi
    fool_missing=$(find_fool_missing || true)
    if [[ -n "$fool_missing" ]]; then
        count=$(echo "$fool_missing" | wc -l)
        log "Push pending${reason:+ [$reason]}: $count fool-missing file(s) remain"
        return
    fi
    probe_incomplete=$(find_probe_incomplete || true)
    if [[ -n "$probe_incomplete" ]]; then
        count=$(echo "$probe_incomplete" | wc -l)
        log "Push pending${reason:+ [$reason]}: $count probe-incomplete file(s) remain"
        return
    fi
    pipeline_left=$(find_pipeline_pending || true)
    if [[ -n "$pipeline_left" ]]; then
        count=$(echo "$pipeline_left" | wc -l)
        log "Push pending${reason:+ [$reason]}: $count pipeline-pending file(s) remain"
        return
    fi

    cd "$REPO_DIR"
    log "Push gate clear${reason:+ [$reason]} — 批改·fool·probe verified"
    git pull --rebase --autostash origin main 2>&1 | tee_log || {
        log "WARNING: rebase pull failed — attempting push anyway"
    }
    if git push origin main 2>&1 | tee_log; then
        log "Pushed"
        clear_push_pending
    else
        log "ERROR: push failed — changes are committed locally, retry next cycle"
    fi
}

main() {
    # Single-instance lock — re-exec under flock(1) with --close (-o).
    #
    # The old design (exec 9>LOCK; flock -n 9) held the lock on fd 9 *inside*
    # this shell, and bash leaks fd 9 into every child it spawns. A long-running
    # child that outlives us — typically an orphaned `claude -p` run — then keeps
    # the advisory lock held forever. The poller process is gone (pgrep finds
    # nothing), yet every future start sees "Another instance already running"
    # because the orphan still owns the fd. The scattered `sleep … 9<&-` hacks
    # were spot-fixes for exactly this leak, only ever applied to the sleeps.
    #
    # flock -o closes the lock fd *before* exec'ing the command, so neither this
    # script nor any of its descendants (claude/git/python) ever inherit it. The
    # lock lives solely in the flock(1) parent, which dies with the daemon and
    # releases it — the orphan-holds-lock class of bug is gone. -E 142 gives a
    # distinct exit code so a lock conflict is told apart from a daemon crash.
    if [[ -z "${_AR_FLOCKED:-}" ]]; then
        local rc=0
        # || rc=$? keeps set -e from aborting on flock's nonzero (conflict) exit.
        _AR_FLOCKED=1 flock -n -o -E 142 "$REPO_DIR/.auto-review.lock" "$REPO_DIR/auto-review.sh" "$@" || rc=$?
        (( rc == 142 )) && { log "Another instance already running — exiting."; exit 0; }
        exit "$rc"
    fi

    trim_log "$LOG_FILE"

    log "========================================"
    log "Auto-review agent started"
    log "Repo: $REPO_DIR"
    log "Agent: $AGENT_BIN · model: $AGENT_MODEL"
    log "========================================"

    local _idle=false
    local _last_heartbeat=0
    local _heartbeat_interval=21600  # 6 hours

    while true; do
        cd "$REPO_DIR"

        if git_is_busy; then
            log "Git is busy (manual operation in progress) — skipping this cycle"
        else
            local pull_out pull_rc=0
            pull_out=$(git pull origin main 2>&1) || pull_rc=$?
            if (( pull_rc != 0 )); then
                log "WARNING: git pull failed — will retry next cycle"
                echo "$pull_out" >> "$LOG_FILE"
            elif ! grep -q 'Already up to date\.' <<< "$pull_out"; then
                # New commits arrived — log them and wake from idle
                echo "$pull_out" >> "$LOG_FILE"
                _idle=false
            fi

            if (( pull_rc == 0 )); then
                local pipeline_pending probe_migrate_list
                pipeline_pending=$(find_pipeline_pending || true)
                local rate_limited=false

                if [[ -z "$pipeline_pending" ]]; then
                    local _now; _now=$(date +%s)
                    if ! $_idle; then
                        log "No pipeline-pending files. Polling every ${POLL_INTERVAL}s."
                        _idle=true
                        _last_heartbeat=$_now
                    elif (( _now - _last_heartbeat >= _heartbeat_interval )); then
                        log "Online — idle $(( (_now - _last_heartbeat) / 3600 ))h, still polling."
                        _last_heartbeat=$_now
                        trim_log "$LOG_FILE"
                        update_today_md
                        git add "$LOG_FILE" console/
                        if ! git diff --cached --quiet; then
                            git commit -m "log: heartbeat" \
                                && git push origin main 2>/dev/null \
                                || log "WARNING: heartbeat log push failed"
                        fi
                    fi
                else
                    _idle=false
                    mark_push_pending
                    set_processing_lock
                    local -a done_files=()
                    while IFS= read -r file; do
                        if git_is_busy; then
                            log "Git busy — deferring pipeline to next cycle"
                            break
                        fi
                        if guard_hit pipeline "$file"; then
                            log "Guard: $(basename "$file" .md) unchanged since failed pipeline — skipping"
                            continue
                        fi
                        local rc=0
                        process_day_file "$file" || rc=$?
                        if [[ $rc -eq 2 ]]; then
                            rate_limited=true
                            break
                        elif [[ $rc -eq 0 ]]; then
                            day_paths "$file"
                            add_fool_nav "$FOOL_PATH"
                            create_console_entry "$FOOL_PATH"
                            add_probe_nav "$PROBE_PATH"
                            create_probe_console_entry "$PROBE_PATH"
                            done_files+=("$file")
                        else
                            guard_mark pipeline "$file"
                            log "Pipeline failed for $(basename "$file" .md) — guarded"
                        fi
                    done <<< "$pipeline_pending"

                    if [[ ${#done_files[@]} -gt 0 ]]; then
                        update_today_md
                        batch_commit
                    fi

                    if $rate_limited; then
                        log "Rate limit — backing off 1 hour"
                        clear_processing_lock
                        sleep 3600
                        continue
                    fi
                    clear_processing_lock
                fi

                # Legacy probe migrate (Q&A → 新格式)
                if ! $rate_limited; then
                    probe_migrate_list=$(find_probe_needs_diagnose || true)
                    if [[ -n "$probe_migrate_list" ]]; then
                        _idle=false
                        mark_push_pending
                        set_processing_lock
                        local migrate_done=false
                        while IFS= read -r file; do
                            if git_is_busy; then break; fi
                            day_paths "$file"
                            if guard_hit probe "$PROBE_PATH"; then
                                continue
                            fi
                            local pm_rc=0
                            probe_migrate_file "$file" "$PROBE_PATH" || pm_rc=$?
                            [[ $pm_rc -eq 1 ]] && guard_mark probe "$PROBE_PATH"
                            if [[ $pm_rc -eq 2 ]]; then
                                rate_limited=true
                                break
                            elif [[ $pm_rc -eq 0 ]]; then
                                add_probe_nav "$PROBE_PATH"
                                create_probe_console_entry "$PROBE_PATH"
                                migrate_done=true
                            fi
                        done <<< "$probe_migrate_list"
                        if $migrate_done; then batch_commit; fi
                        clear_processing_lock
                        if $rate_limited; then
                            sleep 3600
                            continue
                        fi
                    fi
                fi

                # Redo pass: grade 复习区 retranslations
                if ! $rate_limited; then
                    local redo_pending
                    redo_pending=$(find_redo_pending || true)
                    if [[ -n "$redo_pending" ]]; then
                        _idle=false
                        mark_push_pending
                        set_processing_lock
                        local redo_done=false
                        while IFS= read -r file; do
                            if git_is_busy; then break; fi
                            if guard_hit redo "$file"; then continue; fi
                            local redo_rc=0
                            redo_review_file "$file" || redo_rc=$?
                            if [[ $redo_rc -eq 2 ]]; then
                                rate_limited=true
                                break
                            elif [[ $redo_rc -eq 0 ]]; then
                                if needs_redo "$file"; then
                                    guard_mark redo "$file"
                                else
                                    redo_done=true
                                fi
                            else
                                guard_mark redo "$file"
                            fi
                        done <<< "$redo_pending"
                        if $redo_done; then
                            update_today_md
                            batch_commit
                        fi
                        clear_processing_lock
                        if $rate_limited; then
                            sleep 3600
                            continue
                        fi
                    fi
                fi

                try_push "周期末检验"
            fi
        fi

        if $ONCE_MODE; then
            log "Once mode — exiting."
            break
        fi

        poll_sleep "$POLL_INTERVAL"
    done
}

main "$@"

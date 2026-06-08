#!/bin/bash
# auto-review.sh — Autonomous English correction agent
#
# Polls the repo for uncorrected translation files, runs Claude review, pushes results.
# Designed to run as a persistent background process on the home Dell machine.
#
# Usage:
#   ./auto-review.sh                      # default 4-hour poll
#   POLL_INTERVAL=3600 ./auto-review.sh   # custom interval (seconds)
#   ./auto-review.sh --once               # scan once and exit (useful for testing)

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$REPO_DIR/.auto-review.log"
PROCESSING_LOCK_FILE="$REPO_DIR/.auto-review-processing"
PUSH_PENDING_FILE="$REPO_DIR/.auto-review-push-pending"
POLL_INTERVAL="${POLL_INTERVAL:-600}"    # 10 minutes
LOG_RETAIN_DAYS="${LOG_RETAIN_DAYS:-7}"
ONCE_MODE=false

[[ "${1:-}" == "--once" ]] && ONCE_MODE=true

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo "$msg" | tee -a "$LOG_FILE"
}

# Drop log lines with timestamps older than LOG_RETAIN_DAYS
trim_log() {
    local log_file="$1"
    [[ -f "$log_file" ]] || return
    local cutoff
    cutoff=$(date -d "${LOG_RETAIN_DAYS} days ago" '+%Y-%m-%d')
    local start
    start=$(awk -v c="$cutoff" '
        match($0, /\[([0-9]{4})[\/\-]([0-9]{2})[\/\-]([0-9]{2})/, a) {
            if (a[1] "-" a[2] "-" a[3] >= c) { print NR; exit }
        }
    ' "$log_file")
    if [[ -n "$start" && "$start" -gt 1 ]]; then
        local tmp; tmp=$(mktemp)
        tail -n +"$start" "$log_file" > "$tmp" && mv "$tmp" "$log_file"
    fi
}

# Processing lock: signals that a correction/fool cycle is actively running.
# try_push and auto_wish both check this before pushing.
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
    find "$REPO_DIR/source" -name "*.md" -print0 | while IFS= read -r -d '' f; do
        if needs_review "$f"; then
            echo "$f"
        fi
    done
}

# Find corrected source files whose fool is missing or stale
find_fool_missing() {
    find "$REPO_DIR/source" -name "*.md" -print0 | while IFS= read -r -d '' f; do
        local fool_path="${f/\/source\//\/fool\/}"
        if ! needs_review "$f" && needs_fool "$f" "$fool_path"; then
            echo "$f"
        fi
    done
}

# Return 0 on success, 1 on general error, 2 on rate limit
review_file() {
    local file="$1"
    local rel="${file#$REPO_DIR/}"
    log "Reviewing: $rel"

    local tmpout exit_code=0
    tmpout=$(mktemp)

    claude -p "你是这个英语学习项目的批改老师。请批改并完善以下markdown文件。

文件路径：$file

**约束：只允许编辑 $file 这一个文件，不得读取或修改任何其他 source 文件。**

参考风格范例：$REPO_DIR/source/may/0528-day39.md

---
任务说明：

1. 读取待批改文件，找到「## 原句」（英文原句）和「## 我的理解和翻译」（用户翻译尝试）

2. 填写「## 批改」section：
   - 用代码块包裹用户译文，在理解有误的位置标注 [1] [2] [3]...（标在词组后面）
   - 代码块下方逐条解释：聚焦在「为什么这个理解是错的」，而不只是给出答案
   - 末尾给出 **参考译文：**（流畅自然的中文翻译）

3. 填写「## Vocab」section：
   - 收录范围：原句中用户**翻译错的词**优先，其次是值得掌握的重要词汇，共3-6个
   - 每个词条格式严格如下：
   \`\`\`
   ### word *(词性)* · [🔊](https://www.merriam-webster.com/dictionary/word)

   **词根**：拆解词的构成，建立结构感（短语词条可省略）

   **核心意象**：用中文锚定这个词的核心意象——不是罗列释义，是那个感受本身，一两句话

   - *例句1*
   - *例句2*
   - *例句3（可选）*

   **造句**：*（你自己造一句，展示这个词用对了是什么样的）*
   \`\`\`
   - 词性用英文：*(n.)* *(v.)* *(adj.)* *(adv.)* *(prep.)* *(phrase)*
   - 发音链接必须加，URL 中的单词用连字符拼写（如 about-face → about-face）
   - 例句 2-3 个即可，不必凑满三个；展示不同场合的用法

4. 填写「## 评分」section（放在批改参考译文之后、## Vocab 之前）：
   - 按英二翻译阅卷标准，从原句中提取 4-5 个采分点（重要词汇、关键结构、特殊表达）
   - 对照用户译文逐一标记：✓ 完全命中 / △ 部分命中（方向对但有偏差）/ ✗ 未命中
   - △ 或 ✗ 的一句话说明：用户写了什么 → 差在哪
   - 计分：✓ = 1分，△ = 0.5分，✗ = 0分；总分 = 得分/总点数 × 10，步幅0.5，不取整
   - 只做采分点核查，不做分析，格式严格如下：
   \`\`\`
   **X / 10**

   采分点（N点）：
   - ✓/△/✗ [采分点] → [若△或✗：用户译文 · 差距一句话]
   \`\`\`

5. 填写「## Phrases」section（原句中1-3个重要句式结构，
   每个结构名加 ### 标题，下方解释逻辑，配上原句和引申用法）

注意：
- 「## 问答收录」和「## 练习与习得」保持空白，不要填写
- 其余已有内容不得改动
- 风格与参考范例保持一致

直接编辑文件完成任务，不要输出其他内容。" \
        --allowedTools "Read,Edit" \
        --dangerously-skip-permissions \
        > "$tmpout" 2>&1 || exit_code=$?

    cat "$tmpout" | tee -a "$LOG_FILE"

    if [[ $exit_code -ne 0 ]]; then
        if grep -qiE "rate.?limit|usage.?limit|too many request|quota|overloaded|529|429" "$tmpout"; then
            log "Rate limit reached (exit $exit_code) — will back off"
            rm -f "$tmpout"
            return 2
        fi
        log "ERROR: claude exited $exit_code for $rel"
        rm -f "$tmpout"
        return 1
    fi

    rm -f "$tmpout"
    log "Review done: $rel"
}

fool_file() {
    local file="$1"
    local fool_path="$2"
    local rel="${file#$REPO_DIR/}"
    local fool_rel="${fool_path#$REPO_DIR/}"
    log "Running fool decomposition: $rel → $fool_rel"

    mkdir -p "$(dirname "$fool_path")"

    local tmpout exit_code=0
    tmpout=$(mktemp)

    claude -p "你是这个英语学习项目的愚者分析师（The Fool）。请对以下已批改的句子文件执行完整的愚者拆解，将结果写入对应的 fool 文件。

句子文件：$file
fool 文件：$fool_path

---

收集句子文件中所有英文句子（按顺序）：
1. ## 原句 — 主句
2. ## Vocab — 每个词条下的例句（*斜体* bullet points）
3. ## Vocab — 每个词条的 **造句**
4. ## Phrases — 每个句式下的例句

跳过中文内容（批改注解、参考译文、核心意象）。不跳过任何英文句子。

对每个句子执行四步拆解：

**Step 1 扫词**：对有分量的词给出词根（一句话建立结构直觉）+ 核心意象（一句中文，不是定义）；简单句可简短处理。

**Step 2 扫小品词和搭配**：对意义超出单词本身的搭配列 2-3 个平行搭配 + 一句中文感受；无值得注意的搭配时一行说明跳过。

**Step 3 扫句式**：1-3 行说清主谓宾在哪、重心在哪、插入语/对比结构/从句；简单句极简。

**Step 4 读句子**：一句流畅的中文翻译。

---

输出格式，按 source 文件分区（## 原句 / ## Vocab · word / ## Phrases · phrase），每句一个条目：

\`\`\`
### fool-NN
> <完整引用句子>

**Step 1 扫词**
...

**Step 2 扫小品词和搭配**
...

**Step 3 扫句式**
...

**Step 4 读句子**
...

---
\`\`\`

编号 fool-01 / fool-02 … 全文连续，两位补零。

如 fool 文件已有 header，保留 header，在其后写入全部内容。
如 fool 文件不存在，先写文件头再写内容：
\`# Day N Fool Sessions · YYYY-MM-DD\n\nsource: [source/...](../../$rel)\n\n---\n\`

一次性写完整个文件，不分批。" \
        --allowedTools "Read,Write,Edit" \
        --dangerously-skip-permissions \
        > "$tmpout" 2>&1 || exit_code=$?

    cat "$tmpout" | tee -a "$LOG_FILE"

    if [[ $exit_code -ne 0 ]]; then
        if grep -qiE "rate.?limit|usage.?limit|too many request|quota|overloaded|529|429" "$tmpout"; then
            log "Rate limit on fool (exit $exit_code) — will back off"
            rm -f "$tmpout"
            return 2
        fi
        log "ERROR: fool exited $exit_code for $rel"
        rm -f "$tmpout"
        return 1
    fi

    rm -f "$tmpout"
    log "Fool done: $fool_rel"
}

# Write one console file: nav + full fool content + nav.
# Prev/next are stems (e.g. "0606-day47"), empty string means no link on that side.
write_console_file() {
    local stem="$1" fool_path="$2" prev="$3" next="$4"
    local out="$REPO_DIR/console/$stem.md"
    local nav=""
    [[ -n "$prev" ]] && nav+="← [$prev]($prev.md)"
    [[ -n "$prev" && -n "$next" ]] && nav+="　　"
    [[ -n "$next" ]] && nav+="[$next]($next.md) →"
    {
        [[ -n "$nav" ]] && printf '%s\n\n' "$nav"
        cat "$fool_path"
        [[ -n "$nav" ]] && printf '\n\n%s\n' "$nav"
    } > "$out"
}

# Create or refresh a console entry after a fool file is written.
# Also updates the previous entry's "next" link, and refreshes today.md.
create_console_entry() {
    local fool_path="$1"
    local stem; stem=$(basename "$fool_path" .md)
    local console_dir="$REPO_DIR/console"
    mkdir -p "$console_dir"

    # Sorted list of existing console stems (excludes today.md)
    local existing=()
    while IFS= read -r f; do
        local s; s=$(basename "$f" .md)
        [[ "$s" != "today" ]] && existing+=("$s")
    done < <(find "$console_dir" -name "*.md" | sort)

    # Prev = last existing entry (before this one)
    local prev_stem=""
    for s in "${existing[@]}"; do
        [[ "$s" < "$stem" ]] && prev_stem="$s"
    done

    # Write new console file
    write_console_file "$stem" "$fool_path" "$prev_stem" ""

    # Refresh previous entry to add "next" link pointing to new stem
    if [[ -n "$prev_stem" ]]; then
        local prev_prev=""
        for s in "${existing[@]}"; do
            [[ "$s" < "$prev_stem" ]] && prev_prev="$s"
        done
        local prev_fool; prev_fool=$(find "$REPO_DIR/fool" -name "${prev_stem}.md" | head -1)
        [[ -f "$prev_fool" ]] && write_console_file "$prev_stem" "$prev_fool" "$prev_prev" "$stem"
    fi

    # Update today.md to point to the most recent console file
    local latest_stem="$stem"
    for s in "${existing[@]}"; do
        [[ "$s" > "$latest_stem" ]] && latest_stem="$s"
    done
    printf '→ [今天 · %s](%s.md)\n' "$latest_stem" "$latest_stem" > "$console_dir/today.md"

    log "Console: $stem"
}

# Commit staged changes without pushing
batch_commit() {
    cd "$REPO_DIR"

    git add source/ fool/ console/ "$LOG_FILE"

    if git diff --cached --quiet; then
        log "No changes staged, skipping commit"
        return
    fi

    # Derive label from fool files actually written — ground truth of what's done
    local label
    label=$(git diff --cached --name-only -- fool/ \
        | xargs -I{} basename {} .md \
        | paste -sd ', ')
    [[ -z "$label" ]] && label="batch"

    git commit -m "批改+愚者 $label"
    log "Committed: $label"
}

# Push gate: called after clear_processing_lock to verify everything is truly done.
# Three-stage check:
#   1. Processing lock still held → files actively being worked on, wait.
#   2. Uncorrected files remain after unlock → something incomplete, defer.
#   3. Fool-missing files remain after unlock → fool didn't finish, defer.
#   All clear → push.
try_push() {
    local reason="${1:-}"

    # No pending work detected — nothing to push, return immediately.
    push_pending || return

    # Stage 1: lock check — correction/fool still running, keep waiting
    if processing_locked; then
        local locked_pid; locked_pid=$(cat "$PROCESSING_LOCK_FILE" 2>/dev/null)
        log "Push pending${reason:+ [$reason]}: correction/fool in progress (pid $locked_pid) — waiting"
        return
    fi

    # Stage 2 & 3: post-unlock verification — confirm both corrections and fool are truly done
    local uncorrected fool_missing count
    uncorrected=$(find_uncorrected || true)
    if [[ -n "$uncorrected" ]]; then
        count=$(echo "$uncorrected" | wc -l)
        log "Push pending${reason:+ [$reason]}: $count uncorrected file(s) still remain after unlock"
        return
    fi
    fool_missing=$(find_fool_missing || true)
    if [[ -n "$fool_missing" ]]; then
        count=$(echo "$fool_missing" | wc -l)
        log "Push pending${reason:+ [$reason]}: $count fool-missing file(s) still remain after unlock"
        return
    fi

    cd "$REPO_DIR"
    log "Push gate clear${reason:+ [$reason]} — corrections and fool verified complete"
    git pull --rebase origin main 2>&1 | tee -a "$LOG_FILE" || {
        log "WARNING: rebase pull failed — attempting push anyway"
    }
    if git push origin main 2>&1 | tee -a "$LOG_FILE"; then
        log "Pushed"
        clear_push_pending
    else
        log "ERROR: push failed — changes are committed locally, retry next cycle"
    fi
}

main() {
    exec 9>"$REPO_DIR/.auto-review.lock"
    flock -n 9 || { log "Another instance already running — exiting."; exit 0; }

    trim_log "$LOG_FILE"

    log "========================================"
    log "Auto-review agent started"
    log "Repo: $REPO_DIR"
    log "Poll interval: ${POLL_INTERVAL}s"
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
                local uncorrected
                uncorrected=$(find_uncorrected || true)
                local rate_limited=false

                if [[ -z "$uncorrected" ]]; then
                    local _now; _now=$(date +%s)
                    if ! $_idle; then
                        log "No uncorrected files found. Polling every ${POLL_INTERVAL}s."
                        _idle=true
                        _last_heartbeat=$_now
                    elif (( _now - _last_heartbeat >= _heartbeat_interval )); then
                        log "Online — idle $(( (_now - _last_heartbeat) / 3600 ))h, still polling."
                        _last_heartbeat=$_now
                        git add "$LOG_FILE"
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
                    local -a reviewed_files=()
                    while IFS= read -r file; do
                        if git_is_busy; then
                            log "Git became busy mid-cycle — deferring remaining files to next cycle"
                            break
                        fi
                        local rc=0
                        if needs_review "$file"; then
                            review_file "$file" || rc=$?
                        else
                            log "Already reviewed (side effect): $(basename "$file" .md) — skipping Claude call"
                        fi
                        if [[ $rc -eq 2 ]]; then
                            log "Backing off for 1 hour before next attempt"
                            rate_limited=true
                            break
                        elif [[ $rc -eq 0 ]]; then
                            local fool_path="${file/\/source\//\/fool\/}"
                            local fool_rc=0
                            if needs_fool "$file" "$fool_path"; then
                                fool_file "$file" "$fool_path" || fool_rc=$?
                            else
                                log "Already decomposed (side effect): $(basename "$fool_path" .md) — skipping Claude call"
                            fi
                            if [[ $fool_rc -eq 2 ]]; then
                                log "Rate limit on fool — queuing for batch commit"
                                reviewed_files+=("$file")
                                rate_limited=true
                                break
                            elif [[ $fool_rc -eq 0 ]]; then
                                create_console_entry "$fool_path"
                                reviewed_files+=("$file")
                            else
                                log "Fool failed — queuing review-only for batch commit"
                                reviewed_files+=("$file")
                            fi
                        else
                            log "Skipping $file due to review error"
                        fi
                    done <<< "$uncorrected"

                    if [[ ${#reviewed_files[@]} -gt 0 ]]; then
                        batch_commit
                    fi

                    if $rate_limited; then
                        log "Rate limit — backing off 1 hour"
                        sleep 3600
                        continue
                    fi
                fi

                # Fool-missing pass: catch corrected files whose fool was skipped or is stale
                if ! $rate_limited; then
                    local fool_missing
                    fool_missing=$(find_fool_missing || true)
                    if [[ -n "$fool_missing" ]]; then
                        _idle=false
                        mark_push_pending
                        set_processing_lock
                        local -a fool_queued=()
                        while IFS= read -r file; do
                            if git_is_busy; then
                                log "Git became busy — deferring fool-missing to next cycle"
                                break
                            fi
                            local fool_path="${file/\/source\//\/fool\/}"
                            local fool_rc=0
                            log "Fool-missing: $(basename "$file" .md) — running decomposition"
                            fool_file "$file" "$fool_path" || fool_rc=$?
                            if [[ $fool_rc -eq 2 ]]; then
                                fool_queued+=("$file")
                                rate_limited=true
                                break
                            elif [[ $fool_rc -eq 0 ]]; then
                                create_console_entry "$fool_path"
                                fool_queued+=("$file")
                            else
                                log "Fool failed for $(basename "$file" .md) — skipping"
                            fi
                        done <<< "$fool_missing"

                        if [[ ${#fool_queued[@]} -gt 0 ]]; then
                            batch_commit
                        fi

                        if $rate_limited; then
                            log "Rate limit on fool — backing off 1 hour"
                            sleep 3600
                            continue
                        fi
                    fi

                    # Fool-missing pass done (or skipped).
                    # Always clear the lock here (cleans up stale locks too).
                    # Then verify corrections AND fool are truly complete before pushing.
                    clear_processing_lock
                    try_push "解锁后检验"
                fi
            fi
        fi

        if $ONCE_MODE; then
            log "Once mode — exiting."
            break
        fi

        sleep "$POLL_INTERVAL"
    done
}

main "$@"

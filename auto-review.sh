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

# Drop log lines with timestamps older than LOG_RETAIN_DAYS
trim_log() {
    local log_file="$1"
    [[ -f "$log_file" ]] || return
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

# Find corrected source files that have a score but no probe file yet
find_probe_missing() {
    find "$REPO_DIR/src" -name "*.md" -print0 | while IFS= read -r -d '' f; do
        local probe_path="${f/\/src\//\/probe\/}"; probe_path="${probe_path%.md}-probe.md"
        if ! needs_review "$f" && has_score "$f" && needs_probe "$probe_path"; then
            echo "$f"
        fi
    done
}

# Returns 0 if 复习区 has at least one block with 我的重译 filled but 复习批改 empty
needs_redo() {
    local f="$1"
    grep -q '^## 复习区' "$f" || return 1
    python3 - "$f" <<'PYEOF'
import sys, re
text = open(sys.argv[1], encoding='utf-8').read()
m = re.search(r'^## 复习区\s*\n(.*)', text, re.M | re.S)
if not m:
    sys.exit(1)
for block in re.split(r'^### ', m.group(1), flags=re.M)[1:]:
    redo = re.search(r'\*\*我的重译：\*\*\n(.*?)\*\*复习批改：\*\*', block, re.S)
    graded = re.search(r'\*\*复习批改：\*\*\n(.*?)(?:<!-- review-meta|\Z)', block, re.S)
    if redo and redo.group(1).strip() and graded is not None and not graded.group(1).strip():
        sys.exit(0)
sys.exit(1)
PYEOF
}

# Find files with ungraded 复习区 retranslations (main correction must already be done)
find_redo_pending() {
    find "$REPO_DIR/src" -name "*.md" -print0 | while IFS= read -r -d '' f; do
        if ! needs_review "$f" && needs_redo "$f"; then
            echo "$f"
        fi
    done
}

# Find corrected source files whose fool is missing or stale
find_fool_missing() {
    find "$REPO_DIR/src" -name "*.md" -print0 | while IFS= read -r -d '' f; do
        local fool_path="${f/\/src\//\/fool\/}"; fool_path="${fool_path%.md}-fool.md"
        if ! needs_review "$f" && has_correction "$f" && needs_fool "$f" "$fool_path"; then
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

参考风格范例：$REPO_DIR/src/may/0528-day39.md

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
- 「## 复习区」整个 section 不要动（由复习批改流程单独处理）
- 其余已有内容不得改动
- 风格与参考范例保持一致

直接编辑文件完成任务，不要输出其他内容。" \
        --allowedTools "Read,Edit" \
        --dangerously-skip-permissions \
        > "$tmpout" 2>&1 || exit_code=$?

    cat "$tmpout" | tee_log

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

跳过中文内容（批改注解、参考译文、核心意象）。跳过「## 复习区」整个 section（里面是旧句子的重译练习，已在当初的 fool 文件中拆解过）。除此之外不跳过任何英文句子。

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
\`# Day N Fool Sessions · YYYY-MM-DD\n\nsource: [src/...](../../$rel)\n\n---\n\`

一次性写完整个文件，不分批。" \
        --allowedTools "Read,Write,Edit" \
        --dangerously-skip-permissions \
        > "$tmpout" 2>&1 || exit_code=$?

    cat "$tmpout" | tee_log

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

# Grade filled 复习区 retranslations. Return 0 on success, 1 on error, 2 on rate limit.
redo_review_file() {
    local file="$1"
    local rel="${file#$REPO_DIR/}"
    log "Grading 复习区: $rel"

    local tmpout exit_code=0
    tmpout=$(mktemp)

    claude -p "你是这个英语学习项目的复习批改老师。只处理文件中「## 复习区」部分。

文件路径：$file

**约束：只允许编辑这一个文件，且只能在「## 复习区」内「**复习批改：**」的空白处写入内容。其余一切内容（包括 <!-- review-meta --> 注释本身）不得改动、不得删除。**

任务说明：

1. 找到「## 复习区」下每个「### 重译」块中「**我的重译：**」已填写、「**复习批改：**」为空的条目

2. 对照该块引用的英文原句批改这次重译，在「**复习批改：**」下方写入：
   - 只指出仍然存在的错误，逐条简短说明（每条一行，最多5条）；重译质量好就用一两句肯定，并点出最出彩的处理
   - 块尾 <!-- review-meta --> 注释里有首译得分（first=X/10）和参考译文，作对比依据
   - 最后一行固定格式：**复习评分：X / 10**（首译 Y / 10，↑提升 / →持平 / ↓下降）
   - 评分口径与首译一致：按采分点 ✓=1 / △=0.5 / ✗=0 估算，换算到10分制，步幅0.5
   - 若 first=—（首译无评分），最后一行写：**复习评分：X / 10**（首译未评分）

3. 「我的重译」为空的块跳过；「复习批改」已有内容的块跳过

直接编辑文件完成任务，不要输出其他内容。" \
        --allowedTools "Read,Edit" \
        --dangerously-skip-permissions \
        > "$tmpout" 2>&1 || exit_code=$?

    cat "$tmpout" | tee_log

    if [[ $exit_code -ne 0 ]]; then
        if grep -qiE "rate.?limit|usage.?limit|too many request|quota|overloaded|529|429" "$tmpout"; then
            log "Rate limit on redo (exit $exit_code) — will back off"
            rm -f "$tmpout"
            return 2
        fi
        log "ERROR: redo grading exited $exit_code for $rel"
        rm -f "$tmpout"
        return 1
    fi

    rm -f "$tmpout"
    log "复习区 graded: $rel"
}

# shellcheck source=scripts/console.sh
source "$REPO_DIR/scripts/console.sh"
# shellcheck source=scripts/probe.sh
source "$REPO_DIR/scripts/probe.sh"
# shellcheck source=scripts/nav.sh
source "$REPO_DIR/scripts/nav.sh"

# Commit staged changes without pushing
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
    [[ -z "$label" ]] && label=$(git diff --cached --name-only -- src/ \
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
                            local probe_path="${file/\/src\//\/probe\/}"; probe_path="${probe_path%.md}-probe.md"
                            if has_score "$file" && needs_probe "$probe_path"; then
                                create_probe "$file" "$probe_path"
                                add_probe_nav "$probe_path"
                                create_probe_console_entry "$probe_path"
                            fi
                            local fool_path="${file/\/src\//\/fool\/}"; fool_path="${fool_path%.md}-fool.md"
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
                                add_fool_nav "$fool_path"
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
                        sleep 3600 9<&-
                        continue
                    fi
                fi

                # Probe-missing pass: fast bash extraction, no Claude needed
                if ! $rate_limited; then
                    local probe_missing
                    probe_missing=$(find_probe_missing || true)
                    if [[ -n "$probe_missing" ]]; then
                        while IFS= read -r file; do
                            local probe_path="${file/\/src\//\/probe\/}"; probe_path="${probe_path%.md}-probe.md"
                            create_probe "$file" "$probe_path"
                            add_probe_nav "$probe_path"
                            create_probe_console_entry "$probe_path"
                        done <<< "$probe_missing"
                        batch_commit
                    fi
                fi

                # Redo pass: grade 复习区 retranslations the user has filled in
                if ! $rate_limited; then
                    local redo_pending
                    redo_pending=$(find_redo_pending || true)
                    if [[ -n "$redo_pending" ]]; then
                        _idle=false
                        mark_push_pending
                        set_processing_lock
                        local redo_done=false
                        while IFS= read -r file; do
                            if git_is_busy; then
                                log "Git became busy — deferring redo grading to next cycle"
                                break
                            fi
                            local redo_rc=0
                            redo_review_file "$file" || redo_rc=$?
                            if [[ $redo_rc -eq 2 ]]; then
                                rate_limited=true
                                break
                            elif [[ $redo_rc -eq 0 ]]; then
                                redo_done=true
                            fi
                        done <<< "$redo_pending"
                        if $redo_done; then
                            update_today_md
                            batch_commit
                        fi
                        if $rate_limited; then
                            log "Rate limit on redo — backing off 1 hour"
                            sleep 3600 9<&-
                            continue
                        fi
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
                            local fool_path="${file/\/src\//\/fool\/}"; fool_path="${fool_path%.md}-fool.md"
                            local fool_rc=0
                            log "Fool-missing: $(basename "$file" .md) — running decomposition"
                            fool_file "$file" "$fool_path" || fool_rc=$?
                            if [[ $fool_rc -eq 2 ]]; then
                                fool_queued+=("$file")
                                rate_limited=true
                                break
                            elif [[ $fool_rc -eq 0 ]]; then
                                add_fool_nav "$fool_path"
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
                            sleep 3600 9<&-
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

        sleep "$POLL_INTERVAL" 9<&-
    done
}

main "$@"

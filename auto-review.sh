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

# Check a single fool file: returns 0 if it still needs decomposition
needs_fool() {
    local f="$1"
    ! ( [[ -f "$f" ]] && grep -q '^### fool-' "$f" )
}

# Find markdown files where 我的理解和翻译 has content but 批改 is empty
find_uncorrected() {
    find "$REPO_DIR/sentence" -name "*.md" -print0 | while IFS= read -r -d '' f; do
        if needs_review "$f"; then
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

参考风格范例：$REPO_DIR/sentence/may/0528-day39.md

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

4. 填写「## Phrases」section（原句中1-3个重要句式结构，
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
\`# Day N Fool Sessions · YYYY-MM-DD\n\nsource: [sentence/...](../../$rel)\n\n---\n\`

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

batch_commit_and_push() {
    # $@ = list of reviewed sentence file paths (used for commit label only)
    local -a files=("$@")
    cd "$REPO_DIR"

    # Stage everything Claude may have touched in sentence/ and fool/
    git add sentence/ fool/

    if git diff --cached --quiet; then
        log "No changes staged, skipping commit"
        return
    fi

    # Build label from basenames
    local -a names=()
    local f
    for f in "${files[@]}"; do
        names+=("$(basename "$f" .md)")
    done
    local label="${names[0]}"
    local name
    for name in "${names[@]:1}"; do
        label+=", $name"
    done

    git commit -m "批改+愚者 $label"
    log "Committed: $label"

    git pull --rebase origin main 2>&1 | tee -a "$LOG_FILE" || {
        log "WARNING: rebase pull failed — attempting push anyway"
    }

    if git push origin main 2>&1 | tee -a "$LOG_FILE"; then
        log "Pushed: $label"
    else
        log "ERROR: push failed for $label — changes committed locally, retry next cycle"
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

    while true; do
        cd "$REPO_DIR"

        if git_is_busy; then
            log "Git is busy (manual operation in progress) — skipping this cycle"
        else
            log "Pulling latest changes..."
            if ! git pull origin main 2>&1 | tee -a "$LOG_FILE"; then
                log "WARNING: git pull failed — will retry next cycle"
            else
                local uncorrected
                uncorrected=$(find_uncorrected || true)

                if [[ -z "$uncorrected" ]]; then
                    log "No uncorrected files found."
                else
                    local rate_limited=false
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
                            local fool_path="${file/\/sentence\//\/fool\/}"
                            local fool_rc=0
                            if needs_fool "$fool_path"; then
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
                        batch_commit_and_push "${reviewed_files[@]}"
                    fi

                    if $rate_limited; then
                        log "Sleeping 3600s (1 hour) for rate limit recovery..."
                        sleep 3600
                        continue
                    fi
                fi
            fi
        fi

        if $ONCE_MODE; then
            log "Once mode — exiting."
            break
        fi

        log "Sleeping ${POLL_INTERVAL}s..."
        sleep "$POLL_INTERVAL"
    done
}

main "$@"

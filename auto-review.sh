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
POLL_INTERVAL="${POLL_INTERVAL:-14400}"  # 4 hours
ONCE_MODE=false

[[ "${1:-}" == "--once" ]] && ONCE_MODE=true

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo "$msg" | tee -a "$LOG_FILE"
}

# Return non-zero if git is locked by another process (user's manual git op in progress)
git_is_busy() {
    [[ -f "$REPO_DIR/.git/index.lock" ]] || [[ -f "$REPO_DIR/.git/MERGE_HEAD" ]] || [[ -f "$REPO_DIR/.git/rebase-merge" ]]
}

# Find markdown files where 我的理解和翻译 has content but 批改 is empty
find_uncorrected() {
    find "$REPO_DIR/sentence" -name "*.md" -print0 | while IFS= read -r -d '' f; do
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

        if [[ -n "$translation" && -z "$correction" ]]; then
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

commit_and_push() {
    local file="$1"
    local rel="${file#$REPO_DIR/}"
    local basename
    basename=$(basename "$file" .md)

    cd "$REPO_DIR"
    git add "$rel"

    if git diff --cached --quiet; then
        log "No changes staged for $basename, skipping commit"
        return
    fi

    git commit -m "批改 $basename"
    log "Committed: $basename"

    if git push origin main 2>&1 | tee -a "$LOG_FILE"; then
        log "Pushed: $basename"
    else
        log "ERROR: push failed for $basename — changes committed locally, retry next cycle"
    fi
}

main() {
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
                    while IFS= read -r file; do
                        if git_is_busy; then
                            log "Git became busy mid-cycle — deferring remaining files to next cycle"
                            break
                        fi
                        local rc=0
                        review_file "$file" || rc=$?
                        if [[ $rc -eq 2 ]]; then
                            log "Backing off for 5 hours before next attempt"
                            rate_limited=true
                            break
                        elif [[ $rc -eq 0 ]]; then
                            commit_and_push "$file"
                        else
                            log "Skipping commit for $file due to review error"
                        fi
                    done <<< "$uncorrected"

                    if $rate_limited; then
                        log "Sleeping 18000s (5 hours) for rate limit recovery..."
                        sleep 18000
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

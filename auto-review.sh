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

# Find corrected source files that have a score but no probe file yet
find_probe_missing() {
    find "$REPO_DIR/src" -name "*.md" -print0 | while IFS= read -r -d '' f; do
        local probe_path="${f/\/src\//\/probe\/}"; probe_path="${probe_path%.md}-probe.md"
        if ! needs_review "$f" && has_score "$f" && needs_probe "$probe_path"; then
            echo "$f"
        fi
    done
}

# Returns 0 if 复习区 has at least one block with 我的重译 filled but 复习批改 empty.
# Logic lives in scripts/review.py — single owner of 复习区 parsing.
needs_redo() {
    python3 "$REPO_DIR/scripts/review.py" pending "$1"
}

# Claude-call guard: remember the file hash after a failed (or yieldless) attempt
# and skip re-invoking Claude until the file actually changes — no token burn loops.
declare -A _FAILED_HASH
guard_hit()  { [[ "${_FAILED_HASH[$1:$2]:-}" == "$(md5sum "$2" | awk '{print $1}')" ]]; }
guard_mark() { _FAILED_HASH[$1:$2]=$(md5sum "$2" | awk '{print $1}'); }

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

【项目立意 — 所有产出必须服务于此】
学员备考考研英语二（四战），卷面目标从约39分提升到65分以上。
每日一句翻译是探针：根据译文暴露的理解缺口，生成个性化学习任务（Vocab / Phrases），
例句提供英二难度的阅读训练素材；学员把「查字典」的过程前移到批改解析。
产出优先：过程纠错、考纲搭配、可迁移的读句能力 > 百科式堆砌。

【学员档位 — 固定标尺，不引用仓库内任何历史文件】
首译稳定约 3.5–4.5/10（英二卷面约 35–45 分档）。读句高频卡点：多义词、介词方向、主干找错、语义极性搞反、长句读半截。
所有讲解深度按此档位写，不随当天分数浮动，不参照某篇旧批改。

文件路径：$file

**约束：只允许编辑 $file 这一个文件，不得读取或修改任何其他 source 文件。**

【批改语气】耐心、具体；每条 [n] 说清「读句哪一步断了」；参考译文流畅书面。

---
任务说明：

1. 读取「## 原句」和「## 我的理解和翻译」

2. 填写「## 批改」：
   - 代码块包裹用户译文，误处标 [1] [2] [3]...（标在词组后面）
   - 逐条解释：聚焦「读句时哪一步断了、为什么这个理解是错的」，不只给答案
   - 末尾 **参考译文：**（流畅自然的中文）

3. 填写「## 评分」：
   - 按英二翻译阅卷标准，从原句提取 4-5 个采分点（重要词汇、关键结构、特殊表达）
   - 对照用户译文：✓ 完全命中 / △ 部分命中 / ✗ 未命中
   - △ 或 ✗ 写：用户写了什么 → 差在哪
   - 计分：✓=1，△=0.5，✗=0；总分=得分/总点数×10，步幅0.5，不取整
   - 格式：
   \`\`\`
   **X / 10**

   采分点（N点）：
   - ✓/△/✗ [采分点] → [若△或✗：用户译文 · 差距一句话]
   \`\`\`

4. 填写「## Vocab」：
   - 收录：本次译文暴露的**所有**需讲解词/搭配（译错、译漏、译偏优先）；不凑数，不遗漏关键错词
   - 每个需讲解词条配 **3 条例句**（不从原句截取）；用心造句，句长/从句层数贴近原句（±20%），英二真题语感
   - 三例句默认分工（分工标签写在「例句意图」里，便于后续网页筛选与迭代）：
     ① 扣原句 — 同骨架重演该词在原句中的位置与搭配
     ② 考纲迁移 — 英二常见场景中的活句
     ③ 防坑 — 针对本次 [n] 或采分点 ✗，拆本次具体误译
   - 词条格式：
   \`\`\`
   ### word *(词性)* · [🔊](https://www.merriam-webster.com/dictionary/word)

   **词根**：一句话建立结构感（短语词条可省略）

   **核心意象**：中文锚定核心意象，一两句话，不是罗列释义

   - *例句1* （简短中文提示）
     **例句意图：** 扣原句 — （一句话说明本句如何服务原句）
   - *例句2* （简短中文提示）
     **例句意图：** 考纲迁移 — …
   - *例句3* （简短中文提示）
     **例句意图：** 防坑 — 针对[n]/✗…（点明要拆的幻觉）
   \`\`\`
   - 词性：*(n.)* *(v.)* *(adj.)* *(adv.)* *(prep.)* *(phrase)*
   - 发音链接必加，URL 用连字符拼写
   - **不要写「造句」** — 三例句已覆盖产出要求

5. 填写「## Phrases」：
   - 收录：本次译文暴露的**所有**关键句式/习惯用法块（与 Vocab 同级，不设数量折扣）
   - 每个短语块**恰好 3 条例句**，规则与 Vocab 相同（①扣原句 ②考纲迁移 ③防坑），禁止从原句截取
   - 格式：
   \`\`\`
   ### 结构名（中文提示）

   **讲解**：逻辑说明 + 原句引用（> blockquote）

   - *例句1* （简短中文）
     **例句意图：** 扣原句 — …
   - *例句2* （简短中文）
     **例句意图：** 考纲迁移 — …
   - *例句3* （简短中文）
     **例句意图：** 防坑 — 针对[n]/✗…
   \`\`\`

注意：
- 「## 问答收录」和「## 练习与习得」保持空白（疑点由学员手写进 probe，不由你生成）
- 「## 复习区」不要动
- 其余已有内容不得改动

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

    claude -p "你是这个英语学习项目的愚者分析师（The Fool）。请对已批改句子文件执行愚者拆解，写入 fool 文件。

【项目立意】
批改中的英二例句学员单独读仍会懵；fool 把每一句拆到他能吸收的程度，读完等于完成当日阅读训练量。

句子文件：$file
fool 文件：$fool_path

【讲解降维标尺 — 全文固定，不引用仓库内任何历史 fool/probe/src 文件，不随当天分数浮动】

目标读者（恒定画像）：
- 英二卷面约 35–45 分档；首译稳定 3.5–4.5/10
- 认识不少考纲词形，但多义词、介词、嵌套从句、语义极性仍常误读
- 需要「把英二句拆成能跟上的步骤」，不是百科或论文

英文（blockquote 内）：
- 与 source 完全一致，不改写、不替换、不降级英文难度

中文讲解（每条 fool 条目 Step1–4 合计）：
- 总篇幅 ≤ 12 行中文；越靠后的条目与靠前条目同等密度，禁止后段缩略
- 语气：像同事面对面讲，不用「综上所述」「简而言之」
- 术语（定语从句、非限定等）出现时必须同一行用白话落地

Step 1 扫词：实义词最多各 2 行（词根仅当有助于辨析形近/反义时写一行，否则只写核心意象）

Step 2 扫小品词和搭配：只分析 blockquote 内已有英文；1–2 组搭配 + 中文感受；**禁止新增任何英文例句**
- 若「例句意图」含防坑：必须一行写「首译典型错读：…；本句纠偏：…」

Step 3 扫句式：3–5 行；用「谁对谁 / 挂在谁身上 / 逗号后是补充」；禁止连续堆语法术语

Step 4 读句子：两层 — **直读**（口语、短句，像转述给朋友）+ **考场**（书面译法，1 句；极简单句可省考场层）

---

收集英文句子（按顺序，不跳过）：
1. ## 原句
2. ## Vocab — 每个词条下 3 条 *斜体* 例句（不含造句；新版已无造句字段）
3. ## Phrases — 每个短语块下 3 条 *斜体* 例句

跳过：中文批注、参考译文、核心意象、例句意图行。跳过「## 复习区」。

对每个句子做四步拆解（遵守上文【讲解降维标尺】，全文质量一致）：

**Step 1 扫词**

输出格式，按 source 分区（## 原句 / ## Vocab · word / ## Phrases · phrase）：

\`\`\`
### fool-NN [扣原句|迁移|防坑]
> <完整引用句子，与 source 一致>

**Step 1 扫词**
...

**Step 2 扫小品词和搭配**
...

**Step 3 扫句式**
...

**Step 4 读句子**
直读：…
考场：…

---
\`\`\`

标题中的 [扣原句|迁移|防坑] 与 source 的「例句意图」一致。编号 fool-01 起，两位补零，全文连续。

如 fool 文件已有 header，保留 header 后写入；否则先写：
\`# Day N Fool Sessions · YYYY-MM-DD\n\nsource: [src/...](../../$rel)\n\n---\n\`

一次性写完整个文件。" \
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

    claude -p "你是这个英语学习项目的复习批改老师。只处理「## 复习区」。

【项目立意】
间隔重译是在检验「读句过程」是否内化，不只是改字面对错。

文件路径：$file

**约束：只允许在「## 复习区」内「**复习批改：**」空白处写入；其余不得改动（含 <!-- review-meta -->）。**

1. 找到「**我的重译：**」已填、「**复习批改：**」为空的块

2. 在「**复习批改：**」下写入：
   - **过程对比**（2-3 行）：对照 <!-- review-meta --> 中首译情况，写「已修复的过程问题」与「仍存在的卡点」（主干/介词/极性/半句放弃等）
   - 仍存在的错误：每条一行，最多 5 条；质量好则肯定并点出最出彩处理
   - 最后一行：**复习评分：X / 10**（首译 Y / 10，↑/→/↓）
   - 评分：采分点 ✓=1 / △=0.5 / ✗=0，换算 10 分制，步幅 0.5
   - first=— 时写：**复习评分：X / 10**（首译未评分）

3. 空块或已批改块跳过

直接编辑文件，不要输出其他内容。" \
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
    push_pending || return 0

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
                        if guard_hit review "$file"; then
                            log "Guard: $(basename "$file" .md) unchanged since failed review — skipping Claude call"
                            continue
                        elif needs_review "$file"; then
                            review_file "$file" || rc=$?
                            [[ $rc -eq 1 ]] && guard_mark review "$file"
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
                                [[ $fool_rc -eq 1 ]] && guard_mark fool "$file"
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
                        sleep 3600
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
                            if guard_hit redo "$file"; then
                                log "Guard: $(basename "$file" .md) unchanged since last redo attempt — skipping Claude call"
                                continue
                            fi
                            local redo_rc=0
                            redo_review_file "$file" || redo_rc=$?
                            if [[ $redo_rc -eq 2 ]]; then
                                rate_limited=true
                                break
                            elif [[ $redo_rc -eq 0 ]]; then
                                if needs_redo "$file"; then
                                    # Claude exited 0 but the section is still empty —
                                    # don't loop on it; retry only after the file changes.
                                    guard_mark redo "$file"
                                    log "Redo grading yielded no output for $(basename "$file" .md) — guarded"
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
                        if $rate_limited; then
                            log "Rate limit on redo — backing off 1 hour"
                            sleep 3600
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
                            if guard_hit fool "$file"; then
                                log "Guard: $(basename "$file" .md) unchanged since failed fool — skipping Claude call"
                                continue
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
                                guard_mark fool "$file"
                                log "Fool failed for $(basename "$file" .md) — guarded until file changes"
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

        poll_sleep "$POLL_INTERVAL"
    done
}

main "$@"

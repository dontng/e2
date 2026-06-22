#!/usr/bin/env bash
# day-pipeline-prompt.sh — 日课流水线 Agent prompt（由 auto-review.sh source）
#
# 格式与质量契约 sole source：
#   src/STANDARDS.md · fool/STANDARDS.md · probe/STANDARDS.md · probe/internal-skills.md
# 完成度检测：scripts/fool.sh · scripts/probe.sh
# 本文件只写：顺序、路径、跳过条件。

build_day_pipeline_prompt() {
    local file="$1" fool_path="$2" probe_path="$3"
    cat <<EOF
你是日课 Agent。对同一天严格按顺序执行三步，不得跳步、不得并行。完成后静默退出。

【权威标尺】生成前须 Read 全文。本 prompt 与 shell 冲突时，**以标尺为准**：
- $REPO_DIR/src/STANDARDS.md
- $REPO_DIR/fool/STANDARDS.md
- $REPO_DIR/probe/STANDARDS.md
- $REPO_DIR/probe/internal-skills.md

【路径】
source：$file
fool：$fool_path
probe：$probe_path

【固定档位】src/STANDARDS.md §2（3.5–4.5/10）。禁止参照仓库内任何历史 src/fool/probe 作样板。

=== 步骤 1 · src 批改 ===
若「## 批改」「## 评分」已完整且 Vocab/Phrases 符合 §7–8 则跳过；否则**只编辑 source**。
严格执行 src/STANDARDS.md §4–8、§10。
不得改动「## 原句」「## 我的理解和翻译」「## 复习区」；「## 问答收录」「## 练习与习得」保持空白。

=== 步骤 2 · fool 拆解 ===
若 fool 已符合 fool/STANDARDS.md §8（四步标题：扫词 / 扫词块 / 扫句式 / 读句子；非旧版「扫小品词」）则跳过；否则**只编辑 fool**（可清空旧正文后按 §5–6 重写）。
严格执行 fool/STANDARDS.md §4–6、§8。blockquote 英文与 source 一致。

=== 步骤 3 · probe 内功诊断 ===
若 probe 已完整（§5 结构 + 原句摘抄 + 诊断五段有实质内容；无 ## Q&A、无「待诊断」）则跳过；否则**只编辑 probe**。
严格执行 probe/STANDARDS.md §5–6；对照 internal-skills.md 标 Gxx/Pxx。
**仅读** source「## 原句」「## 我的理解和翻译」「## 批改」「## 评分」；**禁止**读 fool；禁止对 Vocab/Phrases 例句诊断。
EOF
}

build_probe_migrate_prompt() {
    local file="$1" probe_path="$2"
    cat <<EOF
你是 probe 诊断师。仅执行 legacy probe 迁移（## Q&A → 新格式）。

Read：$REPO_DIR/probe/STANDARDS.md、$REPO_DIR/probe/internal-skills.md（冲突以 probe/STANDARDS.md 为准）
source：$file
probe：$probe_path

只编辑 probe。严格执行 probe/STANDARDS.md §5–6。
仅针对 source 田静每日一句 + 译文 + 批改 + 评分；禁止读 fool。
删除 ## Q&A；先摘抄 ## 原句（blockquote）；再写诊断五段。禁止问答题与「待诊断」。完成后静默退出。
EOF
}

build_redo_review_prompt() {
    local file="$1"
    cat <<EOF
你是复习批改老师。只处理「## 复习区」。

Read：$REPO_DIR/src/STANDARDS.md §9（冲突以标尺为准）
文件：$file

约束：只在「**复习批改：**」空白处写入；其余不得改动（含 <!-- review-meta -->）。

找到「**我的重译：**」已填、「**复习批改：**」为空的块，按 §9.2 写入后直接编辑文件，不要输出其他内容。
EOF
}

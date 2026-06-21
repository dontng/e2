#!/usr/bin/env bash
# day-pipeline-prompt.sh — build unified day pipeline prompt (sourced by auto-review.sh)

build_day_pipeline_prompt() {
    local file="$1" fool_path="$2" probe_path="$3"
    local rel="${file#"$REPO_DIR"/}"
    cat <<EOF
你是日课 Agent。对同一天严格按顺序执行三步，不得跳步、不得并行。完成后静默退出。

生成前须 Read（与下文冲突以标尺为准）：
- $REPO_DIR/src/STANDARDS.md
- $REPO_DIR/fool/STANDARDS.md
- $REPO_DIR/probe/STANDARDS.md
- $REPO_DIR/probe/internal-skills.md

source：$file
fool：$fool_path
probe：$probe_path

【学员固定档位】首译稳定 3.5–4.5/10（英二约 35–45 分档）。讲解不引用仓库内任何历史 probe/fool/src 作样板。

=== 步骤 1 · 批改 src ===
若「## 批改」与「## 评分」已完整则跳过；否则只编辑 source 文件。
按 src/STANDARDS.md：填 ## 批改（[n] 标误、参考译文）、## 评分（采分点 ✓△✗）、## Vocab 与 ## Phrases（各 3 例句 + 例句意图：扣原句/考纲迁移/防坑）。
「## 问答收录」「## 练习与习得」保持空白；「## 复习区」不得改动。

=== 步骤 2 · fool 拆解 ===
若 fool 文件已有 ### fool- 条目则跳过；否则只编辑 fool 文件。
按 fool/STANDARDS.md：拆解 source 中 ## 原句、## Vocab 例句、## Phrases 例句（全部英文句）；不降维英文难度。

=== 步骤 3 · probe 内功诊断 ===
若 probe 已有 ## 内功印证 且 ## 今日带走（无「待诊断」、无 ## Q&A）则跳过；否则只编辑 probe 文件。
按 probe/STANDARDS.md 与 internal-skills.md 写：

【probe 范围 — 极重要】
- **仅针对** source 里田静「## 原句」下的**这一每日一句**，及「## 我的理解和翻译」「## 批改」「## 评分」
- **禁止**读取或分析 fool 文件；禁止对 Vocab/Phrases 例句做内功诊断
- 招式印证只写**当日这一句**上的误译过程，不得引用 fool 例句

probe 文件结构：
# dayN Probe
source: [链接]
---
## 今日刺痛
## 内功印证
## 招式印证
## 提分台阶
## 今日带走

删除 legacy ## Q&A。禁止问答题、禁止「待诊断」占位。
今日刺痛用感受语言；内功/招式标 Gxx/Pxx；今日带走 = 下一句译前 3 秒可做的**一个**检查点。
EOF
}

build_probe_migrate_prompt() {
    local file="$1" probe_path="$2"
    local rel="${file#"$REPO_DIR"/}"
    cat <<EOF
你是 probe 诊断师。仅执行 probe 迁移（legacy Q&A → 新格式）。

Read：$REPO_DIR/probe/STANDARDS.md、$REPO_DIR/probe/internal-skills.md
source：$file
probe：$probe_path

【probe 范围】仅针对 source「## 原句」田静每日一句 + 学员译文 + 批改 + 评分。
**禁止**读取 fool；禁止对例句做诊断。

只编辑 probe 文件：删除 ## Q&A；写 ## 今日刺痛 / ## 内功印证 / ## 招式印证 / ## 提分台阶 / ## 今日带走。
对照 internal-skills 标 Gxx/Pxx；禁止问答题与「待诊断」。完成后静默退出。
EOF
}

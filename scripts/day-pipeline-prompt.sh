#!/usr/bin/env bash
# day-pipeline-prompt.sh — Cursor Agent prompt builder (sourced by auto-review.sh)

build_day_pipeline_prompt() {
    local file="$1" fool_path="$2" probe_path="$3"
    cat <<EOF
你是日课 Agent。对同一天严格按顺序执行三步，不得跳步。完成后静默退出。

生成前须 Read 以下三份标尺全文：
- $REPO_DIR/src/standard.md
- $REPO_DIR/fool/standard.md
- $REPO_DIR/probe/standard.md

禁止参照仓库内任何历史 src / fool / probe 文件作样板。

【路径】
source：$file
fool：$fool_path
probe：$probe_path

=== 步骤 1：src 批改 ===
编辑 source 文件，按 src/standard.md 执行。
跳过条件：「## 批改」「## 评分」「## Vocab」「## Phrases」均已有实质内容。
不得改动「## 原句」「## 我的理解和翻译」「## 复习区」。「## 问答收录」「## 练习与习得」保持空白。

=== 步骤 2：fool 拆解 ===
编辑 fool 文件，按 fool/standard.md 执行。
跳过条件：fool 文件已存在且每条条目含词 / 词块 / 句式 / 翻译四步实质内容。
处理原句及当天全部 Vocab / Phrases 例句，从 fool-01 起编号。blockquote 英文与 source 一致。

=== 步骤 3：probe Q&A ===
编辑 probe 文件，按 probe/standard.md 执行。
跳过条件：probe 文件已存在且含 2–4 条有实质内容的 Q&A。
只针对原句，不处理 Vocab / Phrases 例句。
只读 source 的「## 原句」「## 我的理解和翻译」「## 批改」「## 评分」，禁止读 fool 文件。
EOF
}

build_probe_migrate_prompt() {
    local file="$1" probe_path="$2"
    cat <<EOF
你是日课 Agent。重写 probe 文件，按新格式生成。

Read：$REPO_DIR/probe/standard.md
source：$file
probe：$probe_path

清空 probe 文件现有内容，按 probe/standard.md 重新生成 2–4 条 Q&A。
只针对原句，只读 source 的「## 原句」「## 我的理解和翻译」「## 批改」「## 评分」。
完成后静默退出。
EOF
}

build_redo_review_prompt() {
    local file="$1"
    cat <<EOF
你是复习批改老师。只处理「## 复习区」。

Read：$REPO_DIR/src/standard.md
文件：$file

找到「**我的重译：**」已填、「**复习批改：**」为空的块，写入复习批改内容后直接编辑文件。
其余内容不得改动（含 <!-- review-meta -->）。完成后静默退出。
EOF
}

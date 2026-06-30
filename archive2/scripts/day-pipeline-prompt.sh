#!/usr/bin/env bash
# day-pipeline-prompt.sh — sourced by auto-review.sh

build_day_pipeline_prompt() {
    local file="$1" fool_path="$2" probe_path="$3"
    cat <<EOF
先 Read 这三个文件：
$REPO_DIR/src/standard.md
$REPO_DIR/fool/standard.md
$REPO_DIR/probe/standard.md

然后按顺序完成以下三步，每步完成再做下一步。不要参照仓库里任何已有的 src/fool/probe 文件。

第一步：批改
编辑 $file
按 src/standard.md 完成「## 批改」「## 评分」「## Vocab」「## Phrases」。
「## 原句」「## 我的理解和翻译」「## 复习区」不得改动。「## 问答收录」「## 练习与习得」留空。
这四个 section 都已有实质内容则跳过。

第二步：fool 拆解
编辑 $fool_path
按 fool/standard.md 对原句和全部 Vocab/Phrases 例句逐条拆解，fool-01 起编号，每条做词/词块/句式/翻译四步。
文件已存在且每条都有这四步则跳过。

第三步：probe
编辑 $probe_path
按 probe/standard.md 针对原句写 2–4 条 Q&A。
只读 $file 里的「## 原句」「## 我的理解和翻译」「## 批改」「## 评分」，不读 fool 文件。
文件已存在且有 2–4 条实质 Q&A 则跳过。
EOF
}

build_probe_migrate_prompt() {
    local file="$1" probe_path="$2"
    cat <<EOF
Read $REPO_DIR/probe/standard.md

清空 $probe_path，按 probe/standard.md 重新写 2–4 条 Q&A。
只读 $file 里的「## 原句」「## 我的理解和翻译」「## 批改」「## 评分」。
EOF
}

build_redo_review_prompt() {
    local file="$1"
    cat <<EOF
Read $REPO_DIR/src/standard.md

编辑 $file，在「## 复习区」里找「**我的重译：**」已填、「**复习批改：**」为空的块，写入复习批改。
其余内容不得改动，包括 <!-- review-meta -->。
EOF
}

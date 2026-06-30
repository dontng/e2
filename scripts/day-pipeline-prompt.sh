#!/usr/bin/env bash
# day-pipeline-prompt.sh — sourced by auto-review.sh

build_day_pipeline_prompt() {
    local file="$1"
    cat <<EOF
Read $REPO_DIR/src/standard.md

编辑 $file，按 src/standard.md 完成「## 批改 Correction」「## 评分 Scoring」「## Vocab」「## Phrases」。
「## 原句」「## 我的理解和翻译」不得改动。
四个 section 都已有实质内容则跳过。
EOF
}


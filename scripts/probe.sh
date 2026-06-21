#!/usr/bin/env bash
# probe.sh — probe 完成度检测（生成由 Agent 在批改流水线内一步写入）
# Sourced by auto-review.sh; requires REPO_DIR and log() to be defined.

needs_probe() {
    [[ ! -f "$1" ]]
}

# probe 诊断段已完整写入（非 legacy Q&A / 待诊断）
probe_complete() {
    local probe_path="$1"
    [[ -f "$probe_path" ]] || return 1
    grep -q '^## Q&A' "$probe_path" 2>/dev/null && return 1
    grep -q '待诊断' "$probe_path" 2>/dev/null && return 1
    grep -q '^## 内功印证' "$probe_path" 2>/dev/null || return 1
    grep -q '^## 今日带走' "$probe_path" 2>/dev/null || return 1
    # 内功印证 section 有实质内容（非仅占位）
    awk '/^## 内功印证/{f=1;next} f&&/^## /{exit} f' "$probe_path" | grep -qv '^[[:space:]]*$'
}

# 旧版 Q&A / 待诊断 / 缺诊断段 → 需单独 probe 迁移（legacy pass）
needs_probe_diagnose() {
    local probe_path="$1"
    [[ -f "$probe_path" ]] || return 0
    probe_complete "$probe_path" && return 1
    return 0
}

has_score() {
    awk '/^## 评分/{f=1;next} f&&/^## /{exit} f' "$1" | grep -q '[^[:space:]]'
}

day_paths() {
    local source_file="$1"
    local rel="${source_file#$REPO_DIR/}"
    FOOL_PATH="${source_file/\/src\//\/fool\/}"; FOOL_PATH="${FOOL_PATH%.md}-fool.md"
    PROBE_PATH="${source_file/\/src\//\/probe\/}"; PROBE_PATH="${PROBE_PATH%.md}-probe.md"
    DAY_REL="$rel"
}

#!/usr/bin/env bash
# probe.sh — probe 完成度检测（生成由 Agent 在批改流水线内一步写入）
# Sourced by auto-review.sh; requires REPO_DIR.

needs_probe() {
    [[ ! -f "$1" ]]
}

# probe 诊断段已完整（非 legacy Q&A / 待诊断；含原句摘抄）
probe_complete() {
    local probe_path="$1"
    [[ -f "$probe_path" ]] || return 1
    grep -q '^## Q&A' "$probe_path" 2>/dev/null && return 1
    grep -q '待诊断' "$probe_path" 2>/dev/null && return 1
    grep -q '^## 原句' "$probe_path" 2>/dev/null || return 1
    awk '/^## 原句/{f=1;next} f&&/^## /{exit} f' "$probe_path" | grep -q '^>[[:space:]]' || return 1
    grep -q '^## 今日刺痛' "$probe_path" 2>/dev/null || return 1
    grep -q '^## 内功印证' "$probe_path" 2>/dev/null || return 1
    grep -q '^## 招式印证' "$probe_path" 2>/dev/null || return 1
    grep -q '^## 提分台阶' "$probe_path" 2>/dev/null || return 1
    grep -q '^## 今日带走' "$probe_path" 2>/dev/null || return 1
    awk '/^## 内功印证/{f=1;next} f&&/^## /{exit} f' "$probe_path" | grep -qv '^[[:space:]]*$' || return 1
    awk '/^## 今日刺痛/{f=1;next} f&&/^## /{exit} f' "$probe_path" | grep -qv '^[[:space:]]*$' || return 1
    awk '/^## 今日带走/{f=1;next} f&&/^## /{exit} f' "$probe_path" | grep -qv '^[[:space:]]*$' || return 1
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
    if [[ "$source_file" != /* ]]; then
        source_file="$REPO_DIR/$source_file"
    fi
    rel="${source_file#$REPO_DIR/}"
    rel="${rel#/}"
    FOOL_PATH="${source_file/\/src\//\/fool\/}"; FOOL_PATH="${FOOL_PATH%.md}-fool.md"
    PROBE_PATH="${source_file/\/src\//\/probe\/}"; PROBE_PATH="${PROBE_PATH%.md}-probe.md"
    DAY_REL="$rel"
}

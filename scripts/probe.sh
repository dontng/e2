#!/usr/bin/env bash
# probe.sh — 日 probe 裁切 + 待诊断标记
# Sourced by auto-review.sh; requires REPO_DIR and log() to be defined.

needs_probe() {
    [[ ! -f "$1" ]]
}

# 旧版 Q&A 探针或诊断段含「待诊断」→ 需要 probe_diagnose
needs_probe_diagnose() {
    local probe_path="$1"
    [[ -f "$probe_path" ]] || return 1
    if grep -q '待诊断' "$probe_path" 2>/dev/null; then
        return 0
    fi
    if grep -q '^## Q&A' "$probe_path" 2>/dev/null; then
        return 0
    fi
    if ! grep -q '^## 内功印证' "$probe_path" 2>/dev/null; then
        return 0
    fi
    return 1
}

has_score() {
    awk '/^## 评分/{f=1;next} f&&/^## /{exit} f' "$1" | grep -q '[^[:space:]]'
}

create_probe() {
    local source_file="$1"
    local probe_path="$2"
    local rel="${source_file#$REPO_DIR/}"

    mkdir -p "$(dirname "$probe_path")"

    local stem; stem=$(basename "$probe_path" -probe.md)
    local day_num; day_num=$(echo "$stem" | grep -oE 'day[0-9]+')

    local original translation score
    original=$(awk '/^## 原句/{f=1;next} f&&/^## /{exit} f' "$source_file")
    translation=$(awk '/^## 我的理解和翻译/{f=1;next} f&&/^## /{exit} f' "$source_file")
    score=$(awk '/^## 评分/{f=1;next} f&&/^## /{exit} f' "$source_file")

    {
        printf '# %s Probe\n\n' "$day_num"
        printf 'source: [%s](../../%s)\n\n' "$rel" "$rel"
        printf '%s\n\n' '---'
        printf '## 原句\n\n%s\n\n' "$original"
        printf '## 我的翻译\n\n%s\n\n' "$translation"
        printf '## 评分\n\n%s\n\n' "$score"
        printf '%s\n\n' '---'
        printf '%s\n\n' '## 今日刺痛'
        printf '%s\n\n' '（待诊断）'
        printf '%s\n\n' '## 内功印证'
        printf '%s\n\n' '（待诊断）'
        printf '%s\n\n' '## 招式印证'
        printf '%s\n\n' '（待诊断）'
        printf '%s\n\n' '## 提分台阶'
        printf '%s\n\n' '（待诊断）'
        printf '%s\n\n' '## 今日带走'
        printf '%s\n' '（待诊断）'
    } > "$probe_path"

    log "Probe scaffold: ${probe_path#$REPO_DIR/}"
}

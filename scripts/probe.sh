#!/usr/bin/env bash
# probe.sh — per-sentence probe card (原句 + 翻译 + 评分 + Q&A placeholder)
# Sourced by auto-review.sh; requires REPO_DIR and log() to be defined.

needs_probe() {
    [[ ! -f "$1" ]]
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
        printf '%s\n\n%s\n\n' '---' '## Q&A'
    } > "$probe_path"

    log "Probe: ${probe_path#$REPO_DIR/}"
}

#!/usr/bin/env bash
# src.sh — src 日课批改完成度检测（依赖 probe.sh 的 has_score）
# Sourced by auto-review.sh after probe.sh

has_correction() {
    awk '/^## 批改/{f=1;next} f&&/^## /{exit} f' "$1" | grep -q '[^[:space:]]'
}

# 步骤 1 完成：批改+评分+Vocab/Phrases 已有实质内容（见 src/STANDARDS.md §10）
src_day_complete() {
    local f="$1"
    has_correction "$f" || return 1
    has_score "$f" || return 1
    awk '/^## Vocab/{f=1;next} f&&/^## /{exit} f' "$f" | grep -q '例句意图' || return 1
    awk '/^## Phrases/{f=1;next} f&&/^## /{exit} f' "$f" | grep -q '例句意图' || return 1
    return 0
}

#!/usr/bin/env bash
# fool.sh — fool 完成度检测（生成由 Agent 在批改流水线内一步写入）
# Sourced by auto-review.sh; requires REPO_DIR.

# v2 标尺：四步标题须为 扫词 / 扫词块 / 扫句式 / 读句子（见 fool/STANDARDS.md §5–8）
fool_complete() {
    local fool_path="$1"
    [[ -f "$fool_path" ]] || return 1
    grep -q '^### fool-' "$fool_path" || return 1

    # 旧版 Step 2 标题 → 视为未完成，触发按新标尺重写
    if grep -qE '\*\*Step 2 扫(小品词|挂接|单词块|词组)' "$fool_path" 2>/dev/null \
        && ! grep -q '\*\*Step 2 扫词块' "$fool_path" 2>/dev/null; then
        return 1
    fi

    grep -q '\*\*Step 1 扫词' "$fool_path" || return 1
    grep -q '\*\*Step 2 扫词块' "$fool_path" || return 1
    grep -q '\*\*Step 3 扫句式' "$fool_path" || return 1
    grep -q '\*\*Step 4 读句子' "$fool_path" || return 1

    # 至少第一条 fool 含完整四步（防只写 header 或后段塌缩）
    awk '
        /^### fool-/ { if (n++) exit; blk=1 }
        blk { print }
    ' "$fool_path" | grep -q '\*\*Step 4 读句子' || return 1

    return 0
}

needs_fool() {
    local _source_file="$1"
    local fool_path="$2"
    [[ ! -f "$fool_path" ]] && return 0
    ! fool_complete "$fool_path" && return 0
    return 1
}

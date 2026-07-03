#!/usr/bin/env bash
# Maintain top/bottom navigation for canonical files under src/.
#
# Canonical rules:
#   - Normal daily files are named MMDD-dayN.md.
#   - The only historical exception is src/june/0630-day67-v2.md.
#   - Other variants such as -v3 or -minimal are ignored and have nav removed.
#   - Dates do not need to be consecutive. Nav only links consecutive day numbers.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="$REPO_DIR/src"

is_nav_line() {
    [[ "$1" == *"«"* || "$1" == *"»"* ]]
}

strip_nav_in_place() {
    local file="$1"
    local tmp
    tmp="$(mktemp)"
    cp "$file" "$tmp"

    while [[ -s "$tmp" ]] && is_nav_line "$(head -n 1 "$tmp")"; do
        sed -i '1d' "$tmp"
        while [[ -s "$tmp" ]] && [[ "$(head -n 1 "$tmp")" =~ ^[[:space:]]*$ ]]; do
            sed -i '1d' "$tmp"
        done
    done

    while [[ -s "$tmp" ]] && is_nav_line "$(tail -n 1 "$tmp")"; do
        sed -i '$d' "$tmp"
        while [[ -s "$tmp" ]] && [[ "$(tail -n 1 "$tmp")" =~ ^[[:space:]]*$ ]]; do
            sed -i '$d' "$tmp"
        done
    done

    mv "$tmp" "$file"
}

rel_path() {
    local from="$1" to="$2"
    if [[ "$(dirname "$from")" == "$(dirname "$to")" ]]; then
        basename "$to"
    else
        printf '../%s/%s' "$(basename "$(dirname "$to")")" "$(basename "$to")"
    fi
}

nav_line() {
    local prev_stem="$1" prev_url="$2" next_stem="$3" next_url="$4"
    local nav=""
    [[ -n "$prev_stem" ]] && nav+="[« ${prev_stem}](${prev_url})"
    [[ -n "$prev_stem" && -n "$next_stem" ]] && nav+="　　"
    [[ -n "$next_stem" ]] && nav+="[${next_stem} »](${next_url})"
    printf '%s' "$nav"
}

add_nav() {
    local file="$1" nav="$2" tmp
    tmp="$(mktemp)"
    { printf '%s\n\n' "$nav"; cat "$file"; printf '\n\n%s\n' "$nav"; } > "$tmp"
    mv "$tmp" "$file"
}

is_canonical() {
    local file="$1"
    local base
    base="$(basename "$file")"

    if [[ "$base" == "0630-day67-v2.md" ]]; then
        return 0
    fi

    if [[ "$base" =~ ^0630-day67 ]]; then
        return 1
    fi

    [[ "$base" =~ ^[0-9]{4}-day[0-9]+\.md$ ]]
}

day_num() {
    local base="$1"
    base="$(basename "$base")"
    [[ "$base" =~ day([0-9]+) ]] || return 1
    printf '%s' "${BASH_REMATCH[1]}"
}

main() {
    mapfile -t all_files < <(find "$SRC_DIR" -type f -name '*.md' | sort)

    for f in "${all_files[@]}"; do
        strip_nav_in_place "$f"
    done

    declare -a days=()
    declare -a files=()

    for f in "${all_files[@]}"; do
        if is_canonical "$f"; then
            days+=("$(day_num "$f")")
            files+=("$f")
        fi
    done

    if ((${#days[@]} == 0)); then
        echo "src-nav: no canonical files"
        return 0
    fi

    local sorted
    sorted="$(mktemp)"
    for i in "${!days[@]}"; do
        printf '%05d\t%s\n' "${days[$i]}" "${files[$i]}" >> "$sorted"
    done
    sort -n "$sorted" -o "$sorted"

    days=()
    files=()
    while IFS=$'\t' read -r d f; do
        days+=("$d")
        files+=("$f")
    done < "$sorted"
    rm -f "$sorted"

    echo "src-nav: ${#files[@]} canonical file(s)"

    for i in "${!files[@]}"; do
        local cur_day cur_file prev_stem prev_url next_stem next_url nav
        cur_day="${days[$i]}"
        cur_file="${files[$i]}"
        prev_stem=""
        prev_url=""
        next_stem=""
        next_url=""

        if (( i > 0 )) && (( 10#$cur_day - 10#${days[$((i - 1))]} == 1 )); then
            prev_stem="$(basename "${files[$((i - 1))]}" .md)"
            prev_url="$(rel_path "$cur_file" "${files[$((i - 1))]}")"
        fi

        if (( i + 1 < ${#files[@]} )) && (( 10#${days[$((i + 1))]} - 10#$cur_day == 1 )); then
            next_stem="$(basename "${files[$((i + 1))]}" .md)"
            next_url="$(rel_path "$cur_file" "${files[$((i + 1))]}")"
        fi

        nav="$(nav_line "$prev_stem" "$prev_url" "$next_stem" "$next_url")"
        if [[ -n "$nav" ]]; then
            add_nav "$cur_file" "$nav"
        fi

        printf '  day%s  %s  <- %s(%s)  -> %s(%s)\n' \
            "$((10#$cur_day))" "$(basename "$cur_file" .md)" \
            "$prev_stem" "$prev_url" "$next_stem" "$next_url"
    done

    echo "src-nav: done"
}

main "$@"

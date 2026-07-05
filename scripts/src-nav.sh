#!/usr/bin/env bash
# Maintain top/bottom navigation for canonical files under src/.
#
# Canonical rules:
#   - Normal daily files are named MMDD-dayN.md.
#   - The only historical exception is src/june/0630-day67-v2.md.
#   - Other variants such as -v3 or -minimal are ignored and have nav removed.
#   - Dates do not need to be consecutive. Nav only links consecutive day numbers.
#
# The script is intentionally idempotent: it scans src/ to calculate the desired
# graph, but only writes files whose rendered navigation would actually change.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="$REPO_DIR/src"
MODE="write"

usage() {
    cat <<'EOF'
Usage:
  bash scripts/src-nav.sh          sync navigation, writing changed files only
  bash scripts/src-nav.sh --check  report files that would change, write nothing
  bash scripts/src-nav.sh --around src/july/0705-day72.md
                                   sync only that file and adjacent day files
EOF
}

AROUND_FILE=""

while (($#)); do
    case "$1" in
        --check)
            MODE="check"
            ;;
        --around)
            shift
            if (($# == 0)); then
                echo "src-nav: --around requires a file path" >&2
                exit 2
            fi
            AROUND_FILE="$1"
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "src-nav: unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
    shift
done

if [[ -n "$AROUND_FILE" ]]; then
    if [[ "$AROUND_FILE" != /* ]]; then
        AROUND_FILE="$REPO_DIR/$AROUND_FILE"
    fi
    AROUND_FILE="$(cd "$(dirname "$AROUND_FILE")" && pwd)/$(basename "$AROUND_FILE")"
fi

is_nav_line() {
    [[ "$1" == *"«"* || "$1" == *"»"* ]]
}

strip_nav_to_file() {
    local file="$1" out="$2" tmp
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

    mv "$tmp" "$out"
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

render_expected() {
    local file="$1" nav="$2" out="$3" stripped
    stripped="$(mktemp)"
    strip_nav_to_file "$file" "$stripped"

    if [[ -n "$nav" ]]; then
        { printf '%s\n\n' "$nav"; cat "$stripped"; printf '\n\n%s\n' "$nav"; } > "$out"
        rm -f "$stripped"
    else
        mv "$stripped" "$out"
    fi
}

is_canonical() {
    local file="$1" base
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

set_desired_nav() {
    local file="$1" nav="$2"
    desired_files+=("$file")
    desired_navs+=("$nav")
}

sync_file() {
    local file="$1" nav="$2" expected
    expected="$(mktemp)"
    render_expected "$file" "$nav" "$expected"

    if cmp -s "$file" "$expected"; then
        rm -f "$expected"
        return 1
    fi

    if [[ "$MODE" == "check" ]]; then
        printf 'would update: %s\n' "${file#$REPO_DIR/}"
        rm -f "$expected"
    else
        mv "$expected" "$file"
        printf 'updated: %s\n' "${file#$REPO_DIR/}"
    fi
    return 0
}

should_sync_file() {
    local file="$1" target

    if [[ -z "$AROUND_FILE" ]]; then
        return 0
    fi

    for target in "${target_files[@]}"; do
        [[ "$file" == "$target" ]] && return 0
    done

    return 1
}

main() {
    mapfile -t all_files < <(find "$SRC_DIR" -type f -name '*.md' | sort)

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

    declare -g -a desired_files=()
    declare -g -a desired_navs=()
    declare -g -a target_files=()

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

        if [[ -n "$AROUND_FILE" && "$cur_file" == "$AROUND_FILE" ]]; then
            target_files+=("$cur_file")
            if [[ -n "$prev_stem" ]]; then
                target_files+=("${files[$((i - 1))]}")
            fi
            if [[ -n "$next_stem" ]]; then
                target_files+=("${files[$((i + 1))]}")
            fi
        fi

        nav="$(nav_line "$prev_stem" "$prev_url" "$next_stem" "$next_url")"
        set_desired_nav "$cur_file" "$nav"

        printf '  day%s  %s  <- %s(%s)  -> %s(%s)\n' \
            "$((10#$cur_day))" "$(basename "$cur_file" .md)" \
            "$prev_stem" "$prev_url" "$next_stem" "$next_url"
    done

    # Non-canonical md files should not carry generated nav, but they are only
    # touched if such nav is actually present.
    for f in "${all_files[@]}"; do
        if ! is_canonical "$f"; then
            set_desired_nav "$f" ""
        fi
    done

    if [[ -n "$AROUND_FILE" && ${#target_files[@]} -eq 0 ]]; then
        echo "src-nav: --around file is not canonical: ${AROUND_FILE#$REPO_DIR/}" >&2
        return 2
    fi

    local changed=0
    for i in "${!desired_files[@]}"; do
        should_sync_file "${desired_files[$i]}" || continue
        if sync_file "${desired_files[$i]}" "${desired_navs[$i]}"; then
            changed=$((changed + 1))
        fi
    done

    if [[ "$MODE" == "check" ]] && ((changed > 0)); then
        echo "src-nav: $changed file(s) need update"
        return 1
    fi

    echo "src-nav: $changed file(s) changed"
}

main "$@"

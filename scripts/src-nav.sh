#!/usr/bin/env bash
# src-nav.sh — maintain « prev  next » navigation in src/ daily files
#
# Rules:
#   - Show only the arrows that exist; no placeholders.
#   - Nav only links consecutive day numbers (dayN ↔ dayN+1).
#   - Canonical file per day: prefer the one that already carries nav,
#     then highest numeric version. Suffixes like -minimal are excluded.

set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ─── helpers ──────────────────────────────────────────────────────────────

rel_path() {
    local from="$1" to="$2"
    if [[ "$(dirname "$from")" == "$(dirname "$to")" ]]; then
        basename "$to"
    else
        echo "../$(basename "$(dirname "$to")")/$(basename "$to")"
    fi
}


build_nav() {
    local prev_stem="$1" prev_url="$2" next_stem="$3" next_url="$4"
    local nav=""
    [[ -n "$prev_stem" ]] && nav+="[« ${prev_stem}](${prev_url})"
    [[ -n "$prev_stem" && -n "$next_stem" ]] && nav+="　　"
    [[ -n "$next_stem" ]] && nav+="[${next_stem} »](${next_url})"
    printf '%s' "$nav"
}

is_nav_line() {
    printf '%s' "$1" | grep -qE '[«»]'
}

strip_nav() {
    local file="$1"
    local tmp; tmp=$(mktemp)
    cp "$file" "$tmp"
    while is_nav_line "$(head -1 "$tmp")"; do
        sed -i '1d' "$tmp"
        while head -1 "$tmp" | grep -q '^[[:space:]]*$'; do sed -i '1d' "$tmp"; done
    done
    while is_nav_line "$(tail -1 "$tmp")"; do
        sed -i '$d' "$tmp"
        while tail -1 "$tmp" | grep -q '^[[:space:]]*$'; do sed -i '$d' "$tmp"; done
    done
    echo "$tmp"
}

apply_nav() {
    local file="$1" nav="$2"
    local stripped; stripped=$(strip_nav "$file")
    local tmp; tmp=$(mktemp)
    { printf '%s\n\n' "$nav"; cat "$stripped"; printf '\n\n%s\n' "$nav"; } > "$tmp"
    mv "$tmp" "$file"
    rm -f "$stripped"
}

# ─── canonical file discovery ─────────────────────────────────────────────

collect_and_rank() {
    while IFS= read -r f; do
        local name; name=$(basename "$f" .md)
        [[ "$name" =~ ^[0-9]{4}-day([0-9]+)(-v([0-9]+))?$ ]] || continue
        local daynum="${BASH_REMATCH[1]}"
        local vernum="${BASH_REMATCH[3]:-0}"
        local has_nav=0
        is_nav_line "$(head -1 "$f")" && has_nav=1
        printf '%05d %02d %d %s\n' "$daynum" "$vernum" "$has_nav" "$f"
    done < <(find "$REPO_DIR/src" -name "*.md" ! -name "standard.md" | sort) \
    | sort -k1,1n -k3,3rn -k2,2rn
}

# ─── main ─────────────────────────────────────────────────────────────────

declare -a DAYS=()
declare -a PATHS=()
prev_day_key=""

while IFS=' ' read -r daynum vernum has_nav f; do
    [[ "$daynum" == "$prev_day_key" ]] && continue
    prev_day_key="$daynum"
    DAYS+=("$daynum")
    PATHS+=("$f")
done < <(collect_and_rank)

n=${#DAYS[@]}
echo "src-nav: $n canonical file(s)"

for ((i=0; i<n; i++)); do
    cur_day="${DAYS[$i]}"
    cur_path="${PATHS[$i]}"
    cur_stem=$(basename "$cur_path" .md)

    # ── left (prev) ───────────────────────────────────────────────────────
    prev_stem="" prev_url=""
    if (( i > 0 )) && (( 10#$cur_day - 10#${DAYS[$((i-1))]} == 1 )); then
        prev_stem=$(basename "${PATHS[$((i-1))]}" .md)
        prev_url=$(rel_path "$cur_path" "${PATHS[$((i-1))]}")
    fi

    # ── right (next) ──────────────────────────────────────────────────────
    next_stem="" next_url=""
    if (( i < n-1 )) && (( 10#${DAYS[$((i+1))]} - 10#$cur_day == 1 )); then
        next_stem=$(basename "${PATHS[$((i+1))]}" .md)
        next_url=$(rel_path "$cur_path" "${PATHS[$((i+1))]}")
    fi

    nav=$(build_nav "$prev_stem" "$prev_url" "$next_stem" "$next_url")
    apply_nav "$cur_path" "$nav"
    printf '  day%s  %s  ← %s(%s)  → %s(%s)\n' \
        "$(( 10#$cur_day ))" "$cur_stem" "$prev_stem" "$prev_url" "$next_stem" "$next_url"
done

echo "src-nav: done"

#!/usr/bin/env bash
# nav.sh — inline navigation for fool/ and probe/ files
# Sourced by auto-review.sh; requires REPO_DIR, log(), all_fool_stems(), all_probe_stems()
# (defined in console.sh, which must be sourced first).

# Relative path from one file to another within the same two-level dir (type/month/file).
_nav_rel() {
    local from="$1" to="$2"
    local from_dir; from_dir=$(dirname "$from")
    local to_dir;   to_dir=$(dirname "$to")
    if [[ "$from_dir" == "$to_dir" ]]; then
        basename "$to"
    else
        echo "../$(basename "$to_dir")/$(basename "$to")"
    fi
}

# Return temp file with nav lines stripped from $1.
# Checks top and bottom independently: a nav line contains «»←→.
_strip_nav() {
    local file="$1"
    local tmp; tmp=$(mktemp)
    local strip_top=0 strip_bottom=0
    head -1 "$file" | grep -q '[«»←→]' && strip_top=1
    tail -1 "$file" | grep -q '[«»←→]' && strip_bottom=1

    if [[ $strip_top -eq 1 && $strip_bottom -eq 1 ]]; then
        tail -n +3 "$file" | head -n -2 > "$tmp"
    elif [[ $strip_top -eq 1 ]]; then
        tail -n +3 "$file" > "$tmp"
    elif [[ $strip_bottom -eq 1 ]]; then
        head -n -2 "$file" > "$tmp"
    else
        cp "$file" "$tmp"
    fi
    echo "$tmp"
}

# Rewrite $file with nav prepended+appended (strips existing nav first).
_apply_nav() {
    local file="$1" nav="$2"
    local stripped; stripped=$(_strip_nav "$file")
    local tmp; tmp=$(mktemp)
    {
        [[ -n "$nav" ]] && printf '%s\n\n' "$nav"
        cat "$stripped"
        [[ -n "$nav" ]] && printf '\n\n%s\n' "$nav"
    } > "$tmp"
    mv "$tmp" "$file"
    rm -f "$stripped"
}

_build_nav() {
    local prev_stem="$1" next_stem="$2" prev_url="$3" next_url="$4"
    local nav=""
    [[ -n "$prev_stem" ]] && nav+="« [$prev_stem]($prev_url)"
    [[ -n "$prev_stem" && -n "$next_stem" ]] && nav+="　　"
    [[ -n "$next_stem" ]] && nav+="[$next_stem]($next_url) »"
    echo "$nav"
}

# _add_nav TYPE PATH
# Add/update nav for a newly created file of TYPE (fool|probe), and update its predecessor.
_add_nav() {
    local type="$1" file_path="$2"
    [[ "$file_path" != /* ]] && file_path="$REPO_DIR/$file_path"
    [[ -f "$file_path" ]] || return

    local suffix="-${type}.md"
    local stem; stem=$(basename "$file_path" "$suffix")
    local dir="$REPO_DIR/$type"

    local all_stems=()
    if [[ "$type" == "fool" ]]; then
        while IFS= read -r s; do all_stems+=("$s"); done < <(all_fool_stems)
    else
        while IFS= read -r s; do all_stems+=("$s"); done < <(all_probe_stems)
    fi

    local idx=-1
    for i in "${!all_stems[@]}"; do
        [[ "${all_stems[$i]}" == "$stem" ]] && idx=$i && break
    done
    [[ $idx -lt 0 ]] && return

    local n=${#all_stems[@]}
    local prev_stem="" next_stem=""
    [[ $idx -gt 0 ]]       && prev_stem="${all_stems[$((idx-1))]}"
    [[ $idx -lt $((n-1)) ]] && next_stem="${all_stems[$((idx+1))]}"

    local prev_url="" next_url=""
    if [[ -n "$prev_stem" ]]; then
        local prev_path; prev_path=$(find "$dir" -name "${prev_stem}${suffix}" | head -1)
        [[ -f "$prev_path" ]] && prev_url=$(_nav_rel "$file_path" "$prev_path")
    fi
    if [[ -n "$next_stem" ]]; then
        local next_path; next_path=$(find "$dir" -name "${next_stem}${suffix}" | head -1)
        [[ -f "$next_path" ]] && next_url=$(_nav_rel "$file_path" "$next_path")
    fi

    local nav; nav=$(_build_nav "$prev_stem" "$next_stem" "$prev_url" "$next_url")
    _apply_nav "$file_path" "$nav"
    log "Nav $type: $stem"

    # Update predecessor: add → link to current
    if [[ -n "$prev_stem" ]]; then
        local prev_path; prev_path=$(find "$dir" -name "${prev_stem}${suffix}" | head -1)
        if [[ -f "$prev_path" ]]; then
            local pp_stem=""
            [[ $idx -gt 1 ]] && pp_stem="${all_stems[$((idx-2))]}"
            local pp_url=""
            if [[ -n "$pp_stem" ]]; then
                local pp_path; pp_path=$(find "$dir" -name "${pp_stem}${suffix}" | head -1)
                [[ -f "$pp_path" ]] && pp_url=$(_nav_rel "$prev_path" "$pp_path")
            fi
            local cur_url; cur_url=$(_nav_rel "$prev_path" "$file_path")
            local prev_nav; prev_nav=$(_build_nav "$pp_stem" "$stem" "$pp_url" "$cur_url")
            _apply_nav "$prev_path" "$prev_nav"
        fi
    fi
}

add_fool_nav()  { _add_nav "fool"  "$1"; }
add_probe_nav() { _add_nav "probe" "$1"; }

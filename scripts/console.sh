#!/usr/bin/env bash
# console.sh — 3-day rolling console window management
# Sourced by auto-review.sh; requires REPO_DIR and log() to be defined.

CONSOLE_WINDOW=3

# Write one console file: nav + content + nav.
# type (arg $7, default "fool"): controls output filename and default URL suffix.
# prev_url/next_url (args $5/$6): explicit link targets; default to stem-{type}.md.
write_console_file() {
    local stem="$1" content_path="$2" prev_label="$3" next_label="$4"
    local prev_url="${5:-}" next_url="${6:-}" type="${7:-fool}"
    [[ -z "$prev_url" && -n "$prev_label" ]] && prev_url="$prev_label-${type}.md"
    [[ -z "$next_url" && -n "$next_label" ]] && next_url="$next_label-${type}.md"
    local out="$REPO_DIR/console/$stem-${type}.md"
    local nav=""
    [[ -n "$prev_label" ]] && nav+="« [$prev_label]($prev_url)"
    [[ -n "$prev_label" && -n "$next_label" ]] && nav+="　　"
    [[ -n "$next_label" ]] && nav+="[$next_label]($next_url) »"
    {
        [[ -n "$nav" ]] && printf '%s\n\n' "$nav"
        cat "$content_path"
        [[ -n "$nav" ]] && printf '\n\n%s\n' "$nav"
    } > "$out"
}

# Sorted list of all fool stems across all subdirs.
all_fool_stems() {
    find "$REPO_DIR/fool" -name "*-fool.md" -printf '%f\t%p\n' | sort | cut -f1 | sed 's/-fool\.md$//'
}

# Sorted list of all probe stems across all subdirs.
all_probe_stems() {
    find "$REPO_DIR/probe" -name "*-probe.md" -printf '%f\t%p\n' | sort | cut -f1 | sed 's/-probe\.md$//'
}

# Rewrite today.md: exam countdown + links to newest fool and probe entries.
EXAM_DATE="2026-12-18"

update_today_md() {
    local console_dir="$REPO_DIR/console"
    local fool_stem="" probe_stem=""
    local fool_latest probe_latest
    fool_latest=$(find "$console_dir" -name "*-fool.md" | sort | tail -1)
    [[ -n "$fool_latest" ]] && fool_stem=$(basename "$fool_latest" -fool.md)
    probe_latest=$(find "$console_dir" -name "*-probe.md" | sort | tail -1)
    [[ -n "$probe_latest" ]] && probe_stem=$(basename "$probe_latest" -probe.md)

    {
        [[ -n "$fool_stem"  ]] && printf '» [今天 fool · %s](%s-fool.md)\n\n'  "$fool_stem"  "$fool_stem"
        [[ -n "$probe_stem" ]] && printf '» [今天 probe · %s](%s-probe.md)\n'  "$probe_stem" "$probe_stem"
    } > "$console_dir/today.md"
}

# Maintain a 3-day rolling window of fool files in console/.
create_console_entry() {
    local fool_path="$1"
    local stem; stem=$(basename "$fool_path" -fool.md)
    local console_dir="$REPO_DIR/console"
    mkdir -p "$console_dir"

    local window=()
    while IFS= read -r f; do
        window+=("$(basename "$f" -fool.md)")
    done < <(find "$console_dir" -name "*-fool.md" | sort)

    local prev_stem=""
    [[ ${#window[@]} -gt 0 ]] && prev_stem="${window[-1]}"

    write_console_file "$stem" "$fool_path" "$prev_stem" ""

    if [[ -n "$prev_stem" ]]; then
        local prev_prev=""
        [[ ${#window[@]} -ge 2 ]] && prev_prev="${window[-2]}"
        local prev_fool; prev_fool=$(find "$REPO_DIR/fool" -name "${prev_stem}-fool.md" | head -1)
        [[ -f "$prev_fool" ]] && write_console_file "$prev_stem" "$prev_fool" "$prev_prev" "$stem"
    fi

    window+=("$stem")
    while [[ ${#window[@]} -gt $CONSOLE_WINDOW ]]; do
        local evicted="${window[0]}"
        rm -f "$console_dir/$evicted-fool.md"
        window=("${window[@]:1}")
        log "Console: evicted fool $evicted"
    done

    local oldest="${window[0]}"
    local oldest_fool; oldest_fool=$(find "$REPO_DIR/fool" -name "${oldest}-fool.md" | head -1)
    if [[ -f "$oldest_fool" ]]; then
        local prev_of_oldest="" prev_of_oldest_path=""
        local prev_candidate=""
        while IFS= read -r candidate; do
            [[ "$candidate" == "$oldest" ]] && { prev_of_oldest="$prev_candidate"; break; }
            prev_candidate="$candidate"
        done < <(all_fool_stems)
        if [[ -n "$prev_of_oldest" ]]; then
            prev_of_oldest_path=$(find "$REPO_DIR/fool" -name "${prev_of_oldest}-fool.md" | head -1)
        fi
        local next_of_oldest="${window[1]:-}"
        local prev_url=""
        [[ -n "$prev_of_oldest_path" ]] && prev_url="../${prev_of_oldest_path#$REPO_DIR/}"
        write_console_file "$oldest" "$oldest_fool" "$prev_of_oldest" "$next_of_oldest" "$prev_url"
    fi

    update_today_md
    log "Console fool: $stem  window=[${window[*]}]"
}

# Maintain a 3-day rolling window of probe files in console/.
create_probe_console_entry() {
    local probe_path="$1"
    local stem; stem=$(basename "$probe_path" -probe.md)
    local console_dir="$REPO_DIR/console"
    mkdir -p "$console_dir"

    local window=()
    while IFS= read -r f; do
        window+=("$(basename "$f" -probe.md)")
    done < <(find "$console_dir" -name "*-probe.md" | sort)

    local prev_stem=""
    [[ ${#window[@]} -gt 0 ]] && prev_stem="${window[-1]}"

    write_console_file "$stem" "$probe_path" "$prev_stem" "" "" "" "probe"

    if [[ -n "$prev_stem" ]]; then
        local prev_prev=""
        [[ ${#window[@]} -ge 2 ]] && prev_prev="${window[-2]}"
        local prev_probe; prev_probe=$(find "$REPO_DIR/probe" -name "${prev_stem}-probe.md" | head -1)
        [[ -f "$prev_probe" ]] && write_console_file "$prev_stem" "$prev_probe" "$prev_prev" "$stem" "" "" "probe"
    fi

    window+=("$stem")
    while [[ ${#window[@]} -gt $CONSOLE_WINDOW ]]; do
        local evicted="${window[0]}"
        rm -f "$console_dir/$evicted-probe.md"
        window=("${window[@]:1}")
        log "Console: evicted probe $evicted"
    done

    local oldest="${window[0]}"
    local oldest_probe; oldest_probe=$(find "$REPO_DIR/probe" -name "${oldest}-probe.md" | head -1)
    if [[ -f "$oldest_probe" ]]; then
        local prev_of_oldest="" prev_of_oldest_path=""
        local prev_candidate=""
        while IFS= read -r candidate; do
            [[ "$candidate" == "$oldest" ]] && { prev_of_oldest="$prev_candidate"; break; }
            prev_candidate="$candidate"
        done < <(all_probe_stems)
        if [[ -n "$prev_of_oldest" ]]; then
            prev_of_oldest_path=$(find "$REPO_DIR/probe" -name "${prev_of_oldest}-probe.md" | head -1)
        fi
        local next_of_oldest="${window[1]:-}"
        local prev_url=""
        [[ -n "$prev_of_oldest_path" ]] && prev_url="../${prev_of_oldest_path#$REPO_DIR/}"
        write_console_file "$oldest" "$oldest_probe" "$prev_of_oldest" "$next_of_oldest" "$prev_url" "" "probe"
    fi

    update_today_md
    log "Console probe: $stem  window=[${window[*]}]"
}

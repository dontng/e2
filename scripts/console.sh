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
    local stripped; stripped=$(_strip_nav "$content_path")
    local rel_src="${content_path#$REPO_DIR/}"
    sed -i "s|^source: .*|source: [$rel_src](../$rel_src)|" "$stripped"
    {
        [[ -n "$nav" ]] && printf '%s\n\n' "$nav"
        cat "$stripped"
        [[ -n "$nav" ]] && printf '\n\n%s\n' "$nav"
    } > "$out"
    rm -f "$stripped"
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

# Regenerate console/scores.md: first-translation trend + redo comparison table.
update_scores_md() {
    python3 - "$REPO_DIR" "$EXAM_DATE" <<'PYEOF'
import sys, re, datetime
from pathlib import Path

repo = Path(sys.argv[1])
exam = datetime.date.fromisoformat(sys.argv[2])
days_left = (exam - datetime.date.today()).days

entries = {}   # day -> {'mmdd', 'score'}
redos = {}     # day -> [(redo_mmdd, score, trend)]

for f in sorted(repo.glob('src/*/*.md')):
    m = re.search(r'(\d{4})-day(\d+)\.md$', f.name)
    if not m:
        continue
    mmdd, day = m.group(1), int(m.group(2))
    text = f.read_text(encoding='utf-8')
    score = None
    sec = re.search(r'^## 评分\s*\n(.*?)(?=^## |\Z)', text, re.M | re.S)
    if sec:
        s = re.search(r'\*\*([\d.]+)\s*/\s*10\*\*', sec.group(1))
        if s:
            score = s.group(1)
    entries[day] = {'mmdd': mmdd, 'score': score}
    for rb in re.finditer(r'^### 重译 day(\d+)[^\n]*\n(.*?)(?=^### |\Z)', text, re.M | re.S):
        rs = re.search(r'\*\*复习评分：([\d.]+)\s*/\s*10\*\*([^\n]*)', rb.group(2))
        if rs:
            tail = rs.group(2)
            trend = next((a for a in '↑→↓' if a in tail), '')
            redos.setdefault(int(rb.group(1)), []).append((mmdd, rs.group(1), trend))

lines = [f'# 评分总览 · 距考试 {days_left} 天', '']
recent = [e['score'] for _, e in sorted(entries.items()) if e['score']][-14:]
if recent:
    lines += ['近 14 次首译：`' + '  '.join(recent) + '`', '']
lines += ['| Day | 日期 | 首译 | 重译 |', '|----:|------|-----:|------|']
for day in sorted(entries, reverse=True):
    e = entries[day]
    redo_cell = ' · '.join(f'{s}{t}（{m[:2]}/{m[2:]}）' for m, s, t in redos.get(day, [])) or '—'
    lines.append(f"| {day} | {e['mmdd'][:2]}/{e['mmdd'][2:]} | {e['score'] or '—'} | {redo_cell} |")

(repo / 'console' / 'scores.md').write_text('\n'.join(lines) + '\n', encoding='utf-8')
PYEOF
}

update_today_md() {
    local console_dir="$REPO_DIR/console"
    local fool_stem="" probe_stem=""
    local fool_latest probe_latest
    fool_latest=$(find "$console_dir" -name "*-fool.md" | sort | tail -1)
    [[ -n "$fool_latest" ]] && fool_stem=$(basename "$fool_latest" -fool.md)
    probe_latest=$(find "$console_dir" -name "*-probe.md" | sort | tail -1)
    [[ -n "$probe_latest" ]] && probe_stem=$(basename "$probe_latest" -probe.md)

    update_scores_md

    local days_left
    days_left=$(( ($(date -d "$EXAM_DATE" +%s) - $(date -d "$(date +%F)" +%s)) / 86400 ))

    {
        printf '# 距考试还有 %s 天\n\n' "$days_left"
        [[ -n "$fool_stem"  ]] && printf '» [今天 fool · %s](%s-fool.md)\n\n'  "$fool_stem"  "$fool_stem"
        [[ -n "$probe_stem" ]] && printf '» [今天 probe · %s](%s-probe.md)\n\n'  "$probe_stem" "$probe_stem"
        printf '» [评分总览 · 复习记录](scores.md)\n'
    } > "$console_dir/today.md"
}

# Shared implementation for the 3-day rolling console window.
_create_console_entry() {
    local type="$1" source_path="$2"
    local suffix="-${type}.md"
    local stem; stem=$(basename "$source_path" "$suffix")
    local console_dir="$REPO_DIR/console"
    local source_dir="$REPO_DIR/$type"
    mkdir -p "$console_dir"

    local window=()
    while IFS= read -r f; do
        window+=("$(basename "$f" "$suffix")")
    done < <(find "$console_dir" -name "*${suffix}" | sort)

    local prev_stem=""
    [[ ${#window[@]} -gt 0 ]] && prev_stem="${window[-1]}"

    write_console_file "$stem" "$source_path" "$prev_stem" "" "" "" "$type"

    if [[ -n "$prev_stem" ]]; then
        local prev_prev=""
        [[ ${#window[@]} -ge 2 ]] && prev_prev="${window[-2]}"
        local prev_source; prev_source=$(find "$source_dir" -name "${prev_stem}${suffix}" | head -1)
        [[ -f "$prev_source" ]] && write_console_file "$prev_stem" "$prev_source" "$prev_prev" "$stem" "" "" "$type"
    fi

    window+=("$stem")
    while [[ ${#window[@]} -gt $CONSOLE_WINDOW ]]; do
        local evicted="${window[0]}"
        rm -f "$console_dir/$evicted${suffix}"
        window=("${window[@]:1}")
        log "Console: evicted $type $evicted"
    done

    local oldest="${window[0]}"
    local oldest_source; oldest_source=$(find "$source_dir" -name "${oldest}${suffix}" | head -1)
    if [[ -f "$oldest_source" ]]; then
        local prev_of_oldest="" prev_of_oldest_path="" prev_candidate=""
        local all_stems_fn="all_${type}_stems"
        while IFS= read -r candidate; do
            [[ "$candidate" == "$oldest" ]] && { prev_of_oldest="$prev_candidate"; break; }
            prev_candidate="$candidate"
        done < <("$all_stems_fn")
        if [[ -n "$prev_of_oldest" ]]; then
            prev_of_oldest_path=$(find "$source_dir" -name "${prev_of_oldest}${suffix}" | head -1)
        fi
        local next_of_oldest="${window[1]:-}"
        local prev_url=""
        [[ -n "$prev_of_oldest_path" ]] && prev_url="../${prev_of_oldest_path#$REPO_DIR/}"
        write_console_file "$oldest" "$oldest_source" "$prev_of_oldest" "$next_of_oldest" "$prev_url" "" "$type"
    fi

    update_today_md
    log "Console $type: $stem  window=[${window[*]}]"
}

# Maintain a 3-day rolling window of fool/probe files in console/.
create_console_entry()       { _create_console_entry "fool"  "$1"; }
create_probe_console_entry() { _create_console_entry "probe" "$1"; }

#!/usr/bin/env bash
# verify-day.sh — 检查某日 src/fool/probe 是否满足流水线完成度（本地诊断用）
# 用法：bash scripts/verify-day.sh src/june/0622-day60.md

set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"

file="$1"
[[ "$file" != /* ]] && file="$REPO_DIR/$file"
[[ ! -f "$file" ]] && { echo "File not found: $1" >&2; exit 1; }

# shellcheck source=scripts/probe.sh
source "$REPO_DIR/scripts/probe.sh"
# shellcheck source=scripts/src.sh
source "$REPO_DIR/scripts/src.sh"
# shellcheck source=scripts/fool.sh
source "$REPO_DIR/scripts/fool.sh"

day_paths "$file"

ok() { echo "OK"; }
fail() { echo "INCOMPLETE"; }

printf 'src:   '; src_day_complete "$file" && ok || fail
printf 'fool:  '; fool_complete "$FOOL_PATH" && ok || fail
printf 'probe: '; probe_complete "$PROBE_PATH" && ok || fail
echo "paths: $file → ${FOOL_PATH#$REPO_DIR/} → ${PROBE_PATH#$REPO_DIR/}"

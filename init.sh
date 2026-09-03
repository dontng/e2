#!/usr/bin/env bash

# Create one minimal Daily file. This script only scaffolds a Daily that has
# already been chosen; it does not make Daily the project's default next task.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$REPO_DIR/src"
cd "$REPO_DIR"

usage() {
    cat <<'EOF'
Usage:
  bash init.sh                    create today's next Daily
  bash init.sh tomorrow           create tomorrow's next Daily
  bash init.sh 0904               create this year's 09-04 Daily
  bash init.sh 2026-09-04 day118  create an explicitly dated/numbered Daily

The target directory uses src/YY-MM/MMDD-dayN.md. If dayN is omitted, the
largest existing day number is incremented automatically.
EOF
}

if (($# > 2)); then
    usage >&2
    exit 2
fi

DATE_ARG="${1:-today}"

case "$DATE_ARG" in
    today)
        FULL_DATE="$(date +%F)"
        ;;
    tomorrow|tom)
        FULL_DATE="$(date -d tomorrow +%F)"
        ;;
    [0-9][0-9][0-9][0-9])
        FULL_DATE="$(date -d "$(date +%Y)-${DATE_ARG:0:2}-${DATE_ARG:2:2}" +%F 2>/dev/null)" || {
            echo "Invalid date: $DATE_ARG" >&2
            exit 2
        }
        ;;
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9])
        FULL_DATE="$(date -d "$DATE_ARG" +%F 2>/dev/null)" || {
            echo "Invalid date: $DATE_ARG" >&2
            exit 2
        }
        if [[ "$FULL_DATE" != "$DATE_ARG" ]]; then
            echo "Invalid date: $DATE_ARG" >&2
            exit 2
        fi
        ;;
    -h|--help)
        usage
        exit 0
        ;;
    *)
        echo "Invalid date argument: $DATE_ARG" >&2
        usage >&2
        exit 2
        ;;
esac

YEAR="${FULL_DATE:0:4}"
YY="${FULL_DATE:2:2}"
MM="${FULL_DATE:5:2}"
DD="${FULL_DATE:8:2}"
MMDD="${MM}${DD}"

if [[ -n "${2:-}" ]]; then
    DAY_NUM="${2#day}"
else
    LAST=0
    while IFS= read -r candidate; do
        base="$(basename "$candidate")"
        if [[ "$base" =~ -day([0-9]+)(-[[:alnum:]-]+)?\.md$ ]] && ((10#${BASH_REMATCH[1]} > LAST)); then
            LAST=$((10#${BASH_REMATCH[1]}))
        fi
    done < <(find "$SRC_DIR" -type f -name '*.md')
    DAY_NUM=$((LAST + 1))
fi

if ! [[ "$DAY_NUM" =~ ^[0-9]+$ ]] || ((10#$DAY_NUM == 0)); then
    echo "Invalid day number: ${2:-$DAY_NUM}" >&2
    exit 2
fi
DAY_NUM=$((10#$DAY_NUM))

DIR="$SRC_DIR/$YY-$MM"
FILE="$DIR/${MMDD}-day${DAY_NUM}.md"
DISPLAY_FILE="${FILE#$REPO_DIR/}"

EXISTING_DATE="$(find "$DIR" -maxdepth 1 -type f -name "${MMDD}-day*.md" -print -quit 2>/dev/null || true)"
if [[ -n "$EXISTING_DATE" ]]; then
    echo "Already exists for $FULL_DATE: ${EXISTING_DATE#$REPO_DIR/}" >&2
    exit 1
fi

EXISTING_DAY="$(find "$SRC_DIR" -type f -name "*-day${DAY_NUM}.md" -print -quit 2>/dev/null || true)"
if [[ -n "$EXISTING_DAY" ]]; then
    echo "day${DAY_NUM} already used: ${EXISTING_DAY#$REPO_DIR/}" >&2
    exit 1
fi

mkdir -p "$DIR"

cat > "$FILE" <<EOF
# Day ${DAY_NUM} · ${FULL_DATE}

## 原句（Input）

>

## 我的翻译

>
EOF

echo "Initialized: $DISPLAY_FILE"
bash "$REPO_DIR/scripts/src-nav.sh" --around "$DISPLAY_FILE"

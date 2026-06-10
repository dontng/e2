#!/bin/bash

if [ -z "$1" ]; then
  MMDD=$(date +%m%d)
  FULL_DATE=$(date +%Y-%m-%d)
  MONTH=$(date +%B | tr '[:upper:]' '[:lower:]')
elif [ "$1" = "tomorrow" ] || [ "$1" = "tom" ]; then
  MMDD=$(date -d tomorrow +%m%d)
  FULL_DATE=$(date -d tomorrow +%Y-%m-%d)
  MONTH=$(date -d tomorrow +%B | tr '[:upper:]' '[:lower:]')
else
  MM=${1:0:2}
  DD=${1:2:2}
  YEAR=$(date +%Y)
  MMDD="${MM}${DD}"
  FULL_DATE="${YEAR}-${MM}-${DD}"
  MONTH=$(date -d "${YEAR}-${MM}-${DD}" +%B | tr '[:upper:]' '[:lower:]')
fi

if [ -n "$2" ]; then
  DAY_NUM=$2
else
  LAST=$(find src -name "*.md" | grep -oP 'day\K[0-9]+' | sort -n | tail -1)
  DAY_NUM=$(( ${LAST:-0} + 1 ))
fi

DIR="src/$MONTH"
FILE="$DIR/${MMDD}-day${DAY_NUM}.md"

FOOL_DIR="fool/$MONTH"
FOOL_FILE="$FOOL_DIR/${MMDD}-day${DAY_NUM}-fool.md"

mkdir -p "$DIR" "$FOOL_DIR"

if [ -f "$FILE" ]; then
  echo "Already exists: $FILE"
  exit 1
fi

cat > "$FILE" << EOF
# Day ${DAY_NUM} on ${FULL_DATE}

## 原句

## 我的理解和翻译

## 批改

## 评分

## Vocab

## Phrases

## 问答收录

## 练习与习得

EOF

cat > "$FOOL_FILE" << EOF
# Day ${DAY_NUM} Fool Sessions · ${FULL_DATE}

source: [src/${MONTH}/${MMDD}-day${DAY_NUM}.md](../../src/${MONTH}/${MMDD}-day${DAY_NUM}.md)

EOF

echo "Created: $FILE"
echo "Created: $FOOL_FILE"

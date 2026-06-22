#!/bin/bash

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

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
  DAY_NUM="${2#day}"   # 允许 day60 或 60，避免生成 0622-dayday60.md
else
  LAST=$(find src -name "*.md" | grep -oP 'day\K[0-9]+' | sort -n | tail -1)
  DAY_NUM=$(( ${LAST:-0} + 1 ))
fi

if ! [[ "$DAY_NUM" =~ ^[0-9]+$ ]]; then
  echo "Invalid day number: ${2:-$DAY_NUM}" >&2
  exit 1
fi

DIR="src/$MONTH"
FILE="$DIR/${MMDD}-day${DAY_NUM}.md"

FOOL_DIR="fool/$MONTH"
FOOL_FILE="$FOOL_DIR/${MMDD}-day${DAY_NUM}-fool.md"

PROBE_DIR="probe/$MONTH"
PROBE_FILE="$PROBE_DIR/${MMDD}-day${DAY_NUM}-probe.md"

mkdir -p "$DIR" "$FOOL_DIR" "$PROBE_DIR"

# 日期去重：同一 MMDD 不得出现两个不同 day 号（见 0612 事故）。
EXISTING=$(find src -name “${MMDD}-day*.md” 2>/dev/null | head -1)
if [ -n “$EXISTING” ]; then
  echo “Already exists for ${MMDD}: $EXISTING” >&2
  exit 1
fi

# day 号去重：同一 day 号不得出现在两个不同日期。
EXISTING_DAY=$(find src -name “*-day${DAY_NUM}.md” 2>/dev/null | head -1)
if [ -n “$EXISTING_DAY” ]; then
  echo “day${DAY_NUM} already used: $EXISTING_DAY” >&2
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

---

EOF

# probe 空壳：头 + source + 诊断 section 骨架（内容等批改流水线 Agent 填，见 probe/STANDARDS.md）
cat > "$PROBE_FILE" << EOF
# day${DAY_NUM} Probe

source: [src/${MONTH}/${MMDD}-day${DAY_NUM}.md](../../src/${MONTH}/${MMDD}-day${DAY_NUM}.md)

---

## 原句

## 今日刺痛

## 内功印证

## 招式印证

## 提分台阶

## 今日带走

EOF

# 复习区注入 — 逻辑全部在 scripts/review.py
python3 scripts/review.py inject "$FILE" "$DAY_NUM"

echo "Created: $FILE"
echo "Created: $FOOL_FILE"
echo "Created: $PROBE_FILE"

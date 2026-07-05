#!/bin/bash

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

# 1. 核心状态初始化：日期与参数解析
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

# 2. 序号自动递增与校验
if [ -n "$2" ]; then
  DAY_NUM="${2#day}"
else
  LAST=$(find src -name "*.md" | grep -oP 'day\K[0-9]+' | sort -n | tail -1)
  DAY_NUM=$(( ${LAST:-0} + 1 ))
fi

if ! [[ "$DAY_NUM" =~ ^[0-9]+$ ]]; then
  echo "Invalid day number: ${2:-$DAY_NUM}" >&2
  exit 1
fi

# 3. 极简目录层级：只保留主任务文件
DIR="src/$MONTH"
FILE="$DIR/${MMDD}-day${DAY_NUM}.md"

mkdir -p "$DIR"

# 4. 去重校验
EXISTING=$(find "$DIR" -maxdepth 1 -name "${MMDD}-day*.md" 2>/dev/null | head -1)
if [ -n "$EXISTING" ]; then
  echo "Already exists for ${MMDD}: $EXISTING" >&2
  exit 1
fi

EXISTING_DAY=$(find src -name "*-day${DAY_NUM}.md" 2>/dev/null | head -1)
if [ -n "$EXISTING_DAY" ]; then
  echo "day${DAY_NUM} already used: $EXISTING_DAY" >&2
  exit 1
fi

# 5. 生成模板
cat > "$FILE" << EOF
# Day ${DAY_NUM} · ${FULL_DATE}

## 原句 (Input)


## 我的翻译


## 批改 (Diff & Debug)


## 核心复盘 (Takeaways)


## 词汇 (Vocab)


## 短语 (Phrases)

EOF

echo "Initialized: $FILE"
bash "$REPO_DIR/scripts/src-nav.sh" --around "$FILE"

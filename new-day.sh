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

# ── 复习区：注入 3 次前 / 7 次前的句子，盲译重做 ──
# 首译得分和参考译文写进 HTML 注释（渲染时不可见），供复习批改对比用。
python3 - "$FILE" "$DAY_NUM" <<'PYEOF'
import sys, re
from pathlib import Path

target, day_num = Path(sys.argv[1]), int(sys.argv[2])

candidates = []
for f in Path('src').glob('*/*.md'):
    m = re.search(r'-day(\d+)\.md$', f.name)
    if not m or int(m.group(1)) >= day_num:
        continue
    text = f.read_text(encoding='utf-8')
    sent_m = re.search(r'^## 原句\s*\n(.*?)(?=^## |\Z)', text, re.M | re.S)
    sentence = sent_m.group(1).strip() if sent_m else ''
    if not sentence:
        continue
    score = ''
    score_sec = re.search(r'^## 评分\s*\n(.*?)(?=^## |\Z)', text, re.M | re.S)
    if score_sec:
        s = re.search(r'\*\*([\d.]+)\s*/\s*10\*\*', score_sec.group(1))
        if s:
            score = s.group(1)
    ref_m = re.search(r'^\*\*参考译文[：:]?\*\*[：:]?\s*(.+)$', text, re.M)
    ref = ref_m.group(1).strip() if ref_m else ''
    candidates.append((int(m.group(1)), f.name[:4], sentence, score, ref))

candidates.sort()
picks = [candidates[-off] for off in (3, 7) if len(candidates) >= off]
if not picks:
    sys.exit(0)

blocks = ['## 复习区\n']
for d, mmdd, sentence, score, ref in picks:
    blocks.append(f'### 重译 day{d} · {mmdd[:2]}/{mmdd[2:]}\n')
    blocks.append(sentence + '\n')
    blocks.append('**我的重译：**\n\n')
    blocks.append('**复习批改：**\n\n')
    meta = f'<!-- review-meta day{d} first={score + "/10" if score else "—"}'
    if ref:
        meta += f'\n参考译文：{ref}'
    meta += '\n-->\n'
    blocks.append(meta)

with open(target, 'a', encoding='utf-8') as out:
    out.write('\n'.join(blocks))
print('复习区: ' + ', '.join(f'day{d}' for d, *_ in picks))
PYEOF

echo "Created: $FILE"
echo "Created: $FOOL_FILE"

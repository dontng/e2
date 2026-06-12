#!/usr/bin/env python3
"""review.py — 复习区的全部逻辑，单一职责模块。

usage:
  review.py inject  <src_file> <day_num>   向新建的 day 文件追加「## 复习区」
  review.py pending <src_file>             exit 0 = 有已填写、待批改的重译

注入规则：抽第 3 次前和第 7 次前的句子（每句一生中恰好被复习两次），
不带答案盲译；首译得分和参考译文写进 HTML 注释，渲染不可见、批改可读。
"""
import sys
import re
from pathlib import Path

OFFSETS = (3, 7)


def _section(text: str, title: str) -> str:
    m = re.search(rf'^## {title}\s*\n(.*?)(?=^## |\Z)', text, re.M | re.S)
    return m.group(1).strip() if m else ''


def _first_score(text: str) -> str:
    m = re.search(r'\*\*([\d.]+)\s*/\s*10\*\*', _section(text, '评分'))
    return m.group(1) if m else ''


def _ref_translation(text: str) -> str:
    m = re.search(r'^\*\*参考译文[：:]?\*\*[：:]?\s*(.+)$', text, re.M)
    return m.group(1).strip() if m else ''


def inject(src_file: Path, day_num: int) -> int:
    src_root = src_file.resolve().parents[2] / 'src'

    candidates = []
    for f in src_root.glob('*/*.md'):
        m = re.search(r'-day(\d+)\.md$', f.name)
        if not m or int(m.group(1)) >= day_num:
            continue
        text = f.read_text(encoding='utf-8')
        sentence = _section(text, '原句')
        if not sentence:
            continue
        candidates.append(
            (int(m.group(1)), f.name[:4], sentence,
             _first_score(text), _ref_translation(text))
        )

    candidates.sort()
    picks = [candidates[-off] for off in OFFSETS if len(candidates) >= off]
    if not picks:
        return 0

    blocks = ['## 复习区\n']
    for day, mmdd, sentence, score, ref in picks:
        blocks.append(f'### 重译 day{day} · {mmdd[:2]}/{mmdd[2:]}\n')
        blocks.append(sentence + '\n')
        blocks.append('**我的重译：**\n\n')
        blocks.append('**复习批改：**\n\n')
        meta = f'<!-- review-meta day{day} first={score + "/10" if score else "—"}'
        if ref:
            meta += f'\n参考译文：{ref}'
        blocks.append(meta + '\n-->\n')

    with open(src_file, 'a', encoding='utf-8') as out:
        out.write('\n'.join(blocks))
    print('复习区: ' + ', '.join(f'day{day}' for day, *_ in picks))
    return 0


def pending(src_file: Path) -> int:
    text = src_file.read_text(encoding='utf-8')
    m = re.search(r'^## 复习区\s*\n(.*)', text, re.M | re.S)
    if not m:
        return 1
    for block in re.split(r'^### ', m.group(1), flags=re.M)[1:]:
        redo = re.search(r'\*\*我的重译：\*\*\n(.*?)\*\*复习批改：\*\*', block, re.S)
        graded = re.search(r'\*\*复习批改：\*\*\n(.*?)(?:<!-- review-meta|\Z)', block, re.S)
        if redo and redo.group(1).strip() and graded is not None and not graded.group(1).strip():
            return 0
    return 1


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__, file=sys.stderr)
        return 2
    cmd, src_file = sys.argv[1], Path(sys.argv[2])
    if cmd == 'inject':
        return inject(src_file, int(sys.argv[3]))
    if cmd == 'pending':
        return pending(src_file)
    print(f'unknown command: {cmd}', file=sys.stderr)
    return 2


if __name__ == '__main__':
    sys.exit(main())

#!/usr/bin/env python3
"""scores.py — 重新生成 console/scores.md，并向 stdout 输出 today.md 用的摘要。

usage:  scores.py <repo_dir> <exam_date>
stdout: sparkline<TAB>近期均分<TAB>近期句数   （无评分数据时无输出）

只扫描一遍 src/，scores.md 与 today.md 摘要共享同一次解析。
"""
import sys
import re
import datetime
from pathlib import Path

SPARK = '▁▂▃▄▅▆▇█'
RECENT = 14


def sparkline(scores):
    return ''.join(SPARK[min(7, int(float(s) / 10 * 8))] for s in scores)


def main():
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
                trend = next((a for a in '↑→↓' if a in rs.group(2)), '')
                redos.setdefault(int(rb.group(1)), []).append((mmdd, rs.group(1), trend))

    scored = [(d, e) for d, e in sorted(entries.items()) if e['score']]
    recent = [e['score'] for _, e in scored[-RECENT:]]
    avg = sum(float(s) for s in recent) / len(recent) if recent else 0

    deltas = [
        float(s) - float(entries[d]['score'])
        for d, rl in redos.items() if entries.get(d, {}).get('score')
        for _, s, _ in rl
    ]

    head = [f'# 评分总览', '',
            f'距考试 **{days_left}** 天 · 已练 **{len(entries)}** 句 · '
            f'近 {len(recent)} 次首译均分 **{avg:.1f}**'
            + (f' · 复习平均 **{sum(deltas) / len(deltas):+.1f}**' if deltas else ''),
            '']
    if recent:
        head += [f'`{sparkline(recent)}`', '']

    table = ['| Day | 日期 | 首译 | 重译 |', '|----:|------|-----:|------|']
    for day in sorted(entries, reverse=True):
        e = entries[day]
        redo_cell = ' · '.join(
            f'{s}{t}（{m[:2]}/{m[2:]}）' for m, s, t in redos.get(day, [])
        ) or '—'
        table.append(f"| {day} | {e['mmdd'][:2]}/{e['mmdd'][2:]} | {e['score'] or '—'} | {redo_cell} |")

    out = repo / 'console' / 'scores.md'
    out.write_text('\n'.join(head + table) + '\n', encoding='utf-8')

    if recent:
        print(f'{sparkline(recent)}\t{avg:.1f}\t{len(recent)}')
    return 0


if __name__ == '__main__':
    sys.exit(main())

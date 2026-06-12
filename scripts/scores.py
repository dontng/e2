#!/usr/bin/env python3
"""scores.py — 评分数据的唯一归属。

CLI:    scores.py <repo_dir> <exam_date>
        重新生成 console/scores.md；stdout 输出 today.md 摘要行
        （sparkline<TAB>近期均分<TAB>近期句数，无数据时无输出）

库:     collect(repo) → {'entries': {day: {mmdd, score}}, 'redos': {day: [(mmdd, score, trend)]}}
        studio.py 复用 collect，一份解析喂所有视图。
"""
import sys
import re
import datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import review

SPARK = '▁▂▃▄▅▆▇█'
RECENT = 14


def sparkline(scores):
    return ''.join(SPARK[min(7, int(float(s) / 10 * 8))] for s in scores)


def collect(repo: Path) -> dict:
    entries, redos = {}, {}
    for f in sorted(repo.glob('src/*/*.md')):
        m = re.search(r'(\d{4})-day(\d+)\.md$', f.name)
        if not m:
            continue
        mmdd, day = m.group(1), int(m.group(2))
        text = f.read_text(encoding='utf-8')
        score = review.first_score(text) or None
        entries[day] = {'mmdd': mmdd, 'score': score}
        for b in review.parse_blocks(text):
            if not b['feedback']:
                continue
            rs = re.search(r'\*\*复习评分：([\d.]+)\s*/\s*10\*\*([^\n]*)', b['feedback'])
            if rs:
                trend = next((a for a in '↑→↓' if a in rs.group(2)), '')
                redos.setdefault(b['day'], []).append((mmdd, rs.group(1), trend))
    return {'entries': entries, 'redos': redos}


def main():
    repo = Path(sys.argv[1])
    exam = datetime.date.fromisoformat(sys.argv[2])
    days_left = (exam - datetime.date.today()).days

    data = collect(repo)
    entries, redos = data['entries'], data['redos']

    recent = [e['score'] for _, e in sorted(entries.items()) if e['score']][-RECENT:]
    avg = sum(float(s) for s in recent) / len(recent) if recent else 0

    deltas = [
        float(s) - float(entries[d]['score'])
        for d, rl in redos.items() if entries.get(d, {}).get('score')
        for _, s, _ in rl
    ]

    head = ['# 评分总览', '',
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

    (repo / 'console' / 'scores.md').write_text('\n'.join(head + table) + '\n', encoding='utf-8')

    if recent:
        print(f'{sparkline(recent)}\t{avg:.1f}\t{len(recent)}')
    return 0


if __name__ == '__main__':
    sys.exit(main())

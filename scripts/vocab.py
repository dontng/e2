#!/usr/bin/env python3
"""vocab.py — 单词库的唯一归属：解析全仓 daily 的「## Vocab」卡片。

库:  collect_vocab(repo) → [{word, pos, gloss, day, mmdd, sentences:[{en, zh}]}, ...]
     按词面去重（同词多次出现合并 sentences、保留首次 day）。

只解析既有 markdown，不生成内容。中文来源全部现成：
  例句行 `- *英文* （中文）` → 句子英文 + 句子中文
  **核心意象** 段首句               → 词义中文（gloss，截断保持简洁）
"""
import re
from pathlib import Path

_CARD = re.compile(r'^###\s+', re.M)
_HEAD = re.compile(r'^(.+?)\s+\*\((.+?)\)\*')          # word *(pos)*
_IMAGE = re.compile(r'\*\*核心意象\*\*[：:]\s*(.+)')
_SENT = re.compile(r'^-\s+\*(.+?)\*\s*(?:（(.+?)）)?', re.M)
_BOLD = re.compile(r'\*\*(.+?)\*\*')


def _vocab_section(text: str) -> str:
    m = re.search(r'^## Vocab\s*$(.*?)(?=^## |\Z)', text, re.M | re.S)
    return m.group(1) if m else ''


def _gloss(card: str) -> str:
    """取核心意象作词义：跳过"……这里是"之类的铺垫直取义项，截到第一个句读，
    仅对过长者收尾省略（不强行精简短义）。"""
    m = _IMAGE.search(card)
    if not m:
        return ''
    s = _BOLD.sub(r'\1', m.group(1)).strip().strip('"“”')
    for mark in ('这里是', '这里指', '这里取', '这里强调'):
        i = s.find(mark)
        if i != -1:
            s = s[i + len(mark):]
            break
    s = re.split(r'[。；—\n]', s, 1)[0].strip().strip('，,"“” ')
    return s[:44] + '…' if len(s) > 46 else s


def collect_vocab(repo: Path) -> list:
    by_word = {}
    for f in sorted(repo.glob('src/*/*.md')):
        fm = re.search(r'(\d{4})-day(\d+)\.md$', f.name)
        if not fm:
            continue
        mmdd, day = fm.group(1), int(fm.group(2))
        section = _vocab_section(f.read_text(encoding='utf-8'))
        for card in _CARD.split(section):
            card = card.strip()
            if not card:
                continue
            hm = _HEAD.match(card)
            if not hm:
                continue
            word = hm.group(1).strip()
            key = word.lower()
            sents = [{'en': en.strip(), 'zh': (zh or '').strip()} for en, zh in _SENT.findall(card)]
            if key in by_word:                       # 同词复现：并句子，保留首次
                seen = {s['en'] for s in by_word[key]['sentences']}
                by_word[key]['sentences'] += [s for s in sents if s['en'] not in seen]
            else:
                by_word[key] = {'word': word, 'pos': hm.group(2).strip(),
                                'gloss': _gloss(card), 'day': day, 'mmdd': mmdd,
                                'sentences': sents}
    return sorted(by_word.values(), key=lambda w: w['day'])


if __name__ == '__main__':
    import sys
    lib = collect_vocab(Path(sys.argv[1] if len(sys.argv) > 1 else '.'))
    print(f'{len(lib)} 词')
    for w in lib[:5]:
        print(f"  {w['word']} ({w['pos']}) — {w['gloss']}  · {len(w['sentences'])} 句")

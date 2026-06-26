#!/usr/bin/env python3
"""vocab.py — 单词库的唯一归属：解析全仓 daily 的「## Vocab」卡片。

库:  collect_vocab(repo) → [{word, pos, gloss, day, mmdd, sentences:[{en, zh}]}, ...]
     按词面去重（同词多次出现合并 sentences、保留首次 day）。

只解析既有 markdown，不生成内容。

当前源文件格式（src/*/*.md）：
  词条用 --- 分隔
  词头行 **`word`** *(pos)* 或 **`word`** *pos.*
  例句行 - 纯英文，无中文翻译
  词义：取词头下第一散文段，截到第一个句读
"""
import re
from pathlib import Path

_CARD_SEP = re.compile(r'^\s*---\s*$', re.M)
_HEAD = re.compile(r'^\*\*`(.+?)`\*\*\s+\*\(?([^*()\n]+)\)?\*', re.M)
_SENT = re.compile(r'^-\s+(.+)$', re.M)
_BOLD = re.compile(r'\*\*(.+?)\*\*')
_CODE = re.compile(r'`(.+?)`')
_ITALIC = re.compile(r'\*(.+?)\*')


def _vocab_section(text: str) -> str:
    m = re.search(r'^## Vocab\s*$(.*?)(?=^## |\Z)', text, re.M | re.S)
    return m.group(1) if m else ''


def _clean_md(s: str) -> str:
    s = _BOLD.sub(r'\1', s)
    s = _CODE.sub(r'\1', s)
    s = _ITALIC.sub(r'\1', s)
    return s.strip()


def _gloss(card: str) -> str:
    """取词头下第一散文段首句作简短词义。"""
    lines = card.split('\n')
    past_head = False
    prose = []
    for line in lines:
        stripped = line.strip()
        if _HEAD.match(stripped):
            past_head = True
            continue
        if not past_head:
            continue
        if not stripped:
            if prose:
                break
            continue
        if stripped.startswith('-'):
            break
        prose.append(stripped)
    if not prose:
        return ''
    s = _clean_md(' '.join(prose))
    s = re.split(r'[。；—\n]', s, 1)[0].strip().strip('，,""" ')
    return s[:44] + '…' if len(s) > 46 else s


def collect_vocab(repo: Path) -> list:
    by_word = {}
    for f in sorted(repo.glob('src/*/*.md')):
        fm = re.search(r'(\d{4})-day(\d+)\.md$', f.name)
        if not fm:
            continue
        mmdd, day = fm.group(1), int(fm.group(2))
        section = _vocab_section(f.read_text(encoding='utf-8'))
        for card in _CARD_SEP.split(section):
            card = card.strip()
            if not card:
                continue
            hm = _HEAD.search(card)
            if not hm:
                continue
            word = hm.group(1).strip()
            pos = hm.group(2).strip().rstrip('.')
            key = word.lower()
            sents = [{'en': _clean_md(s), 'zh': ''} for s in _SENT.findall(card) if s.strip()]
            if key in by_word:
                seen = {s['en'] for s in by_word[key]['sentences']}
                by_word[key]['sentences'] += [s for s in sents if s['en'] not in seen]
            else:
                by_word[key] = {'word': word, 'pos': pos,
                                'gloss': _gloss(card), 'day': day, 'mmdd': mmdd,
                                'sentences': sents}
    return sorted(by_word.values(), key=lambda w: w['day'])


if __name__ == '__main__':
    import sys
    lib = collect_vocab(Path(sys.argv[1] if len(sys.argv) > 1 else '.'))
    print(f'{len(lib)} 词')
    for w in lib[:5]:
        print(f"  {w['word']} ({w['pos']}) — {w['gloss']}  · {len(w['sentences'])} 句")

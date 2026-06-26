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


_Q     = '[“”"]'  # U+201C U+201D U+0022
_CORE  = re.compile('核心[义画面]*[是：:]\\s*' + _Q + '?(.+?)(?=' + _Q + '?[。；，—\\n])')
_MEANS = re.compile('意思是' + _Q + '(.+?)' + _Q)
_EQ    = re.compile(r'=\s*([一-鿿][^。；，—\n]*)')
_ETYM  = re.compile(r'词根|来自(?:古英语|拉丁|希腊|法语)|字面来|原意是|核心画面')
_CORE_MEANING = re.compile('核心义[是：:]\\s*' + _Q + '(.+?)' + _Q)


def _first_para(card: str) -> str:
    lines = card.split('\n')
    past_head, buf = False, []
    for line in lines:
        s = line.strip()
        if _HEAD.match(s):
            past_head = True
            continue
        if not past_head:
            continue
        if not s:
            if buf:
                break
            continue
        if s.startswith('-'):
            break
        buf.append(s)
    return _clean_md(' '.join(buf))


def _strip_word(s: str, word: str) -> str:
    s = re.sub(r'^' + re.escape(word) + r'\s*(?:的|是|=|：|:)?\s*', '', s, flags=re.I)
    s = re.sub(r'^核心义[是：:]\s*', '', s)
    return s.lstrip('是，、').strip()


def _trim(s: str, word: str) -> str:
    s = _strip_word(s.strip(), word)
    return (s[:44] + '…') if len(s) > 46 else s


def _try_point(text: str):
    # 找 特指/专指/用于指/，指 引导的释义；先带引号后不带
    m = re.search('(?:特指|专指|用于指|，指)' + _Q + '(.+?)' + _Q, text)
    if m:
        return m.group(1).strip()
    m = re.search(r'(?:特指|专指|用于指|，指)([^。；\n—，]{4,})(?=[。；—，\n]|$)', text)
    if m:
        return m.group(1).strip()
    return None


def _gloss(card: str) -> str:
    hm = _HEAD.search(card)
    word = hm.group(1).strip() if hm else ''
    first = _first_para(card)
    cleaned = _clean_md(card)

    # P1: word(本身)?是/=”X” —— 带引号的直接定义，最可信
    m = re.search(re.escape(word) + r'(?:本身)?\s*(?:是|=)\s*' + _Q + r'(.+?)' + _Q, cleaned, re.I)
    if m:
        return _trim(m.group(1), word)

    # P2: word = 纯汉字（无引号，word 直接在左，最精确）
    m = re.search(re.escape(word) + r'\s*=\s*([一-鿿][^。；，—\n]*)', cleaned)
    if m:
        s = m.group(1).strip()
        if sum(1 for c in s if ord(c) < 128) / max(len(s), 1) < 0.25:
            return _trim(s, word)

    # P3: 核心义是”X”（区别于核心画面）
    m = _CORE_MEANING.search(first)
    if m:
        return _trim(m.group(1), word)

    # P4: 意思是”X”
    m = _MEANS.search(cleaned)
    if m:
        return _trim(m.group(1), word)

    # P5: 特指/专指/用于指/，指
    s = _try_point(first)
    if s:
        return _trim(s, word)

    # P6: 第一段第二句起，跳过词根/画面句
    sentences = [s.strip() for s in re.split(r'。', first) if s.strip()]
    for sent in sentences[1:]:
        if _ETYM.search(sent):
            continue
        stripped = _strip_word(sent, word)
        if '——' in stripped:
            part = stripped.split('——')[0].strip()
        else:
            part = re.split(r'[，,]', stripped, 1)[0].strip()
        if part and re.match(r'[一-鿿]', part) and len(part) >= 4:
            return _trim(part, word)

    # P7: 末段 word 不是X，是Y 兜底（仅搜最后一段，避免命中首段画面句）
    paras = [p.strip() for p in card.split('\n\n') if p.strip() and not p.strip().startswith('-')]
    last_para = _clean_md(paras[-1]) if paras else ''
    m = re.search(re.escape(word) + r'(?:[^，。\n]+，)+是([一-鿿][^，。—\n（]{3,30})', last_para, re.I)
    if m:
        return _trim(m.group(1), word)

    return ''


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

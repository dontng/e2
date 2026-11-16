#!/usr/bin/env python3
"""Build the selectable 2026 paper using the existing 20.html paper design."""
from pathlib import Path
import html
import json
import re

ROOT = Path(__file__).resolve().parents[1]
DATA = json.loads((ROOT / "e2-analysis/papers/2026/transcription.json").read_text())


def esc(value):
    return html.escape(value, quote=True)


def paragraphs(items, cloze=False):
    def text(item):
        value = esc(item)
        if cloze:
            value = re.sub(r"_(\d+)_", r'<span class="blank-number">\1</span>', value)
        return value
    return '<section class="passage">' + ''.join('<p>' + text(p) + '</p>' for p in items) + '</section>'


pages = []


def page(kind, title, body):
    number = len(pages)
    footer = f'<footer class="exam-footer">2026年考研英语（二）试题　 第 {number} 页 共 14 页</footer>' if number else ''
    pages.append(f'<article class="paper {kind}" data-page="{number}" aria-label="{esc(title)}">{body}{footer}</article>')


# Reuse the project's cover arrangement, explicitly labelling it as a reprint.
cover = (ROOT / 'e2-analysis/papers/2020/full-paper.js').read_text().split('0: ["cover-page", `', 1)[1].split('`],', 1)[0]
cover = cover.replace('2020', '2026').replace('绝密★启用前', '考后整理 · 题面重排')
page('cover-page', '2026 英语二封面', cover)

page('cloze-page', '完形填空原文', '''<h1 class="section-title">Section I　Use of English</h1>
<div class="directions"><strong>Directions:</strong><p>Read the following text. Choose the best word(s) for each numbered blank and mark A, B, C or D on the ANSWER SHEET. (10 points)</p></div>
<div class="cloze-passage">''' + paragraphs(DATA['cloze'], True) + '</div>')

rows = ''.join('<div class="cloze-row" data-question="%d"><span>%d.</span>%s</div>' % (
    n, n, ''.join(f'<span>[{letter}] {esc(option)}</span>' for letter, option in zip('ABCD', options)))
    for n, options in enumerate(DATA['cloze_options'], 1))
page('cloze-answers-page', '完形填空选项及阅读说明', rows + '''
<section class="section-transition"><h2>Section II　Reading Comprehension</h2><h3>Part A</h3>
<strong>Directions:</strong><p>Read the following four texts. Answer the questions below each text by choosing A, B, C or D. Mark your answers on the ANSWER SHEET. (40 points)</p></section>''')

for t, reading in enumerate(DATA['readings'], 1):
    page('reading-page', f'Text {t} 原文', f'<h1 class="paper-title">Text {t}</h1>' + paragraphs(reading['paragraphs']))
    questions = ''
    for j, question in enumerate(reading['questions']):
        n = 21 + (t - 1) * 5 + j
        questions += f'<section class="question" id="q{n}" data-question="{n}"><p class="stem">{n}. {esc(question["stem"])}</p>'
        questions += ''.join(f'<p class="option">[{letter}] {esc(option)}</p>' for letter, option in zip('ABCD', question['options'])) + '</section>'
    page('questions-page', f'Text {t} 题目 {21+(t-1)*5}—{25+(t-1)*5}', questions)

page('part-b-page', '新题型原文上半部分', '''<h1>Part B</h1><div class="directions"><strong>Directions:</strong>
<p>Read the following text and match each of the numbered items in the left column to its corresponding information in the right column. There are two extra choices in the right column. Mark your answers on the ANSWER SHEET. (10 points)</p></div>
''' + paragraphs(DATA['matching'][:4]))

people = ''.join(f'<p data-question="{n}">{n}. {esc(name)}</p>' for n, name in enumerate(DATA['matching_people'], 41))
options = ''.join(f'<p>[{letter}] {esc(option)}</p>' for letter, option in zip('ABCDEFG', DATA['matching_options']))
page('part-b-page matching-page', '新题型原文下半部分与选项', paragraphs(DATA['matching'][4:]) +
     '<div class="matching-columns"><section class="matching-list people-list">' + people + '</section><section class="matching-list options-list">' + options + '</section></div>')

page('translation-page', '翻译第46题', '''<h1 class="section-title">Section III　Translation</h1>
<div class="translation-task" data-question="46"><p>46. <strong>Directions:</strong><br>Translate the following text into Chinese. Write your translation on the ANSWER SHEET. (15 points)</p>''' + paragraphs(DATA['translation']) + '</div>')

page('chart-page', '写作第47—48题', '''<h1 class="section-title">Section IV　Writing</h1>
<section class="writing-a" data-question="47"><h2 class="part-label">Part A</h2><p>47. <strong>Directions:</strong></p>
<p>Suppose your friend Jack has shared with you a video of his family’s travel in China. Write an email to tell him</p>
<p>1) how you feel about the video, and</p><p>2) your wish to learn more about their travel.</p>
<p>Write your answer in about 100 words on the ANSWER SHEET. Do not use your own name in your email. Use “Li Ming” instead. (10 points)</p></section>
<section class="chart-task" data-question="48"><h2 class="part-label">Part B</h2><p>48. <strong>Directions:</strong></p>
<p>Write an essay based on the chart below. In your essay, you should</p><p>1) describe and interpret the chart, and</p><p>2) give your comments.</p>
<p>Write your answer in about 150 words on the ANSWER SHEET. (15 points)</p>
<img src="papers/2026/assets/writing-chart.png" alt="某项关于儿童户外活动看法的调查：满足好奇心54.6%，促进观察力54.5%，强身健体37.2%，增强亲子关系33.2%。"></section>''')

assert len(pages) == 15
document = '''<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>2026 考研英语（二）· 新东方题面重排</title>
<link rel="stylesheet" href="viewer/reader.css"><link rel="stylesheet" href="papers/2026/paper.css">
</head><body>
<div class="top-edge-trigger" aria-hidden="true"></div>
<header class="toolbar"><div class="toolbar-title">2026 英语（二）<span class="toolbar-note">新东方题面重排</span><span id="spreadLabel">封面</span></div>
<div class="toolbar-actions"><a href="papers/2026/SOURCE.md">来源与校对记录</a></div></header>
<nav class="edge-navigation" aria-label="翻页"><button id="prevPage" class="page-edge page-edge-prev" type="button" aria-label="上一组双页"><span aria-hidden="true">‹</span></button><button id="nextPage" class="page-edge page-edge-next" type="button" aria-label="下一组双页"><span aria-hidden="true">›</span></button></nav>
<main id="spread" aria-label="2026年考研英语二试题">''' + '\n'.join(pages) + '''</main>
<div id="fullscreenStatus" role="status"></div><script src="papers/2026/reader.js"></script>
</body></html>
'''
(ROOT / 'e2-analysis/26.html').write_text(document)
print('Built 26.html: cover + 14 pages; 48 questions; no answer explanations.')

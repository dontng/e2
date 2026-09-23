"""Build the other 2020 pages as editable HTML blocks, not page screenshots.

Paragraph and question boundaries below were checked against the source pages.
The PDF text layer is an input draft; visible OCR slips are corrected here.
Text 1 remains the separately hand-set layout in text1-layout.js.
"""
from collections import defaultdict
from html import escape
import json
from pathlib import Path
import re

import fitz

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "archive-e2/2020年考研英语二真题.pdf"
if not SOURCE.exists():
    SOURCE = ROOT / "2020.pdf"
OUTPUT = ROOT / "e2-analysis/papers/2020/full-paper.js"
doc = fitz.open(SOURCE)

CORRECTIONS = {
    "Don the ANSWER": "D on the ANSWER",
    "many mere skills": "many more skills",
    "[B] motive inside candidates": "[B] motivate inside candidates",
    "mode ling": "modeling",
    "expenencmg": "experiencing",
    '"entitled" 1s': '"entitled" is',
    "engage coworkers m a genuine": "engage coworkers in a genuine",
    "tum back": "turn back",
    "Section I Use of English": "Section I　Use of English",
}


def fix(text):
    for source, target in CORRECTIONS.items():
        text = text.replace(source, target)
    return re.sub(r"\s+([,.!?;:])", r"\1", text).strip()


def lines(page_number):
    rows = defaultdict(list)
    for block in doc[page_number].get_text("dict")["blocks"]:
        for line in block.get("lines", []):
            for span in line["spans"]:
                value = span["text"].strip()
                if value:
                    rows[round(line["bbox"][1], 1)].append((span["bbox"][0], value))
    answer = []
    for y, spans in sorted(rows.items()):
        pieces = [s for _, s in sorted(spans)]
        answer.append((y, fix(" ".join(pieces))))
    return answer


def paragraph_text(rows, start, end, cloze=False):
    text = " ".join(value for y, value in rows if start - .5 <= y < end - .5)
    if cloze:
        # This rule belongs only to the numbered gaps in Section I.
        text = re.sub(r"_*\s*(\d{1,2})\s*_*", lambda m: f' <span class="blank-number">{m[1]}</span> ', text)
    return fix(text)


def footer(number):
    return f'<footer class="exam-footer">2020年考研英语（二）试题　 第 {number} 页 共 14 页</footer>'


def reading_page(number, starts, line_height, title):
    rows = lines(number)
    blocks = []
    for index, start in enumerate(starts):
        end = starts[index + 1] if index + 1 < len(starts) else 699
        blocks.append(f'<p>{paragraph_text(rows, start, end)}</p>')
    return f'<h1 class="paper-title">{title}</h1><section class="passage" style="--reading-line:{line_height}pt">' + "\n".join(blocks) + f'</section>{footer(number)}'


def question_page(number, first, indent):
    rows = [(y, value) for y, value in lines(number) if y < 680]
    groups = []
    current = []
    for y, value in rows:
        if re.match(r"^\d{2}\.", value) and current:
            groups.append(current)
            current = []
        current.append((y, value))
    if current:
        groups.append(current)
    blocks = []
    for group in groups:
        stem = escape(group[0][1])
        options = ''.join(f'<p class="option">{escape(value)}</p>' for _, value in group[1:])
        blocks.append(f'<div class="question"><p class="stem">{stem}</p>{options}</div>')
    return '<section class="question-list" style="--question-first:%dpt;--question-indent:%dpt">' % (first, indent) + "\n".join(blocks) + f'</section>{footer(number)}'


def cloze_page():
    rows = lines(1)
    starts = [167.1, 244.5, 321.9, 399.3, 476.4, 572.1]
    body = []
    for index, start in enumerate(starts):
        end = starts[index + 1] if index + 1 < len(starts) else 667
        body.append(f'<p>{paragraph_text(rows, start, end, cloze=True)}</p>')
    return ('<h1 class="section-title">Section I　Use of English</h1>'
            '<div class="directions"><strong>Directions:</strong><p>Read the following text. Choose the best word(s) for each numbered blank and mark A, B, C or D on the ANSWER SHEET. (10 points)</p></div>'
            '<section class="passage cloze-passage">' + ''.join(body) + '</section>' + footer(1))


def cloze_options():
    rows = [value for y, value in lines(2) if y < 510]
    choices = ''.join(f'<div class="cloze-row">{ "".join(f"<span>{escape(part)}</span>" for part in re.split(r"(?=\[[BCD]\])", value) if part) }</div>' for value in rows)
    tail = ('<h2>Section II　Reading Comprehension</h2><h3>Part A</h3>'
            '<strong>Directions:</strong><p>Read the following four texts. Answer the questions after each text by choosing A, B, C or D. Mark your answers on the ANSWER SHEET. (40 points)</p>')
    return f'<section class="cloze-list">{choices}</section><section class="section-transition">{tail}</section>{footer(2)}'


def part_b_page_11():
    rows = lines(11)
    options = ''.join(f'<p class="heading-option">{escape(value)}</p>' for y, value in rows if 160 <= y < 320)
    intro = paragraph_text(rows, 369.5, 477)
    first = paragraph_text(rows, 494.7, 639)
    second = paragraph_text(rows, 659.1, 699)
    return ('<h1>Part B</h1><div class="directions"><strong>Directions:</strong>'
            '<p>Read the following text and answer the questions by choosing the most suitable subheading from the list A—G for each numbered paragraph (41—45). There are two extra subheadings which you do not need to use. Mark your answers on the ANSWER SHEET. (10 points)</p></div>'
            f'<section class="heading-options">{options}</section><h2>Five Ways to Win Over Everyone in the Office</h2>'
            f'<p class="reading-paragraph">{intro}</p><p class="part-b-number">41. __________</p><p class="reading-paragraph">{first}</p>'
            f'<p class="part-b-number">42. __________</p><p class="reading-paragraph">{second}</p>{footer(11)}')


def part_b_page_12():
    rows = lines(12)
    parts = [paragraph_text(rows, a, b) for a, b in [(46,134), (151.8,275), (296.7,401), (422.2,570)]]
    return (f'<p class="reading-paragraph continuation">{parts[0]}</p><p class="part-b-number">43. __________</p>'
            f'<p class="reading-paragraph">{parts[1]}</p><p class="part-b-number">44. __________</p>'
            f'<p class="reading-paragraph">{parts[2]}</p><p class="part-b-number">45. __________</p>'
            f'<p class="reading-paragraph">{parts[3]}</p>{footer(12)}')


def translation_writing():
    rows = lines(13)
    paragraphs = [paragraph_text(rows, a, b) for a, b in [(178.4,240.8), (240.8,342.6), (342.6,425)]]
    content = ''.join(f'<p>{p}</p>' for p in paragraphs)
    return ('<h1 class="section-title">Section III　Translation</h1>'
            '<section class="translation-task"><strong>46. Directions:</strong><p>Translate the following text into Chinese. Write your translation on the ANSWER SHEET. (15 points)</p>'
            f'<div class="passage">{content}</div></section>'
            '<section class="writing-task"><h2>Section IV　Writing</h2><h3>Part A</h3><strong>47. Directions:</strong>'
            '<p>Suppose you are planning a tour of a historical site for a group of international students. Write them an email to</p>'
            '<p>1) tell them about the site, and</p><p>2) give them some tips for the tour.</p>'
            '<p>You should write about 100 words on the ANSWER SHEET.</p><p>Do not use your own name. Use “Li Ming” instead. (10 points)</p></section>' + footer(13))


def writing_chart():
    return ('<section class="chart-task"><h1>Part B</h1><strong>48. Directions:</strong>'
            '<p>Write an essay based on the following chart. In your writing, you should</p>'
            '<p>1) interpret the chart, and</p><p>2) give your comments.</p>'
            '<p>You should write about 150 words on the ANSWER SHEET. (15 points)</p>'
            '<img src="papers/2020/assets/2020-writing-chart.webp" alt="某高校学生手机阅读目的的调查：学习知识59.5%，消磨时间21.3%，获取信息17.0%，其他2.2%">'
            '</section>' + footer(14))


def cover():
    return ('<section class="cover-content"><p>绝密★启用前</p><h1>2020年全国硕士研究生招生考试<br>英语（二）</h1>'
            '<p>（科目代码：204）</p><h2>☆考生注意事项☆</h2>'
            '<p>1. 答题前，考生须在试题册指定位置上填写考生编号和考生姓名；在答题卡指定位置上填写报考单位、考生姓名和考生编号，并涂写考生编号信息点。</p>'
            '<p>2. 考生须把试题册上的“试卷条形码”粘贴条取下，粘贴在答题卡的“试卷条形码粘贴位置”框中。不按规定粘贴条形码而影响评卷结果的，责任由考生自负。</p>'
            '<p>3. 选择题的答案必须涂写在答题卡相应题号的选项上，非选择题的答案必须书写在答题卡指定位置的边框区域内。超出答题区域书写的答案无效；在草稿纸、试题册上答题无效。</p>'
            '<p>4. 填（书）写部分必须使用黑色字迹签字笔书写，字迹工整、笔迹清楚；涂写部分必须使用2B铅笔填涂。</p>'
            '<p>5. 考试结束，将答题卡和试题册按规定交回。</p>'
            '<p>（以下信息考生必须认真填写）</p><p>考生编号　________________</p><p>考生姓名　________________</p></section>')


pages = {
    0: ('cover-page', cover()), 1: ('cloze-page', cloze_page()), 2: ('cloze-answers-page', cloze_options()),
    5: ('reading-page reading-page-5', reading_page(5, [86.7, 168.5, 289.8, 489.5, 590.8], 19.6, 'Text 2')),
    6: ('questions-page question-page-6', question_page(6, 46, 22)),
    7: ('reading-page reading-page-7', reading_page(7, [73.1, 212.7, 266.9, 425.7, 497.4, 551.9], 17.1, 'Text 3')),
    8: ('questions-page question-page-8', question_page(8, 46, 23)),
    9: ('reading-page reading-page-9', reading_page(9, [72.9, 241, 445.9, 577.5], 18.3, 'Text 4')),
    10: ('questions-page question-page-10', question_page(10, 60, 13)),
    11: ('part-b-page part-b-page-11', part_b_page_11()),
    12: ('part-b-page part-b-page-12', part_b_page_12()),
    13: ('translation-page', translation_writing()), 14: ('chart-page', writing_chart()),
}
OUTPUT.write_text('// Original-paper HTML: editable paragraphs, questions and task directions.\nwindow.E2_FULL_PAGES = ' + json.dumps(pages, ensure_ascii=False) + ';\n', encoding='utf-8')
print('wrote', OUTPUT, len(pages), 'pages')

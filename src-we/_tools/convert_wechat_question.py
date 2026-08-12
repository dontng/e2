#!/usr/bin/env python3
"""Convert WeChat “阅读每日一题” HTML exports to focused Markdown notes."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

sys.dont_write_bytecode = True

from convert_wechat_daily import (  # noqa: E402
    RED,
    YELLOW,
    TreeParser,
    content_items,
    find_by_id,
    flatten_2025,
    image_markdown,
    is_content_image,
    item_text,
    plain_text,
)


SECTION_TITLES = {
    "解题方法": "解题方法",
    "难点": "难点",
    "易错点": "易错点",
    "出题点": "出题点",
}

SOURCE_RED = "rgb(255, 76, 65)"
SOURCE_YELLOW = "rgb(255, 251, 0)"


def normalized_item(item) -> str:
    if item.tag == "img":
        return ""
    return flatten_2025(item_text(item).replace("\xa0", " "))


def rich_segments(item) -> list[tuple[str, bool, bool, bool, bool]]:
    """Read the article's inline emphasis while standardizing its colors to daily notes."""
    result: list[tuple[str, bool, bool, bool, bool]] = []

    def visit(node, red: bool = False, highlight: bool = False, strike: bool = False, bold: bool = False) -> None:
        if isinstance(node, str):
            value = re.sub(r"\s+", " ", node).strip()
            if value:
                result.append((value, red, highlight, strike, bold))
            return
        if node.tag == "br":
            result.append(("\n", False, False, False, False))
            return
        style = node.attrs.get("style", "").replace(" ", "")
        red = red or any(f"color:{color}".replace(" ", "") in style for color in (RED, SOURCE_RED))
        highlight = highlight or any(
            f"background-color:{color}".replace(" ", "") in style for color in (YELLOW, SOURCE_YELLOW)
        )
        strike = strike or "text-decoration:line-through" in style
        bold = bold or node.tag in {"b", "strong"} or "font-weight:bold" in style or "font-weight:700" in style
        for child in node.children:
            visit(child, red, highlight, strike, bold)

    visit(item)
    return result


def join_text(previous: str, current: str) -> str:
    if not previous or current.startswith((",", ".", ":", ";", "?", "!", "，", "。", "：", "；", "？", "！", "、", "…", "’", "'", ")", "）")):
        return ""
    if previous.endswith(("(", "（", "[", "【", "“", "‘", "’", "'", "-", "—", "/")):
        return ""
    if re.search(r"[\u3400-\u9fff]$", previous) or re.match(r"^[\u3400-\u9fff]", current):
        return ""
    return " "


def render_rich_item(item) -> str:
    segments = [segment for segment in rich_segments(item) if segment[0] != "\n"]
    if not segments:
        return normalized_item(item)
    all_bold = all(bold and not strike for _, _, _, strike, bold in segments)
    merged: list[list[object]] = []
    previous = ""
    for value, red, highlight, strike, bold in segments:
        flags = (red, highlight, strike, False if all_bold else bold)
        separator = join_text(previous, value)
        if merged and tuple(merged[-1][1:]) == flags:
            merged[-1][0] = str(merged[-1][0]) + separator + value
        else:
            merged.append([separator + value, *flags])
        previous = value

    output = ""
    for value, red, highlight, strike, bold in merged:
        text = str(value)
        if strike:
            text = f"<s>{text}</s>"
        if red:
            text = f'<span style="color: {RED};">{text}</span>'
        if highlight:
            text = f'<mark style="background-color: {YELLOW};">{text}</mark>'
        if bold:
            text = f"**{text}**"
        output += text
    return f"**{output}**" if all_bold else output


def locate(texts: list[str], pattern: str, start: int = 0) -> int:
    regex = re.compile(pattern)
    index = next((i for i in range(start, len(texts)) if regex.fullmatch(texts[i])), None)
    if index is None:
        raise ValueError(f"Cannot locate section matching: {pattern}")
    return index


def parse_source(value: str) -> tuple[str, str, str, str, str]:
    compact = re.sub(r"\s+", "", value)
    match = re.fullmatch(r"英语([一二])(\d{4})年Text(\d+)第(\d+)题[-—－]?(.+)", compact, re.I)
    if not match:
        raise ValueError(f"Cannot parse exam source: {value}")
    paper, year, text_number, question_number, question_type = match.groups()
    return paper, year, text_number, question_number, question_type


def infer_answer(texts: list[str], start: int, end: int) -> str:
    body = " ".join(texts[start:end])
    explicit = re.search(r"正确选项为[：:]?\s*([A-D])", body, re.I)
    if explicit:
        return explicit.group(1).upper()
    explained = re.search(r"本题的\s*([A-D])\s*选项是对原文的高度概括", body, re.I)
    if explained:
        return explained.group(1).upper()
    raise ValueError("Cannot determine the correct answer from the article")


def render_passage(values: list[tuple[str, object]]) -> list[str]:
    output: list[str] = []
    for value, item in values:
        match = re.match(r"^(【段\s*\d+\s*】)\s*(.*)$", value, re.S)
        if match:
            marker, _ = match.groups()
            rendered = render_rich_item(item)
            rendered = re.sub(r"^\*\*(【段\s*\d+\s*】)\*\*\s*", "", rendered)
            rendered = re.sub(r"^(【段\s*\d+\s*】)\s*", "", rendered)
            output.extend([f"**{marker}**", "", rendered, ""])
        else:
            output.extend([render_rich_item(item), ""])
    return output


def render_explanation(values: list[tuple[str, object]]) -> list[str]:
    output: list[str] = []
    for value, item in values:
        key = value.rstrip("：:")
        if key in SECTION_TITLES:
            output.extend([f"## {SECTION_TITLES[key]}", ""])
        else:
            output.extend([render_rich_item(item), ""])
    return output


def extract(html: str, source_name: str) -> tuple[str, str, str, str]:
    parser = TreeParser()
    parser.feed(html)
    content = find_by_id(parser.root, "js_content")
    if content is None:
        raise ValueError('Missing WeChat article body: id="js_content"')

    publish_node = find_by_id(parser.root, "publish_time")
    published = plain_text(publish_node) if publish_node else ""
    date_match = re.search(r"(\d{4})年(\d{2})月(\d{2})日", published)
    if not date_match:
        date_match = re.search(r"\[(\d{4})-(\d{2})-(\d{2})-", source_name)
    if not date_match:
        raise ValueError("Cannot infer the publication date")
    publish_year, month, day = date_match.groups()

    items = content_items(content)
    texts = [normalized_item(item) for item in items]
    truth_start = locate(texts, r"先做真题")
    number_index = locate(texts, r"阅读每日一题\s*\d{3}", truth_start + 1)
    number_match = re.search(r"(\d{3})", texts[number_index])
    assert number_match is not None
    number = number_match.group(1)
    source_index = next((i for i in range(number_index + 1, len(texts)) if texts[i]), None)
    if source_index is None:
        raise ValueError("Cannot locate the exam source")
    paper, exam_year, text_number, question_number, question_type = parse_source(texts[source_index])

    explanation_marker = locate(texts, r"再看讲解", source_index + 1)
    solve_wrong = locate(texts, r"解决[“\"]做不对[”\"]的问题", explanation_marker + 1)
    solve_reading = locate(texts, r"解决[“\"]看不懂[”\"]的问题", solve_wrong + 1)
    save_images = locate(texts, r"保存图片\s*随时复习", solve_reading + 1)
    preview = locate(texts, r"每日一题\s*明日预告", save_images + 1)

    lead = [(i, texts[i]) for i in range(source_index + 1, explanation_marker) if texts[i]]
    question_index = next((i for i, value in lead if re.match(r"^\d+\.", value)), None)
    if question_index is None:
        raise ValueError("Cannot locate the question")
    passage = [(value, items[i]) for i, value in lead if i < question_index and value.startswith("【段")]
    question = texts[question_index]
    options = [
        match.groups()
        for i, value in lead
        if i > question_index and (match := re.match(r"^\[([A-D])\]\s*(.+)$", value, re.I))
    ]
    if len(options) != 4:
        raise ValueError(f"Expected four options, found {len(options)}")

    answer = infer_answer(texts, question_index, solve_reading)
    explanation = [(texts[i], items[i]) for i in range(solve_wrong + 1, solve_reading) if texts[i]]
    understanding = [texts[i] for i in range(solve_reading + 1, save_images) if texts[i]]
    image_notes = [texts[i] for i in range(save_images + 1, preview) if texts[i]]
    images = [
        image_markdown(items[i], f"每日一题 {number} 解析图 {image_number}")
        for image_number, i in enumerate(
            [i for i in range(save_images + 1, preview) if items[i].tag == "img" and is_content_image(items[i])],
            start=1,
        )
    ]
    if not images:
        raise ValueError("Cannot locate the analysis images")

    output = [
        "## 真题",
        "",
    ]
    output.extend(render_passage(passage))
    output.extend(
        [
            f'<div align="center">【每日一题 {number} · {exam_year} 英语{paper} Text {text_number} 第 {question_number} 题 · {question_type}】</div>',
            "",
            "**题目:**",
            "",
            question,
            "",
        ]
    )
    for letter, text in options:
        output.extend([f"[{letter}] {text}", ""])

    vocab_index = next((i for i, value in enumerate(understanding) if value == "生词"), None)
    long_index = next((i for i, value in enumerate(understanding) if value == "长难句"), None)
    if vocab_index is not None:
        vocab_end = long_index if long_index is not None else len(understanding)
        output.extend(["", "## 生词", ""])
        vocab = understanding[vocab_index + 1 : vocab_end]
        output.extend(f"✅ {value}{'  ' if index < len(vocab) - 1 else ''}" for index, value in enumerate(vocab))
    if long_index is not None:
        output.extend(["", "## 长难句", ""])
        output.extend(render_passage([(texts[i], items[i]) for i in range(solve_reading + 1, save_images) if texts[i] in understanding[long_index + 1 :]]))

    output.extend(["", "<details>", '<summary><strong>答案与讲解</strong></summary>', "", f"**答案：{answer}**", ""])
    output.extend(render_explanation(explanation))
    output.extend(["## 解析图片", ""])
    output.extend(f"- {note}" for note in image_notes)
    output.append("")
    for image in images:
        output.extend([image, ""])
    output.extend(["</details>", ""])
    return publish_year, month + day, number, "\n".join(output)


def input_files(inputs: list[Path]) -> list[Path]:
    files: list[Path] = []
    for item in inputs:
        if item.is_dir():
            for source in sorted(item.glob("*.html")):
                if re.search(r"每日一题\d{3}", source.name):
                    files.append(source)
                else:
                    print(f"SKIP non-numbered HTML {source}", file=sys.stderr)
        elif item.suffix.lower() in {".html", ".htm"}:
            files.append(item)
        else:
            raise ValueError(f"Not an HTML file or directory: {item}")
    return files


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("inputs", nargs="+", type=Path, help="HTML file(s) or a directory containing HTML files")
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "questions",
        help="Parent directory for year-based output folders",
    )
    parser.add_argument("--check", action="store_true", help="Verify existing output instead of writing it")
    args = parser.parse_args()

    try:
        files = input_files(args.inputs)
        if not files:
            raise ValueError("No numbered question HTML files found")
        failed = False
        for source in files:
            year, mmdd, number, markdown = extract(source.read_text(encoding="utf-8"), source.name)
            destination = args.output_dir / year / f"{mmdd}-question{number}.md"
            if args.check:
                if not destination.exists() or destination.read_text(encoding="utf-8") != markdown:
                    print(f"OUTDATED {destination}", file=sys.stderr)
                    failed = True
                else:
                    print(f"OK {destination}")
            else:
                destination.parent.mkdir(parents=True, exist_ok=True)
                destination.write_text(markdown, encoding="utf-8")
                print(destination)
        return 1 if failed else 0
    except (OSError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())

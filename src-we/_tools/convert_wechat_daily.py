#!/usr/bin/env python3
"""Convert WeChat “长难句每日一句” HTML exports to stable Markdown notes."""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass, field
from html.parser import HTMLParser
from pathlib import Path
from typing import Iterable, Iterator


RED = "rgb(239, 18, 18)"
YELLOW = "rgb(238, 245, 13)"


@dataclass
class Node:
    tag: str
    attrs: dict[str, str] = field(default_factory=dict)
    parent: "Node | None" = None
    children: list["Node | str"] = field(default_factory=list)


class TreeParser(HTMLParser):
    VOID = {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "param", "source", "track", "wbr"}

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.root = Node("document")
        self.stack = [self.root]

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        node = Node(tag, {key: value or "" for key, value in attrs}, self.stack[-1])
        self.stack[-1].children.append(node)
        if tag not in self.VOID:
            self.stack.append(node)

    def handle_startendtag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        self.handle_starttag(tag, attrs)
        if tag not in self.VOID:
            self.handle_endtag(tag)

    def handle_endtag(self, tag: str) -> None:
        for index in range(len(self.stack) - 1, 0, -1):
            if self.stack[index].tag == tag:
                del self.stack[index:]
                return

    def handle_data(self, data: str) -> None:
        self.stack[-1].children.append(data)


def nodes(root: Node, tag: str | None = None) -> Iterator[Node]:
    stack = [child for child in reversed(root.children) if isinstance(child, Node)]
    while stack:
        node = stack.pop()
        if tag is None or node.tag == tag:
            yield node
        stack.extend(child for child in reversed(node.children) if isinstance(child, Node))


def plain_text(node: Node) -> str:
    parts: list[str] = []

    def visit(item: Node | str) -> None:
        if isinstance(item, str):
            parts.append(item)
            return
        if item.tag == "br":
            parts.append("\n")
            return
        for child in item.children:
            visit(child)

    visit(node)
    text = "".join(parts)
    text = re.sub(r"[\t\r\f\v ]+", " ", text)
    text = re.sub(r" *\n *", "\n", text)
    text = re.sub(r"\n{2,}", "\n", text)
    return text.strip()


def find_by_id(root: Node, node_id: str) -> Node | None:
    return next((node for node in nodes(root) if node.attrs.get("id") == node_id), None)


def p_nodes(root: Node) -> list[Node]:
    return list(nodes(root, "p"))


def closest_card(node: Node, required: Iterable[str]) -> Node:
    current = node.parent
    required = tuple(required)
    while current is not None:
        text = plain_text(current)
        if current.tag == "section" and all(item in text for item in required):
            return current
        current = current.parent
    raise ValueError(f"Cannot find article card containing: {', '.join(required)}")


def next_nonempty(paragraphs: list[Node], start: int) -> Node:
    for paragraph in paragraphs[start + 1 :]:
        if plain_text(paragraph):
            return paragraph
    raise ValueError("Expected another non-empty paragraph")


def contains_style(node: Node, fragment: str) -> bool:
    return fragment.replace(" ", "") in node.attrs.get("style", "").replace(" ", "")


def styled_segments(node: Node) -> list[tuple[str, bool, bool, bool]]:
    result: list[tuple[str, bool, bool, bool]] = []

    def visit(item: Node | str, red: bool = False, strike: bool = False, bold: bool = False) -> None:
        if isinstance(item, str):
            value = re.sub(r"\s+", " ", item).strip()
            if value:
                result.append((value, red, strike, bold))
            return
        if item.tag == "br":
            result.append(("\n", False, False, False))
            return
        style = item.attrs.get("style", "").replace(" ", "")
        red = red or f"color:{RED}".replace(" ", "") in style
        strike = strike or "text-decoration:line-through" in style
        bold = bold or item.tag in {"b", "strong"}
        for child in item.children:
            visit(child, red, strike, bold)

    visit(node)
    return result


def wrap_segment(text: str, red: bool, strike: bool, bold: bool) -> str:
    if strike:
        text = f"<s>{text}</s>"
    if red:
        text = f'<span style="color: {RED};">{text}</span>'
    if bold:
        text = f"**{text}**"
    return text


def join_styled(segments: list[tuple[str, bool, bool, bool]]) -> list[str]:
    lines: list[list[tuple[str, bool, bool, bool]]] = [[]]
    for segment in segments:
        if segment[0] == "\n":
            if lines[-1]:
                lines.append([])
            continue
        lines[-1].append(segment)

    rendered: list[str] = []
    for line in lines:
        if not line:
            continue
        output = ""
        previous_text = ""
        for text, red, strike, bold in line:
            separator = ""
            if output and not text.startswith((",", ".", ":", ";", "，", "。", "：", "；", "…")):
                if not previous_text.endswith(("：", "…")):
                    separator = " "
            output += separator + wrap_segment(text, red, strike, bold)
            previous_text = text
        rendered.append(output)
    return rendered


def normalize_paragraph(text: str) -> str:
    """Normalize exported paragraph text without discarding intentional line breaks."""
    lines = [re.sub(r"[\t\r\f\v ]+", " ", line).strip() for line in text.splitlines()]
    return "\n".join(line for line in lines if line)


def first_index(texts: list[str], value: str, start: int = 0) -> int | None:
    return next((index for index in range(start, len(texts)) if texts[index] == value), None)


def section_end(texts: list[str], start: int, headings: set[str]) -> int:
    return next((index for index in range(start + 1, len(texts)) if texts[index] in headings), len(texts))


HEADINGS = {
    "分析长难句前的准备工作",
    "视频讲解",
    "内容详解",
    "生词",
    "分析句子",
    "参考译文",
    "语法重点",
    "翻译要点",
    "难点提示",
    "今日预习",
}


def flatten(text: str) -> str:
    text = " ".join(normalize_paragraph(text).splitlines())
    return re.sub(r"\s+([,.;:，。；：！？])", r"\1", text).strip()


def flatten_2025(text: str) -> str:
    text = flatten(text)
    return re.sub(r"(?<=[A-Za-z])\s*([’'])\s*(?=[A-Za-z])", r"\1", text)


def format_step(text: str) -> str | None:
    match = re.match(r"^([012]\s+[^：:\n]+[：:])\s*(.*)$", normalize_paragraph(text), re.S)
    if not match:
        return None
    label, explanation = match.groups()
    separator = " " if label.startswith("0 ") and explanation else ""
    return f'<strong><span style="color: {RED};">{label}</span></strong>{separator}{flatten(explanation)}'


def vocabulary_lines(paragraphs: list[Node]) -> list[str]:
    entries: list[str] = []
    for paragraph in paragraphs:
        text = normalize_paragraph(plain_text(paragraph))
        if not text:
            continue
        chunks = [chunk for chunk in re.split(r"(?=[✅☑])", text) if chunk.strip()]
        entries.extend(flatten(chunk) for chunk in chunks)
    return entries


def render_styled_paragraph(paragraph: Node) -> str:
    lines = join_styled(styled_segments(paragraph))
    return "  \n".join(lines) if lines else normalize_paragraph(plain_text(paragraph))


def render_2025_styled_paragraph(paragraph: Node) -> str:
    segments = styled_segments(paragraph)
    visible = [segment for segment in segments if segment[0] != "\n"]
    if visible and all(bold and not strike for _, _, strike, bold in visible):
        text = flatten_2025(plain_text(paragraph))
        if all(red for _, red, _, _ in visible):
            text = f'<span style="color: {RED};">{text}</span>'
        return f"**{text}**"
    lines = join_styled(segments)
    return "  \n".join(lines) if lines else normalize_paragraph(plain_text(paragraph))


def analysis_blocks(paragraphs: list[Node]) -> list[str]:
    blocks: list[str] = []
    bullets: list[str] = []

    def flush_bullets() -> None:
        if bullets:
            blocks.append("\n".join(bullets))
            bullets.clear()

    for paragraph in paragraphs:
        text = normalize_paragraph(plain_text(paragraph))
        if not text:
            continue
        step = format_step(text)
        if step:
            flush_bullets()
            blocks.append(step)
            continue
        if text.startswith("【句"):
            if "简化后的核心内容：" in text:
                flush_bullets()
                lines = join_styled(styled_segments(paragraph))
                if len(lines) >= 2:
                    core = lines[-1].replace("**简化后的核心内容：** ", "**简化后的核心内容：**")
                    blocks.append(f"- {lines[0]}\n\n  {core}")
                else:
                    blocks.append(f"- {flatten(text)}")
            else:
                bullets.append(f"- {flatten(text)}")
            continue
        flush_bullets()
        blocks.append(text)
    flush_bullets()
    return blocks


BLOCK_TAGS = {"p", "section", "ul", "ol", "li"}


def item_text(node: Node) -> str:
    if node.tag == "p":
        return normalize_paragraph(plain_text(node))
    parts: list[str] = []

    def visit(item: Node | str) -> None:
        if isinstance(item, str):
            parts.append(item)
        elif item.tag == "br":
            parts.append("\n")
        elif item.tag not in BLOCK_TAGS and item.tag != "img":
            for child in item.children:
                visit(child)

    for child in node.children:
        visit(child)
    return normalize_paragraph("".join(parts))


def content_items(root: Node) -> list[Node]:
    result: list[Node] = []

    def append_inline(children: list[Node | str], parent: Node) -> None:
        if not children:
            return
        block = Node("text-block", parent=parent, children=list(children))
        if item_text(block):
            result.append(block)

    def visit(node: Node) -> None:
        if node.tag == "img":
            result.append(node)
            return
        if node.tag == "p":
            result.append(node)
            for descendant in nodes(node, "img"):
                result.append(descendant)
            return
        inline: list[Node | str] = []
        for child in node.children:
            if isinstance(child, Node) and (child.tag in BLOCK_TAGS or child.tag == "img"):
                append_inline(inline, node)
                inline.clear()
                visit(child)
            else:
                inline.append(child)
        append_inline(inline, node)

    visit(root)
    return result


def item_heading_index(items: list[Node], heading: str, start: int = 0) -> int | None:
    return next(
        (
            index
            for index in range(start, len(items))
            if items[index].tag != "img" and item_text(items[index]) == heading
        ),
        None,
    )


def is_content_image(node: Node) -> bool:
    url = node.attrs.get("data-src") or node.attrs.get("src", "")
    if not url or "_gif/" in url or "wx_fmt=gif" in url:
        return False
    try:
        width = int(float(node.attrs.get("data-w", "0")))
    except ValueError:
        width = 0
    return width >= 600


def image_markdown(node: Node, alt: str) -> str:
    url = node.attrs.get("data-src") or node.attrs.get("src", "")
    return f"![{alt}]({url})"


def render_2025_items(items: list[Node], image_alt: str) -> list[str]:
    rendered: list[str] = []
    for item in items:
        if item.tag == "img":
            if not is_content_image(item):
                continue
            value = image_markdown(item, image_alt)
        else:
            text = item_text(item)
            if not text:
                continue
            value = render_2025_styled_paragraph(item) if item.tag == "p" else text
        if value not in rendered:
            rendered.append(value)
    return rendered


def render_2025_vocabulary(items: list[Node]) -> list[str]:
    rendered: list[str] = []
    for item in items:
        if item.tag == "img":
            if not is_content_image(item):
                continue
            values = [image_markdown(item, "生词图")]
        else:
            text = item_text(item)
            values = []
            for chunk in re.split(r"(?=[✅☑])", text):
                if not chunk.strip():
                    continue
                value = flatten_2025(chunk)
                value = re.sub(
                    r"/([^/]+)/",
                    lambda match: "/" + re.sub(r"\s+", "", match.group(1)) + "/",
                    value,
                )
                value = re.sub(r"^([✅☑]\s+)([A-Za-z])\s+([a-z]{3,})", r"\1\2\3", value)
                values.append(value)
        for value in values:
            if value not in rendered:
                rendered.append(value)
    return rendered


def extract_2025(
    content: Node,
    paragraphs: list[Node],
    texts: list[str],
    year: str,
    mmdd: str,
) -> tuple[str, str, str, str]:
    day_match = next(
        (match for text in texts if (match := re.fullmatch(r"DAY\s*(\d+)", text, re.I))),
        None,
    )
    if not day_match:
        raise ValueError("Cannot infer Day N from the article")
    day = day_match.group(1)

    items = content_items(content)
    day_item = item_heading_index(items, next(text for text in texts if re.fullmatch(r"DAY\s*\d+", text, re.I)))
    video_item = item_heading_index(items, "视频讲解", day_item + 1 if day_item is not None else 0)
    if day_item is None or video_item is None:
        raise ValueError("Cannot locate the daily sentence card")

    lead_items = items[day_item + 1 : video_item]
    lead_text_nodes = [
        item
        for item in lead_items
        if item.tag != "img"
        and item_text(item)
        and not re.fullmatch(r"词汇\s*[|｜]\s*语法\s*[|｜]\s*解析\s*[|｜]\s*答疑", flatten(item_text(item)))
    ]
    lead_texts = [item_text(item) for item in lead_text_nodes]
    sentence = next((text for text in lead_texts if len(re.findall(r"[A-Za-z]", text)) >= 12), None)
    source = next((text for text in lead_texts if re.fullmatch(r"【\d{4}[^】]*】", text)), None)
    questions = [
        flatten_2025(text)
        for text in lead_texts
        if text not in {sentence, source, "思考题:", "思考题："}
    ]
    lead_images = [image_markdown(item, "原句") for item in lead_items if item.tag == "img" and is_content_image(item)]

    output = ["## 原句", ""]
    if sentence:
        output.append(f"> {flatten_2025(sentence)}")
    output.extend(lead_images)
    if source:
        output.extend(["", f'<div align="center">{source}</div>'])
    if questions:
        output.extend(["", "**思考题:**", "", " ".join(questions)])

    section_names = {
        "生词": "生词",
        "分析": "分析句子",
        "翻译": "参考译文",
        "语法重点": "语法重点",
    }
    section_order = ["生词", "分析", "翻译", "语法重点", "难点提示"]
    item_starts = {heading: item_heading_index(items, heading, video_item + 1) for heading in section_order}
    missing = [heading for heading in ("生词", "翻译", "语法重点", "难点提示") if item_starts[heading] is None]
    if missing:
        raise ValueError(f"Cannot locate required section(s): {', '.join(missing)}")

    bodies: dict[str, list[Node]] = {}
    available_sections = [heading for heading in section_order if item_starts[heading] is not None]
    for index, heading in enumerate(available_sections[:-1]):
        start = item_starts[heading]
        end = item_starts[available_sections[index + 1]]
        assert start is not None and end is not None
        bodies[heading] = items[start + 1 : end]

    for heading in ("生词", "分析", "语法重点", "翻译"):
        if heading not in bodies:
            continue
        values = (
            render_2025_vocabulary(bodies[heading])
            if heading == "生词"
            else render_2025_items(bodies[heading], f"{section_names[heading]}图")
        )
        if not values:
            continue
        output.extend(["", f"## {section_names[heading]}", ""])
        if heading == "生词" and not any(value.startswith("![") for value in values):
            for index, value in enumerate(values):
                output.append(f"{flatten(value)}{'  ' if index < len(values) - 1 else ''}")
        else:
            for index, value in enumerate(values):
                if index:
                    output.append("")
                output.append(value)
    output.append("")
    return year, mmdd, day, "\n".join(output)


def extract(html: str) -> tuple[str, str, str, str]:
    """Extract a formatted study note, including the complete grammar section."""
    parser = TreeParser()
    parser.feed(html)
    content = find_by_id(parser.root, "js_content")
    if content is None:
        raise ValueError('Missing WeChat article body: id="js_content"')

    paragraphs = p_nodes(content)
    texts = [normalize_paragraph(plain_text(paragraph)) for paragraph in paragraphs]

    publish_node = find_by_id(parser.root, "publish_time")
    published = plain_text(publish_node) if publish_node else ""
    date_match = re.search(r"(\d{4})年(\d{2})月(\d{2})日", published)
    if not date_match:
        raise ValueError("Cannot infer the publication date")
    year = date_match.group(1)
    mmdd = date_match.group(2) + date_match.group(3)
    if year == "2025":
        return extract_2025(content, paragraphs, texts, year, mmdd)

    source_index = next(
        (
            index
            for index, text in enumerate(texts)
            if re.fullmatch(r"【\d{4}\s*年[^】]*(?:阅读|翻译)[^】]*】", text)
        ),
        None,
    )
    if source_index is None:
        raise ValueError("Cannot locate the exam source label")

    sentence_index = next((index for index in range(source_index - 1, -1, -1) if texts[index]), None)
    if sentence_index is None:
        raise ValueError("Cannot locate the original sentence")
    sentence = texts[sentence_index].replace("\n", " ")
    source = texts[source_index]

    question_index = next(
        (index for index in range(source_index + 1, len(texts)) if texts[index] in {"思考题:", "思考题："}),
        None,
    )
    if question_index is None:
        raise ValueError("Cannot locate the question heading")
    question_value_index = next((index for index in range(question_index + 1, len(texts)) if texts[index]), None)
    if question_value_index is None:
        raise ValueError("Cannot locate the question")
    question = texts[question_value_index].replace("\n", " ")

    section_starts: dict[str, int] = {}
    for heading in HEADINGS:
        index = first_index(texts, heading, source_index + 1)
        if index is not None:
            section_starts[heading] = index

    required = {"生词", "参考译文"}
    missing = sorted(required - section_starts.keys())
    if missing:
        raise ValueError(f"Cannot locate required section(s): {', '.join(missing)}")

    def body(heading: str) -> list[str]:
        start = section_starts[heading]
        end = section_end(texts, start, HEADINGS)
        return [text for text in texts[start + 1 : end] if text]

    def body_nodes(heading: str) -> list[Node]:
        start = section_starts[heading]
        end = section_end(texts, start, HEADINGS)
        return [paragraph for paragraph in paragraphs[start + 1 : end] if plain_text(paragraph)]

    output = [
        "## 原句",
        "",
        f"> {sentence}",
        "",
        f'<div align="center">{source}</div>',
        "",
        "**思考题:**",
        "",
        question,
    ]

    def append_section(title: str, values: list[str]) -> None:
        if not values:
            return
        output.extend(["", f"## {title}", ""])
        for index, value in enumerate(values):
            if index:
                output.append("")
            output.append(value)

    if "分析长难句前的准备工作" in section_starts:
        prep_nodes = body_nodes("分析长难句前的准备工作")
        prep_values: list[str] = []
        for index, paragraph in enumerate(prep_nodes):
            text = normalize_paragraph(plain_text(paragraph))
            step = format_step(text)
            if step:
                prep_values.append(step)
            elif index >= 2:
                prep_values.append(f'<mark style="background-color: {YELLOW};">{text}</mark>')
            else:
                prep_values.append(text)
        append_section("分析长难句前的准备工作", prep_values)

    vocab = vocabulary_lines(body_nodes("生词"))
    output.extend(["", "## 生词", ""])
    output.extend(f"{line}  " for line in vocab[:-1])
    output.append(vocab[-1])

    if "分析句子" in section_starts:
        append_section("分析句子", analysis_blocks(body_nodes("分析句子")))
    if "语法重点" in section_starts:
        append_section("语法重点", [render_styled_paragraph(node) for node in body_nodes("语法重点")])
    if "翻译要点" in section_starts:
        append_section("翻译要点", [render_styled_paragraph(node) for node in body_nodes("翻译要点")])
    append_section("参考译文", body("参考译文"))
    output.append("")

    day_match = next(
        (match for text in texts if (match := re.fullmatch(r"Day\s*(\d+)", text, re.I))),
        None,
    )
    if not day_match:
        raise ValueError("Cannot infer Day N from the article")
    return year, mmdd, day_match.group(1), "\n".join(output)


def input_files(inputs: list[Path]) -> list[Path]:
    files: list[Path] = []
    for item in inputs:
        if item.is_dir():
            for source in sorted(item.glob("*.html")):
                if re.search(r"Day\s*\d+", source.read_text(encoding="utf-8"), re.I):
                    files.append(source)
                else:
                    print(f"SKIP non-daily HTML {source}", file=sys.stderr)
        elif item.suffix.lower() in {".html", ".htm"}:
            files.append(item)
        else:
            raise ValueError(f"Not an HTML file or directory: {item}")
    return files


def dedupe_ignores(output_dir: Path) -> set[str]:
    manifest = output_dir / "_tools" / "dedupe-ignore.txt"
    if not manifest.exists():
        return set()
    return {
        line.strip()
        for line in manifest.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("inputs", nargs="+", type=Path, help="HTML file(s) or a directory containing HTML files")
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path(__file__).resolve().parents[1],
        help="Parent directory for year-based output folders",
    )
    parser.add_argument("--check", action="store_true", help="Verify existing output instead of writing it")
    args = parser.parse_args()

    try:
        files = input_files(args.inputs)
        if not files:
            raise ValueError("No HTML files found")
        ignored = dedupe_ignores(args.output_dir)
        failed = False
        for source in files:
            year, mmdd, day, markdown = extract(source.read_text(encoding="utf-8"))
            destination = args.output_dir / year / f"{mmdd}-day{day}.md"
            relative_destination = destination.relative_to(args.output_dir).as_posix()
            if relative_destination in ignored:
                print(f"SKIP deduplicated {destination}")
                continue
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
    except (OSError, ValueError, StopIteration) as error:
        print(f"error: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())

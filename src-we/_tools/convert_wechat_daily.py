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
    for child in root.children:
        if isinstance(child, Node):
            if tag is None or child.tag == tag:
                yield child
            yield from nodes(child, tag)


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


def extract(html: str) -> tuple[str, str, str]:
    parser = TreeParser()
    parser.feed(html)
    content = find_by_id(parser.root, "js_content")
    if content is None:
        raise ValueError('Missing WeChat article body: id="js_content"')

    paragraphs = p_nodes(content)
    texts = [plain_text(p) for p in paragraphs]

    source_index = next((i for i, text in enumerate(texts) if re.fullmatch(r"【\d{4}年英[一二]阅读\s*Text\s*\d+】", text)), None)
    if source_index is None:
        raise ValueError("Cannot locate the exam source label")
    source = texts[source_index]
    source_node = paragraphs[source_index]
    card = closest_card(source_node, ("思考题",))
    card_paragraphs = [p for p in p_nodes(card) if plain_text(p)]
    card_texts = [plain_text(p) for p in card_paragraphs]
    local_source_index = card_texts.index(source)
    sentence = card_texts[local_source_index - 1]
    question_label_index = next(i for i, text in enumerate(card_texts) if text in {"思考题:", "思考题："})
    question = card_texts[question_label_index + 1]

    predicate_index = next(i for i, text in enumerate(texts) if text.startswith("0 找谓语动词："))
    predicate_full = texts[predicate_index]
    predicate = predicate_full.removeprefix("0 找谓语动词：").strip()
    predicate_count_node = next_nonempty(paragraphs, predicate_index)
    predicate_count = plain_text(predicate_count_node)
    count_index = paragraphs.index(predicate_count_node)
    predicate_note = plain_text(next_nonempty(paragraphs, count_index))

    vocab_heading = next(i for i, text in enumerate(texts) if text == "生词")
    analysis_heading = next(i for i, text in enumerate(texts) if text == "分析句子")
    vocab_lines: list[str] = []
    for paragraph in paragraphs[vocab_heading + 1 : analysis_heading]:
        for line in plain_text(paragraph).splitlines():
            if line.startswith("✅"):
                vocab_lines.append(line)
    if not vocab_lines:
        raise ValueError("Cannot locate vocabulary entries")

    split_index = next(i for i, text in enumerate(texts) if text.startswith("1 断开："))
    split_intro = texts[split_index].removeprefix("1 断开：").strip()
    simplify_index = next(i for i, text in enumerate(texts) if text.startswith("2 简化主句1："))
    split_lines: list[str] = []
    for paragraph in paragraphs[split_index + 1 : simplify_index]:
        text = plain_text(paragraph)
        if text.startswith("【句") and text not in split_lines:
            split_lines.append(text)
    simplify_intro = texts[simplify_index].removeprefix("2 简化主句1：").strip()

    simplify_paragraph = next(
        paragraph
        for paragraph in paragraphs[simplify_index + 1 :]
        if plain_text(paragraph).startswith("【句1】主句1：") and "简化后的核心内容：" in plain_text(paragraph)
    )
    simplify_lines = join_styled(styled_segments(simplify_paragraph))
    if len(simplify_lines) < 2:
        raise ValueError("Cannot split the simplified sentence and its core")
    simplified_sentence = simplify_lines[0]
    simplified_core = simplify_lines[-1]
    simplified_core = simplified_core.replace("**简化后的核心内容：** ", "**简化后的核心内容：**")

    translation_heading = next(i for i, text in enumerate(texts) if text == "参考译文")
    translation = plain_text(next_nonempty(paragraphs, translation_heading))

    publish_node = find_by_id(parser.root, "publish_time")
    published = plain_text(publish_node) if publish_node else ""
    date_match = re.search(r"(\d{4})年(\d{2})月(\d{2})日", published)
    if not date_match:
        raise ValueError("Cannot infer MMDD from the publish time")
    mmdd = date_match.group(2) + date_match.group(3)

    content_text = plain_text(content)
    day_match = re.search(r"Day\s*(\d+)", content_text, re.I)
    if not day_match:
        raise ValueError("Cannot infer Day N from the article")
    day = day_match.group(1)

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
        "",
        "## 分析长难句前的准备工作",
        "",
        f'<strong><span style="color: {RED};">0 找谓语动词：</span></strong> {predicate}',
        "",
        predicate_count,
        "",
        f'<mark style="background-color: {YELLOW};">{predicate_note}</mark>',
        "",
        "## 生词",
        "",
    ]
    output.extend(f"{line}  " for line in vocab_lines[:-1])
    output.append(vocab_lines[-1])
    output.extend([
        "",
        "## 分析句子",
        "",
        f'<strong><span style="color: {RED};">1 断开：</span></strong>{split_intro}',
        "",
    ])
    output.extend(f"- {line}" for line in split_lines)
    output.extend([
        "",
        f'<strong><span style="color: {RED};">2 简化主句1：</span></strong>{simplify_intro}',
        "",
        f"- {simplified_sentence}",
        "",
        f"  {simplified_core}",
        "",
        "## 参考译文",
        "",
        translation,
        "",
    ])
    return mmdd, day, "\n".join(output)


def input_files(inputs: list[Path]) -> list[Path]:
    files: list[Path] = []
    for item in inputs:
        if item.is_dir():
            files.extend(sorted(item.glob("*.html")))
        elif item.suffix.lower() in {".html", ".htm"}:
            files.append(item)
        else:
            raise ValueError(f"Not an HTML file or directory: {item}")
    return files


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("inputs", nargs="+", type=Path, help="HTML file(s) or a directory containing HTML files")
    parser.add_argument("--output-dir", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--check", action="store_true", help="Verify existing output instead of writing it")
    args = parser.parse_args()

    try:
        files = input_files(args.inputs)
        if not files:
            raise ValueError("No HTML files found")
        failed = False
        for source in files:
            mmdd, day, markdown = extract(source.read_text(encoding="utf-8"))
            destination = args.output_dir / f"{mmdd}-day{day}.md"
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

#!/usr/bin/env python3
"""Strip all sections except navigation, title, 原句, user translation, and 复习区."""

import re
import sys
from pathlib import Path

# Sections to KEEP (matched by header text)
KEEP_HEADERS = {"原句", "原句 (Input)", "我的理解和翻译", "我的翻译", "复习区"}

def strip_file(path: Path):
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines(keepends=True)

    # Split into blocks: each block is (header_line_idx, header_text, [content_lines])
    # Non-section lines before first ## are "preamble"
    sections = []   # list of (kind, lines)  kind = 'preamble' | 'section:<name>'
    current_kind = "preamble"
    current_lines = []

    section_re = re.compile(r"^##\s+(.+)")

    for line in lines:
        m = section_re.match(line)
        if m:
            sections.append((current_kind, current_lines))
            current_kind = "section:" + m.group(1).strip()
            current_lines = [line]
        else:
            current_lines.append(line)

    sections.append((current_kind, current_lines))

    # Build output
    out_parts = []
    for kind, block_lines in sections:
        if kind == "preamble":
            out_parts.append("".join(block_lines))
        elif kind.startswith("section:"):
            name = kind[len("section:"):]
            if name in KEEP_HEADERS:
                out_parts.append("".join(block_lines))
            # else: discard

    result = "".join(out_parts)

    # Clean up excessive blank lines (more than 2 consecutive)
    result = re.sub(r"\n{4,}", "\n\n\n", result)

    path.write_text(result, encoding="utf-8")
    print(f"stripped: {path}")


def main():
    repo = Path("/home/djology/english2-daily/src")

    # May: day31–day41
    may_files = sorted((repo / "may").glob("*.md"))
    may_files = [f for f in may_files if f.name != "0518-day30.md"]

    # June: day42–day66 (before 0630)
    june_files = sorted((repo / "june").glob("*.md"))
    june_files = [f for f in june_files if f.name < "0630"]

    targets = may_files + june_files
    print(f"Total files to strip: {len(targets)}")
    for f in targets:
        strip_file(f)
    print("Done.")

if __name__ == "__main__":
    main()

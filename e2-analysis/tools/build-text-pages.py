"""Extract selectable page text from the checked 2020 source PDF.

Text 1 uses the hand-set semantic HTML in text1-layout.js instead. Page 14 is
a scanned image, so it keeps the graphic and gets a separate OCR text layer.
"""
import html
import hashlib
import json
import subprocess
from pathlib import Path

import fitz

ROOT = Path(__file__).resolve().parents[2]
PDF = ROOT / "archive-e2/2020年考研英语二真题.pdf"
if not PDF.exists():
    PDF = ROOT / "2020.pdf"  # Scratch copy of the same source while working here.
OUTPUT = ROOT / "e2-analysis/papers/2020/text-pages.js"
assert hashlib.sha256(PDF.read_bytes()).hexdigest() == "5a73d22c80feaccd1318280f11ff1875f750e7e59dd33662b9691e9c0ac7ac2c"


def pt(n):
    return f"{n:.2f}pt"


def page_html(page):
    result = []
    for block in page.get_text("dict")["blocks"]:
        for line in block.get("lines", []):
            for span in line["spans"]:
                if not span["text"].strip():
                    continue
                x0, y0, x1, y1 = span["bbox"]
                family = '"Times New Roman", Times, serif' if "Times" in span["font"] else '"SimSun", serif'
                weight = "bold" if "Bold" in span["font"] or "Hei" in span["font"] else "normal"
                style = f"left:{pt(x0)};top:{pt(y0)};font-size:{pt(span['size'])};font-family:{family};font-weight:{weight}"
                result.append(f'<span class="pdf-text" style="{style}">{html.escape(span["text"])}</span>')
    return "\n".join(result)


doc = fitz.open(PDF)
assert len(doc) == 15
pages = {str(i): page_html(doc[i]) for i in range(14) if i not in (3, 4)}
scan = ROOT / "e2-analysis/papers/2020/assets/page-14.webp"
rows = subprocess.check_output(["tesseract", str(scan), "stdout", "-l", "eng", "tsv"], stderr=subprocess.DEVNULL, text=True).splitlines()
head = rows.pop(0).split("\t")
ocr = []
for raw in rows:
    cell = dict(zip(head, raw.split("\t")))
    if cell.get("level") != "5" or float(cell.get("conf", -1)) < 55 or not cell.get("text", "").strip():
        continue
    x, y, w, h = (int(cell[key]) for key in ("left", "top", "width", "height"))
    style = f"left:{pt(x * 535.748 / 1286)};top:{pt(y * 748.347 / 1797)};font-size:{pt(h * 748.347 / 1797)}"
    ocr.append(f'<span class="scan-text" style="{style}">{html.escape(cell["text"])}</span>')
OUTPUT.write_text("// Selectable page text and the OCR layer for the scanned chart page.\nwindow.E2_TEXT_PAGES = " + json.dumps(pages, ensure_ascii=False) + ";\nwindow.E2_SCAN_TEXT = " + json.dumps("\n".join(ocr), ensure_ascii=False) + ";\n", encoding="utf-8")
print("Wrote", OUTPUT, "with", len(pages), "selectable pages")

"""Render every page of an original exam PDF into pixel-identical lossless WebP.

Requires PyMuPDF and Pillow. The source PDF remains the authority for print and
page boundaries; output assets only supply the browser's double-page surface.
"""

import argparse
from pathlib import Path

import fitz
from PIL import Image


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("pdf", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--scale", type=float, default=2.4)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)

    with fitz.open(args.pdf) as source:
        for index, page in enumerate(source):
            pixels = page.get_pixmap(
                matrix=fitz.Matrix(args.scale, args.scale),
                colorspace=fitz.csRGB,
                alpha=False,
            )
            image = Image.frombytes("RGB", (pixels.width, pixels.height), pixels.samples)
            target = args.output / f"page-{index:02d}.webp"
            image.save(target, format="WEBP", lossless=True, method=6)
            print(f"{index:02d}: {pixels.width}×{pixels.height} → {target}")


if __name__ == "__main__":
    main()

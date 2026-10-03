"""Generates the Phase 3 test images locally (no downloads). Needs Pillow:

    python3 -m venv /tmp/celia-eval-venv && /tmp/celia-eval-venv/bin/pip install pillow
    /tmp/celia-eval-venv/bin/python backend/eval/make_images.py

Writes JPEGs to backend/eval/out/images/. Small sizes keep image tokens (and cost) low.
"""

import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out", "images")
FONT_PATHS = [
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    "/System/Library/Fonts/Supplemental/Arial.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
]


def font(size: int) -> ImageFont.FreeTypeFont:
    for path in FONT_PATHS:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    sys.exit("no TrueType font found; edit FONT_PATHS")


def box(lines: list[tuple[str, int]], size=(768, 512)) -> Image.Image:
    img = Image.new("RGB", size, (250, 250, 248))
    d = ImageDraw.Draw(img)
    d.rectangle([12, 12, size[0] - 12, size[1] - 12], outline=(40, 40, 40), width=4)
    y = 60
    for text, px in lines:
        d.text((48, y), text, fill=(20, 20, 30), font=font(px))
        y += int(px * 1.5)
    return img


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    klacid = box([("KLACID 500 mg", 72), ("Clarithromycinum", 44), ("14 tabletek powlekanych", 36)])
    klacid.save(os.path.join(OUT, "1-klacid.jpg"), quality=85)
    klacid.filter(ImageFilter.GaussianBlur(14)).save(os.path.join(OUT, "2-klacid-blur.jpg"), quality=85)
    box([("Grocery list:", 56), ("milk, eggs, bread", 48)]).save(os.path.join(OUT, "3-grocery.jpg"), quality=85)
    two = Image.new("RGB", (768, 512), (235, 235, 235))
    two.paste(box([("Zofran 4 mg", 52), ("Ondansetron", 34)], (370, 480)), (8, 16))
    two.paste(box([("Apap 500 mg", 52), ("Paracetamol", 34)], (370, 480)), (390, 16))
    two.save(os.path.join(OUT, "4-two-products.jpg"), quality=85)
    print("\n".join(sorted(os.listdir(OUT))))


if __name__ == "__main__":
    main()

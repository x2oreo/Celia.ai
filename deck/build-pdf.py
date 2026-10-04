#!/usr/bin/env python3
"""Print the HTML decks to PDF with a demo video that plays from any PDF viewer.

Usage (needs Google Chrome, ffprobe and `pip install pypdf pillow`):
    python3 deck/build-pdf.py            # all decks
    python3 deck/build-pdf.py index.html # one deck

Each deck is printed with headless Chrome (the print CSS shows the poster and the
"Click to play" button). On the "Demo" slide the script adds a link over the whole
video frame to the hosted MP4 (VIDEO_URL), so a click plays it in the browser from
Preview, Chrome, Acrobat or any other viewer. Video inside a PDF only plays in
Acrobat, so the PDF does not rely on it and does not carry the MP4.

Images are downscaled to MAX_IMAGE_PX and stored as JPEG (alpha masks stay lossless)
so each PDF stays under 10 MB.

VIDEO_URL is the landing page's copy of site/media/demo.mp4: deploy the site after
a new render so the link serves the new cut.
"""

import io
import re
import subprocess
import zlib
import sys
import tempfile
from pathlib import Path

from PIL import Image
from pypdf import PdfReader, PdfWriter
from pypdf.generic import (
    ArrayObject,
    DictionaryObject,
    FloatObject,
    NameObject,
    NumberObject,
    TextStringObject,
)

DECK = Path(__file__).resolve().parent
VIDEO = DECK.parent / "site" / "media" / "demo.mp4"
VIDEO_URL = "https://celia-share.vercel.app/media/demo.mp4"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

DECKS = {
    "index.html": "Celia-ai-deck.pdf",
    "ai.html": "Celia-ai-deck-AI.pdf",
    "sport-health.html": "Celia-ai-deck-sport-health.pdf",
}

MAX_IMAGE_PX = 1400  # longest side; slides are 1920 x 1080, no image fills more than that
JPEG_QUALITY = 82

# PDF points on a 1440 x 810 page (the 1920 x 1080 px slide at 0.75 pt/px), origin bottom-left.
VIDEO_RECT = (90, 66.75, 1350, 606.75)  # the 1680 x 720 px video frame, "Click to play" button inside


def video_length() -> str:
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(VIDEO)],
        capture_output=True, text=True, check=True,
    ).stdout
    seconds = round(float(out))
    return f"{seconds // 60}:{seconds % 60:02d}"


def demo_page_index(html: Path) -> int:
    titles = re.findall(r'<section class="slide[^"]*" data-title="([^"]*)"', html.read_text())
    return titles.index("Demo")


def print_pdf(html: Path, out: Path) -> None:
    subprocess.run(
        [CHROME, "--headless=new", "--disable-gpu", "--no-pdf-header-footer",
         "--virtual-time-budget=8000", f"--print-to-pdf={out}", html.as_uri()],
        check=True, capture_output=True,
    )


def embed(src: Path, out: Path, page_index: int, length: str) -> None:
    writer = PdfWriter(clone_from=PdfReader(src))
    page = writer.pages[page_index]

    link = writer._add_object(DictionaryObject({
        NameObject("/Type"): NameObject("/Annot"),
        NameObject("/Subtype"): NameObject("/Link"),
        NameObject("/Rect"): ArrayObject([FloatObject(v) for v in VIDEO_RECT]),
        NameObject("/Border"): ArrayObject([NumberObject(0), NumberObject(0), NumberObject(0)]),
        NameObject("/F"): NumberObject(4),
        NameObject("/P"): page.indirect_reference,
        NameObject("/Contents"): TextStringObject(f"Play the Celia.ai demo video ({length})"),
        NameObject("/A"): DictionaryObject({
            NameObject("/Type"): NameObject("/Action"),
            NameObject("/S"): NameObject("/URI"),
            NameObject("/URI"): TextStringObject(VIDEO_URL),
        }),
    }))

    annots = page.get("/Annots")
    if annots is None:
        annots = ArrayObject()
        page[NameObject("/Annots")] = annots
    else:
        annots = annots.get_object()
    annots.append(link)

    compress_images(writer)
    for p in writer.pages:
        p.compress_content_streams()
    writer.compress_identical_objects(remove_duplicates=True, remove_unreferenced=True)
    with out.open("wb") as f:
        writer.write(f)


def image_objects(writer: PdfWriter) -> list:
    found = {}

    def walk(resources) -> None:
        resources = resources.get_object() if resources is not None else {}
        xobjects = resources.get("/XObject")
        if xobjects is None:
            return
        for ref in xobjects.get_object().values():
            obj = ref.get_object()
            if obj.get("/Subtype") == "/Image":
                found[ref.idnum] = obj
            elif obj.get("/Subtype") == "/Form":
                walk(obj.get("/Resources"))

    for p in writer.pages:
        walk(p.get("/Resources"))
    return list(found.values())


def scaled_size(w: int, h: int) -> tuple:
    k = min(1.0, MAX_IMAGE_PX / max(w, h))
    return max(1, round(w * k)), max(1, round(h * k))


def compress_images(writer: PdfWriter) -> None:
    """Downscale big 8-bit RGB images and store them as JPEG; their alpha masks stay Flate."""
    for obj in image_objects(writer):
        w, h = int(obj["/Width"]), int(obj["/Height"])
        if obj.get("/BitsPerComponent") != 8 or obj.get("/Filter") not in ("/FlateDecode", "/DCTDecode"):
            continue
        data = obj.get_data()
        if obj.get("/Filter") == "/DCTDecode":
            img = Image.open(io.BytesIO(data)).convert("RGB")
        elif len(data) == w * h * 3:
            img = Image.frombytes("RGB", (w, h), data)
        else:
            continue  # grayscale or unusual layout: leave as is
        size = scaled_size(w, h)
        if size == (w, h) and obj.get("/Filter") == "/DCTDecode":
            continue
        buf = io.BytesIO()
        img.resize(size, Image.LANCZOS).save(buf, "JPEG", quality=JPEG_QUALITY, optimize=True)
        obj._data = buf.getvalue()
        obj[NameObject("/Filter")] = NameObject("/DCTDecode")
        obj.pop("/DecodeParms", None)
        obj[NameObject("/ColorSpace")] = NameObject("/DeviceRGB")
        obj[NameObject("/Width")], obj[NameObject("/Height")] = NumberObject(size[0]), NumberObject(size[1])

        if "/SMask" in obj:
            mask = obj["/SMask"].get_object()
            mw, mh = int(mask["/Width"]), int(mask["/Height"])
            alpha = Image.frombytes("L", (mw, mh), mask.get_data()).resize(size, Image.LANCZOS)
            mask._data = zlib.compress(alpha.tobytes(), 9)
            mask[NameObject("/Filter")] = NameObject("/FlateDecode")
            mask.pop("/DecodeParms", None)
            mask[NameObject("/Width")], mask[NameObject("/Height")] = NumberObject(size[0]), NumberObject(size[1])


def main() -> None:
    length = video_length()
    targets = sys.argv[1:] or list(DECKS)
    with tempfile.TemporaryDirectory() as tmp:
        for name in targets:
            html = DECK / name
            pdf = DECK / DECKS[name]
            raw = Path(tmp) / f"{html.stem}.pdf"
            print_pdf(html, raw)
            embed(raw, pdf, demo_page_index(html), length)
            print(f"{pdf.name}: demo on page {demo_page_index(html) + 1}, video {length} -> {VIDEO_URL}")


if __name__ == "__main__":
    main()

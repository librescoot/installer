#!/usr/bin/env python3
"""Build the brake-lever sprite sheet from the supplied PNG animation ZIP.

Usage: python3 tool/prepare_brake_animation.py /path/to/animation.zip
Requires Pillow. The source is 25 fps; only the four movements are needed,
with the installer timer controlling the holds between them.
"""

import argparse
from io import BytesIO
from pathlib import Path
from zipfile import ZipFile

from PIL import Image

FRAME_SIZE = (790, 174)
COLUMNS = 4
FRAMES_PER_MOVEMENT = 12
# Both in, right out, right in, both out. Trim the lead-in before each motion.
MOVEMENT_STARTS = (135, 385, 410, 1135)


def build(archive: Path, output: Path) -> None:
    sheet = Image.new("RGB", (FRAME_SIZE[0] * COLUMNS, FRAME_SIZE[1] * 12))
    with ZipFile(archive) as source:
        frames = sorted(name for name in source.namelist() if name.endswith(".png"))
        if len(frames) < max(MOVEMENT_STARTS) + FRAMES_PER_MOVEMENT:
            raise ValueError("The archive does not contain the complete animation")
        for movement, start in enumerate(MOVEMENT_STARTS):
            for step in range(FRAMES_PER_MOVEMENT):
                image = Image.open(BytesIO(source.read(frames[start + step])))
                if image.size != (1590, 350):
                    raise ValueError(f"Unexpected source dimensions: {image.size}")
                image = image.convert("RGB").resize(FRAME_SIZE, Image.Resampling.LANCZOS)
                index = movement * FRAMES_PER_MOVEMENT + step
                sheet.paste(image, ((index % COLUMNS) * FRAME_SIZE[0],
                                   (index // COLUMNS) * FRAME_SIZE[1]))
    output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output, "WEBP", quality=85, method=6)
    print(f"{output}: {output.stat().st_size:,} bytes, {sheet.width}x{sheet.height}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("--output", type=Path, default=Path(__file__).resolve().parents[1]
                        / "assets/images/brake-levers.webp")
    args = parser.parse_args()
    build(args.archive, args.output)

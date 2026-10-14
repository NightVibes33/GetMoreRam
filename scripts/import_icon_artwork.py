#!/usr/bin/env python3
"""Import the ten original GetMoreRam icon designs into native Xcode assets.

Input: the user-supplied 1536x1024 two-row, five-column artwork.
Output: AppIcon plus nine appiconsets and ten SwiftUI preview imagesets.
No mock icons or unrelated screenshot/UI content are used.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
from PIL import Image, ImageFilter

ICONS = ("Default", "Blue", "Purple", "Green", "Mono",
         "Glass", "Orbit", "Gradient", "Carbon", "Board")
# Measured centers of the icons in the supplied, unmodified artwork.
CENTERS_X = (171, 470, 767, 1065, 1363)
CENTERS_Y = (276, 690)
SOURCE_SIZE = (1536, 1024)
CROP_SIZE = 278

def write_catalog(target: Path, filename: str, size: int | None = None) -> None:
    target.mkdir(parents=True, exist_ok=True)
    image_entry: dict[str, object] = {"idiom": "universal", "filename": filename}
    if size is not None:
        image_entry.update({"platform": "ios", "size": f"{size}x{size}"})
    payload = {"images": [image_entry], "info": {"author": "xcode", "version": 1}}
    (target / "Contents.json").write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")

def generate(source: Path, destination: Path) -> None:
    image = Image.open(source).convert("RGB")
    if image.size != SOURCE_SIZE:
        raise ValueError(f"Expected the original {SOURCE_SIZE} icon artwork; got {image.size}.")
    for index, name in enumerate(ICONS):
        x, y = CENTERS_X[index % 5], CENTERS_Y[index // 5]
        half = CROP_SIZE // 2
        cropped = image.crop((x - half, y - half, x + half, y + half))
        # Preserve the actual artwork. Lanczos interpolation only changes resolution.
        icon = cropped.resize((1024, 1024), Image.Resampling.LANCZOS)
        icon = icon.filter(ImageFilter.UnsharpMask(radius=1.3, percent=75, threshold=3))
        icon_dir = destination / ("AppIcon.appiconset" if name == "Default" else f"{name}.appiconset")
        write_catalog(icon_dir, f"{name}.png", 1024)
        icon.save(icon_dir / f"{name}.png", format="PNG", optimize=True)

        preview_dir = destination / f"IconPreview-{name}.imageset"
        write_catalog(preview_dir, f"{name}.png")
        cropped.resize((256, 256), Image.Resampling.LANCZOS).save(
            preview_dir / f"{name}.png", format="PNG", optimize=True
        )
        print(f"{name}: app icon 1024x1024 + Settings preview 256x256")

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("assets", type=Path)
    args = parser.parse_args()
    generate(args.source, args.assets)

if __name__ == "__main__":
    main()

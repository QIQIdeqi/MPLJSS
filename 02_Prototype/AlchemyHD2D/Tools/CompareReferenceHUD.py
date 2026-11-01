"""Read-only comparison of opaque HUD artwork at the 1672x940 reference size.

Excludes transparent pixels, changing text, fills, skill art and live map content.
Requires Pillow, already used by ExtractReferenceUI.py. Never edits images/assets.
"""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("screenshot", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    assets = Path(__file__).resolve().parents[1] / "ArtSource/UIReference20261031"
    manifest = json.loads((assets / "manifest.json").read_text(encoding="utf-8-sig"))
    native = Image.open(args.screenshot).convert("RGB")
    if list(native.size) != manifest["reference_size"]:
        parser.error("Use an unscaled 1672x940 native screenshot; scaled captures are not pixel-comparable.")
    names = {"Portrait", "PortraitBadge", "HPFrame", "DodgeFrame", "TimerLeft",
             "TimerRight", "Skull", "Coin", "MinimapFrame", "AddSkill", "XPFrame"}
    result = {
        "method": "Read-only opaque artwork comparison at manifest coordinates; no images edited.",
        "native_sha256": hashlib.sha256(args.screenshot.read_bytes()).hexdigest(),
        "native_size": list(native.size),
        "parts": [],
    }
    for part in manifest["parts"]:
        if part["name"] not in names:
            continue
        tile = Image.open(assets / (part["name"] + ".png")).convert("RGBA")
        x, y, right, bottom = part["source_box"]
        crop = native.crop((x, y, right, bottom))
        count = changed = total = 0
        pixels = tile.load()
        native_pixels = crop.load()
        for index in range(tile.width * tile.height):
            point = (index % tile.width, index // tile.width)
            expected, actual = pixels[point], native_pixels[point]
            if expected[3] != 255:
                continue
            delta = [abs(expected[i] - actual[i]) for i in range(3)]
            count += 1
            total += sum(delta)
            changed += max(delta) > 2
        result["parts"].append({
            "part": part["name"], "expected_xy": [x, y],
            "opaque_pixels": count, "changed_pixels_over_2": changed,
            "mean_abs_rgb": round(total / (count * 3), 6) if count else None,
        })
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()

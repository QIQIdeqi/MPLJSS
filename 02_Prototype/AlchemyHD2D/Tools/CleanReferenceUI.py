"""User-authorized pixel cleanup; preserve every pixel outside two explicit regions."""
import argparse
import json
import shutil
from pathlib import Path

from PIL import Image

HP_TOP = (16, 7, 280, 7)  # Inclusive; the right dark/gold cap starts after this.
MAP_SPOT = (1, 2, 4, 5)


def clean_part(name, image):
    if name not in ('HPFrame', 'MinimapDark'):
        return image
    image = image.convert('RGBA').copy()
    if name == 'HPFrame':
        assert image.size == (306, 32), image.size
        for x in range(HP_TOP[0], HP_TOP[2] + 1):
            image.putpixel((x, 7), (*image.getpixel((x, 7))[:3], 0))
    else:
        assert image.size == (21, 15), image.size
        # Sample untouched pixels on the same row; retain the original texture elsewhere.
        for y in range(MAP_SPOT[1], MAP_SPOT[3] + 1):
            left, right = image.getpixel((0, y)), image.getpixel((5, y))
            for x in range(1, 5):
                image.putpixel((x, y), tuple(round((left[c] * (5-x) + right[c] * x) / 5) for c in range(4)))
    return image


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true', help='Write cleaned PNGs; default only checks.')
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    art = project / 'ArtSource/UIReference20261031'
    out = project / 'Evidence/HUDAssetCleanup_20261101'
    records = []
    for name in ('HPFrame', 'MinimapDark'):
        path = art / (name + '.png')
        original = Image.open(path).convert('RGBA')
        clean = clean_part(name, original)
        assert clean_part(name, clean).tobytes() == clean.tobytes(), 'Cleanup must be idempotent'
        changes = [{'xy': [x, y], 'before': list(original.getpixel((x, y))), 'after': list(clean.getpixel((x, y)))}
                   for y in range(original.height) for x in range(original.width)
                   if original.getpixel((x, y)) != clean.getpixel((x, y))]
        records.append({'name': name, 'size': list(clean.size), 'changed_pixels': len(changes), 'changes': changes})
        if args.apply and changes:
            backup = out / 'original' / path.name
            backup.parent.mkdir(parents=True, exist_ok=True)
            if not backup.exists():
                shutil.copy2(path, backup)
            clean.save(path)
    if args.apply and any(r['changed_pixels'] for r in records):
        (out / 'pixel-changes.json').write_text(json.dumps(records, indent=2) + '\n', encoding='utf-8')
    print(json.dumps([{'name': r['name'], 'changed_pixels': r['changed_pixels']} for r in records]))
    if not args.apply and any(r['changed_pixels'] for r in records):
        raise SystemExit('Cleanup still needed; use --apply to write.')


if __name__ == '__main__':
    main()

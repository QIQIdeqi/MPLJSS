"""Verify preservation against the retained reference and actual rendered HP samples."""
import json
from pathlib import Path
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[1]
art = root / 'ArtSource/UIReference20261031'
reference = Image.open(art / 'ReferenceHUD.png').convert('RGBA')
hp_before = reference.crop((197, 27, 503, 59))
mask = Image.new('L', hp_before.size, 0)
draw = ImageDraw.Draw(mask)
draw.polygon([(1,15),(10,2),(289,2),(304,15),(290,29),(10,29)], fill=255)
draw.rectangle((16,8,286,23), fill=0)
hp_before.putalpha(mask)
hp = Image.open(art / 'HPFrame.png').convert('RGBA')
assert hp.size == hp_before.size == (306, 32)
changed = []
for y in range(hp.height):
    for x in range(hp.width):
        a, b = hp_before.getpixel((x,y)), hp.getpixel((x,y))
        if a != b:
            assert y == 7 and 16 <= x <= 280 and a[:3] == b[:3] and b[3] == 0
            changed.append([x,y])
assert len(changed) == 265, len(changed)
residue = json.loads((root / 'Docs/Verification/UIReferenceAudit_20261101/hp-residue.json').read_text(encoding='utf-8'))
assert len(residue['opaque_white_pixels_in_numeric_region']) == 10
assert all(hp.getpixel(tuple(p['asset_xy']))[3] == 0 for p in residue['opaque_white_pixels_in_numeric_region'])

map_before = reference.crop((1450,169,1471,184))
mini = Image.open(art / 'MinimapDark.png').convert('RGBA')
assert mini.size == map_before.size == (21,15)
map_changed = []
for y in range(mini.height):
    for x in range(mini.width):
        a, b = map_before.getpixel((x,y)), mini.getpixel((x,y))
        assert a[3] == b[3] == 255
        if a != b:
            assert 1 <= x <= 4 and 2 <= y <= 5
            map_changed.append([x,y])
assert len(map_changed) == 16
assert max(max(mini.getpixel((x,y))[:3]) for x in range(1,5) for y in range(2,6)) <= 75

samples = {}
folder = root / 'Evidence/HUDAssetCleanup_20261101/Reference60/1672x940'
for name in ('12-hp-full', '13-hp-half', '14-hp-empty'):
    image = Image.open(folder / (name + '.png')).convert('RGB')
    assert image.size == (1672,940)
    samples[name] = [list(image.getpixel((x,34))) for x in (240,365)]
def red(pixel):
    return pixel[0] > 120 and pixel[0] > pixel[1] * 1.7
assert [red(p) for p in samples['12-hp-full']] == [True,True], samples
assert [red(p) for p in samples['13-hp-half']] == [True,False], samples
assert [red(p) for p in samples['14-hp-empty']] == [False,False], samples
result = {'hp_changed_alpha_pixels': len(changed), 'hp_other_pixels_changed': 0,
          'original_numeric_residuals_transparent': 10, 'map_changed_pixels': len(map_changed),
          'map_other_pixels_changed': 0, 'map_patch_original_max_channel': 152,
          'map_patch_clean_max_channel': max(max(mini.getpixel((x,y))[:3]) for x in range(1,5) for y in range(2,6)),
          'native_HP_top_row_y34_samples_x240_x365': samples}
out = root / 'Docs/Verification/HUDAssetCleanup_20261101'
out.mkdir(parents=True, exist_ok=True)
(out / 'pixel-verification.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
print('REFERENCE_UI_CLEANUP_PIXEL_PASS', json.dumps(result))

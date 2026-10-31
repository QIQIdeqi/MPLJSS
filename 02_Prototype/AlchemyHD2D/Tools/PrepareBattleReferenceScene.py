"""Deterministic polygon alpha slices of the user's clean scene; no generation or repainting."""
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[1]
source = root / 'ArtSource' / 'ReferenceBattle60_20261031'
image_path = source / 'Scene.png'
assert image_path.is_file(), 'Archive the clean user scene as ArtSource/ReferenceBattle60_20261031/Scene.png first.'
image = Image.open(image_path).convert('RGBA')
assert image.size == (1672, 941), image.size
layers = [
    {'name': 'Backdrop', 'file': 'Scene.png', 'foot': None},
    {'name': 'Oak', 'file': 'Oak.png', 'foot': [267, 225], 'points': [
        [96,0],[399,0],[429,22],[445,45],[467,62],[468,97],[446,120],
        [408,139],[371,148],[345,155],[326,174],[338,194],[315,210],
        [282,223],[240,225],[203,216],[177,201],[158,181],[177,161],
        [144,145],[113,151],[87,139],[74,116],[52,91],[64,60],[83,32]]},
    {'name': 'Cart', 'file': 'Cart.png', 'foot': [1518, 388], 'points': [
        [1441,317],[1480,298],[1518,305],[1560,316],[1565,324],
        [1604,332],[1606,349],[1585,348],[1578,365],[1583,383],
        [1566,394],[1548,394],[1534,383],[1516,387],[1500,382],
        [1470,378],[1453,381],[1434,373],[1414,377],[1411,368],
        [1449,351],[1443,337]]},
    {'name': 'CartFenceLeft', 'file': 'CartFenceLeft.png', 'foot': [1360, 338], 'points': [
        [1287,286],[1303,285],[1306,313],[1342,318],[1344,306],
        [1353,307],[1356,322],[1386,327],[1386,316],[1393,316],
        [1399,330],[1431,336],[1434,347],[1291,334]]},
    {'name': 'CartFenceRight', 'file': 'CartFenceRight.png', 'foot': [1630, 364], 'points': [
        [1593,309],[1607,309],[1609,335],[1640,342],[1640,325],
        [1651,327],[1655,349],[1671,354],[1671,376],[1590,351]]},
    {'name': 'FrontFence', 'file': 'FrontFence.png', 'foot': [185, 807], 'points': [
        [0,704],[13,706],[15,732],[91,753],[91,739],[107,742],
        [110,760],[167,775],[167,758],[181,763],[183,780],[211,786],
        [211,774],[225,780],[226,791],[257,799],[257,779],[270,786],
        [274,825],[257,823],[255,813],[225,806],[224,819],[212,816],
        [211,802],[181,795],[180,809],[165,805],[165,791],[108,775],
        [107,790],[92,786],[91,771],[14,750],[13,764],[0,761]]},
    {'name': 'LeftLog', 'file': 'LeftLog.png', 'foot': [129, 585], 'points': [
        [69,561],[149,550],[163,546],[177,553],[182,578],[175,589],
        [157,588],[148,579],[91,591],[69,584]]},
]
for layer in layers:
    if 'points' not in layer:
        continue
    alpha = Image.new('L', image.size, 0)
    ImageDraw.Draw(alpha).polygon([tuple(p) for p in layer['points']], fill=255)
    # Multiply the original alpha, retaining only source pixels in the authored silhouette.
    output = image.copy()
    output.putalpha(alpha)
    output.save(source / layer['file'])
    bounds = alpha.getbbox()
    assert bounds and bounds != (0, 0, 1672, 941)
    layer['alpha_bbox'] = list(bounds)
manifest = {
    'source_size': [1672, 941],
    'source_sha256': hashlib.sha256(image_path.read_bytes()).hexdigest(),
    'method': 'Original pixels plus manually authored polygon alpha masks. No repainting, generated terrain, baked actors or HUD.',
    'layers': layers,
}
(source / 'layers.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
runtime = root / 'Content' / 'Reference'
runtime.mkdir(parents=True, exist_ok=True)
runtime.joinpath('BattleReferenceSpec.json').write_bytes(root.joinpath('Tools/BattleReferenceSpec.json').read_bytes())
runtime.joinpath('BattleReferenceLayers.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
print('BATTLE_REFERENCE_PREPARE_PASS layers=%d source=%s' % (len(layers), image_path))

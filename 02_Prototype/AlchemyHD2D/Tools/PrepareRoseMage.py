"""Normalize existing approved-direction art; no generated or repainted animation."""
from pathlib import Path
import hashlib
import json
from PIL import Image

root = Path(__file__).resolve().parents[1]
workspace = root.parents[1]
inputs = root / 'ArtSource/BattlePresentation_20261031/RoseMage/SourceInputs'
views = inputs / 'views'
attack = inputs / 'attack'
output = root / 'ArtSource/BattlePresentation_20261031/RoseMage'
output.mkdir(parents=True, exist_ok=True)
size, baseline, body_height = 512, 488, 320
records = []

def retain(source, image, filename):
    target = output / filename
    image.save(target)
    records.append({'file': filename, 'source': str(source.relative_to(workspace)),
                    'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
                    'sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
                    'size': list(image.size), 'alpha_bbox': image.getbbox()})

for view, relative in [('Front', 'front/front.png'), ('Back', 'back/back.png'), ('Side', 'side-right/side-right.png')]:
    source = views / relative
    image = Image.open(source).convert('RGBA')
    box = image.getbbox()
    cropped = image.crop(box)
    scale = body_height / (box[3] - box[1])
    cropped = cropped.resize((round(cropped.width * scale), body_height), Image.Resampling.NEAREST)
    normalized = Image.new('RGBA', (size, size))
    normalized.alpha_composite(cropped, ((size-cropped.width)//2, baseline-body_height))
    retain(source, normalized, f'T_RoseMage{view}.png')

# Keep one scale across the complete action, anchored to its original shared foot line.
# Frame zero body is y189..488: later raised staff and spell arcs must not rescale the body.
scale = body_height / 299
atlas = Image.new('RGBA', (size*8, size))
for index in range(8):
    source = attack / f'frames/attack/frame-{index}.png'
    image = Image.open(source).convert('RGBA')
    resized = image.resize((round(image.width*scale), round(image.height*scale)), Image.Resampling.NEAREST)
    frame = Image.new('RGBA', (size, size))
    frame.alpha_composite(resized, (round(size/2-256*scale), round(baseline-488*scale)))
    assert frame.getbbox() and all((frame.getbbox()[0]>0, frame.getbbox()[1]>0, frame.getbbox()[2]<size, frame.getbbox()[3]<size)), index
    atlas.alpha_composite(frame, (index*size, 0))
retain(attack/'sprite-sheet-alpha.png', atlas, 'T_RoseMageAttack.png')

# Portrait uses the existing front-view head and scarf, with no redraw or new identity.
source = views / 'front/front.png'
image = Image.open(source).convert('RGBA').crop((196, 20, 576, 410))
image.thumbnail((240,240), Image.Resampling.NEAREST)
portrait = Image.new('RGBA',(256,256))
portrait.alpha_composite(image, ((256-image.width)//2, (256-image.height)//2))
retain(source, portrait, 'T_RoseMagePortrait.png')
manifest = {'identity': 'Previously supplied white-haired rose mage, 2026-10-29 art chat',
            'user_source_thread': '01a187cc-439c-7992-a010-c854c9f28bfa',
            'original_user_image': 'codex-clipboard-74361215-0692-439c-8308-f4bfde794711.png',
            'normalization': {'cell': size, 'baseline_y': baseline, 'body_height_px': body_height,
                              'body_height_cm': 180, 'sheet_world_size_cm':288, 'foot_offset_cm':130.5,
                              'filter':'NEAREST', 'attack_fps':10,'attack_frames':8,'attack_loop':False},
            'limitations': ['Only existing front/back/right static views and front-three-quarter attack are authored.',
                           'Movement uses directional static art; hit tint and death fade are procedural, not hand-drawn animation.',
                           'Attack facing is not a full directional action set; left view mirrors accessories.',
                           'Art preparation alone does not validate engine rendering; see the project verification report.'],
            'files': records}
(output/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'result':'NORMALIZED','files':len(records),'output':str(output)},ensure_ascii=False))

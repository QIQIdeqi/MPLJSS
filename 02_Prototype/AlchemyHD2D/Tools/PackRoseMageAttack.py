"""Pack retained, component-extracted poses; no generated or interpolated motion.

Each half uses its neutral pose for ONE uniform scale. Original directional
idle pixels replace the endpoints, as selected by the producer.
"""
from pathlib import Path
import hashlib
import json
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[1]
art = root / 'ArtSource/RoseMageAttack_20261101'
runtime = art / 'Runtime'
anchors = root / 'ArtSource/BattlePresentation_20261031/RoseMage'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def foot_x(image):
    """Match sprite-gen's alpha-weighted bottom-20%-of-bbox foot anchor."""
    box = image.getchannel('A').getbbox()
    crop = image.crop(box)
    alpha = crop.getchannel('A')
    start = crop.height - max(2, round(crop.height * .2))
    total = weighted = 0
    for y in range(start, crop.height):
        for x in range(crop.width):
            value = alpha.getpixel((x, y))
            total += value
            weighted += value * (x + .5)
    return box[0] + weighted / total


def normalize(image, factor, target_x):
    box = image.getchannel('A').getbbox()
    crop = image.crop(box)
    scaled = crop.resize((round(crop.width * factor), round(crop.height * factor)),
                         Image.Resampling.NEAREST)
    # Placement changes the origin only, never a pose or its relative limb positions.
    destination = (round(target_x - foot_x(scaled)), 488 - scaled.height)
    assert destination[0] >= 0 and destination[1] >= 0
    assert destination[0] + scaled.width <= 512
    result = Image.new('RGBA', (512, 512))
    result.alpha_composite(scaled, destination)
    assert sum(value * count for value, count in enumerate(result.getchannel('A').histogram())) == sum(
        value * count for value, count in enumerate(scaled.getchannel('A').histogram()))
    return result


def main():
    runtime.mkdir(parents=True, exist_ok=True)
    report = {
        'result': 'STATIC_QA_PENDING', 'cell': [512, 512], 'atlas': [4096, 512],
        'fps': 10, 'loop': False, 'release_frame': 4, 'release_seconds': .4,
        'baseline': 488, 'foot_anchor_x': 'Per-direction original idle footAnchor', 'neutral_body_height': 320,
        'normalization': 'One uniform factor per half, calibrated from windup0/release3; nearest.',
        'source': 'Native image_gen supplied by producer; no generation CLI/API used.',
        'endpoints': 'Original approved direction PNG reused byte-for-byte as frame0/frame7 pixels.',
        'frame_accounting': {'new_intermediate_poses': 12, 'reused_neutral_frames': 4,
                             'existing_front_frames_unchanged': 8, 'total_runtime_frames': 24},
        'safety': 'Final alpha bbox >=24px horizontal/top padding; baseline leaves24px below. '
                  'All poses share the original directional idle foot anchor within0.6px.',
        'directions': {},
        'limitations': ['UE import, runtime playback and visual acceptance are pending producer review.',
                       'Original Front attack is retained; it was not redrawn in this batch.',
                       'Native intermediate poses are brighter than the original neutral sprites.'],
    }
    for direction in ('Side', 'Back'):
        idle_path = anchors / f'T_RoseMage{direction}.png'
        idle = Image.open(idle_path).convert('RGBA')
        target_x = foot_x(idle)
        run = art / direction / 'run'
        inspection = json.loads((run / 'sprite-inspect.report.json').read_text(encoding='utf-8'))
        extraction = json.loads((run / 'frames/frames-manifest.json').read_text(encoding='utf-8'))
        assert inspection['ok'] and extraction['ok'], direction
        assert {(row['state'], row['frames'], row['method']) for row in extraction['rows']} == {
            ('windup', 4, 'components'), ('release', 4, 'components')}
        inputs = json.loads((run / 'attack-inputs.json').read_text(encoding='utf-8'))
        for item in inputs['raw'].values():
            assert digest(root / item['path']) == item['sha256'], 'Retained raw changed'
        frames = {}
        scales = {}
        for state, neutral in (('windup', 0), ('release', 3)):
            sources = [run / 'curated' / f'{state}-frame-{i}.png' for i in range(4)]
            images = [Image.open(path).convert('RGBA') for path in sources]
            box = images[neutral].getchannel('A').getbbox()
            factor = 320 / (box[3] - box[1])
            scales[state] = {'factor': factor, 'neutral_frame': neutral,
                             'neutral_input_height': box[3] - box[1]}
            for index, (path, image) in enumerate(zip(sources, images)):
                frames[(state, index)] = (normalize(image, factor, target_x), path)
        order = [('windup', i) for i in range(4)] + [('release', i) for i in range(4)]
        if direction == 'Back':
            order = [('windup', 0), ('windup', 1), ('windup', 2), ('release', 0),
                     ('windup', 3), ('release', 1), ('release', 2), ('release', 3)]
        atlas = Image.new('RGBA', (4096, 512))
        contact = Image.new('RGB', (2048, 1024), (36, 44, 46))
        drawing = ImageDraw.Draw(contact)
        frame_dir = runtime / 'Frames' / direction
        frame_dir.mkdir(parents=True, exist_ok=True)
        records, gif = [], []
        for index, key in enumerate(order):
            image, source = frames[key]
            if index in (0, 7):
                source = idle_path
                image = idle.copy()
                assert image.tobytes() == idle.tobytes()
            box = image.getchannel('A').getbbox()
            assert image.size == (512, 512) and box[3] == 488, (direction, index, box)
            padding = min(box[0], box[1], 512 - box[2])
            assert padding >= 24, (direction, index, 'unsafe padding', padding)
            cyan = sum(1 for r, g, b, a in image.get_flattened_data()
                       if a > 10 and r < 80 and g > 160 and b > 160)
            assert cyan == 0, (direction, index, 'retained cyan', cyan)
            assert image.getchannel('A').getextrema() == (0, 255)
            foot_error = abs(foot_x(image) - target_x)
            assert foot_error <= .6, (direction, index, foot_x(image), target_x)
            image.save(frame_dir / f'frame-{index}.png')
            atlas.alpha_composite(image, (index * 512, 0))
            x, y = index % 4 * 512, index // 4 * 512
            contact.paste(image, (x, y), image)
            drawing.text((x + 12, y + 12), f'{direction} {index} {key[0]}{key[1]}' +
                         (' ORIGINAL IDLE' if index in (0, 7) else ''), fill='white')
            drawing.line((x + round(target_x) - 16, y + 488,
                          x + round(target_x) + 16, y + 488), fill=(80, 200, 120))
            bg = Image.new('RGBA', (512, 512), (36, 44, 46, 255))
            bg.alpha_composite(image)
            gif.append(bg.convert('RGB'))
            records.append({'frame': index, 'selection': list(key),
                            'original_idle_reuse': index in (0, 7),
                            'source': str(source.relative_to(root)), 'source_sha256': digest(source),
                            'alpha_bbox': list(box), 'foot_centroid_x': round(foot_x(image), 3),
                            'foot_anchor_error_px': round(foot_error, 3),
                            'padding': {'left': box[0], 'top': box[1],
                                        'right': 512 - box[2], 'bottom': 512 - box[3]},
                            'minimum_top_horizontal_padding': padding, 'cyan_pixels': cyan})
        path = runtime / f'T_RoseMage{direction}Attack.png'
        atlas.save(path)
        contact.save(runtime / f'{direction}_attack-contact.png')
        gif[0].save(runtime / f'{direction}_attack.gif', save_all=True,
                    append_images=gif[1:], duration=[100] * 7 + [700])
        report['directions'][direction] = {'texture': path.name, 'sha256': digest(path),
                                           'footAnchor': target_x,
                                           'scales': scales, 'frames': records,
                                           'component_extraction_pass': True, 'inspect_pass': True}
    report['result'] = 'STATIC_QA_PASS_RUNTIME_NOT_RUN'
    (runtime / 'verification.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'result': report['result'], 'textures': 2, 'new_intermediate_poses': 12}))


if __name__ == '__main__':
    main()

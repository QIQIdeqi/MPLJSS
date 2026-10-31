"""Extract retained native-imagegen attack strips with the installed sprite-gen pipeline.

No generation commands, provider settings, fixed-grid cutting, or UE operations.
"""
from pathlib import Path
import hashlib
import json
import os
import subprocess


root = Path(__file__).resolve().parents[1]
workspace = root.parents[1]
art = root / 'ArtSource/RoseMageAttack_20261101'
anchors = root / 'ArtSource/BattlePresentation_20261031/RoseMage'
tool = workspace / '01_Skill/installed/sprite-gen/.venv/Scripts/sprite-gen.exe'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    assert tool.is_file(), f'Missing installed sprite-gen: {tool}'
    environment = dict(os.environ, PYTHONUTF8='1', PYTHONIOENCODING='utf-8')
    for direction in ('Side', 'Back'):
        folder = art / direction
        run = folder / 'run'
        raw = {state: run / 'raw' / f'{state}.png' for state in ('windup', 'release')}
        for path in raw.values():
            assert path.is_file(), f'Missing retained native imagegen strip: {path}'
        hashes = {state: digest(path) for state, path in raw.items()}
        base = run / 'base-source.png'
        request = {
            'states': {
                'windup': {'frames': 4, 'fps': 10, 'loop': False,
                           'action': 'Retained native-imagegen windup poses; do not regenerate.'},
                'release': {'frames': 4, 'fps': 10, 'loop': False,
                            'action': 'Retained native-imagegen release and recovery poses; do not regenerate.'},
            },
            'fit': {'resample': 'nearest', 'align_y': 'bottom',
                    'align_x': 'foot-centroid', 'ground_frames': True,
                    'pixel_unfake': False},
            'style': 'Confirmed Lilita identity, existing directional anchor, original pixels retained.',
        }
        request_path = folder / 'request.json'
        request_path.write_text(json.dumps(request, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        commands = []
        if not (run / 'sprite-request.json').is_file():
            commands.append(['prepare', '--out-dir', str(run), '--character-id',
                             'rose-mage-attack-' + direction.lower(), '--base-image',
                             str(anchors / f'T_RoseMage{direction}.png'), '--force',
                             '--request', str(request_path), '--cell-size', '512',
                             '--safe-margin', '24', '--chroma-key', '#00FFFF',
                             '--fit-align-x', 'foot-centroid', '--fit-align-y', 'bottom',
                             '--fit-ground-frames', '--fit-resample', 'nearest', '--no-fit-pixel-unfake'])
        commands.extend([
            ['extract', '--run-dir', str(run), '--segmentation', 'components'],
            ['compose-atlas', '--run-dir', str(run)],
            ['preview', '--run-dir', str(run)],
            ['inspect', '--run-dir', str(run)],
            ['export-pngs', '--run-dir', str(run)],
        ])
        log_path = run / 'attack-pipeline.log'
        with log_path.open('w', encoding='utf-8') as log:
            for arguments in commands:
                result = subprocess.run([str(tool), *arguments], env=environment,
                                        capture_output=True, text=True, encoding='utf-8')
                log.write(json.dumps(arguments, ensure_ascii=False) + '\n')
                log.write(result.stdout + result.stderr + '\n')
                log.flush()
                if result.returncode:
                    raise RuntimeError(f'{direction} {arguments[0]} failed ({result.returncode}); see {log_path}')
        assert all(digest(raw[state]) == hashes[state] for state in raw), 'Pipeline changed retained raw input'
        (run / 'attack-inputs.json').write_text(json.dumps({
            'generation': 'Native image_gen supplied by producer; no generation CLI invoked.',
            'prompt_provenance': '../../PROVENANCE.md and ../../prompts/ (producer-owned)',
            'base': {'path': str(base.relative_to(root)), 'sha256': digest(base)},
            'raw': {state: {'path': str(path.relative_to(root)), 'sha256': hashes[state]}
                    for state, path in raw.items()},
            'processing': 'prepare -> components -> compose -> preview -> inspect -> curated PNG export',
        }, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        print(json.dumps({'direction': direction, 'result': 'EXPORTED', 'log': str(log_path)}, ensure_ascii=False))


if __name__ == '__main__':
    main()

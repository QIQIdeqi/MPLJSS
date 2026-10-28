"""Offline installation check. Run with sprite-gen's SSD-local venv Python."""
from pathlib import Path
import json
import os
import shutil
import subprocess
import sys
from PIL import Image, ImageDraw
import numpy

root = Path(__file__).resolve().parents[1]
installed = root / '01_Skill/installed/sprite-gen'
out = root / '03_Build/sprite-gen/_installation-check'
out.mkdir(parents=True, exist_ok=True)
os.environ['SPRITE_GEN_CONFIG_DIR'] = str(root / '01_Skill/config/sprite-gen')
os.environ['SPRITE_GEN_DATA_DIR'] = str(root / '01_Skill/data/sprite-gen')
os.environ['TEMP'] = os.environ['TMP'] = str(root / '01_Skill/tmp')
os.environ['PYTHONIOENCODING'] = 'utf-8'
os.environ['PYTHONDONTWRITEBYTECODE'] = '1'
codex_dir = Path.home() / '.codex/.sandbox-bin'
if (codex_dir / 'codex.exe').is_file():
    os.environ['PATH'] = str(codex_dir) + os.pathsep + os.environ.get('PATH', '')
cli = installed / '.venv/Scripts/sprite-gen.exe'

def run(*args):
    result = subprocess.run([str(cli), *map(str, args)], capture_output=True, text=True,
                            encoding='utf-8', errors='replace', timeout=45)
    assert result.returncode == 0, (args, result.stderr, result.stdout)
    return result.stdout

help_text = run('--help')
(root / 'logs/sprite-gen/cli-help.txt').write_text(help_text, encoding='utf-8')
image = Image.new('RGB', (128, 128), (255, 0, 255))
ImageDraw.Draw(image).rectangle((40, 24, 87, 103), fill=(30, 80, 220))
image.save(out / 'synthetic-input.png')
cutout_report = run('cutout', out / 'synthetic-input.png', '--out', out / 'synthetic-alpha.png',
                    '--key', 'magenta', '--white-check')
(out / 'cutout-report.json').write_text(cutout_report, encoding='utf-8')
with Image.open(out / 'synthetic-alpha.png') as result:
    assert result.mode == 'RGBA'
    assert result.getpixel((0, 0))[3] == 0
    assert result.getpixel((64, 64))[3] == 255
run('prepare', '--out-dir', out / 'prepared-run', '--character-id', 'install-check',
    '--base-image', out / 'synthetic-alpha.png')
workflow = subprocess.run([str(cli), 'workflow', '--kind', 'sprite'], capture_output=True,
                          text=True, encoding='utf-8', errors='replace', timeout=45)
assert workflow.returncode in (0, 2), workflow.stderr
workflow_data = json.loads(workflow.stdout)
(root / 'logs/sprite-gen/workflow-sprite.json').write_text(workflow.stdout, encoding='utf-8')
from sprite_gen.gen.codex_provider import codex_login
login = codex_login()
source_repo = root / '01_Skill/sources/sprite-gen'
commit = subprocess.check_output(['git', '-C', str(source_repo), 'rev-parse', 'HEAD'], text=True).strip()
import hashlib
hashes = {}
for name in ('SKILL.md', 'pyproject.toml'):
    original = subprocess.check_output(['git', '-C', str(source_repo), 'show', 'HEAD:' + name])
    actual = (installed / name).read_bytes()
    assert original == actual, name
    hashes[name] = hashlib.sha256(actual).hexdigest()
report = {'date': '2026-10-28', 'version': '3.5.0', 'commit': commit,
          'python': sys.version, 'interpreter': sys.executable, 'numpy': numpy.__version__,
          'pillow': Image.__version__, 'skill_entry_readable': (Path.home()/'.codex/skills/sprite-gen/SKILL.md').is_file(),
          'cli_help': 'passed', 'offline_cutout_alpha': 'passed', 'offline_prepare': 'passed',
          'workflow_status': workflow_data.get('status'), 'codex_login': {'source': login.source, 'reason': login.reason},
          'optional_binaries': {name: shutil.which(name) for name in ('ffmpeg','img2webp','node','rife-ncnn-vulkan')},
          'upstream_hashes': hashes, 'generation': 'not attempted'}
(root / '01_Skill/sprite-gen-install.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps(report, ensure_ascii=False, indent=2))

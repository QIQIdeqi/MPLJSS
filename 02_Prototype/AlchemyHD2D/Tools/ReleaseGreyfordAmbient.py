"""Archive the verified playable build without test screenshots or runtime saves."""
from pathlib import Path
import hashlib,json,zipfile

project=Path(__file__).resolve().parents[1];workspace=project.parents[1]
evidence=project/'Evidence/Greyford/Ambient'
assert json.loads((evidence/'verification.json').read_text(encoding='utf-8'))['status']=='PASS'
build=workspace/'03_Build/Greyford_Ambient_Win64_20261030'
archive=workspace/'03_Build/冒牌炼金术士_动态村庄_Win64_2026-10-30.zip'
files=[p for p in build.rglob('*') if p.is_file() and not any(x in ('Evidence','Saved','Intermediate') for x in p.relative_to(build).parts)]
assert (build/'启动完整试玩.cmd') in files
assert any(p.suffix=='.ucas' for p in files)
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    for p in files:z.write(p,p.relative_to(build).as_posix())
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    assert len(z.namelist())==len(files)
def sha(p):
    with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
report=dict(zip=str(archive),bytes=archive.stat().st_size,files=len(files),crc='PASS',sha256=sha(archive),
    original_reference_sha256=sha(project/'ArtSource/GreyfordReference20261030/VillageReference.png'),
    exe_sha256=sha(build/'Windows/AlchemyHD2D/Binaries/Win64/AlchemyHD2D.exe'))
(evidence/'release.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
archive.with_suffix('.zip.sha256').write_text(report['sha256']+'  '+archive.name+'\n',encoding='utf-8')
print(json.dumps(report,ensure_ascii=False))

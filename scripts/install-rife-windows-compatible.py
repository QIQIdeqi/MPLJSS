from pathlib import Path
import urllib.request, hashlib, json, shutil
from sprite_gen.video import rife, rife_install
root=Path.cwd(); cache=root/'01_Skill/cache/video-tools'; cache.mkdir(parents=True,exist_ok=True)
archive=cache/'rife-ncnn-vulkan-20221029-windows.zip'
url=rife_install.URL.format(release=rife.RELEASE,name=rife_install.zip_name('windows'))
if not archive.is_file():
    print('Downloading pinned RIFE archive to SSD cache',flush=True)
    with urllib.request.urlopen(url,timeout=60) as response, archive.open('wb') as out:
        shutil.copyfileobj(response,out,1024*1024)
assert rife_install._sha256(archive)==rife_install.ZIP_SHA256['windows'], 'archive hash mismatch'
target=rife.installed_binary(root/'01_Skill/data/sprite-gen/rife','windows').parent
assert not target.exists(), 'destination already exists; inspect first'
files=rife_install._unpack(archive,target,'windows')
p=target/rife.MODEL/'flownet.param'; raw=p.read_bytes(); normalized=raw.replace(b'\r\n',b'\n')
report={'archive_sha256':rife_install._sha256(archive),'original_param_sha256':hashlib.sha256(raw).hexdigest(),'normalized_param_sha256':hashlib.sha256(normalized).hexdigest()}
if hashlib.sha256(raw).hexdigest()!=rife.MODEL_SHA256['flownet.param']:
    assert hashlib.sha256(normalized).hexdigest()==rife.MODEL_SHA256['flownet.param'], 'not a CRLF-only difference; stopped'
    p.write_bytes(normalized)
    report['compatibility_fix']='canonical LF line endings in Windows flownet.param; original zip remains intact'
rife.model_bytes(target/rife.MODEL)
report['check']=rife_install.check(rife.installed_binary(root/'01_Skill/data/sprite-gen/rife','windows'), target/rife.MODEL)
report['path']=str(target)
(target/rife_install.MARKER).write_text(json.dumps({'release':rife.RELEASE,'zip':archive.name,'sha256':rife_install.ZIP_SHA256['windows']}),encoding='utf-8')
(root/'01_Skill/rife-windows-install.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report,indent=2),flush=True)

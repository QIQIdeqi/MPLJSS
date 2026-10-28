from pathlib import Path
import urllib.request, zipfile, hashlib, json
root=Path.cwd(); downloads=root/'01_Skill/cache/video-tools'; tools=root/'01_Skill/tools'; downloads.mkdir(parents=True,exist_ok=True)
items=[('ffmpeg','https://www.gyan.dev/ffmpeg/builds/packages/ffmpeg-9.0.2-essentials_build.zip','60f467265b1e312373dbcd92200c2618a74850f98d3d078e94296bb3fa2047ba'),('libwebp','https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-1.6.0-windows-x64.zip',None)]
results=[]
for name,url,expected in items:
    archive=downloads/(name+'.zip')
    if not archive.exists():
        print('Downloading '+name,flush=True)
        with urllib.request.urlopen(url,timeout=60) as response,archive.open('wb') as target:
            while block:=response.read(1024*1024): target.write(block)
    actual=hashlib.sha256(archive.read_bytes()).hexdigest()
    if expected and expected!=actual: raise SystemExit('SHA256 mismatch: '+name)
    target=tools/name; target.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(archive) as z:
        for entry in z.infolist():
            if entry.is_dir(): continue
            path=Path(entry.filename)
            if path.suffix.lower() in ('.exe','.dll') or path.name.lower().startswith(('copying','license','readme')):
                (target/path.name).write_bytes(z.read(entry))
    results.append({'name':name,'source':url,'sha256':actual,'path':str(target)})
    print(name+' installed: '+str(target),flush=True)
(root/'01_Skill/video-tools-install.json').write_text(json.dumps(results,indent=2),encoding='utf-8')

"""Create a standalone static deployment, preserving the published document snapshot.

Run with Python's standard library only. This does not publish or change the Sites copy.
"""
from pathlib import Path
from urllib.parse import urlparse, unquote
from html.parser import HTMLParser
import shutil, hashlib, json, zipfile

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parents[2]
SOURCE = PROJECT / '04_Web/alchemy-official/dist'
PUBLIC = HERE / 'public'
DEMO = PROJECT / '03_Build/HD2D_PC_UI/冒牌炼金术士_Demo_Win64_最新测试版.zip'
DOWNLOAD_PATH = '/downloads/alchemy-demo-win64-2026-10-29.zip'

def digest(path):
    h=hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda:stream.read(1024*1024),b''):
            h.update(block)
    return h.hexdigest()

assert SOURCE.is_dir() and DEMO.is_file(), 'Missing SSD site source or complete Demo ZIP'
PUBLIC.mkdir(parents=True,exist_ok=True)
shutil.copytree(SOURCE,PUBLIC,dirs_exist_ok=True)
(PUBLIC/'downloads').mkdir(exist_ok=True)
target_demo=PUBLIC/DOWNLOAD_PATH.lstrip('/')
if not target_demo.exists() or digest(target_demo)!=digest(DEMO):
    shutil.copy2(DEMO,target_demo)
home=(PUBLIC/'index.html').read_text(encoding='utf-8')
parser_home=home
import re
links=re.findall(r'href="(https://media\.githubusercontent\.com/[^\"]+)"',home)
assert len(links)==1, 'Expected one primary Demo download link'
home=home.replace(links[0],DOWNLOAD_PATH)
old='已发布测试包：2026.10.29 · ZIP / 约 337 MB<br>10.30 Greyford 新包仍在本地，本入口提供远端已发布版本。'
new='试玩版本：2026.10.29 · ZIP / 约 337 MB<br>完整试玩包由本站提供下载，解压后运行。'
assert old in home, 'Download version text changed; review it before migration'
home=home.replace(old,new)
(PUBLIC/'index.html').write_text(home,encoding='utf-8')
demo_hash=digest(DEMO)
(PUBLIC/'downloads/alchemy-demo-win64-2026-10-29.zip.sha256').write_text(demo_hash+'  '+target_demo.name+'\n',encoding='ascii')

class CheckLinks(HTMLParser):
    def handle_starttag(self,tag,attrs):
        for attr,value in attrs:
            if attr not in ('href','src','data-image') or not value:
                continue
            parsed=urlparse(value)
            if parsed.scheme or parsed.netloc or not parsed.path:
                continue
            target=PUBLIC/unquote(parsed.path).lstrip('/') if parsed.path.startswith('/') else self.page.parent/unquote(parsed.path)
            assert target.exists(), f'{self.page.name}: missing {value}'

pages=list(PUBLIC.rglob('*.html'))
assert len(pages)==13
for page in pages:
    parser=CheckLinks()
    parser.page=page
    parser.feed(page.read_text(encoding='utf-8'))
index=json.loads((PUBLIC/'search-index.json').read_text(encoding='utf-8'))
assert len(index)==12
for doc in index:
    assert (PUBLIC/doc['url'].lstrip('/')).is_file()
for original in SOURCE.rglob('*'):
    if original.is_file() and original.name!='index.html':
        assert digest(original)==digest(PUBLIC/original.relative_to(SOURCE)),f'Unexpected change: {original.name}'
assert digest(target_demo)==demo_hash
runtime_external=[]
for page in pages:
    text=page.read_text(encoding='utf-8')
    runtime_external.extend(re.findall(r'(?:src|data-image)="(https?://[^\"]+)"',text))
assert not runtime_external, 'Runtime resources must be hosted locally'
archive=HERE/'冒牌炼金术士_官网与策划_大陆托管完整包_2026-10-30.zip'
with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as bundle:
    for path in sorted(PUBLIC.rglob('*')):
        if path.is_file():
            mode=zipfile.ZIP_STORED if path.suffix=='.zip' else zipfile.ZIP_DEFLATED
            bundle.write(path,path.relative_to(PUBLIC).as_posix(),compress_type=mode)
with zipfile.ZipFile(archive) as bundle:
    assert 'index.html' in bundle.namelist()
    assert 'docs/scene.html' in bundle.namelist()
    assert 'downloads/'+target_demo.name in bundle.namelist()
    assert bundle.testzip() is None
report={
    'status':'prepared_not_deployed',
    'recommended_host':'Tencent CloudBase static hosting in a mainland China region with a custom domain',
    'html_pages':len(pages),'searchable_documents':len(index),
    'preserved_snapshot_files':sum(p.is_file() and p.name!='index.html' for p in SOURCE.rglob('*')),
    'demo':{'version':'2026-10-29','bytes':DEMO.stat().st_size,'sha256':demo_hash,'download_path':DOWNLOAD_PATH},
    'checks':{'local_links':'PASS','document_and_asset_preservation':'PASS','no_external_runtime_assets':'PASS','demo_integrity':'PASS','zip_integrity':'PASS'},
    'archive':archive.name,'archive_bytes':archive.stat().st_size,'archive_sha256':digest(archive),
    'remaining':['User creates and signs into a Tencent Cloud account','User completes identity verification and approves any paid plan','Create hosting environment and deploy public/','Register and file a custom domain for a mainland production endpoint','Configure HTTPS and test the real mainland phone networks'],
}
(HERE/'migration-verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
(HERE/(archive.name+'.sha256')).write_text(report['archive_sha256']+'  '+archive.name+'\n',encoding='utf-8')
print(json.dumps(report,ensure_ascii=False))

"""Check generated navigation, assets, search records and source snapshots."""
from pathlib import Path
from html.parser import HTMLParser
from urllib.parse import urlparse, unquote
import json

root=Path(__file__).resolve().parent/'dist'
class Links(HTMLParser):
    def handle_starttag(self,tag,attrs):
        for key,value in attrs:
            if key not in ('src','href') or not value:
                continue
            url=urlparse(value)
            if url.scheme or url.netloc or not url.path:
                continue
            target=(root/unquote(url.path).lstrip('/')) if url.path.startswith('/') else self.page.parent/unquote(url.path)
            assert target.exists(),f'{self.page.name}: missing {value}'

pages=list(root.rglob('*.html'))
for page in pages:
    parser=Links()
    parser.page=page
    text=page.read_text(encoding='utf-8')
    parser.feed(text)
    assert '<html lang="zh-CN">' in text
    assert '<title>' in text and 'id="main"' in text
index=json.loads((root/'search-index.json').read_text(encoding='utf-8'))
assert len(index)==12
assert len({doc['url'] for doc in index})==len(index)
for doc in index:
    target=root/doc['url'].lstrip('/')
    assert target.exists() and target.with_suffix('.md').exists()
    assert doc['text'].strip()
assert any('概率' in doc['text'] for doc in index)
assert len(pages)==13
print(f'PASS: {len(pages)} HTML pages, all local links/assets, {len(index)} searchable source snapshots')

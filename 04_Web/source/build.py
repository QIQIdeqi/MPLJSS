"""Rebuild the site from the project's Git-owned planning documents.

Build dependency: Markdown (installed in ../tooling/python on this SSD).
Run: python build.py
"""
from pathlib import Path
from urllib.parse import quote, unquote, urlparse
from datetime import datetime, timezone, timedelta
import sys, json, shutil, re, html

SITE = Path(__file__).resolve().parent
PROJECT = SITE.parents[1]
sys.path.insert(0, str(SITE.parent / 'tooling/python'))
import markdown

DIST = SITE / 'dist'
ASSETS = DIST / 'assets'
DOCS = DIST / 'docs'
SOURCE = PROJECT / '00_Doc/协作策划'
for folder in [DIST, ASSETS, DOCS]:
    folder.mkdir(parents=True, exist_ok=True)
STAMP = datetime.now(timezone(timedelta(hours=8))).strftime('%Y-%m-%d %H:%M')
GITHUB = 'https://github.com/QIQIdeqi/MPLJSS/blob/main/'
DOWNLOAD = 'https://media.githubusercontent.com/media/QIQIdeqi/MPLJSS/main/' + quote('03_Build/HD2D_PC_UI/冒牌炼金术士_Demo_Win64_最新测试版.zip')

def git_url(path):
    return GITHUB + quote(path.relative_to(PROJECT).as_posix())

def copy_asset(path, name=None):
    target = ASSETS / (name or path.name)
    shutil.copy2(path, target)
    return '/assets/' + quote(target.name)

images = {
    'hero': copy_asset(PROJECT / '00_Doc/场景设计/2026-10-30_Greyford/village-concept-wolai.jpg', 'village-concept.jpg'),
    'outskirts': copy_asset(PROJECT / '00_Doc/场景设计/2026-10-30_Greyford/outskirts-concept-wolai.jpg', 'outskirts-concept.jpg'),
    'combat': copy_asset(PROJECT / '00_Doc/场景设计/2026-10-30_Greyford/verification/editor-final-combat.jpg', 'combat-editor.jpg'),
    'alchemy': copy_asset(PROJECT / '02_Prototype/AlchemyHD2D/Evidence/ALCH002_Alchemy.png', 'alchemy-prototype.png'),
}
for material in ['FirePowder','Dew','MagicShard']:
    copy_asset(PROJECT / f'02_Prototype/AlchemyHD2D/ArtSource/{material}.png')
for attachment in (SOURCE / '附件').iterdir():
    if attachment.suffix.lower() in ['.jpg','.jpeg','.png','.webp']:
        copy_asset(attachment)

entries = [
    ('scene','1.2 场景','乡野美术、村庄与外围场景。',SOURCE / '1.2场景.md'),
    ('level','1.4 关卡','地图空间、成长节奏与 Boss 挑战。',SOURCE / '1.4关卡.md'),
    ('system','1.5 系统','材料、炼金、技能构筑与资源循环。',SOURCE / '1.5系统.md'),
    ('balance','1.6 数值','概率曲线、技能基线与起测参数。',SOURCE / '1.6数值.md'),
    ('village','格雷弗德边境村庄','村庄设定、布局与场景素材。',SOURCE / '场景_格雷弗德边境村庄.md'),
    ('outskirts','村庄外围（第一关）','草原场景、走位空间与素材清单。',SOURCE / '场景_村庄外围_第一关.md'),
    ('level-record','关卡持续确认记录','关卡设计的历次确认与待办。',PROJECT / '00_Doc/关卡策划_持续确认记录.md'),
    ('system-record','系统持续设计记录','系统设计的历次确认与待办。',PROJECT / '00_Doc/系统/1.5系统_持续设计记录.md'),
    ('balance-record','数值持续设计记录','数值设计的历次确认与待办。',PROJECT / '00_Doc/数值/1.6数值_持续设计记录.md'),
    ('boss','雾界草甸 · Boss 场地','Boss 场地方案与规格记录。',PROJECT / '00_Doc/场景设计/2026-10-30_Greyford/Boss_雾界草甸/README.md'),
    ('tools','UE 关卡与技能编辑器','原生编辑工具的操作说明。',PROJECT / '00_Doc/工具/UE关卡与技能编辑器使用说明.md'),
]
for path in sorted((SOURCE / '附件').glob('*.md')):
    entries.append(('boss-proposal','Boss 场地历史提案','历史提案，状态以最新正文为准。',path))
routes = {path.resolve():f'/docs/{slug}.html' for slug,title,desc,path in entries}

def header():
    return '''<a class="skip" href="#main">跳到正文</a><header class="wrap topbar"><a class="brand" href="/" aria-label="冒牌炼金术士首页"><span class="sigil" aria-hidden="true">✧</span><span>冒牌炼金术士<small>THE IMPOSTOR ALCHEMIST</small></span></a><nav class="nav" aria-label="主导航"><a href="/#play">游戏玩法</a><a href="/#world">游戏影像</a><a href="/#download">下载试玩</a><a class="nav-docs" href="/docs/scene.html">策划档案 ↗</a></nav></header>'''

def footer():
    return '<footer class="wrap"><span>✧ 冒牌炼金术士 · 一个仍在生长的炼金世界</span><span>开发中原型 · 2026 <a href="https://github.com/QIQIdeqi/MPLJSS">项目 GitHub ↗</a></span></footer>'

def page(title,description,body):
    return f'''<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>{html.escape(title)} · 冒牌炼金术士</title><meta name="description" content="{html.escape(description,quote=True)}"><meta name="theme-color" content="#203d30"><link rel="icon" href="/assets/FirePowder.png"><link rel="stylesheet" href="/style.css"><script src="/app.js" defer></script></head><body>{header()}{body}{footer()}</body></html>'''

homepage = f'''<main id="main">
<section class="hero"><img class="hero-img" src="{images['hero']}" alt="格雷弗德村庄概念图：炼金小屋、木桥、溪流与淡青雾界" fetchpriority="high"><div class="wrap hero-content"><div class="eyebrow">一场关于材料、选择与生存的实验</div><h1>配方尚未写好。<br>你的<em>冒险</em>也是。</h1><p>走进格雷弗德的乡野，收集战斗中掉落的材料，<br>把一次大胆的炼金，变成下一次突围的可能。</p><div class="actions"><a class="btn primary" href="#download">下载 Windows 试玩 <span>↓</span></a><a class="btn" href="#play">翻开冒险手记 <span>↘</span></a></div></div><div class="hero-note">格雷弗德 · 场景概念图 <span>氛围参考，非实机画面</span></div></section>
<div class="wrap ribbon"><span><b>PC 单人</b> Windows 试玩</span><span><b>HD2.5D</b> 斜俯视世界</span><span><b>材料组合</b> 探索不同技能</span><span><b>开发中</b> 可玩原型</span></div>
<section class="section wrap" id="play"><div class="section-head"><div><span class="kicker">01 / THE ALCHEMY LOOP</span><h2>每一份材料，都有新的可能。</h2></div><p>材料组合探索为主，成长与生存挑战相伴。<br>你需要决定：现在炼金，还是再攒一点？</p></div><div class="loop"><article><span class="num">Ⅰ · 收集</span><h3>在敌群之间，找回退路。</h3><p>移动、闪避与自动战斗，在危险中拾取材料。火粉、露水、魔法碎片，是下一次尝试的起点。</p><div class="materials"><img src="/assets/FirePowder.png" alt="火粉素材图标" loading="lazy"><img src="/assets/Dew.png" alt="露水素材图标" loading="lazy"><img src="/assets/MagicShard.png" alt="魔法碎片素材图标" loading="lazy"></div></article><article><span class="num">Ⅱ · 炼金</span><h3>让未知，落进炼金炉。</h3><p>三类普通材料、七组组合。选择材料种类与投入数量，探索不同的技能结果；普通炼金支持 3–10 份材料投入。</p><p>原型已接入 21 个普通技能与 3 个精英专属技能。</p></article><article><span class="num">Ⅲ · 构筑</span><h3>把偶然，炼成自己的打法。</h3><p>安排装备与储备技能，尝试自动连锁，在继续成长与迎接挑战之间作出选择。</p><p>体验仍在迭代，欢迎带着你的发现回来。</p></article></div></section>
<section class="section gallery-section" id="world"><div class="wrap"><div class="section-head"><div><span class="kicker">02 / FIELD NOTES</span><h2>从安静村庄，到未知草野。</h2></div><p>一瞥这个正在搭建的世界。<br>点击影像可放大，概念设计与工程画面分别标注。</p></div><div class="gallery"><button class="shot featured" data-image="{images['outskirts']}" data-caption="村庄外围 · 场景概念设计，非游戏实机画面。"><figure><img src="{images['outskirts']}" alt="村庄外围草原与溪流的场景概念设计" loading="lazy"><span class="tag">场景概念设计</span></figure><small>GREYFORD / THE OUTSKIRTS</small><h3>雾界之外，冒险开始。</h3></button><div class="gallery-side"><button class="shot" data-image="{images['combat']}" data-caption="村庄外围 · UE 编辑器内运行截图（2026-10-30），开发中原型。"><figure><img src="{images['combat']}" alt="UE 编辑器中运行的草原战斗原型" loading="lazy"><span class="tag">工程运行截图 · 10.30</span></figure><small>IN DEVELOPMENT</small><h3>草原战斗 · 原型一瞥</h3></button><button class="shot" data-image="{images['alchemy']}" data-caption="炼金界面 · ALCH-002 原型历史实机截图，非最终界面。"><figure><img src="{images['alchemy']}" alt="ALCH-002 炼金界面历史原型截图" loading="lazy"><span class="tag">原型历史实机截图</span></figure><small>AT THE ALCHEMY TABLE</small><h3>下一次组合，由你决定。</h3></button></div></div></div></section>
<section class="section wrap" id="planning"><div class="archive"><div><span class="kicker">03 / THE DESIGN ARCHIVE</span><h2>不止冒险。<br>也记录它如何诞生。</h2><p>场景、关卡、系统与数值，组成这个世界的另一面。打开策划档案，查阅当前设计、已确认规则与尚待验证的实验。</p><a class="btn" href="/docs/scene.html">进入策划资料区 <span>↗</span></a><p style="font-size:11px">网站提供阅读快照；正文与设计修改继续在 Git 仓库维护。</p></div><div class="doc-grid">'''
for slug,title,desc,path in entries[:4]:
    code,label=title.split(' ',1)
    homepage+=f'<a class="doc-card" href="/docs/{slug}.html"><span class="code">{code} / DESIGN</span><span class="arrow">↗</span><h3>{label}</h3><p>{desc}</p></a>'
homepage+=f'''</div></div></section><section class="section download" id="download"><div class="wrap inner"><div><span class="kicker">04 / BEGIN YOUR EXPERIMENT</span><h2>带上好奇心。<br>第一炉，现在开始。</h2><p>Windows 64 位开发中试玩版。<br>无需安装 Unreal Engine，完整解压后即可启动。</p><div class="actions"><a class="btn primary" href="{DOWNLOAD}">下载 Windows Demo <span>↓</span></a></div><p class="fine">已发布测试包：2026.10.29 · ZIP / 约 337 MB<br>10.30 Greyford 新包仍在本地，本入口提供远端已发布版本。</p><a style="font-size:12px;text-decoration:underline" href="{GITHUB+quote('03_Build/HD2D_PC_UI/冒牌炼金术士_Demo_Win64_最新测试版.zip')}">通过 GitHub 文件页下载 ↗</a></div><div><div class="version">试玩准备 / BEFORE YOU START</div><ol><li>下载完整 ZIP，并将全部文件解压到同一目录。</li><li>双击「启动Demo.cmd」，保留旁边的 Windows 文件夹。</li><li>首次进入后跟随炼金引导，尝试你的第一组材料。</li></ol><div class="keys"><span><kbd>WASD</kbd>移动</span><span><kbd>Space</kbd>闪避</span><span><kbd>Tab</kbd>炼金</span><span><kbd>F7</kbd>字体调试</span></div><p class="fine">当前为可玩原型，美术、体验与战斗平衡持续迭代。<br>试玩反馈请附分辨率、截图与触发步骤。</p><a style="font-size:12px;text-decoration:underline" href="https://github.com/QIQIdeqi/MPLJSS/issues">提交试玩反馈 ↗</a></div></div></section></main><dialog id="gallery-dialog" aria-label="影像大图"><img alt=""><p></p><button class="close" type="button" aria-label="关闭影像大图">关闭 ×</button></dialog>'''
(DIST/'index.html').write_text(page('官网与策划档案','收集材料、探索炼金组合、构筑技能。查看游戏影像、下载 Windows Demo，查阅项目策划档案。',homepage),encoding='utf-8')

def rewrite_rendered(content, source):
    def replace(match):
        attr, original = match.group(1), html.unescape(match.group(2))
        parsed=urlparse(original)
        if parsed.scheme or original.startswith(('#','//')):
            return match.group(0)
        target=(source.parent / unquote(parsed.path)).resolve()
        if target in routes:
            result=routes[target]
        elif target.is_file() and target.suffix.lower() in ['.jpg','.jpeg','.png','.webp']:
            result=copy_asset(target)
        elif target.is_relative_to(PROJECT):
            result=git_url(target)
        else:
            return match.group(0)
        if parsed.fragment:
            result+='#'+parsed.fragment
        return f'{attr}="{html.escape(result,quote=True)}"'
    return re.sub(r'(href|src)="([^"]+)"',replace,content)

index=[]
for slug,title,desc,source in entries:
    text=source.read_text(encoding='utf-8-sig')
    rendered=markdown.markdown(text,extensions=['tables','fenced_code','toc','sane_lists'])
    rendered=rewrite_rendered(rendered,source)
    plain=re.sub('<[^>]+>',' ',rendered)
    plain=re.sub(r'\s+',' ',html.unescape(plain)).strip()
    index.append({'title':title,'text':plain,'url':f'/docs/{slug}.html'})
    nav=''
    for n,(other,label,description,path) in enumerate(entries):
        if n in [0,4,6]:
            nav+=f'<span class="group">{ {0:"核心策划 / DESIGN",4:"场景正文 / WORLD",6:"记录与工具 / RECORDS"}[n]}</span>'
        active=' class="active" aria-current="page"' if slug==other else ''
        nav+=f'<a{active} href="/docs/{other}.html">{label}</a>'
    body=f'''<main id="main" class="wrap"><div class="docs-banner"><span class="kicker">THE DESIGN ARCHIVE / 策划资料区</span><h1>让每一次决定，都有迹可循。</h1><p>阅读快照：{STAMP}（北京时间） · 原文中的已确认、历史提案与待验证状态均保留。</p></div><div class="docs-layout"><aside class="docs-sidebar"><label class="search-label" for="doc-search">检索全部策划与记录</label><input id="doc-search" class="search" type="search" placeholder="搜索 Boss、概率、场景…" autocomplete="off"><nav class="doc-nav" aria-label="策划分类">{nav}</nav><p class="source-note">正文维护于 Git。此处为发布时的阅读快照，不自动写回仓库。<br>角色、怪物与原文案继续在 wolai 维护。文档记录的实现状态以各次核验时点为准。</p></aside><section class="doc-content"><div id="search-results" class="results" aria-live="polite" hidden></div><div class="doc-top"><span>{title} · 阅读快照</span><a href="{git_url(source)}">在 GitHub 查看 / 编辑正文 ↗</a></div><article class="prose">{rendered}</article><div class="doc-top" style="margin-top:35px;margin-bottom:0;border-top:1px solid var(--line);border-bottom:0;padding-top:20px"><span>更新原文后，重新生成并发布网站以刷新快照。</span><a href="/docs/{slug}.md" download>下载 Markdown ↓</a></div></section></div></main>'''
    (DOCS/f'{slug}.html').write_text(page(title,desc,body),encoding='utf-8')
    shutil.copy2(source,DOCS/f'{slug}.md')
(DIST/'search-index.json').write_text(json.dumps(index,ensure_ascii=False),encoding='utf-8')
print(json.dumps({'pages':len(entries)+1,'assets':len(list(ASSETS.iterdir())),'snapshot':STAMP,'download':DOWNLOAD},ensure_ascii=False))

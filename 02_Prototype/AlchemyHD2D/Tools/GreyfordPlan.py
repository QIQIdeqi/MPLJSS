"""Single source of truth for the two editable Greyford blockout maps (cm)."""
import json
import hashlib
from pathlib import Path
from collections import deque
from PIL import Image, ImageDraw, ImageFont

PROJECT = Path(__file__).resolve().parents[1]
OUT = PROJECT.parents[1] / '00_Doc/场景设计/2026-10-30_Greyford'
ART = PROJECT / 'ArtSource/Greyford20261030'
CELL = 600
COLS, ROWS = 24, 18


def make_plan():
    def rect(name, x, y, w, h, kind, **kw):
        return dict(name=name, rect=[x, y, w, h], kind=kind, **kw)

    village = dict(id='Village', title='格雷弗德村庄 / 局外', spawn=[11.5, 10.5],
        spawn_candidates=[[11.5, 10.5]],
        routes=[[[7.5, 6.7], [7.5, 9.5], [13.5, 9.5], [22, 9.5]]],
        objects=[
            rect('格蕾丝小屋', 4, 3, 4, 3, 'building', asset='Cottage'),
            rect('药圃（装饰）', 1, 3, 2, 3, 'garden'),
            rect('粮仓', 15, 3, 4, 3, 'building', asset='Warehouse'),
            rect('作坊', 20, 5, 2, 3, 'building', asset='House'),
            rect('水井', 11, 7, 1, 1, 'block', asset='Well'),
            rect('公共广场', 9, 7, 6, 5, 'plaza'),
            rect('主路', 5, 9, 19, 2, 'road'),
            rect('小屋支路', 7, 6, 2, 4, 'road'),
            rect('农田支路', 7, 10, 2, 6, 'road'),
            rect('溪流', 0, 14, 7, 1, 'water'),
            rect('溪流东段', 8, 14, 2, 1, 'water'),
            rect('木桥', 7, 14, 1, 1, 'bridge', asset='Bridge'),
            rect('农田', 2, 11, 4, 2, 'garden'),
            rect('雾口', 22, 9, 2, 2, 'gate'),
            rect('北阵石', 22, 8, .5, .5, 'block', asset='RuneStone'),
            rect('南阵石', 22, 11.5, .5, .5, 'block', asset='RuneStone'),
            rect('小屋旁橡树', 9, 3.5, .6, .6, 'tree', asset='Oak'),
            rect('广场南侧橡树', 16, 12.5, .6, .6, 'tree', asset='Oak'),
            rect('药圃旁灌木', 3, 7, 1, .7, 'decor', asset='Bush'),
            rect('广场东侧灌木', 16, 7.5, 1, .7, 'decor', asset='Bush'),
            rect('小屋晾药架', 4.4, 6.3, 1.2, .7, 'decor', asset='HerbRack'),
            rect('粮仓箱袋', 18, 6.3, 1.2, .8, 'decor', asset='Crates'),
        ])
    for row in (0, 16):
        for col in range(1, 23, 3):
            village['objects'].append(rect('住宅_%d_%d' % (col, row), col, row, 2, 2, 'building', asset='House'))
    for col, row in [(0, 6), (0, 9), (0, 12), (22, 3), (22, 12)]:
        village['objects'].append(rect('住宅_%d_%d' % (col, row), col, row, 2, 2, 'building', asset='House'))

    field = dict(id='Outskirts', title='村庄外围 / 第一环', spawn=[12, 9], player_radius_cm=45,
        spawn_candidates=[[12, 9], [5, 8], [18, 7], [9, 13], [18, 13]],
        routes=[[[5, 8], [9, 5], [16, 5], [17, 8], [17, 10.5], [20.8, 10.5], [16, 14], [9, 13], [5, 8]],
                [[9, 13], [12, 9], [18, 7]]],
        objects=[
            rect('中央开阔草甸', 7, 5, 10, 8, 'meadow'),
            rect('老橡树树干', 3, 3, 1, 1, 'tree', asset='Oak'),
            rect('西北短障碍', 4, 5.5, 2.5, .5, 'block', asset='Fence'),
            rect('西侧短障碍', 3, 9.5, .5, 2, 'block', asset='Fence'),
            rect('东侧断篱', 18, 9.5, 2.5, .5, 'block', asset='Fence'),
            rect('东侧田车', 20, 7, 1.5, 1, 'block', asset='Cart'),
            rect('北侧树干', 17, 2, .7, .7, 'tree', asset='Oak'),
            rect('东侧树干', 22, 12, .7, .7, 'tree', asset='Oak'),
            rect('西南短障碍', 5, 14.5, 2, .5, 'block', asset='Fence'),
            rect('西北灌木', 2, 5, 1.2, 1, 'decor', asset='Bush'),
            rect('东边灌木', 21, 10.5, 1.2, 1, 'decor', asset='Bush'),
            rect('田车旁散箱', 22, 6.5, .8, .7, 'decor', asset='Crates'),
            rect('北阵标', 11, 1.5, .5, .5, 'block', asset='RuneStone'),
            rect('南侧溪水', 13, 16, 11, 2, 'water'),
            rect('东南溪水', 22, 14, 2, 2, 'water'),
        ])
    return dict(version=1, cell_cm=CELL, columns=COLS, rows=ROWS,
        movement_speed_cm_s=500, player_radius_cm=35, axis='design east/right and south/down; world=(-design_x,-design_y,z)',
        constraints=['独立编辑器灰盒；不替换Research，不改变正式存档/战斗规则。',
                     '草原复用正式战斗模拟并使用临时进度；出生点仍为候选标记。',
                     '草药仅装饰；材料来自战斗；独立Boss场地不属于本次两图。'], maps=[village, field])


BLOCKING = {'building', 'block', 'tree', 'water'}


def blocked_rectangles(scene):
    return [o['rect'] for o in scene['objects'] if o['kind'] in BLOCKING]


def validate(scene):
    # The same footprints used by the editor builder, inflated by the player's radius.
    step, radius = .25, scene.get('player_radius_cm',35) / CELL
    nx, ny = int(COLS / step), int(ROWS / step)
    rects = blocked_rectangles(scene)
    def free(i, j):
        x, y = (i + .5) * step, (j + .5) * step
        return (radius < x < COLS-radius and radius < y < ROWS-radius and
            not any(a-radius <= x <= a+w+radius and b-radius <= y <= b+h+radius for a,b,w,h in rects))
    legal = {(i,j) for i in range(nx) for j in range(ny) if free(i,j)}
    def node(p): return int(p[0]/step), int(p[1]/step)
    start = node(scene['spawn'])
    assert start in legal, (scene['id'], 'blocked start')
    seen, queue = {start}, deque([start])
    while queue:
        x,y = queue.popleft()
        for nxt in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
            if nxt in legal and nxt not in seen:
                seen.add(nxt); queue.append(nxt)
    for p in scene['spawn_candidates']:
        n = node(p)
        assert n in seen, (scene['id'], 'unreachable spawn', p)
        x,y=n
        assert sum((x+dx,y+dy) in legal for dx,dy in ((1,0),(-1,0),(0,1),(0,-1))) >= 2
    for route in scene['routes']:
        for a,b in zip(route,route[1:]):
            count=max(1,int(max(abs(b[0]-a[0]),abs(b[1]-a[1]))/.05))
            for i in range(count+1):
                x=a[0]+(b[0]-a[0])*i/count;y=a[1]+(b[1]-a[1])*i/count
                assert not any(rx-radius<=x<=rx+w+radius and ry-radius<=y<=ry+h+radius for rx,ry,w,h in rects), ('route intersects obstacle',scene['id'],x,y)
    if scene['id'] == 'Village':
        for target in ([7.5,6.7], [13.5,9.5], [22,9.5], [7.5,15.5]):
            assert node(target) in seen, ('village route unreachable', target)
    return dict(id=scene['id'], connected_spawn_candidates=len(scene['spawn_candidates']),
        reachable_cells=len(seen), free_cells=len(legal), grid_step_cm=step*CELL,
        footprint_player_radius_cm=scene.get('player_radius_cm',35), free_area_fraction=round(len(legal)/(nx*ny),3),
        note='2D occupancy connectivity only; engine collision/rendering tested separately')


def render(scene, path):
    scale, left, top = 48, 80, 105
    image = Image.new('RGB', (1312, 1100), '#18232a')
    d = ImageDraw.Draw(image)
    font_path = 'C:/Windows/Fonts/msyh.ttc'
    f = ImageFont.truetype(font_path, 18)
    small = ImageFont.truetype(font_path, 13)
    title = ImageFont.truetype(font_path, 30)
    d.text((left,20), scene['title']+' · 俯视布局 V3', font=title, fill='#f6e6bd')
    d.text((left,65), '24 × 18 格 / 每格 6m / 总地表 144 × 108m    N ↑    起测方案，非平衡验收', font=f, fill='#aabec5')
    d.rectangle((left,top,left+COLS*scale,top+ROWS*scale),fill='#536e50')
    colors=dict(building='#9d8e7d', block='#978f7c', tree='#2d493d',water='#437e97',garden='#88935f',
        road='#c6ad7e',plaza='#bab09b',bridge='#a87e51',gate='#73c4bd',meadow='#68865a',decor='#628453')
    order=['meadow','plaza','road','garden','water','bridge','building','tree','block','decor','gate']
    for kind in order:
        for obj in scene['objects']:
            if obj['kind'] != kind: continue
            x,y,w,h=obj['rect']; box=(left+x*scale,top+y*scale,left+(x+w)*scale,top+(y+h)*scale)
            d.rectangle(box,fill=colors[kind],outline='#21322c',width=2)
            if not obj['name'].startswith('住宅'):
                label=obj['name']
                if w < 2 or h < 1:
                    d.text((box[0]+4,box[1]-18),label,font=small,fill='#f4f0d6',stroke_width=1,stroke_fill='#28382d')
                else:d.text((box[0]+4,box[1]+4),label,font=small,fill='#18251f')
    for i in range(COLS+1):
        d.line((left+i*scale,top,left+i*scale,top+ROWS*scale),fill='#486248',width=1)
    for j in range(ROWS+1):
        d.line((left,top+j*scale,left+COLS*scale,top+j*scale),fill='#486248',width=1)
    for line in scene['routes']:
        points=[(left+x*scale,top+y*scale) for x,y in line]
        d.line(points,fill='#f4d274',width=4)
        for a,b in zip(points,points[1:]):
            mx,my=(a[0]+b[0])/2,(a[1]+b[1])/2
            d.ellipse((mx-4,my-4,mx+4,my+4),fill='#fff0a0')
    for i,(x,y) in enumerate(scene['spawn_candidates']):
        px,py=left+x*scale,top+y*scale
        d.ellipse((px-10,py-10,px+10,py+10),outline='#85e5ee',width=3)
        d.text((px+12,py-10),'S'+str(i+1),font=f,fill='#bbf5fb')
    for i in range(COLS):d.text((left+i*scale+12,top+ROWS*scale+8),str(i+1),font=small,fill='#aabec5')
    d.text((left,1010),'黄线：建议动线    青圈：出生候选    灰色：阻挡占位    蓝色：溪水不可通行',font=f,fill='#d6dfd5')
    d.text((left,1042),'地块/对象/碰撞在 UE 关卡编辑器中独立可选、可改；装饰不代表新增采集功能。',font=f,fill='#aabec5')
    image.save(path)


def inventory():
    families = [
        ('P0', ['Grass','Dirt','Stone','Water'], ['草地','泥路','石路','溪水'], 'ground', 'opaque', 600),
        ('P1', ['Cottage','House','Warehouse','Oak','Bush','RuneStone'], ['炼金小屋','住宅','粮仓','橡树','灌木','阵石'], 'sprite', 'alpha', 900),
        ('P2', ['Well','Cart','Fence','Bridge','HerbRack','Crates'], ['水井','田车','短篱笆','木桥','晾药架','箱袋'], 'sprite', 'alpha', 500)]
    items=[]
    for priority,names,labels,kind,alpha,size in families:
        for name,label in zip(names,labels):
            item=dict(id=name,label=label,priority=priority,kind=kind,alpha=alpha,source=name+'.png',
                size_px=[512,512],initial_world_size_cm=size,filter='nearest',mips=False,
                pivot='ground-center' if kind=='ground' else 'bottom-center at y=488/512',
                collision='separate authored footprint; no texture-derived collision',
                generation='native ChatGPT imagegen -> sprite-gen 3.5.0',
                status='generated-awaiting-engine-review')
            path=ART/(name+'.png')
            if path.exists():
                with Image.open(path) as im:
                    assert im.size==(512,512),(name,im.size)
                    extrema=im.getchannel('A').getextrema()
                    assert extrema[0]==0 if alpha=='alpha' else extrema[0]==255,(name,extrema)
                    item['qa']={'size':list(im.size),'alpha_extrema':list(extrema),'bbox':im.getbbox()}
                item['sha256']=hashlib.sha256(path.read_bytes()).hexdigest()
                item['texture_path']='/Game/Greyford/Textures/T_GF_'+name
                item['material_path']='/Game/Greyford/Materials/M_GF_'+name
                if (PROJECT/('Content/Greyford/Textures/T_GF_'+name+'.uasset')).exists():item['status']='imported-draft-final-art-review-pending'
                replacement=PROJECT/('Evidence/Greyford/'+priority+'/replacement-report.json')
                if priority in ('P1','P2') and replacement.exists():
                    reports=json.loads(replacement.read_text(encoding='utf-8'))
                    item['scene_instances']={r['map']:sum(e['asset']==name for e in r['entries']) for r in reports}
                    if any(item['scene_instances'].values()):item['status']='placed-draft-final-art-review-pending'
                if kind=='ground':item['tile_report_status']=json.loads((ART/(name+'.report.json')).read_text())['status']
            items.append(item)
    return dict(version=1,items=items,scope='16 assets generated in P0 -> P1 -> P2 order; greybox footprints stay independent')


if __name__ == '__main__':
    OUT.mkdir(parents=True,exist_ok=True)
    plan=make_plan()
    reports=[validate(s) for s in plan['maps']]
    (OUT/'layout.json').write_text(json.dumps(plan,ensure_ascii=False,indent=2),encoding='utf-8')
    (OUT/'layout-validation.json').write_text(json.dumps(reports,ensure_ascii=False,indent=2),encoding='utf-8')
    (ART/'asset-manifest.json').write_text(json.dumps(inventory(),ensure_ascii=False,indent=2),encoding='utf-8')
    for scene in plan['maps']:render(scene,OUT/(scene['id'].lower()+'-layout.png'))
    print(json.dumps(reports,ensure_ascii=False))

"""Summarize native packaged evidence; never substitute this for running the game."""
import csv, json, math
from pathlib import Path
from PIL import Image, ImageDraw

root=Path(__file__).resolve().parents[1]
out=root/'Evidence/Greyford/Spatial'
run=out/'Packaged-spatial'
assert (run/'result.txt').read_text(encoding='utf-8-sig').strip()=='PASS'
cases=list(csv.DictReader((run/'cases.csv').open(encoding='utf-8-sig')))
coverage={k:int(v) for k,v in (line.split('=') for line in (run/'coverage.txt').read_text(encoding='utf-8-sig').splitlines())}
assert all(r['expected']==r['actual'] for r in cases)
assert coverage['swept_path_failures']==coverage['landmark_path_failures']==0
assert coverage['connected_components']==1
screens=list(csv.reader((run/'screen.csv').open(encoding='utf-8-sig')))

def crop(folder,row):
    idx,name,x,y=row;x=float(x);y=float(y)
    return Image.open(folder/f'{int(idx):02d}-{name}.png').convert('RGB').crop((round(x-150),round(y-180),round(x+150),round(y+40)))

for batch in range((len(screens)+19)//20):
    sheet=Image.new('RGB',(1500,1000),(30,30,30));draw=ImageDraw.Draw(sheet)
    for i,row in enumerate(screens[batch*20:(batch+1)*20]):
        x=(i%5)*300;y=(i//5)*250;sheet.paste(crop(run,row),(x,y));draw.text((x+5,y+222),row[1],fill='white')
    sheet.save(out/f'contact-{batch+1}.jpg',quality=94)

# Earlier captures recorded a stale controller projection. Recompute from the actual camera rule.
oldcases={r['name']:r for r in csv.DictReader((out/'Before/cases.csv').open(encoding='utf-8-sig'))}
oldrows={r[1]:r for r in csv.reader((out/'Before/screen.csv').open(encoding='utf-8-sig'))}
newrows={r[1]:r for r in screens}
s=180/52;sn=math.sin(math.radians(48));width=1672*s/2;height=width*720/1280
for name,row in oldrows.items():
    c=oldcases[name];x=(836-float(c['pixel_x']))*s;y=(470.5-float(c['pixel_y']))*s/sn
    cx=max(-1672*s/2+width/2,min(1672*s/2-width/2,x))
    cy=max(-941*s/2/sn+height/2/sn,min(941*s/2/sn-height/2/sn,y+100))
    row[2]=640-(x-cx)*1280/width;row[3]=360-(y-cy)*sn*1280/width
names=['barn_front','bridge_mid_west','bench_back','farm_bottom_lane']
comparison=Image.new('RGB',(600,len(names)*250),(30,30,30));draw=ImageDraw.Draw(comparison)
for i,name in enumerate(names):
    comparison.paste(crop(out/'Before',oldrows[name]),(0,i*250));comparison.paste(crop(run,newrows[name]),(300,i*250))
    draw.text((5,i*250+225),'BEFORE / '+name,fill='white');draw.text((305,i*250+225),'AFTER / '+name,fill='white')
comparison.save(out/'comparison.jpg',quality=95)

spec=json.loads((root/'Tools/GreyfordReference.json').read_text(encoding='utf-8'))
base=Image.open(root/'ArtSource/GreyfordReference20261030/VillageReference.png').convert('RGBA')
overlay=Image.new('RGBA',base.size);draw=ImageDraw.Draw(overlay)
for r in csv.DictReader((run/'grid.csv').open(encoding='utf-8-sig')):
    if r['walkable']=='1':
        x=int(r['pixel_x']);y=int(r['pixel_y']);draw.ellipse((x-2,y-2,x+2,y+2),fill=(60,255,130,210))
for r in spec['blocked']:draw.polygon([tuple(p) for p in r['points']],fill=(255,40,40,70),outline=(255,50,50,240),width=2)
for r in cases:
    x=float(r['pixel_x']);y=float(r['pixel_y']);draw.ellipse((x-4,y-4,x+4,y+4),outline=(255,255,255,255),width=2)
Image.alpha_composite(base,overlay).convert('RGB').save(out/'coverage-map.jpg',quality=94)

flow={}
for mode in ['flow-wide','flow-tall']:
    log=(root/f'Evidence/spatial-packaged-{mode}.log').read_text(encoding='utf-8-sig')
    assert 'GREYFORD_FLOW_PASS' in log and 'CHECK ' in log
    assert not any('GREYFORD_FLOW_CHECK' in l and 'FAIL' in l for l in log.splitlines())
    flow[mode]=sum('GREYFORD_FLOW_CHECK' in l and 'PASS' in l for l in log.splitlines())
smoke=(root/'Evidence/packaged-layout-smoke.log').read_text(encoding='utf-8-sig')
assert 'ALCHEMY_SMOKE_PASS' in smoke and 'ALCH002_TEST_PASS' in smoke
report=dict(result='PASS',method='Native packaged D3D12 production movement, authored semantic fixtures, grid connectivity, screenshots; finite spatial sampling, not human playtest.',semantic_cases=len(cases),screenshots=len(screens),coverage=coverage,flow=flow,smoke='PASS',depth_layers=len(spec['layers']),walk_regions=len(spec['walk']),blocked_regions=len(spec['blocked']),village_body_radius_cm=30)
(out/'verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,ensure_ascii=False))

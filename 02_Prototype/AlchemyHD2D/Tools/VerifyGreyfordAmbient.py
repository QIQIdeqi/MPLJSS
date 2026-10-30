"""Read-only checks on actual packaged captures, not a substitute for visual review."""
import csv,json,math
from pathlib import Path
from PIL import Image,ImageStat,ImageChops

root=Path(__file__).resolve().parents[1]/'Evidence/Greyford/Ambient'
tour=root/'Packaged-tour'
rows=list(csv.DictReader((tour/'movement.csv').open(encoding='utf-8-sig')))
frames=sorted(tour.glob('frame-*.png'))
assert 'result=PASS' in (tour/'result.txt').read_text(encoding='utf-8-sig')
assert len(frames)==len(rows) and len(rows)>400
assert all(r['in_bounds']=='1' for r in rows)
for i,f in enumerate(frames):
    assert f.name==f'frame-{i:05d}.png'
    with Image.open(f) as im:
        assert im.size==(1280,720)
        assert sum(ImageStat.Stat(im.convert('RGB')).mean)/3>20, f'Black/empty frame: {f}'

def difference(a,b,box):
    with Image.open(frames[a]) as x,Image.open(frames[b]) as y:
        d=ImageChops.difference(x.convert('RGB').crop(box),y.convert('RGB').crop(box))
        return sum(ImageStat.Stat(d).mean)/3

def paused_pair(waypoint):
    group=[r for r in rows if int(r['waypoint'])==waypoint]
    start=group[0]
    still=[r for r in group if r['player_x']==start['player_x'] and r['player_y']==start['player_y']]
    assert len(still)>60
    return int(still[25]['frame']),int(still[55]['frame'])

def screen_box(frame,rect):
    r=rows[frame];scale=180/52;zoom=1280/836
    left=836-float(r['camera_x'])/scale-418
    top=470.5-float(r['camera_y'])*math.sin(math.radians(48))/scale-720/zoom/2
    x0,y0,x1,y1=rect
    return (max(0,round((x0-left)*zoom)),max(0,round((y0-top)*zoom)),min(1280,round((x1-left)*zoom)),min(720,round((y1-top)*zoom)))

farm=paused_pair(2);north=paused_pair(5)
motion={name:difference(*pair,screen_box(pair[0],rect)) for name,pair,rect in [
    ('waterwheel',farm,(0,450,60,580)),('creek',farm,(125,560,225,620)),
    ('chimney_smoke',north,(413,0,465,70)),('static_roof_control',farm,(670,585,780,640)),
]}
assert min(motion[k] for k in ('waterwheel','creek','chimney_smoke'))>0.5
assert motion['static_roof_control']<0.5
with Image.open(root/'Packaged-overview/01-village.png') as a,Image.open(root/'Packaged-overview/11-returned-village.png') as b:
    box=(825,715,875,790)
    motion['south_chimney_smoke']=sum(ImageStat.Stat(ImageChops.difference(a.convert('RGB').crop(box),b.convert('RGB').crop(box))).mean)/3
assert motion['south_chimney_smoke']>0.5
flows={}
for mode in ('1280x720','1024x768','overview'):
    folder=root/f'Packaged-{mode}'
    result=(folder/'flow-result.txt').read_text(encoding='utf-8-sig')
    assert 'FAIL' not in result and 'PASS' in result
    flows[mode]=result.strip()
report=dict(status='PASS',runtime='Windows packaged D3D12',frames=len(frames),size=[1280,720],fps=20,
    seconds=round(len(frames)/20,2),waypoints=5,camera_in_bounds_frames=len(rows),zoom=2,
    image_difference_mae_0_255=motion,comparison_frames={'farm':farm,'north':north},flow_checks=flows,
    limits='Automated production movement and image checks; no manual combat/balance or FPS benchmark claim.')
(root/'verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k!='flow_checks'},ensure_ascii=False))

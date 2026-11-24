from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json, shutil, hashlib
import numpy as np

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / 'ArtSource/Regions_20261124'
DEST = ROOT / '02_Prototype/AlchemyGodot/art/regions'
OUT = ROOT / 'outputs/five_regions_art_20261124'
IDS = ['greyford_01','trade_road_02','manor_03','pilgrimage_04','capital_05']

def seam_tile(image):
    """Normalize the generated raster for periodic texture sampling, preserving its artwork."""
    a = np.asarray(image.convert('RGB').resize((256,256),Image.Resampling.LANCZOS),dtype=float).copy()
    for offset in range(12):
        w = (1 - offset/12) ** 2 * .5
        left,right = a[:,offset].copy(),a[:,-1-offset].copy()
        a[:,offset] = left*(1-w)+right*w
        a[:,-1-offset] = right*(1-w)+left*w
    for offset in range(12):
        w = (1 - offset/12) ** 2 * .5
        top,bottom = a[offset].copy(),a[-1-offset].copy()
        a[offset] = top*(1-w)+bottom*w
        a[-1-offset] = bottom*(1-w)+top*w
    return Image.fromarray(a.clip(0,255).astype('uint8'))

def prepare():
    records=[]
    for ident in IDS:
        target=DEST/ident;target.mkdir(parents=True,exist_ok=True)
        for name in ['ground','prop_a','prop_b']:
            source=SOURCE/(ident+'_'+name+'_raw.png')
            if not source.exists(): continue
            raw=Image.open(source).convert('RGBA')
            if name=='ground':
                image=seam_tile(raw)
                a=np.asarray(image)
                assert np.array_equal(a[0],a[-1]) and np.array_equal(a[:,0],a[:,-1])
                foot=None
            else:
                alpha=raw.getchannel('A')
                assert alpha.getextrema()[0]==0, f'No transparent background: {source}'
                box=alpha.point(lambda x:255 if x>12 else 0).getbbox()
                assert box
                content=raw.crop(box)
                content.thumbnail((224,212),Image.Resampling.LANCZOS)
                image=Image.new('RGBA',(256,256),(0,0,0,0))
                image.alpha_composite(content,((256-content.width)//2,232-content.height))
                foot=232
            path=target/(name+'.png');image.save(path)
            records.append({'id':ident,'name':name,'path':str(path.relative_to(ROOT)).replace('\\','/'),'source':str(source.relative_to(ROOT)).replace('\\','/'),'source_size':list(raw.size),'size':list(image.size),'foot_y_px':foot,'alpha':name!='ground','sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
    (SOURCE/'asset_manifest.json').write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n','utf-8')
    font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',18)
    board=Image.new('RGB',(960,5*320),'#25352b');draw=ImageDraw.Draw(board)
    for i,ident in enumerate(IDS):
        draw.text((16,i*320+8),ident,font=font,fill='#eee5d1')
        for j,name in enumerate(['ground','prop_a','prop_b']):
            p=DEST/ident/(name+'.png')
            if not p.exists():continue
            image=Image.open(p).convert('RGBA')
            board.paste(image,(20+j*310,i*320+42),image)
    board.save(OUT/'素材联系表.png')
    print(json.dumps({'prepared':len(records),'ids':IDS},ensure_ascii=False))

if __name__=='__main__':prepare()

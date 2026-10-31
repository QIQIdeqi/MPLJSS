"""Extract authorized reference HUD artwork; masks remove the scene and baked numeric state."""
from pathlib import Path
import argparse, hashlib, json, shutil
from PIL import Image, ImageDraw

root=Path(__file__).resolve().parents[1]/'ArtSource'/'UIReference20261031'
parser=argparse.ArgumentParser()
parser.add_argument('--reference',default=str(root/'ReferenceHUD.png'))
parser.add_argument('--background',default=str(root/'BackgroundClean.png'))
args=parser.parse_args()
root.mkdir(parents=True,exist_ok=True)
source=Image.open(args.reference).convert('RGBA')
assert source.size==(1672,940),source.size
for original,target in [(Path(args.reference),root/'ReferenceHUD.png'),(Path(args.background),root/'BackgroundClean.png')]:
    if original.resolve()!=target.resolve():
        shutil.copy2(original,target)
parts=[]
def cut(name,box,shape='rect',hole=None,polygon=None):
    tile=source.crop(box)
    mask=Image.new('L',tile.size,0);draw=ImageDraw.Draw(mask);w,h=tile.size
    if polygon:draw.polygon(polygon,fill=255)
    elif shape=='ellipse':draw.ellipse((1,1,w-2,h-2),fill=255)
    elif shape=='rounded':draw.rounded_rectangle((1,1,w-2,h-2),radius=7,fill=255)
    else:draw.rectangle((0,0,w-1,h-1),fill=255)
    if hole:draw.rectangle(hole,fill=0)
    tile.putalpha(mask);tile.save(root/(name+'.png'))
    parts.append({'name':name,'source_box':box,'size':tile.size,'hole':hole,'mask':shape})

cut('Portrait',(20,8,119,113),'ellipse')
cut('PortraitBadge',(20,82,49,113),'ellipse')
cut('HPFrame',(197,27,503,59),hole=(16,8,286,23),polygon=[(1,15),(10,2),(289,2),(304,15),(290,29),(10,29)])
cut('HPFill',(224,35,254,49))
cut('BarDark',(350,63,380,71))
cut('DodgeFrame',(118,55,414,79),hole=(11,6,281,17),polygon=[(2,3),(285,3),(294,11),(285,22),(2,22)])
cut('DodgeFill',(132,63,160,71))
cut('TimerLeft',(735,22,795,46),polygon=[(1,10),(39,10),(46,4),(51,10),(58,10),(51,14),(46,21),(39,14),(1,14)])
cut('TimerRight',(891,22,951,46),polygon=[(1,10),(8,10),(14,4),(21,10),(58,10),(58,14),(21,14),(14,21),(8,14)])
cut('Skull',(1332,11,1368,49),'ellipse')
cut('Coin',(1488,10,1527,50),'ellipse')
cut('MinimapFrame',(1405,52,1654,200),'rounded',hole=(7,7,241,140))
cut('MinimapDark',(1450,169,1471,184))
cut('SkillFrame',(624,804,699,880),'rounded',hole=(8,8,66,67))
for i,x in enumerate((624,712,800,888)):
    cut('SkillArt'+str(i),(x+9,814,x+65,870),'rounded')
cut('AddSkill',(978,810,1045,879),'rounded')
cut('XPFrame',(373,902,1299,932),hole=(20,9,904,22),polygon=[(1,15),(14,2),(909,2),(924,15),(909,28),(14,28)])
cut('XPFill',(501,913,540,923))
manifest={'reference_size':source.size,'reference_sha256':hashlib.sha256(Path(args.reference).read_bytes()).hexdigest(),
          'source':'User-supplied reference; extracted artwork only, no claim of third-party license.',
          'method':'Deterministic crop and explicit alpha masks. Numeric state is removed and supplied by UMG at runtime.',
          'parts':parts}
(root/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
sheet=Image.new('RGB',(900,((len(parts)+3)//4)*150),(45,48,52));d=ImageDraw.Draw(sheet)
for i,part in enumerate(parts):
    tile=Image.open(root/(part['name']+'.png'));tile.thumbnail((210,110))
    x=(i%4)*225+6;y=(i//4)*150+23;sheet.paste(tile,(x,y),tile);d.text((x,y-18),part['name'],fill='white')
sheet.save(root/'extraction-contact-sheet.png')
print('REFERENCE_UI_EXTRACT_PASS',len(parts),root)

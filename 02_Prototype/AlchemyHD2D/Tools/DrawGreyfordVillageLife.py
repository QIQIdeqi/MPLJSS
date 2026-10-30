"""Draw a plan from the village's saved authoring reports, rather than an invented concept."""
from pathlib import Path
import json
from PIL import Image,ImageDraw,ImageFont
root=Path(__file__).resolve().parents[1];work=root.parents[1]
report=json.loads((root/'Evidence/Greyford/VillageLife/authoring-report.json').read_text(encoding='utf-8'))
paving=json.loads((root/'Evidence/Greyford/VillageCompact/authoring-report.json').read_text(encoding='utf-8'))
out=Image.new('RGB',(1600,1200),'#263d35');d=ImageDraw.Draw(out)
font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',18);title=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',30)
def pt(x,y):return 800-x*.095,610-y*.095
def rect(x,y,w,h,color,outline=None):
    a,b=pt(x+w/2,y+h/2);c,e=pt(x-w/2,y-h/2);d.rectangle((a,b,c,e),fill=color,outline=outline,width=2)
rect(0,0,14400,10800,'#6d8c54','#adc49c')
for x in range(-7200,7201,600):d.line((*pt(x,-5400),*pt(x,5400)),fill='#77975f')
for y in range(-5400,5401,600):d.line((*pt(-7200,y),*pt(7200,y)),fill='#77975f')
rect(4200,-3300,6000,600,'#548d9e')
for r in paving['road_markers']:rect(*r,'#b69b6a')
for r in paving['soil_markers']:rect(*r,'#826444')
rect(*paving['plaza_after_cm'],'#b8b7a2')
for obj in report['moved_buildings']:
    n=obj['label'];x,y=obj['after']
    if '橡树' in n:continue
    w,h=(884,568.4) if n=='格蕾丝小屋' else (1062.5,667) if n=='粮仓' else (765,377) if n=='作坊' else (765,580)
    rect(x,y+h/2,w,h,'#b8754e','#4a382d')
    if not n.startswith('住宅'):d.text(pt(x,y+h+130),n,font=font,fill='#fff2cf',anchor='ms')
colors={'HerbBed':'#b3c96e','CropRow':'#80b84f','Oak':'#30572c','Bush':'#416a39','FogGate':'#82ded9','BankRocks':'#a1a6a0','Fence':'#d2b180','StoneWall':'#a5aba1'}
for obj in report['props']:
    x,y=obj['foot'];w,h=obj['collision'] or (70,70)
    rect(x,y,w,h,colors.get(obj['asset'],'#f6cd72'))
for i,(x,y) in enumerate(report['walk_targets']):
    a,b=pt(x,y);d.ellipse((a-4,b-4,a+4,b+4),fill='#f8f8ee');d.text((a+5,b),str(i+1),font=font,fill='white')
for text,x,y in [('药圃',2500,1500),('菜田',4400,-1050),('水车溪岸',4500,-3800),('木桥',2700,-3300),('雾门',-5600,-1000),('公共广场',0,950)]:d.text(pt(x,y),text,font=font,fill='white',anchor='mm')
d.text((70,25),'格雷弗德村庄 · 当前关卡布局',font=title,fill='white')
d.text((70,72),'依据保存的建筑脚点、碰撞占地及道路标记绘制；小格 6 米。数字为已验证路线目标。',font=font,fill='#d7e5d3')
d.text((70,1135),'棕：建筑占地   黄：生活道具   绿：种植与植被   蓝：溪水   白点：通路检查点；本图不是氛围概念图。',font=font,fill='white')
dest=work/'00_Doc/协作策划/附件/UE_GreyfordVillageLife_layout.png';out.save(dest);print(dest)

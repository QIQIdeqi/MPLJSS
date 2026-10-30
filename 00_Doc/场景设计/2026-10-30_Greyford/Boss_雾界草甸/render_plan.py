from pathlib import Path
import math
from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parent
W, H = 1440, 1080
im = Image.new('RGB', (W, H), '#17272b')
d = ImageDraw.Draw(im)
font_path = 'C:/Windows/Fonts/msyh.ttc'
fonts = {s: ImageFont.truetype(font_path, s) for s in (18, 20, 22, 26, 34, 42)}
def text(x, y, value, size=22, fill='#e7e9d7', anchor=None):
    d.text((x, y), value, font=fonts[size], fill=fill, anchor=anchor)
def line(points, fill='#a7c4b8', width=2):
    d.line(points, fill=fill, width=width, joint='curve')
def dot(x,y,r,fill,outline=None):
    d.ellipse((x-r,y-r,x+r,y+r),fill=fill,outline=outline,width=2)
def label(x,y,n):
    dot(x,y,16,'#213738','#dfd8b6');text(x,y,str(n),18,anchor='mm')

text(48,26,'雾界草甸 · 独立 Boss 场地提案',42)
text(50,86,'延续 Greyford 草原美术｜开阔中央＋自然外缘｜俯视示意，非实机画面',22,'#adc4bd')
d.rounded_rectangle((35,140,1035,956),radius=20,fill='#263f3d')
cx,cy,rx,ry=530,548,350,280
def outline(scale=1):
    return [(cx+rx*scale*math.cos(a)*(1+.012*math.sin(3*a)),cy+ry*scale*math.sin(a)) for a in [i*math.tau/240 for i in range(241)]]
outer=outline(1.13)
d.polygon(outer,fill='#536c5b')
line(outline(1.18),'#71928a',18)
line(outline(1.14),'#8aa59a',7)
d.polygon(outline(),fill='#6d805b')
# Low-contrast flat ground patches; these are not obstacles.
d.ellipse((365,445,700,648),fill='#7a8161')
d.ellipse((430,515,735,685),fill='#7a8060')
d.ellipse((310,440,500,575),fill='#74805d')
for i in range(0,240,4):
    p=outline()[i:i+3];line(p,'#d2dbb8',2)
# Background stream outside the playable perimeter.
line([(955,465),(978,570),(949,681),(903,788),(818,881),(741,925)],'#3c666c',40)
line([(955,465),(978,570),(949,681),(903,788),(818,881),(741,925)],'#6c9795',9)
for x,y in [(938,505),(946,615),(916,721),(857,817),(781,891)]:
    d.ellipse((x-15,y-9,x+15,y+9),fill='#8c9280',outline='#a8ad99')
# Northwest oak: canopy and trunk are outside the combat footprint.
for x,y,r in [(164,310,58),(120,280,43),(192,273,46),(127,340,43),(210,327,34)]:
    dot(x,y,r,'#405f46','#6e8658')
d.rectangle((155,322,170,375),fill='#776952')
for x,y in [(220,800),(160,670),(175,706),(826,264),(870,304)]:
    dot(x,y,20,'#46694e');dot(x+16,y+7,14,'#5c7954')
# East cart and broken fences, entirely outside the clearing.
d.rounded_rectangle((896,300,967,344),radius=6,fill='#8a7452',outline='#c3b58c',width=2)
dot(907,347,9,'#253a36','#b9a77f');dot(954,347,9,'#253a36','#b9a77f')
line([(895,355),(871,380)],'#a89570',4)
for x,y in [(830,223),(945,385)]:
    line([(x,y),(x+58,y+15)],'#b8a780',4)
    for dx in (0,27,58):line([(x+dx,y-8),(x+dx,y+24)],'#8d785a',5)
# Old alchemy boundary markers, no central platform.
for x,y in [(530,214),(452,875),(609,875)]:
    d.polygon([(x-12,y+20),(x-14,y-12),(x,y-28),(x+13,y-10),(x+11,y+20)],fill='#8a9788',outline='#c0c9b5')
    line([(x,y-16),(x-6,y-5),(x,y+7),(x+6,y-5),(x,y-16)],'#b6d9cb',2)
# Candidate arrival positions, not fixed game rules.
dot(530,402,18,'#934c48','#e3c2a9');text(530,356,'Boss 入场候选',22,anchor='mm')
dot(530,703,14,'#8bd3ce','#d2f0dd');text(530,744,'玩家落点候选',22,anchor='mm')
text(530,526,'中央净空',34,anchor='mm')
text(530,570,'短草 · 平坦泥痕 · 无实体障碍',22,'#e2e4cc',anchor='mm')
text(530,619,'景物均留在外围',20,'#ccd6bb',anchor='mm')
# Diagram dimensions are proposed test inputs.
line([(180,188),(880,188)],'#d7c69a',2)
for x in (180,880):line([(x,180),(x,196)],'#d7c69a',2)
text(530,166,'32 m（起测候选，非最终尺寸）',20,'#e5d3a4',anchor='mm')
line([(100,268),(100,828)],'#d7c69a',2)
for y in (268,828):line([(92,y),(108,y)],'#d7c69a',2)
text(63,525,'26m',20,'#e5d3a4',anchor='mm')
for x,y,n in [(230,350,1),(906,280,2),(923,777,3),(579,214,4),(635,879,5)]:label(x,y,n)

text(1080,158,'景物与战斗空间',26)
cards=[('1  老橡树 / 灌木','树冠留在战斗区外'),('2  田车 / 断篱','乡野剪影，不放补给'),('3  浅溪 / 低石岸','只在外围，不切断场地'),('4  旧阵石 / 雾界','低亮点缀，雾不盖中心'),('5  入场平地','标记无阻挡，不可返回')]
for i,(title,body) in enumerate(cards):
    y=214+i*112
    d.rounded_rectangle((1066,y-12,1404,y+78),radius=10,fill='#21373a')
    text(1080,y,title,22,'#e8d8ac');text(1080,y+39,body,20,'#b7ccc3')
text(1080,805,'图示说明',22,'#e8d8ac')
text(1080,846,'浅虚线：可走边界示意',18)
text(1080,880,'雾与装饰在边界外',18)
text(1080,914,'轮廓、尺寸、落点待试玩',18,'#b7ccc3')
text(48,985,'首轮尺度候选 32 × 26 m｜5 m/s 直穿约 6.4 / 5.2 s｜外围装饰带约 4—6 m',22)
text(48,1026,'沿用现有镜头；示意图不等于正式素材、碰撞验证或战斗平衡结论。2026-10-30 / V0.1',20,'#a6c0b8')
im.save(OUT/'boss-layout.png',optimize=True)
im.save(OUT/'boss-layout-wolai.jpg',quality=87,optimize=True)
print('Created:',OUT/'boss-layout.png')
print('Wolai JPEG bytes:',(OUT/'boss-layout-wolai.jpg').stat().st_size)

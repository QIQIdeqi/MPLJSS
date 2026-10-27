"""Original placeholder pixel art, no downloaded game assets; standard library only."""
from pathlib import Path
import struct, zlib, random

OUT = Path(__file__).resolve().parents[1] / 'ArtSource'
OUT.mkdir(exist_ok=True)

class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.p = [[(0,0,0,0) for _ in range(w)] for _ in range(h)]
    def rect(self, x0,y0,x1,y1,c):
        c = tuple(bytes.fromhex(c)) + (255,)
        for y in range(max(0,y0), min(self.h,y1+1)):
            for x in range(max(0,x0), min(self.w,x1+1)): self.p[y][x]=c
    def poly(self, pts, c):
        for y in range(self.h):
            hits=[]
            for (x1,y1),(x2,y2) in zip(pts,pts[1:]+pts[:1]):
                if min(y1,y2)<=y<max(y1,y2): hits.append(x1+(y-y1)*(x2-x1)/(y2-y1))
            hits.sort()
            for i in range(0,len(hits)-1,2): self.rect(round(hits[i]),y,round(hits[i+1]),y,c)
    def save(self,name):
        def chunk(k,d): return struct.pack('!I',len(d))+k+d+struct.pack('!I',zlib.crc32(k+d)&0xffffffff)
        raw=b''.join(b'\0'+bytes(v for p in row for v in p) for row in self.p)
        (OUT/(name+'.png')).write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('!2I5B',self.w,self.h,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(raw))+chunk(b'IEND',b''))

def create_drop_icons():
    a=Canvas(32,32)
    for y in range(32):
        for x in range(32):
            r=(x-15.5)**2+(y-15.5)**2
            if r<=196: a.rect(x,y,x,y,'493019' if r>156 else 'd38a22' if r>112 else 'f6c75b')
    a.rect(9,6,20,7,'fff2ac'); a.rect(6,9,7,18,'ffe69a')
    a.rect(13,9,18,11,'805020'); a.rect(14,11,17,15,'805020')
    a.poly([(14,15),(17,15),(22,23),(10,23)],'805020'); a.rect(12,21,20,22,'ffdf7a'); a.save('Coin')
    a=Canvas(32,32); a.poly([(9,13),(23,13),(26,26),(6,26)],'62362c');a.rect(11,11,21,14,'d8a65a')
    a.poly([(11,22),(15,15),(15,6),(21,12),(23,20),(18,25)],'f16d32');a.poly([(14,22),(18,15),(20,22)],'ffdc75');a.save('FirePowder')
    a=Canvas(32,32); a.poly([(16,3),(27,18),(25,25),(20,29),(11,29),(5,23),(6,17)],'264d6e');a.poly([(16,6),(24,19),(22,25),(12,26),(8,22),(9,17)],'5bd2ea');a.rect(11,16,13,22,'d0faff');a.save('Dew')
    a=Canvas(32,32);a.poly([(13,3),(25,10),(21,26),(9,29),(4,19)],'493971');a.poly([(13,6),(21,11),(15,25),(7,19)],'b698ee');a.poly([(13,6),(15,25),(17,12)],'eee1ff');a.save('MagicShard')
    a=Canvas(32,32);a.poly([(15,3),(27,12),(26,24),(16,29),(5,22),(5,11)],'54392c');a.poly([(15,7),(23,14),(20,24),(10,23),(8,13)],'d99553');a.rect(12,12,19,19,'fbdf9e');a.save('BeastCore')
    a=Canvas(32,32);a.poly([(17,2),(27,14),(21,28),(8,27),(4,14)],'27284f');a.poly([(17,5),(23,14),(16,25),(8,22)],'8151c6');a.poly([(17,5),(16,25),(13,13)],'d1a4ff');a.save('VoidCrystal')
    a=Canvas(32,32);a.poly([(6,10),(12,7),(16,12),(21,7),(27,11),(25,20),(16,28),(6,20)],'30644b');a.poly([(8,12),(12,10),(16,15),(21,10),(24,13),(21,21),(16,24),(10,19)],'83c56b');a.rect(15,16,17,26,'c1df88');a.save('RootHeart')

if '--drops-only' in __import__('sys').argv:
    create_drop_icons()
    raise SystemExit(0)

create_drop_icons()
for back in range(2):
    for f in range(4):
        a=Canvas(48,64); dy=1 if f%2 else 0; foot=2 if f==1 else -2 if f==3 else 0
        a.rect(16,53,22,60+foot,'192d38'); a.rect(27,53,33,60-foot,'192d38')
        a.rect(15,59+foot,23,61+foot,'101c28'); a.rect(27,59-foot,35,61-foot,'101c28')
        a.poly([(17,31+dy),(32,31+dy),(39,53+dy),(9,53+dy)],'172c3a')
        a.poly([(18,32+dy),(29,32+dy),(34,51+dy),(13,51+dy)],'275c67')
        a.poly([(19,33+dy),(25,34+dy),(22,49+dy),(15,49+dy)],'438684')
        a.rect(17,33+dy,31,38+dy,'deaa6b'); a.rect(20,38+dy,28,40+dy,'bb7353')
        a.rect(13,42+dy,17,50+dy,'edc18c'); a.rect(32,39+dy,36,45+dy,'e5b782')
        a.rect(15,45+dy,32,47+dy,'644839'); a.rect(23,45+dy,26,48+dy,'e0b76a')
        a.rect(31,47+dy,36,53+dy,'111e2b'); a.rect(32,48+dy,35,52+dy,'64d5cc'); a.rect(33,47+dy,34,49+dy,'cbfff2')
        a.rect(16,20+dy,32,33+dy,'30282d'); a.rect(18,22+dy,31,32+dy,'eab985')
        a.rect(18,21+dy,21,27+dy,'6c4535'); a.rect(28,21+dy,32,26+dy,'6c4535')
        if not back:
            a.rect(23,26+dy,24,28+dy,'182a33'); a.rect(29,26+dy,30,28+dy,'182a33')
            a.rect(25,30+dy,28,30+dy,'ac6552')
        else: a.rect(18,23+dy,32,32+dy,'654735')
        a.poly([(13,19+dy),(17,10+dy),(23,4+dy),(28,6+dy),(30,16+dy),(38,21+dy),(10,23+dy)],'152b3e')
        a.poly([(17,17+dy),(21,8+dy),(25,6+dy),(27,17+dy)],'36737a')
        a.rect(15,18+dy,32,20+dy,'b98b54'); a.rect(24,18+dy,27,21+dy,'f1d482')
        a.save(f'Hero{back}_{f}')

for kind in range(10):
    a=Canvas(48,48)
    if kind in (0,4):
        a.poly([(5,32),(10,23),(18,20),(31,22),(39,30),(44,34),(33,38),(10,38)],'342b43')
        a.poly([(8,31),(16,23),(29,25),(36,32),(28,35),(11,35)],'766580' if kind==0 else '39485f')
        a.rect(14,18,20,25,'aa7f99'); a.rect(29,28,31,30,'fc8b91'); a.rect(10,37,16,40,'b49c9d'); a.rect(29,36,35,39,'b49c9d')
        a.poly([(6,33),(2,29),(0,29),(1,34),(7,38)],'ad7c9a')
    elif kind in (1,3):
        a.poly([(6,38),(8,26),(15,17),(32,18),(40,29),(42,39)],'182e3c')
        a.poly([(9,36),(12,25),(19,20),(30,21),(37,31),(37,37)],'559d7b' if kind==1 else '8c698e')
        a.rect(17,25,20,28,'e9e6b0'); a.rect(29,25,32,28,'e9e6b0'); a.rect(18,31,31,33,'203443')
        a.rect(15,21,18,23,'a6d39d'); a.rect(22,19,27,21,'a6d39d')
    else:
        col=['aab6b5','94b7ae','938aa8','709a93','5c7184','8b6a98','b4a282','a193ae'][kind-2]
        a.rect(16,8,33,23,'202a39'); a.rect(18,10,31,21,col)
        a.rect(20,15,22,18,'fdc17a'); a.rect(28,15,30,18,'fdc17a')
        a.poly([(17,24),(32,24),(39,42),(10,42)],'2a3f4e'); a.rect(20,25,30,37,col)
        a.rect(12,28,16,39,col); a.rect(34,27,38,38,col); a.rect(17,40,21,46,'1a293b'); a.rect(29,40,33,46,'1a293b')
        if kind>=7:
            a.poly([(13,11),(7,2),(18,8),(24,2),(29,8),(40,1),(36,16)],'87b493')
    a.save(f'Enemy{kind}')

for name,col in [('Grass','344d46'),('Dirt','706149'),('Stone','777f7b')]:
    a=Canvas(64,64); base=tuple(bytes.fromhex(col)); rng=random.Random(77)
    for y in range(64):
        for x in range(64):
            n=rng.choice([-8,-4,0,0,0,3,6])
            c=''.join(f'{max(0,min(255,v+n)):02x}' for v in base)
            a.rect(x,y,x,y,c)
    a.save(name)
for variant in range(3):
    a=Canvas(96,144); rng=random.Random(330+variant)
    a.poly([(38,68),(57,68),(62,132),(48,140),(32,135)],'263b35')
    a.poly([(43,68),(52,68),(51,132),(38,135)],'58604a')
    a.poly([(44,113),(24,92),(29,88),(48,100),(71,83),(76,88),(52,115)],'394b3d')
    a.poly([(8,79),(2,59),(8,38),(23,27),(33,9),(53,4),(73,16),(78,31),(92,43),(94,65),(82,85),(66,96),(25,94)],'172f32')
    a.poly([(9,67),(12,40),(29,29),(39,14),(57,10),(74,24),(72,37),(87,47),(85,66),(71,80),(36,85),(17,79)],'31544a' if variant!=2 else '424f48')
    for i in range(120):
        x,y=rng.randrange(12,84),rng.randrange(18,82)
        if (x-48)**2/1300+(y-52)**2/1300<1:
            c=rng.choice(['466851','53735a','385f4d','698264','27463f'])
            a.rect(x,y,x+rng.randrange(2,6),y+rng.randrange(1,4),c)
    a.poly([(18,38),(34,19),(53,13),(64,18),(45,20),(29,36)],'79906b')
    a.rect(39,123,43,131,'92a279'); a.rect(53,112,56,117,'7a8f65')
    a.save(f'Tree{variant}')

for variant in range(2):
    a=Canvas(192,176)
    a.poly([(29,83),(144,83),(171,66),(171,151),(141,169),(29,155)],'303c39')
    a.poly([(31,83),(139,83),(139,161),(31,150)],'a28b63')
    a.poly([(140,82),(167,65),(167,149),(140,162)],'645c49')
    a.poly([(17,79),(83,17),(151,76),(172,62),(112,10),(80,12),(7,74)],'243a3c')
    a.poly([(14,74),(81,15),(144,76),(143,87),(15,83)],'60766a' if variant==0 else '966e56')
    a.poly([(83,16),(113,13),(177,65),(146,83)],'344c48' if variant==0 else '614938')
    for y in range(28,82,8):
        x0=81-(y-15); x1=81+(y-15)
        a.rect(max(15,x0),y,min(145,x1),y+1,'8a9679' if variant==0 else 'b8936b')
        for x in range(max(16,x0)+5,min(144,x1),16): a.rect(x,y+1,x+1,y+6,'4a615a')
    a.rect(30,86,35,150,'574c3a'); a.rect(133,87,139,163,'574c3a'); a.rect(31,118,137,122,'6f6047')
    a.rect(75,114,100,157,'34423f'); a.rect(79,117,96,156,'4a5140'); a.rect(90,138,92,140,'dfbc77')
    for x in (45,111):
        a.rect(x,95,x+16,113,'3a4137'); a.rect(x+2,97,x+14,111,'e0ba77'); a.rect(x+7,96,x+8,113,'756346')
    a.rect(119,29,134,60,'72756a'); a.rect(117,26,136,31,'9d9b81')
    a.poly([(73,158),(101,158),(110,165),(67,165)],'70776a')
    a.save(f'House{variant}')

a=Canvas(64,48)
a.poly([(4,35),(13,14),(34,6),(56,15),(61,34),(46,42),(17,43)],'344543')
a.poly([(8,32),(17,17),(34,10),(52,17),(43,31),(21,37)],'758274')
a.poly([(17,17),(34,10),(39,18),(25,27),(10,30)],'9b9e85')
a.poly([(43,31),(52,17),(57,33),(44,38)],'53675d'); a.save('Rock')

a=Canvas(48,64)
a.poly([(8,23),(38,23),(43,36),(39,52),(29,58),(14,56),(6,44)],'203842')
a.poly([(9,28),(37,28),(38,40),(33,50),(13,47)],'3b6870')
a.rect(9,22,37,27,'9aa58c'); a.rect(12,23,34,25,'65d6b2')
a.rect(11,48,15,59,'172a32'); a.rect(31,48,35,59,'172a32')
a.rect(17,15,20,18,'8de7cc'); a.rect(29,8,31,11,'83c7b5'); a.rect(24,1,26,4,'bdd7b8'); a.save('Cauldron')

a=Canvas(48,64)
a.rect(21,22,28,57,'5b4b37'); a.rect(12,57,37,61,'393d34')
a.poly([(4,18),(21,12),(25,16),(29,12),(45,16),(43,34),(26,38),(7,33)],'574d3b')
a.poly([(6,16),(21,11),(25,16),(25,34),(9,29)],'d5c79a')
a.poly([(26,16),(30,11),(44,14),(42,29),(26,34)],'aaae87')
for y in (18,22,26): a.rect(10,y,20,y,'9a9874'); a.rect(30,y,39,y,'767f66')
a.save('Lectern')

a=Canvas(96,128)
a.poly([(10,121),(10,36),(23,12),(70,12),(87,36),(87,121),(71,121),(71,43),(60,30),(35,30),(26,43),(26,121)],'354b4a')
for y in range(19,121,13):
    a.rect(11,y,25,y+9,'7c8c7a'); a.rect(72,y,86,y+9,'5b7065')
a.rect(28,13,67,27,'94a184'); a.rect(40,17,55,23,'57dfcc')
a.poly([(29,112),(28,44),(38,32),(59,32),(69,46),(69,112)],'1d625d')
for x,y in [(36,50),(54,44),(44,65),(60,86),(35,94),(50,103)]: a.rect(x,y,x+2,y+5,'7fe4d0')
a.save('Portal')

a=Canvas(48,48)
a.poly([(6,14),(34,8),(43,14),(43,37),(17,43),(6,35)],'493e30')
a.poly([(8,16),(32,11),(40,16),(17,23)],'b59a5e'); a.rect(8,23,16,36,'826e45')
a.poly([(18,25),(41,18),(41,35),(18,41)],'6c6544'); a.rect(25,25,30,31,'e1c787'); a.save('Chest')

a=Canvas(32,32)
a.rect(13,3,19,7,'c2bd96'); a.rect(14,7,18,11,'66756d')
a.poly([(13,11),(19,11),(25,21),(24,27),(9,27),(8,21)],'203d45')
a.poly([(13,15),(20,15),(23,22),(22,25),(11,25),(10,22)],'6cc6b6'); a.rect(12,18,14,22,'c8ecce'); a.save('Bottle')

a=Canvas(32,32)
for y in range(32):
    for x in range(32):
        if (x-15.5)**2+(y-15.5)**2<225: a.rect(x,y,x,y,'ffffff')
a.save('Disc')
print('Original 2D sheet assets written:', len(list(OUT.glob('*.png'))))

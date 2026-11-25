/* Offline concept renderer. Gameplay, damage and rewards remain in Godot. */
(() => {
  'use strict';
  const CW = 1280, CH = 720, FLAT = .62;
  const COLORS = ['#85905f', '#a48f68', '#7d927b', '#ad956b', '#767c84'];
  const mod = (n, d) => ((n % d) + d) % d;
  function hash(a, b, seed) {
    let n = Math.imul(a | 0, 374761393) ^ Math.imul(b | 0, 668265263) ^ (seed | 0);
    n = Math.imul(n ^ n >>> 13, 1274126177); return (n ^ n >>> 16) >>> 0;
  }
  function random(seed) { let s = seed >>> 0; return () => { s += 0x6D2B79F5; let t = Math.imul(s ^ s >>> 15, 1 | s); t ^= t + Math.imul(t ^ t >>> 7, 61 | t); return ((t ^ t >>> 14) >>> 0) / 4294967296; }; }
  class WorldPreview {
    constructor(canvas, assets, levels, onChange) {
      this.canvas = canvas; this.ctx = canvas.getContext('2d'); this.assets = assets; this.levels = levels; this.onChange = onChange;
      this.level = 0; this.seed = 77; this.time = 0; this.clock = 0; this.mode = 'field'; this.player = {x: 0, y: 0};
      this.overlays = {chunks: false, routes: false, safe: false}; this.cache = new Map(); this.patterns = {}; this.patches = {};
      this.portal = null; this.loaded = 0; this.unloaded = 0; this.moving = false; this.facing = 1; this._size(); this._sync();
    }
    _size() {
      const r = this.canvas.getBoundingClientRect(); this.w = Math.max(300, r.width || this.canvas.width || 1000); this.h = Math.max(220, r.height || this.canvas.height || 550);
      const d = Math.min(window.devicePixelRatio || 1, 2); this.dpr = d;
      if (this.canvas.width !== Math.round(this.w*d) || this.canvas.height !== Math.round(this.h*d)) { this.canvas.width = Math.round(this.w*d); this.canvas.height = Math.round(this.h*d); }
      this.zoom = Math.max(.52, Math.min(.88, this.w / 1550));
    }
    _notify() { if (this.onChange) this.onChange(this.getState()); }
    setLevel(i) { this.level = Math.max(0, Math.min(4, Number(i) || 0)); this.resetView(); }
    setSeed(seed) { this.seed = Number(seed) | 0; this.resetView(); }
    setTime(t) {
      this.time = Math.max(0, Math.min(390, Number(t) || 0));
      if (this.time >= 300 && !this.portal) this.portal = {x: this.player.x + 330, y: this.player.y - 65};
      if (this.time < 300) { this.portal = null; if (this.mode === 'boss') { this.mode = 'field'; this.player = this.fieldPosition || {x: 0, y: 0}; this.cache.clear(); } }
      this._sync(); this._notify();
    }
    setOverlays(values) { Object.assign(this.overlays, values); }
    enterBoss() {
      if (this.time < 300) return false;
      this.fieldPosition = {...this.player}; this.mode = 'boss'; this.player = {x: 640, y: 500}; this.cache.clear(); this._sync(); this._notify(); return true;
    }
    resetView() { this.mode = 'field'; this.time = 0; this.player = {x: 0, y: 0}; this.portal = null; this.cache.clear(); this._sync(); this._notify(); }
    moveTo(x, y) { this.player = {x: Number(x) || 0, y: Number(y) || 0}; if (this.mode === 'boss') this._clamp(); this._sync(); this._notify(); }
    _clamp() { this.player.x = Math.max(100, Math.min(1180, this.player.x)); this.player.y = Math.max(120, Math.min(625, this.player.y)); }
    _roadDistance(x, y) {
      if (this.level === 2 || this.level === 4) return Math.min(Math.abs(x - Math.round(x/640)*640), Math.abs(y - Math.round(y/360)*360));
      if (this.level === 3) return Math.abs(x - Math.round(x/CW)*CW - Math.sin(y/850)*150);
      const bend = Math.sin(x/(this.level === 1 ? 480 : 650))* (this.level === 1 ? 130 : 85);
      return Math.min(Math.abs(y - Math.round(y/CH)*CH - bend), Math.abs(x - Math.round(x/(CW*2))*CW*2 - Math.sin(y/700)*65));
    }
    getChunk(cx, cy) {
      const s = hash(cx, cy, hash(this.level+1, 29, this.seed)), rng = random(s), ox = cx*CW, oy = cy*CH;
      const chunk = {cx, cy, trees: [], props: [], enemies: [], safe: {x: ox+640, y: oy+360, r: 118}};
      const add = (kind, x, y, h, collision = 0) => chunk.props.push({kind, x: ox+x, y: oy+y, h, flip: rng()>.5, collision});
      if (this.level === 1) { add('cart', 410, 210, 104, 28); add('house', 940, 565, 190, 55); }
      if (this.level === 2) { add('warehouse', 330, 230, 225, 70); add('house', 975, 580, 190, 60); add('lantern', 690, 280, 100); }
      if (this.level === 3) { add('cart', 350, 250, 104, 28); add('cart', 945, 530, 104, 28); add('lantern', 190, 80, 108); }
      if (this.level === 4) { for (const p of [[290,230],[950,230],[290,580],[950,580]]) add('house', p[0], p[1], 210+rng()*35, 65); add('lantern', 620, 280, 100); }
      const count = 6 + Math.floor(rng()*5);
      for (let attempts = 0; chunk.trees.length < count && attempts < 1400; attempts++) {
        const x = ox+75+rng()*1130, y = oy+60+rng()*600;
        if (Math.hypot(x, y)<155 || this._roadDistance(x,y)<82 || Math.hypot(x-chunk.safe.x,y-chunk.safe.y)<125) continue;
        if (chunk.props.some(p => Math.hypot(p.x-x,p.y-y)<(p.kind==='oak'?126:150))) continue;
        const item = {kind: 'oak', x, y, h: 190+rng()*40, flip:rng()>.5, collision:21}; chunk.trees.push(item); chunk.props.push(item);
      }
      // A sparse deterministic lattice guarantees the authored count even for dense courtyard templates.
      for (let i=0; chunk.trees.length<count && i<10000; i++) {
        const x=ox+85+mod(i*233+s,1100), y=oy+70+mod(i*173+(s>>>8),580);
        if (this._roadDistance(x,y)<60 || Math.hypot(x,y)<155 || chunk.props.some(p=>Math.hypot(p.x-x,p.y-y)<80)) continue;
        const item={kind:'oak',x,y,h:195+mod(i*17,30),flip:!!(i%2),collision:21}; chunk.trees.push(item);chunk.props.push(item);
      }
      for (let i=0; i<20; i++) {
        const x=80+rng()*1120, y=55+rng()*610;
        if (this._roadDistance(ox+x,oy+y)<68 || Math.hypot(ox+x,oy+y)<125 || chunk.props.some(p=>Math.hypot(p.x-ox-x,p.y-oy-y)<75)) continue;
        const kind=i%6===0?'fence':i%4===0?'crates':'bush'; add(kind,x,y,kind==='bush'?45+rng()*18:kind==='fence'?72:62,kind==='bush'?0:22);
      }
      for (let i=0;i<14;i++) chunk.enemies.push({x:ox+60+rng()*1160,y:oy+40+rng()*640,slot:i,phase:rng()*Math.PI*2});
      chunk.treeCount=chunk.trees.length; return chunk;
    }
    _sync() {
      const cx=Math.floor(this.player.x/CW),cy=Math.floor(this.player.y/CH),want=new Set();
      const rx=this.mode==='boss'?0:Math.ceil(this.w/this.zoom/CW/2)+1,ry=this.mode==='boss'?0:Math.ceil(this.h/this.zoom/FLAT/CH/2)+1;
      for(let y=cy-ry;y<=cy+ry;y++) for(let x=cx-rx;x<=cx+rx;x++) {const key=x+','+y;want.add(key);if(!this.cache.has(key)){this.cache.set(key,this.getChunk(x,y));this.loaded++;}}
      for(const key of this.cache.keys()) if(!want.has(key)){this.cache.delete(key);this.unloaded++;}
    }
    _collides(x,y) {
      for(const chunk of this.cache.values()) for(const p of chunk.props) if(p.collision && Math.hypot(x-p.x,(y-p.y)*1.7)<p.collision+13) return true;
      return false;
    }
    update(dt,input={x:0,y:0}) {
      dt=Math.min(.06,Math.max(0,dt||0));this.clock+=dt;const len=Math.hypot(input.x||0,input.y||0)||1;
      const vx=(input.x||0)/Math.max(1,len),vy=(input.y||0)/Math.max(1,len);this.moving=!!(vx||vy);if(vx)this.facing=vx>0?1:-1;
      if(this.moving){const speed=350;let x=this.player.x+vx*speed*dt,y=this.player.y+vy*speed*dt;
        if(this.mode==='boss'){this.player={x,y};this._clamp();}else{if(!this._collides(x,this.player.y))this.player.x=x;if(!this._collides(this.player.x,y))this.player.y=y;}
        this._sync();this._notify();}
    }
    _phase() {
      const phases=window.PREVIEW_PHASES||[];
      return phases.find(p=>this.time>=p.start&&this.time<p.end)||phases[phases.length-1]||{type:'teach',intensity:.18,cap:12};
    }
    _sampleEnemies() {
      const phase=this._phase(),intensity=Math.max(0,Math.min(1,phase.intensity||0));
      const number=Math.min(Math.max(0,phase.cap||0),Math.round(4+intensity*(phase.type==='rest'?12:18))),candidates=[];
      for(const chunk of this.cache.values())for(const e of chunk.enemies){const p=this._point(e.x,e.y);if(p.x>-50&&p.x<this.w+50&&p.y>65&&p.y<this.h+65)candidates.push(e);}
      candidates.sort((a,b)=>Math.hypot(a.x-this.player.x,a.y-this.player.y)-Math.hypot(b.x-this.player.x,b.y-this.player.y));
      return candidates.slice(0,number);
    }
    getState() {
      const chunk={x:Math.floor(this.player.x/CW),y:Math.floor(this.player.y/CH)},data=this.cache.get(chunk.x+','+chunk.y)||this.getChunk(chunk.x,chunk.y);
      return {level:this.level,seed:this.seed,mode:this.mode,time:this.time,player:{...this.player},chunk,activeChunks:this.cache.size,trees:data.treeCount,treeRange:[6,10],portalReady:this.time>=300,portal:this.portal?{...this.portal}:null,loaded:this.loaded,unloaded:this.unloaded,phaseType:this._phase().type,enemyTypes:this._types(),visibleEnemyCount:this.mode==='boss'?1:this._sampleEnemies().length,bossMove:this.mode==='boss'&&this.level===0?(Math.floor(this.clock/3)%2?'fan':'charge'):null,worldWrites:0};
    }
    _point(x,y) {return {x:this.w/2+(x-this.player.x)*this.zoom,y:this.h*.55+(y-this.player.y)*this.zoom*FLAT};}
    _worldTransform(){this.ctx.setTransform(this.dpr*this.zoom,0,0,this.dpr*this.zoom*FLAT,this.dpr*(this.w/2-this.player.x*this.zoom),this.dpr*(this.h*.55-this.player.y*this.zoom*FLAT));}
    _pattern(kind) {
      const img=this.assets[kind];if(!img || !img.complete || !img.naturalWidth)return null;
      if(!this.patterns[kind])this.patterns[kind]=this.ctx.createPattern(img,'repeat');return this.patterns[kind];
    }
    _patch(kind) {
      if(this.patches[kind])return this.patches[kind];const img=this.assets[kind];if(!img||!img.complete||!img.naturalWidth)return null;
      const c=document.createElement('canvas');c.width=c.height=256;const g=c.getContext('2d');g.fillStyle=g.createPattern(img,'repeat');g.fillRect(0,0,256,256);g.globalCompositeOperation='destination-in';
      const fade=g.createRadialGradient(128,128,28,128,128,128);fade.addColorStop(0,'#fff');fade.addColorStop(.55,'#fffc');fade.addColorStop(1,'#fff0');g.fillStyle=fade;g.fillRect(0,0,256,256);return this.patches[kind]=c;
    }
    _floor() {
      const g=this.ctx,z=this.zoom,x=this.player.x-this.w/z/2-300,y=this.player.y-this.h/z/FLAT-100,w=this.w/z+600,h=this.h/z/FLAT*2+200;
      this._worldTransform();g.fillStyle=this._pattern(this.level===4?'stone':'grass')||COLORS[this.level];g.fillRect(x,y,w,h);
      g.fillStyle=COLORS[this.level];g.globalAlpha=this.level===4?.24:.16;g.fillRect(x,y,w,h);g.globalAlpha=1;
      const patch=this._patch(this.level===4?'grass':'dirt');
      for(let gy=Math.floor(y/360);gy<(y+h)/360;gy++)for(let gx=Math.floor(x/440);gx<(x+w)/440;gx++){
        const r=random(hash(gx,gy,this.seed+this.level*773));if(r()<.24)continue;const px=gx*440+r()*240,py=gy*360+r()*180;
        if(patch){g.globalAlpha=.38+r()*.22;g.drawImage(patch,px-220,py-160,440+r()*180,320+r()*140);}
      }g.globalAlpha=1;
      g.lineCap='round';g.lineJoin='round';
      const line=(draw,width=110)=>{g.beginPath();draw();for(const [extra,alpha] of [[60,.07],[30,.12],[0,.50]]){g.lineWidth=width+extra;g.strokeStyle=this._pattern(this.level>=2?'stone':'dirt')||'#b49a70';g.globalAlpha=alpha;g.stroke();}g.globalAlpha=1;if(this.overlays.routes){g.strokeStyle='#e5c777';g.lineWidth=4/z;g.setLineDash([13/z,12/z]);g.stroke();g.setLineDash([]);}};
      if(this.level===2||this.level===4){for(let i=Math.floor(x/640);i<=(x+w)/640;i++)line(()=>{g.moveTo(i*640,y);g.lineTo(i*640,y+h)},this.level===4?145:92);for(let i=Math.floor(y/360);i<=(y+h)/360;i++)line(()=>{g.moveTo(x,i*360);g.lineTo(x+w,i*360)},this.level===4?120:82);}
      else if(this.level===3){for(let i=Math.floor(x/CW)-1;i<=(x+w)/CW+1;i++)line(()=>{for(let py=y,j=0;py<y+h+80;py+=65,j++){const px=i*CW+Math.sin(py/850)*150;j?g.lineTo(px,py):g.moveTo(px,py)}},155);}
      else {for(let i=Math.floor(y/CH)-1;i<=(y+h)/CH+1;i++)line(()=>{for(let px=x,j=0;px<x+w+80;px+=65,j++){const py=i*CH+Math.sin(px/(this.level===1?480:650))*(this.level===1?130:85);j?g.lineTo(px,py):g.moveTo(px,py)}},this.level===1?115:98);
        for(let i=Math.floor(x/(CW*2))-1;i<=(x+w)/(CW*2)+1;i++)line(()=>{for(let py=y,j=0;py<y+h+80;py+=65,j++){const px=i*CW*2+Math.sin(py/700)*65;j?g.lineTo(px,py):g.moveTo(px,py)}},78);}
      if(this.overlays.chunks){g.lineWidth=1.3/z;g.strokeStyle='#efdca46b';g.setLineDash([12/z,9/z]);for(const c of this.cache.values()){g.strokeRect(c.cx*CW,c.cy*CH,CW,CH);g.font=`${15/z}px Microsoft YaHei`;g.fillStyle='#f1dfb4';g.fillText(`区块 ${c.cx}, ${c.cy} · 树 ${c.treeCount}`,c.cx*CW+16/z,c.cy*CH+30/z);}g.setLineDash([]);}
      if(this.overlays.safe){for(const c of this.cache.values()){g.fillStyle='#6fcda51c';g.strokeStyle='#8fdfb58c';g.lineWidth=2/z;g.beginPath();g.arc(c.safe.x,c.safe.y,c.safe.r,0,Math.PI*2);g.fill();g.stroke();}}
    }
    _sprite(item) {
      const g=this.ctx,p=this._point(item.x,item.y),kind=item.kind,img=this.assets[kind]||this.assets[kind==='warehouse'?'house':kind==='cart'?'crates':kind==='lantern'?'fence':'bush'];
      let h=item.h*this.zoom,w=img&&img.naturalHeight?h*img.naturalWidth/img.naturalHeight:h*.7;
      w=Math.min(w,h*1.9);if(p.x+w<0||p.x-w>this.w||p.y<0||p.y-h>this.h)return;
      g.save();g.translate(p.x,p.y);g.fillStyle='#111b1e48';g.beginPath();g.ellipse(-w*.16,3,w*.37,Math.max(4,h*.045),-.25,0,Math.PI*2);g.fill();
      if((kind==='oak'||kind==='house'||kind==='warehouse')&&p.y>this.h*.55&&p.y<this.h*.55+h*.83&&Math.abs(p.x-this.w/2)<w*.39)g.globalAlpha=.30;
      if(item.player){g.shadowColor='#f7d67d';g.shadowBlur=10;g.globalAlpha=1;}
      const bob=item.player&&this.moving?Math.sin(this.clock*17)*2.2:0;
      if(item.flip)g.scale(-1,1);
      if(img&&img.complete&&img.naturalWidth)g.drawImage(img,-w/2,-h+bob,w,h);else {g.fillStyle='#6a6055';g.fillRect(-w/2,-h,w,h);}
      g.restore();
    }
    _types() {
      if(this.level===0){const kinds=['slime','skeleton'];if(this.time>=30)kinds.push('wolf');if(this.time>=80)kinds.push('bat');if(this.time>=145)kinds.push('spider');if(this.time>=175)kinds.push('mushroom');if(this.time>=195)kinds.push('water');return kinds;}
      const raw=this.levels[this.level]?.primary||[['slime'],['spider','skeleton'],['mushroom','slime'],['wolf','bat'],['skeleton','water']][this.level];
      const kinds=raw.slice(0,this.time<30?1:this.time<80?2:raw.length).map(x=>x==='water_spirit'?'water':x);if(this.time>=80)kinds.push(this.level===3?'water':'wolf');if(this.time>=145)kinds.push(this.level===2?'spider':'mushroom');return [...new Set(kinds)];
    }
    _warning(x,y,kind,size=1) {
      const g=this.ctx;this._worldTransform();g.save();g.translate(x,y);const pulse=.55+Math.sin(this.clock*3)*.17;
      g.lineWidth=2/this.zoom;g.strokeStyle=`rgba(246,172,100,${pulse})`;g.fillStyle=`rgba(241,143,80,${pulse*.15})`;
      if(kind==='fan'){g.strokeStyle='#85d9eeba';g.fillStyle='#a6e8f9cc';for(let i=-2;i<=2;i++){const angle=Math.PI/2+i*Math.PI/12,dx=Math.cos(angle)*285*size,dy=Math.sin(angle)*285*size,progress=.2+mod(this.clock,3)/3*.8;g.beginPath();g.moveTo(0,0);g.lineTo(dx,dy);g.stroke();g.beginPath();g.arc(dx*progress,dy*progress,5*size,0,Math.PI*2);g.fill();}}
      else if(kind==='charge'){g.fillRect(-25*size,0,50*size,270*size);g.strokeRect(-25*size,0,50*size,270*size);}
      else if(kind==='spider'){g.strokeStyle='#d9e0d9a3';for(let i=-2;i<=2;i++){g.beginPath();g.moveTo(0,0);g.lineTo(280*size,85*i*size);g.stroke();}g.beginPath();g.ellipse(230*size,0,76*size,155*size,0,0,Math.PI*2);g.fill();g.stroke();}
      else if(kind==='mushroom'){g.fillStyle='#a7bf6342';g.strokeStyle='#c8d78caa';for(let i=0;i<3;i++){g.beginPath();g.arc(Math.cos(i*2.1)*125*size,Math.sin(i*2.1)*105*size,57*size,0,Math.PI*2);g.fill();g.stroke();}}
      else if(kind==='water'){g.strokeStyle='#85d9eeba';g.fillStyle='#70b7d82e';for(let i=-1;i<=1;i++){g.beginPath();g.moveTo(0,0);g.lineTo(265*size,110*i*size);g.stroke();}}
      else if(kind==='bat'||kind==='wolf'){g.rotate(-.4);g.fillRect(-23*size,-270*size,46*size,270*size);g.strokeRect(-23*size,-270*size,46*size,270*size);}
      else {g.beginPath();g.arc(0,0,kind==='slime'?55*size:90*size,-.5,2.6);g.lineTo(0,0);g.closePath();g.fill();g.stroke();}
      g.restore();
    }
    _portal() {
      if(!this.portal||this.mode!=='field')return;const p=this._point(this.portal.x,this.portal.y),g=this.ctx;g.save();g.translate(p.x,p.y);
      const glow=g.createRadialGradient(0,-35,5,0,-35,92);glow.addColorStop(0,'#b1e6ca77');glow.addColorStop(1,'#7fccbc00');g.fillStyle=glow;g.fillRect(-100,-130,200,180);
      g.strokeStyle='#b5eed4';g.lineWidth=3;g.beginPath();g.ellipse(0,-43,30,49,0,0,Math.PI*2);g.stroke();g.strokeStyle='#d7b978';g.lineWidth=6;g.beginPath();g.ellipse(0,4,45,12,0,0,Math.PI*2);g.stroke();
      g.font='13px Microsoft YaHei';g.textAlign='center';g.fillStyle='#f3e8c9';g.fillText('Boss 入口 · 自由挑战',0,-109);g.restore();
    }
    render() {
      this._size();this._sync();const g=this.ctx;g.setTransform(this.dpr,0,0,this.dpr,0,0);g.clearRect(0,0,this.w,this.h);g.fillStyle='#152025';g.fillRect(0,0,this.w,this.h);
      g.save();if(this.mode==='boss'){const a=this._point(45,70),b=this._point(1235,665);g.beginPath();g.rect(a.x,a.y,b.x-a.x,b.y-a.y);g.clip();}
      this._floor();g.setTransform(this.dpr,0,0,this.dpr,0,0);g.restore();
      const sprites=[];
      if(this.mode==='field'){
        for(const chunk of this.cache.values())sprites.push(...chunk.props);
        const types=this._types();
        this._sampleEnemies().forEach((e,i)=>{const kind=types[mod(e.slot+i,types.length)],x=e.x+Math.sin(this.clock*.7+e.phase)*14,y=e.y+Math.cos(this.clock*.6+e.phase)*12;
          if(i<2&&this.time>25)this._warning(x,y,kind,.70);sprites.push({kind,x,y:y+(kind==='bat'?Math.sin(this.clock*5+e.phase)*8:0),h:kind==='water'?96:kind==='bat'?75:kind==='mushroom'?64:62,flip:Math.cos(e.phase)<0});});
        this._portal();
      }else{
        this._worldTransform();g.strokeStyle='#e6a290b5';g.lineWidth=2.5/this.zoom;g.strokeRect(65,90,1150,555);g.strokeStyle='#dbc99445';g.lineWidth=2;g.beginPath();g.ellipse(640,350,390,220,0,0,Math.PI*2);g.stroke();
        const kind=['boss','spider','mushroom','bat','boss'][this.level],attack=this.level===0?(Math.floor(this.clock/3)%2?'fan':'charge'):this.level===4?'water':kind;
        this._warning(640,265,attack,1.35);if(this.level===4)this._warning(420,350,'mushroom',1);
        sprites.push({kind,x:640,y:265,h:kind==='boss'?215:175,flip:false});
      }
      sprites.push({kind:'player',x:this.player.x,y:this.player.y,h:92,flip:this.facing<0,player:true});sprites.sort((a,b)=>a.y-b.y);g.setTransform(this.dpr,0,0,this.dpr,0,0);for(const sprite of sprites)this._sprite(sprite);
      const vignette=g.createRadialGradient(this.w*.5,this.h*.52,this.h*.24,this.w*.5,this.h*.5,this.w*.65);vignette.addColorStop(0,'#08111400');vignette.addColorStop(1,'#08111489');g.fillStyle=vignette;g.fillRect(0,0,this.w,this.h);
    }
  }
  window.WorldPreview=WorldPreview;
})();

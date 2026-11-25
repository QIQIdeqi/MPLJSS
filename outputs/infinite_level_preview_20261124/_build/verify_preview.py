from pathlib import Path
import html
import json
import re
from build_preview import build, chrome, BUILD, OUT

SCRIPT = r"""
(async function(){
 const checks=[], failures=[];
 const check=(ok,detail)=>{checks.push({passed:!!ok,detail});if(!ok)failures.push(detail);};
 const frames=()=>Promise.race([new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))),new Promise(resolve=>setTimeout(resolve,150))]);
 const rect=el=>{const r=el.getBoundingClientRect();return {x:r.x,y:r.y,w:r.width,h:r.height,right:r.right,bottom:r.bottom};};
 try{
  const ready=await Promise.race([window.previewReady,new Promise(resolve=>setTimeout(()=>resolve(false),4500))]);
  check(ready,'All inline images and renderer loaded');if(!ready)throw Error('Preview did not become ready');
  await frames();const api=window.previewApi;
  check(document.querySelectorAll('.level-card').length===5,'Five region cards are visible');
  for(let i=0;i<5;i++){
   document.querySelector('[data-level="'+i+'"]').click();
   check(api.getState().selectedLevel===i&&document.getElementById('region-name').textContent===PREVIEW_LEVELS[i].name,'Level '+(i+1)+' changes map and region text');
   check(document.getElementById('boss-name').textContent===PREVIEW_LEVELS[i].boss.name,'Level '+(i+1)+' changes its Boss brief');
   check(document.querySelectorAll('.level-card[aria-pressed="true"]').length===1,'One active card for level '+(i+1));
  }
  api.setLevel(1);check(document.getElementById('boss-name').textContent==='织网型首领','Second region uses approved spider Boss');
  api.setLevel(3);check(document.getElementById('boss-name').textContent==='突袭型首领','Fourth region uses approved aerial Boss');
  for(let i=0;i<5;i++){api.setLevel(i);api.setTime(0);const first=api.getState().enemyTypes.length;api.setTime(200);const late=api.getState().enemyTypes;check(first===(i===0?2:1)&&late.length>first&&document.getElementById('enemies').dataset.kinds===late.join(','),'Level '+(i+1)+' staggers threats and synchronizes the current enemy list');}
  api.setLevel(0);api.setSeed(77);api.setTime(95);
  const original=JSON.stringify(api.getChunk(0,0));
  api.moveTo(6400,3600);let far=api.getState();
  check(far.chunk.x===5&&far.chunk.y===5,'Moving beyond old map creates distant positive chunks');
  check(far.activeChunks<=49&&far.unloaded>0,'Distant chunks unload instead of accumulating');
  api.moveTo(-2560,-1440);check(api.getState().chunk.x===-2&&api.getState().chunk.y===-2,'Negative coordinates work without a world edge');
  api.moveTo(0,0);check(JSON.stringify(api.getChunk(0,0))===original,'Returning to an old chunk preserves its layout');
  api.setSeed(78);check(JSON.stringify(api.getChunk(0,0))!==original,'Different seed changes terrain and props');
  api.setSeed(77);check(JSON.stringify(api.getChunk(0,0))===original,'Re-entering the same seed reproduces the chunk');
  let countsOK=true;
  for(let i=0;i<5;i++){api.setLevel(i);for(const [x,y] of [[0,0],[3,-2],[-4,5]]){const chunk=api.getChunk(x,y);countsOK=countsOK&&chunk.trees.length>=6&&chunk.trees.length<=10;}}
  check(countsOK,'Tree count stays within 6–10 for all five regions and signed coordinates');
  api.setLevel(0);api.setTime(20);check(api.getState().phase!==undefined,'Time exposes current pacing stage');
  const phaseNames=[20,45,70,100,137,180,220,250,292,310,360,380].map(t=>{api.setTime(t);return api.getState().phase;});
  check(new Set(phaseNames).size===12,'All twelve beats, including post-300 loop, are reachable');
  for(let i=0;i<5;i++){api.setLevel(i);api.setTime(360);const peak=api.getState().visibleEnemyCount;api.setTime(380);const rest=api.getState();check(rest.phaseType==='rest'&&rest.visibleEnemyCount<peak,'Post-gate breather reduces displayed threats in level '+(i+1));}
  api.setLevel(0);
  api.setTime(299);check(!api.getState().portalReady&&document.getElementById('boss-enter').disabled&&!api.enterBoss(),'Boss cannot be entered before 300 seconds');
  api.setTime(300);check(api.getState().portalReady&&!document.getElementById('boss-enter').disabled,'Boss gate opens exactly at 300 seconds');
  const portal=JSON.stringify(api.getState().portal);api.moveTo(2560,0);
  check(JSON.stringify(api.getState().portal)===portal,'Gate stays in place when player keeps exploring');
  document.getElementById('boss-enter').click();check(api.getState().mode==='boss','Boss button enters independent arena without an event prerequisite');
  const moves=new Set();for(let i=0;i<70;i++){api.step(.06,0,0);moves.add(api.getState().bossMove);}check(moves.has('charge')&&moves.has('fan'),'First Boss shows both charge and fan warning patterns');
  api.moveTo(99999,-99999);const boss=api.getState();
  check(boss.player.x<=1180&&boss.player.y>=120,'Boss arena has finite bounds');
  document.getElementById('boss-enter').click();check(api.getState().mode!=='boss'&&api.getState().time===0,'Reset returns to ordinary preview');
  for(const id of ['show-chunks','show-routes','show-safe']){const control=document.getElementById(id);control.checked=true;control.dispatchEvent(new Event('change'));check(control.checked,'Overlay switch works: '+id);}
  api.setTime(65);const slider=document.getElementById('time');slider.value='230';slider.dispatchEvent(new Event('input'));check(api.getState().time===230,'Dragging timeline updates renderer time');
  api.setLevel(0);api.moveTo(0,0);
  const px=api.getState().player.x;api.step(.25,1,0);check(api.getState().player.x>px,'Movement steps update player position');
  document.getElementById('home').click();check(api.getState().player.x===0&&api.getState().player.y===0,'Return to start preserves the run');
  const seed=api.getState().seed;document.getElementById('reroll').click();check(api.getState().seed!==seed&&api.getState().time===0,'New-run button changes seed and resets timeline');
  api.setSeed(77);api.setTime(95);
  const speed=document.getElementById('speed');speed.value='30';speed.dispatchEvent(new Event('change'));check(api.getState().speed===30,'Playback speed selection works');
  document.getElementById('play').click();const before=api.getState().time;await frames();check(api.getState().playing&&api.getState().time>before,'Playback advances time');document.getElementById('play').click();check(!api.getState().playing,'Pause stops playback');
  const beforeMove=api.getState().player.x;
  document.body.dispatchEvent(new KeyboardEvent('keydown',{key:'d',bubbles:true}));await frames();document.body.dispatchEvent(new KeyboardEvent('keyup',{key:'d',bubbles:true}));
  check(api.getState().player.x>beforeMove,'WASD keyboard events move Lilita');
  check(api.getState().actualGameWrites===0&&api.getState().worldWrites===0,'Preview does not write game data');
  check(Array.from(document.images).every(img=>img.complete&&img.naturalWidth>0),'All visible image assets are decoded');
  const external=performance.getEntriesByType('resource').filter(r=>/^https?:/.test(r.name));
  check(external.length===0,'Preview uses no network assets');
  api.setLevel(0);api.setSeed(77);api.setTime(95);api.render();await frames();
  const page=rect(document.getElementById('app'));
  check(page.right<=innerWidth+1&&page.bottom<=innerHeight+1,'Whole artboard fits viewport');
  for(const selector of ['.masthead','.levels','.middle','.timeline','.footer']){
   const node=document.querySelector(selector),r=rect(node);
   check(r.x>=-1&&r.right<=innerWidth+1&&r.y>=-1&&r.bottom<=innerHeight+1,'Section stays on screen: '+selector);
  }
  const c=rect(document.getElementById('curve')),t=rect(document.querySelector('.timeline'));
  check(c.h>25&&c.bottom<=t.bottom&&c.w>200,'Pressure graph stays inside its panel');
  const right=document.querySelector('.detail-scroll');
  check(right.scrollWidth<=right.clientWidth+2,'Details have no horizontal clipping');
  const show=Array.from(document.querySelectorAll('.level-card')).every(el=>el.scrollWidth<=el.clientWidth+2);
  check(show,'All region names and Boss lines fit their cards');
  const seedRect=rect(document.getElementById('seed'));check(seedRect.w>=80&&seedRect.right<=innerWidth,'Seed input remains visible at this viewport');
  check((window.__previewErrors||[]).length===0,'No browser errors');
  const pre=document.createElement('pre');pre.id='preview-verification';pre.hidden=true;
  pre.textContent=JSON.stringify({viewport:[innerWidth,innerHeight],checks,failures,errors:window.__previewErrors||[],rects:{page,curve:c,timeline:t,details:rect(right)},state:api.getState()});
  document.body.append(pre);
 }catch(error){const pre=document.createElement('pre');pre.id='preview-verification';pre.hidden=true;pre.textContent=JSON.stringify({checks,failures:failures.concat(String(error)),errors:window.__previewErrors||[]});document.body.append(pre);}
})();
"""

def verify():
    target=build()
    content=target.read_text(encoding="utf-8")
    capture="<script>window.__previewErrors=[];window.addEventListener('error',e=>window.__previewErrors.push(e.message));window.addEventListener('unhandledrejection',e=>window.__previewErrors.push(String(e.reason)));</script>"
    wrapped=content.replace("<head>","<head>"+capture,1).replace("</body>","<script>"+SCRIPT+"</script></body>")
    fixture=BUILD/"verify.html"
    fixture.write_text(wrapped,encoding="utf-8")
    reports=[]
    for w,h in [(1280,720),(1920,1080)]:
        dom=chrome([f"--window-size={w},{h}","--virtual-time-budget=6500","--screenshot="+str(BUILD/f"qa_{w}.png"),"--dump-dom",fixture.as_uri()],f"verify_{w}.log")
        match=re.search(r'<pre id="preview-verification" hidden="">(.*?)</pre>',dom,re.S)
        if not match:
            (BUILD/f"unparsed_{w}.html").write_text(dom,encoding="utf-8")
            raise RuntimeError("Browser verification did not finish")
        report=json.loads(html.unescape(match.group(1)))
        reports.append(report)
        print(json.dumps({"requested":[w,h],"viewport":report.get("viewport"),"checks":len(report["checks"]),"failures":report["failures"]},ensure_ascii=False))
    (BUILD/"verification.json").write_text(json.dumps(reports,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    if any(r["failures"] for r in reports):raise RuntimeError("Preview validation has failures")

if __name__=="__main__":verify()

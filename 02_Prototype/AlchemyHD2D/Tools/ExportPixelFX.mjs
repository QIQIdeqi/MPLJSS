// Export the pinned PixelFX sources without the gallery actor, font or background.
import { mkdirSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { createFx, createFrame, clearFrame } from '../ThirdParty/PixelFX/src/core/fx.js';
import { encodePNG } from '../ThirdParty/PixelFX/tools/lib/png.mjs';
import * as Hit from '../ThirdParty/PixelFX/src/fx/impacts/hit-spark.js';
import * as Poison from '../ThirdParty/PixelFX/src/fx/nature/poison-cloud.js';
import * as Portal from '../ThirdParty/PixelFX/src/fx/arcane/portal.js';

const root = fileURLToPath(new URL('../ArtSource/PixelFX/', import.meta.url));
mkdirSync(root, { recursive: true });
const entries = [
  ['Hit', Hit, {}, 2.2],
  ['Poison', Poison, { spread:.72, palette:['#1b2a25','#304f34','#46633a','#5b7d49','#719b50','#9dbc56','#c2dc74','#e8f2b0'] }, 4.0],
  ['Portal', Portal, { palette: ['#101c20','#203a3c','#31665c','#629e83','#a8d1ab','#e2f0cb','#ffffff'] }, 4.2],
];
const manifest = { repository: 'https://github.com/patch-gg/pixelfx', commit: 'fe7103c36d94e02f2d7df7d8f7a341e493837cde', fps: 30, effects: [] };
for (const [name, mod, options, unitsPerPixel] of entries) {
  const [w,h] = mod.meta.size, [ox,oy] = mod.meta.origin;
  const count = Math.round(mod.meta.duration * 30), columns = name === 'Hit' ? 4 : 8, rows = Math.ceil(count / columns);
  const layers = {};
  for (const side of ['Back','Front']) for (const channel of ['Color','Light']) layers[side+channel] = new Uint8Array(w*h*columns*rows*4);
  const fx = createFx(mod, options), f = createFrame(w,h,-ox,-oy);
  for (let i=0;i<count;i++) {
    for (const side of ['Back','Front']) {
      clearFrame(f); fx.draw(f,side.toLowerCase());
      for (const channel of ['Color','Light']) {
        const src = f[channel.toLowerCase()], dst = layers[side+channel];
        for (let y=0;y<h;y++) for (let x=0;x<w;x++) {
          const c=src[y*w+x], k=((Math.floor(i/columns)*h+y)*w*columns+(i%columns)*w+x)*4;
          dst[k]=c&255;dst[k+1]=(c>>>8)&255;dst[k+2]=(c>>>16)&255;
          dst[k+3]=channel==='Light' ? 255 : c>>>24;
        }
      }
    }
    fx.update(1/30);
  }
  const exported=[];
  for (const [layer,bytes] of Object.entries(layers)) {
    const any=bytes.some((v,i)=>v>0 && (layer.endsWith('Light') ? i%4!==3 : i%4===3));
    if(!any) continue;
    writeFileSync(root+name+'_'+layer+'.png',encodePNG(w*columns,h*rows,bytes));exported.push(layer);
  }
  manifest.effects.push({ name, size:[w,h],origin:[ox,oy],count,columns,rows,loop:!!mod.meta.loop,unitsPerPixel,options,layers:exported });
  console.log(name, `${count} frames`, exported.join(', '));
}
writeFileSync(root+'manifest.json',JSON.stringify(manifest,null,2)+'\n');

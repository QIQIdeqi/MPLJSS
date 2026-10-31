"""Pack sprite-gen curated poses for the existing 512px/488 baseline runtime.

This integration step scales a complete state by one factor; it never redraws,
interpolates, rotates, or independently enlarges a collapsed pose.
"""
from pathlib import Path
import hashlib
import json
from PIL import Image

root=Path(__file__).resolve().parents[1]
art=root/'ArtSource/RoseMageAnimation_20261031'
runtime=art/'Runtime'
runtime.mkdir(parents=True,exist_ok=True)
states=[('walk',6,8,True),('hurt',4,10,False),('death',6,8,False)]
report={'generation':'Native built-in image_gen; nine independently drawn directional state strips',
        'extraction':'Installed sprite-gen components, compose, preview, inspect, export-pngs',
        'integration':'Uniform per-state scale from curated frames, groundline retained; no invented motion',
        'cell':[512,512], 'baseline':488,'body_height_px':320,'directions':{},
        'limitations':['Foot contact/stride has not been metrically calibrated.',
                       'Gameplay size and state transition visual acceptance require the in-engine run.']}
for direction in ('Side','Front','Back'):
    run=art/direction/'run'
    atlas=Image.new('RGBA',(3072,1536))
    info={}
    for row,(state,count,fps,loop) in enumerate(states):
        sources=[run/'curated'/f'{state}-frame-{i}.png' for i in range(count)]
        frames=[Image.open(p).convert('RGBA') for p in sources]
        heights=[f.getbbox()[3]-f.getbbox()[1] for f in frames]
        factor=320/max(heights)
        boxes=[]
        normalized=[]
        for index,frame in enumerate(frames):
            scaled=frame.resize((round(512*factor),round(512*factor)),Image.Resampling.NEAREST)
            result=Image.new('RGBA',(512,512))
            result.alpha_composite(scaled,(round(256-256*factor),488-scaled.getbbox()[3]))
            box=result.getbbox()
            assert box and box[0]>0 and box[1]>0 and box[2]<512 and box[3]==488,(direction,state,index,box)
            boxes.append(list(box))
            normalized.append(result)
            atlas.alpha_composite(result,(index*512,row*512))
        if state=='death':
            assert heights[-1]<heights[0]*.5,(direction,heights)
        # Lossless pose sequence preview; death one-shot preserves the final lying pose.
        gif_frames=[]
        for frame in normalized:
            bg=Image.new('RGBA',frame.size,(36,44,46,255))
            bg.alpha_composite(frame)
            gif_frames.append(bg.convert('RGB'))
        durations=[round(1000/fps)]*count
        if not loop:durations[-1]=1000
        gif_frames[0].save(runtime/f'{direction}_{state}.gif',save_all=True,append_images=gif_frames[1:],duration=durations,**({'loop':0} if loop else {}))
        info[state]={'row':row,'frames':count,'fps':fps,'loop':loop,'scale':factor,'boxes':boxes,
                     'input_sha256':[hashlib.sha256(p.read_bytes()).hexdigest() for p in sources]}
    path=runtime/f'T_RoseMage{direction}Motion.png'
    atlas.save(path)
    info['texture']=path.name
    info['sha256']=hashlib.sha256(path.read_bytes()).hexdigest()
    report['directions'][direction]=info
(runtime/'verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'result':'PACKED','textures':3,'authored_frames':48,'baseline':488}))

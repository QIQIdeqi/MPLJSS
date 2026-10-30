"""Create only the new Boss lock cue and fading bolt material; preserve existing art."""
import unreal as u
from pathlib import Path
import math, struct, wave

root=Path(u.Paths.project_dir()).resolve()
source=root/'ArtSource/BossPlan';source.mkdir(parents=True,exist_ok=True)
audio=source/'BossLock.wav'
with wave.open(str(audio),'wb') as w:
    w.setparams((1,2,44100,0,'NONE','not compressed'))
    w.writeframes(b''.join(struct.pack('<h',int(11000*math.sin(2*math.pi*(920*t+1600*t*t))*min(1,t/.006)*max(0,1-t/.12)**2)) for t in (i/44100 for i in range(5292))))
task=u.AssetImportTask();task.filename=str(audio);task.destination_path='/Game/Art/Audio';task.destination_name='S_BossLock';task.automated=True;task.save=True;task.replace_existing=True
u.AssetToolsHelpers.get_asset_tools().import_asset_tasks([task])
assert u.EditorAssetLibrary.load_asset('/Game/Art/Audio/S_BossLock')
path='/Game/Art/M_PlannedBossBolt'
lib=u.EditorAssetLibrary;edit=u.MaterialEditingLibrary
m=lib.load_asset(path) if lib.does_asset_exist(path) else u.AssetToolsHelpers.get_asset_tools().create_asset('M_PlannedBossBolt','/Game/Art',u.Material,u.MaterialFactoryNew())
edit.delete_all_material_expressions(m)
m.set_editor_property('blend_mode',u.BlendMode.BLEND_TRANSLUCENT);m.set_editor_property('shading_model',u.MaterialShadingModel.MSM_UNLIT);m.set_editor_property('two_sided',True)
def node(kind,**props):
    n=edit.create_material_expression(m,kind)
    for k,v in props.items():n.set_editor_property(k,v)
    return n
def link(a,b,pin):
    if pin=='Input':pin=edit.get_material_expression_input_names(b)[0]
    assert edit.connect_material_expressions(a,'',b,pin)
tint=node(u.MaterialExpressionVectorParameter,parameter_name='Tint',default_value=u.LinearColor(.15,.9,1,1))
glow=node(u.MaterialExpressionMultiply,const_b=2);link(tint,glow,'A');assert edit.connect_material_property(glow,'',u.MaterialProperty.MP_EMISSIVE_COLOR)
uv=node(u.MaterialExpressionTextureCoordinate);center=node(u.MaterialExpressionConstant2Vector,r=.5,g=.5)
dist=node(u.MaterialExpressionDistance);link(uv,dist,'A');link(center,dist,'B')
outer=node(u.MaterialExpressionSubtract,const_a=.5);link(dist,outer,'B')
scale=node(u.MaterialExpressionMultiply,const_b=12);link(outer,scale,'A')
clamp=node(u.MaterialExpressionClamp);link(scale,clamp,'Input')
opacity=node(u.MaterialExpressionScalarParameter,parameter_name='Opacity',default_value=1)
alpha=node(u.MaterialExpressionMultiply);link(clamp,alpha,'A');link(opacity,alpha,'B')
assert edit.connect_material_property(alpha,'',u.MaterialProperty.MP_OPACITY)
edit.recompile_material(m);assert lib.save_loaded_asset(m)
u.log('BOSS_PLAN_PRESENTATION_PASS')

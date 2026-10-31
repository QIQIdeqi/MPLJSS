"""Import retained RoseMage art; does not load/change any map or old V3 asset."""
from pathlib import Path
import unreal as u

root=Path(u.Paths.project_dir()).resolve()
source=root/'ArtSource/BattlePresentation_20261031/RoseMage'
target='/Game/Characters/RoseMage'
lib=u.EditorAssetLibrary
tools=u.AssetToolsHelpers.get_asset_tools()
edit=u.MaterialEditingLibrary
lib.make_directory(target)
textures={}
for view in ('Front','Back','Side','Attack','Portrait'):
    name=f'T_RoseMage{view}'
    task=u.AssetImportTask()
    task.filename=str(source/f'{name}.png')
    task.destination_path=target
    task.destination_name=name
    task.automated=True
    task.replace_existing=True
    task.save=True
    tools.import_asset_tasks([task])
    tex=lib.load_asset(f'{target}/{name}')
    assert tex,name
    tex.set_editor_property('filter',u.TextureFilter.TF_NEAREST)
    tex.set_editor_property('mip_gen_settings',u.TextureMipGenSettings.TMGS_NO_MIPMAPS)
    tex.set_editor_property('compression_settings',u.TextureCompressionSettings.TC_EDITOR_ICON)
    tex.set_editor_property('compression_no_alpha',False)
    lib.save_loaded_asset(tex)
    textures[view]=tex
name='M_RoseMage'
material=lib.load_asset(f'{target}/{name}') if lib.does_asset_exist(f'{target}/{name}') else tools.create_asset(name,target,u.Material,u.MaterialFactoryNew())
edit.delete_all_material_expressions(material)
material.set_editor_property('blend_mode',u.BlendMode.BLEND_TRANSLUCENT)
material.set_editor_property('two_sided',True)
material.set_editor_property('shading_model',u.MaterialShadingModel.MSM_UNLIT)

def node(cls,x=0,y=0):return edit.create_material_expression(material,cls,x,y)
def connect(a,out,b,pin=''):assert edit.connect_material_expressions(a,out,b,pin)

sample=node(u.MaterialExpressionTextureSampleParameter2D,400,0)
sample.set_editor_property('parameter_name','SpriteSheet')
sample.set_editor_property('texture',textures['Front'])
uv=node(u.MaterialExpressionTextureCoordinate,-600,0)
scale=node(u.MaterialExpressionVectorParameter,-600,150)
scale.set_editor_property('parameter_name','UVScale')
scale.set_editor_property('default_value',u.LinearColor(1,1,0,0))
offset=node(u.MaterialExpressionVectorParameter,-300,240)
offset.set_editor_property('parameter_name','UVOffset')
offset.set_editor_property('default_value',u.LinearColor(0,0,0,0))
masks=[]
for parameter in (scale,offset):
    mask=node(u.MaterialExpressionComponentMask)
    mask.set_editor_property('r',True)
    mask.set_editor_property('g',True)
    connect(parameter,'',mask)
    masks.append(mask)
multiply=node(u.MaterialExpressionMultiply,-200,0)
add=node(u.MaterialExpressionAdd,100,0)
connect(uv,'',multiply,'A')
connect(masks[0],'',multiply,'B')
connect(multiply,'',add,'A')
connect(masks[1],'',add,'B')
connect(add,'',sample)
tint=node(u.MaterialExpressionVectorParameter,400,250)
tint.set_editor_property('parameter_name','SpriteTint')
tint.set_editor_property('default_value',u.LinearColor(1,1,1,1))
color=node(u.MaterialExpressionMultiply,700,0)
alpha=node(u.MaterialExpressionMultiply,700,200)
connect(sample,'RGB',color,'A')
connect(tint,'',color,'B')
connect(sample,'A',alpha,'A')
connect(tint,'A',alpha,'B')
assert edit.connect_material_property(color,'',u.MaterialProperty.MP_EMISSIVE_COLOR)
assert edit.connect_material_property(alpha,'',u.MaterialProperty.MP_OPACITY)
edit.recompile_material(material)
lib.save_loaded_asset(material)
u.log('ROSE_MAGE_IMPORT_PASS '+target+' portrait='+textures['Portrait'].get_path_name())

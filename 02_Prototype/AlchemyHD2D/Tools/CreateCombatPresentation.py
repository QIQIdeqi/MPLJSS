"""Create native materials for readable boss telegraphs and a soft character ground shadow."""
import unreal as u
lib=u.EditorAssetLibrary
edit=u.MaterialEditingLibrary
tools=u.AssetToolsHelpers.get_asset_tools()
for name in ('M_ArenaRing','M_ThreatLane','M_SoftShadow','M_HostileBolt'):
    path='/Game/Art/'+name
    mat=lib.load_asset(path) if lib.does_asset_exist(path) else tools.create_asset(name,'/Game/Art',u.Material,u.MaterialFactoryNew())
    edit.delete_all_material_expressions(mat)
    mat.set_editor_property('blend_mode',u.BlendMode.BLEND_TRANSLUCENT)
    mat.set_editor_property('shading_model',u.MaterialShadingModel.MSM_UNLIT)
    mat.set_editor_property('two_sided',True)
    def node(kind,**props):
        n=edit.create_material_expression(mat,kind)
        for key,value in props.items():n.set_editor_property(key,value)
        return n
    def link(a,b,pin):
        if pin=='Input':pin=edit.get_material_expression_input_names(b)[0]
        assert edit.connect_material_expressions(a,'',b,pin),(name,pin)
    tint=node(u.MaterialExpressionVectorParameter,parameter_name='Tint',default_value=u.LinearColor(.01,.025,.025,1) if name=='M_SoftShadow' else u.LinearColor(1,.65,.2,1))
    color=tint
    if name=='M_HostileBolt':
        color=node(u.MaterialExpressionMultiply,const_b=2.4);link(tint,color,'A')
    edit.connect_material_property(color,'',u.MaterialProperty.MP_EMISSIVE_COLOR)
    if name=='M_ThreatLane':
        alpha=node(u.MaterialExpressionConstant,r=.32)
    else:
        uv=node(u.MaterialExpressionTextureCoordinate)
        center=node(u.MaterialExpressionConstant2Vector,r=.5,g=.5)
        distance=node(u.MaterialExpressionDistance);link(uv,distance,'A');link(center,distance,'B')
        outer=node(u.MaterialExpressionSubtract,const_a=.5);link(distance,outer,'B')
        scale=node(u.MaterialExpressionMultiply,const_b=180 if name=='M_ArenaRing' else 2);link(outer,scale,'A')
        limit=node(u.MaterialExpressionClamp);link(scale,limit,'Input')
        if name=='M_ArenaRing':
            inner=node(u.MaterialExpressionSubtract,const_b=.487);link(distance,inner,'A')
            factor=node(u.MaterialExpressionMultiply,const_b=180);link(inner,factor,'A')
            clamp=node(u.MaterialExpressionClamp);link(factor,clamp,'Input')
            alpha=node(u.MaterialExpressionMultiply);link(clamp,alpha,'A');link(limit,alpha,'B')
        else:
            falloff=node(u.MaterialExpressionPower,const_exponent=2);link(limit,falloff,'Base')
            alpha=node(u.MaterialExpressionMultiply,const_b=.95 if name=='M_HostileBolt' else .5);link(falloff,alpha,'A')
    assert edit.connect_material_property(alpha,'',u.MaterialProperty.MP_OPACITY)
    edit.recompile_material(mat);lib.save_loaded_asset(mat)
    u.log('COMBAT_PRESENTATION_MATERIAL_OK '+path)

from pathlib import Path
source=Path(u.Paths.project_dir())/'ArtSource/BossCorruption.png'
assert source.is_file(),source
task=u.AssetImportTask();task.filename=str(source);task.destination_path='/Game/Art';task.destination_name='BossCorruption';task.automated=True;task.save=True;task.replace_existing=True
tools.import_asset_tasks([task]);tex=lib.load_asset('/Game/Art/BossCorruption');assert tex
tex.set_editor_property('filter',u.TextureFilter.TF_NEAREST)
tex.set_editor_property('mip_gen_settings',u.TextureMipGenSettings.TMGS_NO_MIPMAPS)
tex.set_editor_property('compression_settings',u.TextureCompressionSettings.TC_EDITOR_ICON)
lib.save_loaded_asset(tex)
for lit in (False,True):
    name='M_BossCorruption'+('_Lit' if lit else '')
    mat=lib.load_asset('/Game/Art/'+name) if lib.does_asset_exist('/Game/Art/'+name) else tools.create_asset(name,'/Game/Art',u.Material,u.MaterialFactoryNew())
    edit.delete_all_material_expressions(mat);mat.set_editor_property('blend_mode',u.BlendMode.BLEND_MASKED);mat.set_editor_property('two_sided',True)
    mat.set_editor_property('shading_model',u.MaterialShadingModel.MSM_DEFAULT_LIT if lit else u.MaterialShadingModel.MSM_UNLIT)
    sample=edit.create_material_expression(mat,u.MaterialExpressionTextureSample);sample.set_editor_property('texture',tex)
    assert edit.connect_material_property(sample,'RGB',u.MaterialProperty.MP_BASE_COLOR if lit else u.MaterialProperty.MP_EMISSIVE_COLOR)
    assert edit.connect_material_property(sample,'A',u.MaterialProperty.MP_OPACITY_MASK)
    edit.recompile_material(mat);lib.save_loaded_asset(mat)

# Retain the authored ground textures and collision, but blend their square edges into grass.
mat=lib.load_asset('/Game/Design/M_DesignerGround');assert mat
edit.delete_all_material_expressions(mat)
mat.set_editor_property('shading_model',u.MaterialShadingModel.MSM_DEFAULT_LIT)
image=node(u.MaterialExpressionTextureSampleParameter2D,parameter_name='Image',texture=lib.load_asset('/Game/Art/Grass'))
grass=node(u.MaterialExpressionTextureSample,texture=lib.load_asset('/Game/Art/Grass'))
uv=node(u.MaterialExpressionTextureCoordinate);center=node(u.MaterialExpressionConstant2Vector,r=.5,g=.5)
distance=node(u.MaterialExpressionDistance);link(uv,distance,'A');link(center,distance,'B')
scale=node(u.MaterialExpressionMultiply,const_b=1.9);link(distance,scale,'A')
invert=node(u.MaterialExpressionOneMinus);link(scale,invert,'Input')
clamp=node(u.MaterialExpressionClamp);link(invert,clamp,'Input')
blend=node(u.MaterialExpressionLinearInterpolate);link(grass,blend,'A');link(image,blend,'B');link(clamp,blend,'Alpha')
tint=node(u.MaterialExpressionVectorParameter,parameter_name='GroundTint',default_value=u.LinearColor(.83,.89,.85,1))
color=node(u.MaterialExpressionMultiply);link(blend,color,'A');link(tint,color,'B')
assert edit.connect_material_property(color,'',u.MaterialProperty.MP_BASE_COLOR)
assert edit.connect_material_property(image,'A',u.MaterialProperty.MP_OPACITY_MASK)
rough=node(u.MaterialExpressionConstant,r=.96);edit.connect_material_property(rough,'',u.MaterialProperty.MP_ROUGHNESS)
edit.recompile_material(mat);lib.save_loaded_asset(mat)
u.log('COMBAT_PRESENTATION_IMPORT_PASS')

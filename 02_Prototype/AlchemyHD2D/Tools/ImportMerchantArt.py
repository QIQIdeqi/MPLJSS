"""Import the merchant sprite and author local arrival materials; no engine assets modified."""
import unreal as u
from pathlib import Path
lib=u.EditorAssetLibrary
edit=u.MaterialEditingLibrary
tools=u.AssetToolsHelpers.get_asset_tools()
task=u.AssetImportTask()
task.filename=str(Path(u.Paths.project_dir())/'ArtSource/MerchantWanderer.png')
task.destination_path='/Game/Art';task.destination_name='MerchantWanderer'
task.automated=True;task.save=True;task.replace_existing=True
tools.import_asset_tasks([task])
tex=lib.load_asset('/Game/Art/MerchantWanderer');assert tex
tex.set_editor_property('filter',u.TextureFilter.TF_NEAREST)
tex.set_editor_property('mip_gen_settings',u.TextureMipGenSettings.TMGS_NO_MIPMAPS)
tex.set_editor_property('compression_settings',u.TextureCompressionSettings.TC_EDITOR_ICON)
lib.save_loaded_asset(tex)

def material(name):
    m=lib.load_asset('/Game/Art/'+name) if lib.does_asset_exist('/Game/Art/'+name) else tools.create_asset(name,'/Game/Art',u.Material,u.MaterialFactoryNew())
    edit.delete_all_material_expressions(m)
    m.set_editor_property('two_sided',True)
    return m

for lit in (False,True):
    m=material('M_MerchantWanderer'+('_Lit' if lit else ''))
    m.set_editor_property('blend_mode',u.BlendMode.BLEND_MASKED)
    m.set_editor_property('shading_model',u.MaterialShadingModel.MSM_DEFAULT_LIT if lit else u.MaterialShadingModel.MSM_UNLIT)
    sample=edit.create_material_expression(m,u.MaterialExpressionTextureSample);sample.texture=tex
    assert edit.connect_material_property(sample,'RGB',u.MaterialProperty.MP_BASE_COLOR if lit else u.MaterialProperty.MP_EMISSIVE_COLOR)
    assert edit.connect_material_property(sample,'A',u.MaterialProperty.MP_OPACITY_MASK)
    edit.recompile_material(m);lib.save_loaded_asset(m)

for ring in (True,False):
    m=material('M_MerchantArrival' if ring else 'M_MerchantSpark')
    m.set_editor_property('blend_mode',u.BlendMode.BLEND_ADDITIVE)
    m.set_editor_property('shading_model',u.MaterialShadingModel.MSM_UNLIT)
    def node(kind,**props):
        n=edit.create_material_expression(m,kind)
        for k,v in props.items():n.set_editor_property(k,v)
        return n
    def link(a,b,pin):
        if pin=='Input':pin=edit.get_material_expression_input_names(b)[0]
        assert edit.connect_material_expressions(a,'',b,pin),pin
    tint=node(u.MaterialExpressionVectorParameter,parameter_name='Tint',default_value=u.LinearColor(.3,1,.85,1))
    edit.connect_material_property(tint,'',u.MaterialProperty.MP_EMISSIVE_COLOR)
    uv=node(u.MaterialExpressionTextureCoordinate)
    center=node(u.MaterialExpressionConstant2Vector,r=.5,g=.5)
    distance=node(u.MaterialExpressionDistance);link(uv,distance,'A');link(center,distance,'B')
    edge=node(u.MaterialExpressionSubtract,const_a=.5);link(distance,edge,'B')
    scale=node(u.MaterialExpressionMultiply,const_b=110 if ring else 2);link(edge,scale,'A')
    outer=node(u.MaterialExpressionClamp);link(scale,outer,'Input')
    alpha=outer
    if ring:
        inner=node(u.MaterialExpressionSubtract,const_b=.467);link(distance,inner,'A')
        factor=node(u.MaterialExpressionMultiply,const_b=110);link(inner,factor,'A')
        clamp=node(u.MaterialExpressionClamp);link(factor,clamp,'Input')
        alpha=node(u.MaterialExpressionMultiply);link(outer,alpha,'A');link(clamp,alpha,'B')
    fade=node(u.MaterialExpressionScalarParameter,parameter_name='Fade',default_value=1)
    opacity=node(u.MaterialExpressionMultiply);link(alpha,opacity,'A');link(fade,opacity,'B')
    assert edit.connect_material_property(opacity,'',u.MaterialProperty.MP_OPACITY)
    edit.recompile_material(m);lib.save_loaded_asset(m)
u.log('MERCHANT_ART_IMPORT_PASS')

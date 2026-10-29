"""Import the merchant's canonical six-column, two-row animation atlas."""
import json
from pathlib import Path
import unreal as u
root=Path(u.Paths.project_dir())/'ArtSource/MerchantAnimation'
data=json.loads((root/'manifest.json').read_text(encoding='utf-8'))
assert data['animation']['columns']==6
assert data['animation']['rows']['idle']['frames']==4 and data['animation']['rows']['wave']['frames']==6
lib=u.EditorAssetLibrary;edit=u.MaterialEditingLibrary;tools=u.AssetToolsHelpers.get_asset_tools()
task=u.AssetImportTask();task.filename=str(root/'MerchantAnimated.png')
task.destination_path='/Game/Art';task.destination_name='MerchantAnimated'
task.automated=True;task.save=True;task.replace_existing=True;tools.import_asset_tasks([task])
tex=lib.load_asset('/Game/Art/MerchantAnimated');assert tex
tex.set_editor_property('filter',u.TextureFilter.TF_NEAREST)
tex.set_editor_property('mip_gen_settings',u.TextureMipGenSettings.TMGS_NO_MIPMAPS)
tex.set_editor_property('compression_settings',u.TextureCompressionSettings.TC_EDITOR_ICON)
lib.save_loaded_asset(tex)
for lit in (False,True):
    name='M_MerchantAnimated'+('_Lit' if lit else '')
    mat=lib.load_asset('/Game/Art/'+name) if lib.does_asset_exist('/Game/Art/'+name) else tools.create_asset(name,'/Game/Art',u.Material,u.MaterialFactoryNew())
    edit.delete_all_material_expressions(mat)
    mat.set_editor_property('blend_mode',u.BlendMode.BLEND_MASKED)
    mat.set_editor_property('two_sided',True)
    mat.set_editor_property('shading_model',u.MaterialShadingModel.MSM_DEFAULT_LIT if lit else u.MaterialShadingModel.MSM_UNLIT)
    def node(kind,**props):
        n=edit.create_material_expression(mat,kind)
        for k,v in props.items():n.set_editor_property(k,v)
        return n
    def link(a,b,pin=''):
        if not pin:pin=edit.get_material_expression_input_names(b)[0]
        assert edit.connect_material_expressions(a,'',b,pin)
    uv=node(u.MaterialExpressionTextureCoordinate)
    scale=node(u.MaterialExpressionVectorParameter,parameter_name='UVScale',default_value=u.LinearColor(1/6,1/2,0,0))
    offset=node(u.MaterialExpressionVectorParameter,parameter_name='UVOffset',default_value=u.LinearColor(0,0,0,0))
    masks=[]
    for param in (scale,offset):
        mask=node(u.MaterialExpressionComponentMask,r=True,g=True,b=False,a=False);link(param,mask);masks.append(mask)
    mul=node(u.MaterialExpressionMultiply);link(uv,mul,'A');link(masks[0],mul,'B')
    add=node(u.MaterialExpressionAdd);link(mul,add,'A');link(masks[1],add,'B')
    sample=node(u.MaterialExpressionTextureSample,texture=tex);link(add,sample)
    assert edit.connect_material_property(sample,'RGB',u.MaterialProperty.MP_BASE_COLOR if lit else u.MaterialProperty.MP_EMISSIVE_COLOR)
    assert edit.connect_material_property(sample,'A',u.MaterialProperty.MP_OPACITY_MASK)
    edit.recompile_material(mat);lib.save_loaded_asset(mat)
u.log('MERCHANT_ANIMATION_IMPORT_PASS')

"""Import the PixelFX split atlases. Does not rebuild maps or collision regions."""
import json
from pathlib import Path
import unreal as u

root=Path(u.Paths.project_dir())/'ArtSource/PixelFX'
data=json.loads((root/'manifest.json').read_text(encoding='utf-8'))
dest='/Game/VFX/PixelFX'
lib=u.EditorAssetLibrary; edit=u.MaterialEditingLibrary; tools=u.AssetToolsHelpers.get_asset_tools()
for effect in data['effects']:
    for layer in effect['layers']:
        name='T_'+effect['name']+'_'+layer
        task=u.AssetImportTask();task.filename=str(root/(effect['name']+'_'+layer+'.png'))
        task.destination_path=dest;task.destination_name=name;task.automated=True;task.replace_existing=True
        tools.import_asset_tasks([task])
        tex=lib.load_asset(dest+'/'+name)
        tex.set_editor_property('filter',u.TextureFilter.TF_NEAREST)
        tex.set_editor_property('mip_gen_settings',u.TextureMipGenSettings.TMGS_NO_MIPMAPS)
        tex.set_editor_property('compression_settings',u.TextureCompressionSettings.TC_EDITOR_ICON)
        tex.set_editor_property('never_stream',True)
        lib.save_loaded_asset(tex)

for light in (False,True):
    name='M_PixelFX_'+('Light' if light else 'Color')
    mat=lib.load_asset(dest+'/'+name) if lib.does_asset_exist(dest+'/'+name) else tools.create_asset(name,dest,u.Material,u.MaterialFactoryNew())
    edit.delete_all_material_expressions(mat)
    mat.set_editor_property('blend_mode',u.BlendMode.BLEND_ADDITIVE if light else u.BlendMode.BLEND_TRANSLUCENT)
    mat.set_editor_property('two_sided',True)
    mat.set_editor_property('shading_model',u.MaterialShadingModel.MSM_UNLIT)
    mat.set_editor_property('disable_depth_test',False)
    def node(kind,**props):
        n=edit.create_material_expression(mat,kind)
        for k,v in props.items():n.set_editor_property(k,v)
        return n
    def link(a,b,pin,output=''):
        assert edit.connect_material_expressions(a,output,b,pin)
    uv=node(u.MaterialExpressionTextureCoordinate)
    frame=node(u.MaterialExpressionScalarParameter,parameter_name='Frame',default_value=0)
    cols=node(u.MaterialExpressionScalarParameter,parameter_name='Columns',default_value=8)
    rows=node(u.MaterialExpressionScalarParameter,parameter_name='Rows',default_value=15)
    inputs=[]
    for label in ('UV','Frame','Columns','Rows'):
        ci=u.CustomInput();ci.set_editor_property('input_name',label);inputs.append(ci)
    atlas_uv=node(u.MaterialExpressionCustom,code='return (UV+float2(fmod(floor(Frame),Columns),floor(Frame/Columns)))/float2(Columns,Rows);',output_type=u.CustomMaterialOutputType.CMOT_FLOAT2,inputs=inputs)
    for label,n in zip(('UV','Frame','Columns','Rows'),(uv,frame,cols,rows)):link(n,atlas_uv,label)
    sample=node(u.MaterialExpressionTextureSampleParameter2D,parameter_name='Atlas',texture=lib.load_asset(dest+'/T_Poison_Front'+('Light' if light else 'Color')))
    link(atlas_uv,sample,'UVs')
    opacity=node(u.MaterialExpressionScalarParameter,parameter_name='Opacity',default_value=1)
    strength=node(u.MaterialExpressionScalarParameter,parameter_name='Strength',default_value=1)
    color=node(u.MaterialExpressionMultiply);link(sample,color,'A','RGB');link(strength,color,'B')
    alpha=node(u.MaterialExpressionMultiply);link(sample,alpha,'A','A');link(opacity,alpha,'B')
    assert edit.connect_material_property(color,'',u.MaterialProperty.MP_EMISSIVE_COLOR)
    assert edit.connect_material_property(alpha,'',u.MaterialProperty.MP_OPACITY)
    edit.recompile_material(mat);lib.save_loaded_asset(mat)
u.log('PIXELFX_IMPORT_PASS effects=3 depth_test=enabled color_light_separate=1')

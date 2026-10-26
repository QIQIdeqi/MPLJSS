"""Run with UnrealEditor-Cmd -run=pythonscript -script=... after compiling."""
import unreal as u
from pathlib import Path
root=Path(u.Paths.project_dir())
lib=u.EditorAssetLibrary
tools=u.AssetToolsHelpers.get_asset_tools()
for p in sorted((root/'ArtSource').glob('*.png')):
    dest='/Game/Art/'+p.stem
    if not lib.does_asset_exist(dest):
        t=u.AssetImportTask(); t.filename=str(p); t.destination_path='/Game/Art'; t.automated=True; t.save=True
        tools.import_asset_tasks([t])
    tex=lib.load_asset(dest)
    tex.set_editor_property('filter',u.TextureFilter.TF_NEAREST)
    tex.set_editor_property('mip_gen_settings',u.TextureMipGenSettings.TMGS_NO_MIPMAPS)
    tex.set_editor_property('compression_settings',u.TextureCompressionSettings.TC_EDITOR_ICON)
    lib.save_loaded_asset(tex)
    if p.stem not in ('Grass','Dirt','Stone','Disc'):
        for lit in (False,True):
            name='M_'+p.stem+('_Lit' if lit else '')
            if lib.does_asset_exist('/Game/Art/'+name): continue
            mat=tools.create_asset(name,'/Game/Art',u.Material,u.MaterialFactoryNew())
            mat.set_editor_property('blend_mode',u.BlendMode.BLEND_MASKED)
            mat.set_editor_property('two_sided',True)
            mat.set_editor_property('shading_model',u.MaterialShadingModel.MSM_DEFAULT_LIT if lit else u.MaterialShadingModel.MSM_UNLIT)
            texnode=u.MaterialEditingLibrary.create_material_expression(mat,u.MaterialExpressionTextureSample)
            texnode.texture=tex
            u.MaterialEditingLibrary.connect_material_property(texnode,'RGB',u.MaterialProperty.MP_BASE_COLOR if lit else u.MaterialProperty.MP_EMISSIVE_COLOR)
            u.MaterialEditingLibrary.connect_material_property(texnode,'A',u.MaterialProperty.MP_OPACITY_MASK)
            u.MaterialEditingLibrary.recompile_material(mat); lib.save_loaded_asset(mat)

if not lib.does_asset_exist('/Game/Art/M_Disc'):
    mat=tools.create_asset('M_Disc','/Game/Art',u.Material,u.MaterialFactoryNew())
    mat.set_editor_property('blend_mode',u.BlendMode.BLEND_MASKED); mat.set_editor_property('two_sided',True)
    tex=u.MaterialEditingLibrary.create_material_expression(mat,u.MaterialExpressionTextureSample); tex.texture=lib.load_asset('/Game/Art/Disc')
    c=u.MaterialEditingLibrary.create_material_expression(mat,u.MaterialExpressionVectorParameter); c.set_editor_property('parameter_name','Tint')
    u.MaterialEditingLibrary.connect_material_property(c,'',u.MaterialProperty.MP_BASE_COLOR)
    u.MaterialEditingLibrary.connect_material_property(tex,'A',u.MaterialProperty.MP_OPACITY_MASK)
    u.MaterialEditingLibrary.recompile_material(mat); lib.save_loaded_asset(mat)

if not lib.does_asset_exist('/Game/Art/M_World'):
    mat=tools.create_asset('M_World','/Game/Art',u.Material,u.MaterialFactoryNew())
    c=u.MaterialEditingLibrary.create_material_expression(mat,u.MaterialExpressionVectorParameter)
    c.set_editor_property('parameter_name','Tint'); c.set_editor_property('default_value',u.LinearColor(0.2,0.3,0.25,1))
    u.MaterialEditingLibrary.connect_material_property(c,'',u.MaterialProperty.MP_BASE_COLOR)
    r=u.MaterialEditingLibrary.create_material_expression(mat,u.MaterialExpressionConstant); r.set_editor_property('r',0.92)
    u.MaterialEditingLibrary.connect_material_property(r,'',u.MaterialProperty.MP_ROUGHNESS)
    u.MaterialEditingLibrary.recompile_material(mat); lib.save_loaded_asset(mat)

for name in ('Grass','Dirt','Stone'):
    path='/Game/Art/M_'+name
    if lib.does_asset_exist(path): continue
    mat=tools.create_asset('M_'+name,'/Game/Art',u.Material,u.MaterialFactoryNew())
    tex=u.MaterialEditingLibrary.create_material_expression(mat,u.MaterialExpressionTextureSample)
    tex.texture=lib.load_asset('/Game/Art/'+name)
    uv=u.MaterialEditingLibrary.create_material_expression(mat,u.MaterialExpressionWorldPosition)
    mask=u.MaterialEditingLibrary.create_material_expression(mat,u.MaterialExpressionComponentMask); mask.set_editor_property('r',True); mask.set_editor_property('g',True)
    mul=u.MaterialEditingLibrary.create_material_expression(mat,u.MaterialExpressionMultiply); mul.set_editor_property('const_b',0.004)
    u.MaterialEditingLibrary.connect_material_expressions(uv,'',mask,'Input')
    u.MaterialEditingLibrary.connect_material_expressions(mask,'',mul,'A')
    u.MaterialEditingLibrary.connect_material_expressions(mul,'',tex,'Coordinates')
    u.MaterialEditingLibrary.connect_material_property(tex,'RGB',u.MaterialProperty.MP_BASE_COLOR)
    u.MaterialEditingLibrary.recompile_material(mat); lib.save_loaded_asset(mat)

sub=u.get_editor_subsystem(u.LevelEditorSubsystem)
if not lib.does_asset_exist('/Game/Maps/Research'):
    sub.new_level('/Game/Maps/Research')
    sub.save_current_level()
u.log('ALCHEMY_BOOTSTRAP_OK')

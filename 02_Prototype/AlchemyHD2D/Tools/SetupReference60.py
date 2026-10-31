from pathlib import Path
import runpy
import unreal as u
root=Path(u.Paths.project_dir()).resolve()
runpy.run_path(str(root/'Tools/ImportBattleReferenceScene.py'))
a=u.AssetToolsHelpers.get_asset_tools();e=u.MaterialEditingLibrary;lib=u.EditorAssetLibrary
job=u.AssetImportTask();job.filename=str(root/'ArtSource/ReferenceBattle60_20261031/BossMeadow.png');job.destination_path='/Game/ReferenceBattle';job.destination_name='T_BossMeadow';job.automated=True;job.replace_existing=True;job.save=True
a.import_asset_tasks([job]);tex=lib.load_asset('/Game/ReferenceBattle/T_BossMeadow');assert tex
tex.set_editor_property('filter',u.TextureFilter.TF_NEAREST);tex.set_editor_property('address_x',u.TextureAddress.TA_MIRROR);tex.set_editor_property('address_y',u.TextureAddress.TA_MIRROR);lib.save_loaded_asset(tex)
path='/Game/ReferenceBattle/M_BossMeadow';mat=lib.load_asset(path) if lib.does_asset_exist(path) else a.create_asset('M_BossMeadow','/Game/ReferenceBattle',u.Material,u.MaterialFactoryNew())
e.delete_all_material_expressions(mat);mat.set_editor_property('shading_model',u.MaterialShadingModel.MSM_UNLIT)
sample=e.create_material_expression(mat,u.MaterialExpressionTextureSample);sample.set_editor_property('texture',tex)
uv=e.create_material_expression(mat,u.MaterialExpressionTextureCoordinate);uv.set_editor_property('u_tiling',2.4);uv.set_editor_property('v_tiling',2.4)
e.connect_material_expressions(uv,'',sample,'UVs');e.connect_material_property(sample,'RGB',u.MaterialProperty.MP_EMISSIVE_COLOR);e.recompile_material(mat);lib.save_loaded_asset(mat)
path='/Game/ReferenceBattle/M_Shadow';shadow=lib.load_asset(path) if lib.does_asset_exist(path) else a.create_asset('M_Shadow','/Game/ReferenceBattle',u.Material,u.MaterialFactoryNew())
e.delete_all_material_expressions(shadow);shadow.set_editor_property('blend_mode',u.BlendMode.BLEND_TRANSLUCENT);shadow.set_editor_property('shading_model',u.MaterialShadingModel.MSM_UNLIT);shadow.set_editor_property('two_sided',True)
sample=e.create_material_expression(shadow,u.MaterialExpressionTextureSample);sample.set_editor_property('texture',lib.load_asset('/Game/Art/Disc'))
alpha=e.create_material_expression(shadow,u.MaterialExpressionMultiply);alpha.set_editor_property('const_b',.25);e.connect_material_expressions(sample,'A',alpha,'A');e.connect_material_property(alpha,'',u.MaterialProperty.MP_OPACITY)
black=e.create_material_expression(shadow,u.MaterialExpressionConstant);black.set_editor_property('r',0.);e.connect_material_property(black,'',u.MaterialProperty.MP_EMISSIVE_COLOR);e.recompile_material(shadow);lib.save_loaded_asset(shadow)
path='/Game/ReferenceBattle/M_Disc';disc=lib.load_asset(path) if lib.does_asset_exist(path) else a.create_asset('M_Disc','/Game/ReferenceBattle',u.Material,u.MaterialFactoryNew())
e.delete_all_material_expressions(disc);disc.set_editor_property('blend_mode',u.BlendMode.BLEND_TRANSLUCENT);disc.set_editor_property('shading_model',u.MaterialShadingModel.MSM_UNLIT);disc.set_editor_property('two_sided',True)
sample=e.create_material_expression(disc,u.MaterialExpressionTextureSample);sample.set_editor_property('texture',lib.load_asset('/Game/Art/Disc'))
alpha=e.create_material_expression(disc,u.MaterialExpressionMultiply);alpha.set_editor_property('const_b',.5);e.connect_material_expressions(sample,'A',alpha,'A');e.connect_material_property(alpha,'',u.MaterialProperty.MP_OPACITY)
tint=e.create_material_expression(disc,u.MaterialExpressionVectorParameter);tint.set_editor_property('parameter_name','Tint');e.connect_material_property(tint,'RGB',u.MaterialProperty.MP_EMISSIVE_COLOR);e.recompile_material(disc);lib.save_loaded_asset(disc)
runpy.run_path(str(root/'Tools/ImportRoseMageMotion.py'))
runpy.run_path(str(root/'Tools/ImportReferenceUI.py'))
u.log('REFERENCE60_SETUP_PASS')

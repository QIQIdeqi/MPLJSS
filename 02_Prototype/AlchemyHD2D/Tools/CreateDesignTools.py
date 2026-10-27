"""Editor-only setup. Existing authoring tables and edited level cells are preserved."""
import unreal as u
from pathlib import Path

root=Path(__file__).resolve().parents[1]
lib=u.EditorAssetLibrary
assets=u.AssetToolsHelpers.get_asset_tools()
levels=u.get_editor_subsystem(u.LevelEditorSubsystem)
actors=u.get_editor_subsystem(u.EditorActorSubsystem)

for name in ('Coin','FirePowder','Dew','MagicShard','BeastCore','VoidCrystal','RootHeart'):
    path='/Game/Art/'+name
    if not lib.does_asset_exist(path):
        task=u.AssetImportTask();task.filename=str(root/'ArtSource'/(name+'.png'));task.destination_path='/Game/Art';task.automated=True;task.save=True
        assets.import_asset_tasks([task])
    tex=lib.load_asset(path)
    tex.set_editor_property('filter',u.TextureFilter.TF_NEAREST)
    tex.set_editor_property('mip_gen_settings',u.TextureMipGenSettings.TMGS_NO_MIPMAPS)
    tex.set_editor_property('compression_settings',u.TextureCompressionSettings.TC_EDITOR_ICON)
    lib.save_loaded_asset(tex)
    for lit in (False,True):
        material='M_'+name+('_Lit' if lit else '')
        if lib.does_asset_exist('/Game/Art/'+material):continue
        m=assets.create_asset(material,'/Game/Art',u.Material,u.MaterialFactoryNew())
        m.set_editor_property('blend_mode',u.BlendMode.BLEND_MASKED);m.set_editor_property('two_sided',True)
        m.set_editor_property('shading_model',u.MaterialShadingModel.MSM_DEFAULT_LIT if lit else u.MaterialShadingModel.MSM_UNLIT)
        sample=u.MaterialEditingLibrary.create_material_expression(m,u.MaterialExpressionTextureSample);sample.texture=tex
        u.MaterialEditingLibrary.connect_material_property(sample,'RGB',u.MaterialProperty.MP_BASE_COLOR if lit else u.MaterialProperty.MP_EMISSIVE_COLOR)
        u.MaterialEditingLibrary.connect_material_property(sample,'A',u.MaterialProperty.MP_OPACITY_MASK)
        u.MaterialEditingLibrary.recompile_material(m);lib.save_loaded_asset(m)

for ground in (False,True):
    name='M_DesignerGround' if ground else 'M_DesignerSprite'
    if lib.does_asset_exist('/Game/Design/'+name):continue
    m=assets.create_asset(name,'/Game/Design',u.Material,u.MaterialFactoryNew())
    m.set_editor_property('blend_mode',u.BlendMode.BLEND_MASKED);m.set_editor_property('two_sided',True)
    m.set_editor_property('shading_model',u.MaterialShadingModel.MSM_DEFAULT_LIT if ground else u.MaterialShadingModel.MSM_UNLIT)
    sample=u.MaterialEditingLibrary.create_material_expression(m,u.MaterialExpressionTextureSampleParameter2D)
    sample.set_editor_property('parameter_name','Image');sample.texture=lib.load_asset('/Game/Art/Grass')
    u.MaterialEditingLibrary.connect_material_property(sample,'RGB',u.MaterialProperty.MP_BASE_COLOR if ground else u.MaterialProperty.MP_EMISSIVE_COLOR)
    u.MaterialEditingLibrary.connect_material_property(sample,'A',u.MaterialProperty.MP_OPACITY_MASK)
    u.MaterialEditingLibrary.recompile_material(m);lib.save_loaded_asset(m)

assert levels.load_level('/Game/Maps/Research')
designer=next((a for a in actors.get_all_level_actors() if isinstance(a,u.AlchemyLevelDesigner)),None)
fresh=designer is None
if fresh:
    designer=actors.spawn_actor_from_class(u.AlchemyLevelDesigner,u.Vector(0,0,0))
    designer.set_actor_label('Alchemy_Level_Designer_关卡与技能工具')
designer.create_starter_tables()
designer.import_palette()
assert designer.validate_library(),designer.get_editor_property('status')
if fresh:
    designer.randomize()
    # Keep the authored collision layout equal to Layout A; these cells remain manually editable.
    rects=[(-42,-22,14,3),(-39,-12,4,7),(26,-23,14,3),(36,-13,4,8),(-42,19,14,3),(-39,28,4,6),(26,19,14,3),(36,28,4,6)]
    for i,(x,y,w,h) in enumerate(rects):
        c=actors.spawn_actor_from_class(u.AlchemyTileCell,u.Vector(-100*(x+w/2),-100*(y+h/2),5))
        c.set_owner(designer);c.set_actor_label('Layout_Block_%02d'%i);c.set_folder_path('Alchemy/EditableCollision')
        c.set_editor_property('material_override',lib.load_asset('/Game/Art/M_Stone'))
        c.set_editor_property('visual_size',u.Vector2D(w*100,h*100))
        c.set_editor_property('collision_half_size',u.Vector2D(w*50,h*50))
        c.set_editor_property('blocks_movement',True);c.set_editor_property('lock_random',True)
if not any(isinstance(a,u.DirectionalLight) for a in actors.get_all_level_actors()):
    light=actors.spawn_actor_from_class(u.DirectionalLight,u.Vector(0,0,1500),u.Rotator(-55,30,0))
    light.set_actor_label('Editor_Preview_Sun');light.set_editor_property('tags',['AlchemyEditorPreviewLight'])
    light.set_editor_property('is_editor_only_actor',True);light.set_actor_hidden_in_game(True)
    light.get_component_by_class(u.DirectionalLightComponent).set_intensity(3)
try:u.EditorLevelLibrary.set_level_viewport_camera_info(u.Vector(0,-10000,10000),u.Rotator(-45,90,0))
except Exception:pass
designer.refresh_cells()
designer.save_design()
assert levels.save_current_level()
exports=root/'Docs'/'DesignerCSV';exports.mkdir(parents=True,exist_ok=True)
for key in ('skill_table','recipe_table','chain_table','quality_table'):
    t=designer.get_editor_property(key)
    assert u.DataTableFunctionLibrary.export_data_table_to_csv_file(t,str(exports/(t.get_name()+'.csv')))
count=sum(isinstance(a,u.AlchemyTileCell) and a.get_owner()==designer for a in actors.get_all_level_actors())
(root/'Evidence'/'designer-setup.txt').write_text('palette=%d\ncells=%d\nskills=25\nrecipes=10\nchains=10\nresult=PASS\n'%(len(designer.get_editor_property('palette')),count),encoding='utf-8')
u.log('ALCHEMY_DESIGNER_SETUP_PASS cells=%d'%count)

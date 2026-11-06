"""Focus the existing authoring actor when opening the editor; does not regenerate anything."""
import unreal as u
from pathlib import Path
import json

_frame=0
def _focus_after_startup(delta):
    global _frame
    _frame+=1
    if _frame<30:return
    try:
        a=u.get_editor_subsystem(u.EditorActorSubsystem)
        random_editor='-AlchemyRandomDesigner' in u.SystemLibrary.get_command_line()
        boss_editor='-AlchemyDesignerBoss' in u.SystemLibrary.get_command_line()
        if random_editor:
            world=u.get_editor_subsystem(u.UnrealEditorSubsystem).get_editor_world()
            for name in ('Village_Reference','Outskirts_Blockout','Greyford_Boss'):
                stream=u.GameplayStatics.get_streaming_level(world,'/Game/Greyford/Maps/'+name)
                if stream and stream.get_loaded_level():
                    u.EditorLevelUtils.set_level_visibility(stream.get_loaded_level(),name==('Greyford_Boss' if boss_editor else 'Outskirts_Blockout'),False)
        designers=[x for x in a.get_all_level_actors() if isinstance(x,u.AlchemyLevelDesigner)]
        if random_editor:
            d=next((x for x in designers if x.actor_has_tag('AlchemyRandomStage') and x.get_editor_property('boss_layout')==boss_editor),None)
            if d is None:
                a.set_selected_level_actors([])
                raise RuntimeError('Missing random stage preset: '+('Alchemy_Random_Boss' if boss_editor else 'Alchemy_Random_Normal'))
        else:
            d=designers[0] if designers else None
        if random_editor:
            for old in a.get_all_level_actors():
                if old!=d and old.get_owner()!=d and not isinstance(old,(u.Light,u.CameraActor)):
                    old.set_is_temporarily_hidden_in_editor(True)
        for light in a.get_all_level_actors():
            if isinstance(light,u.DirectionalLight) and 'AlchemyEditorPreviewLight' in [str(t) for t in light.tags]:
                light.set_actor_rotation(u.Rotator(pitch=-55,yaw=30,roll=0),False)
        if d:
            d.refresh_cells()
            a.set_selected_level_actors([d])
            u.EditorLevelLibrary.set_level_viewport_camera_info(u.Vector(0,-10000,10000),u.Rotator(pitch=-45,yaw=90,roll=0))
            u.log('ALCHEMY_DESIGNER_FOCUSED')
        if '-AlchemyVerifyRandomEditor' in u.SystemLibrary.get_command_line():
            assert d and 'AlchemyRandomStage' in [str(t) for t in d.tags]
            assert d.get_actor_label()==('Alchemy_Random_Boss' if boss_editor else 'Alchemy_Random_Normal')
            assert a.get_selected_level_actors()==[d]
            assert d.get_editor_property('boss_layout')==boss_editor
            assert d.get_editor_property('camera_facing_objects') and d.get_editor_property('ground_blend_material')
            assert all(callable(getattr(d,n,None)) for n in ('randomize_ground','randomize_objects','generate_layers','paint_cell','save_design'))
            cells=[x for x in a.get_all_level_actors() if isinstance(x,u.AlchemyTileCell) and x.get_owner()==d]
            ground=sum(x.get_editor_property('ground') for x in cells)
            assert ground>0 and len(cells)>ground
            out=Path(u.Paths.project_dir()).resolve()/'Evidence/RandomLayers_20261104'
            out.mkdir(parents=True,exist_ok=True)
            (out/('editor-entry-'+('boss' if boss_editor else 'normal')+'.json')).write_text(json.dumps({'actor':d.get_path_name(),'boss':boss_editor,'ground':ground,'objects':len(cells)-ground,'result':'PASS','scope':'Editor startup selection and native reflected APIs; not mouse clicks or human usability.'},indent=2)+'\n',encoding='utf-8')
            u.log('RANDOM_EDITOR_ENTRY_PASS')
        if '-AlchemyVerifyEditorUI' in u.SystemLibrary.get_command_line():
            assert d is not None
            d.open_skills();d.open_recipes();d.open_chains();d.open_quality()
            tables=[d.skill_table,d.recipe_table,d.chain_table,d.quality_table]
            assert all(t is not None for t in tables)
            proof={'native_table_editors':[t.get_path_name() for t in tables],'result':'NATIVE_METHODS_COMPLETED','method':'four native editor UFunctions; verify corresponding asset-editor log events; desktop clicks require unlocked session'}
            (Path(u.Paths.project_dir()).resolve()/'Evidence'/'designer-ui-api.json').write_text(json.dumps(proof,ensure_ascii=False,indent=2),encoding='utf-8')
            u.log('ALCHEMY_DESIGNER_UI_API_PASS')
    except Exception as e:
        u.log_error('ALCHEMY_DESIGNER_FOCUS_ERROR '+str(e))
    finally:
        u.unregister_slate_post_tick_callback(_handle)
        if '-AlchemyVerifyEditorUI' in u.SystemLibrary.get_command_line() or '-AlchemyVerifyRandomEditor' in u.SystemLibrary.get_command_line():u.SystemLibrary.quit_editor()
_handle=u.register_slate_post_tick_callback(_focus_after_startup)

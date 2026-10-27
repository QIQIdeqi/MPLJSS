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
        d=next((x for x in a.get_all_level_actors() if isinstance(x,u.AlchemyLevelDesigner)),None)
        if d:
            a.set_selected_level_actors([d])
            u.EditorLevelLibrary.set_level_viewport_camera_info(u.Vector(0,-10000,10000),u.Rotator(-45,90,0))
            u.log('ALCHEMY_DESIGNER_FOCUSED')
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
        if '-AlchemyVerifyEditorUI' in u.SystemLibrary.get_command_line():u.SystemLibrary.quit_editor()
_handle=u.register_slate_post_tick_callback(_focus_after_startup)

"""Switch the open editor to the production flow without discarding unsaved map edits."""
import unreal as u
levels=u.get_editor_subsystem(u.LevelEditorSubsystem)
dirty=u.EditorLoadingAndSavingUtils.get_dirty_map_packages()
if dirty:
    u.log_warning('PRODUCTION_ENTRY_NOT_SWITCHED_UNSAVED_MAPS '+','.join(p.get_path_name() for p in dirty))
else:
    assert levels.load_level('/Game/Greyford/Maps/Greyford_Flow')
    world=u.get_editor_subsystem(u.UnrealEditorSubsystem).get_editor_world()
    camera=next((a for a in u.get_editor_subsystem(u.EditorActorSubsystem).get_all_level_actors() if a.actor_has_tag('BattleReferencePreviewCamera')),None)
    if camera:levels.pilot_level_actor(camera)
    u.log('PRODUCTION_ENTRY_OPEN '+world.get_path_name())
    u.log('PRODUCTION_ENTRY_MODE '+str(world.get_world_settings().get_editor_property('default_game_mode')))

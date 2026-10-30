"""Open the saved blockout from its overview camera, without regenerating actors."""
import unreal as u

_ticks=0
def _focus(delta):
    global _ticks
    _ticks+=1
    if _ticks<30:return
    try:
        actors=u.get_editor_subsystem(u.EditorActorSubsystem)
        camera=next(a for a in actors.get_all_level_actors() if isinstance(a,u.CameraActor) and a.actor_has_tag('GreyfordGenerated'))
        u.get_editor_subsystem(u.LevelEditorSubsystem).pilot_level_actor(camera)
        designer=next(a for a in actors.get_all_level_actors() if isinstance(a,u.AlchemyLevelDesigner))
        actors.set_selected_level_actors([designer])
        u.log('GREYFORD_EDITOR_FOCUSED')
    finally:u.unregister_slate_post_tick_callback(_handle)
_handle=u.register_slate_post_tick_callback(_focus)

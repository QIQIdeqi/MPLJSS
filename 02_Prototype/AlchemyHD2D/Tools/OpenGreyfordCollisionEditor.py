"""Run inside the editor to open the collision workspace without changing the game view."""
import unreal as u
levels=u.get_editor_subsystem(u.LevelEditorSubsystem);actors=u.get_editor_subsystem(u.EditorActorSubsystem)
assert levels.load_level('/Game/Greyford/Maps/Village_Reference')
regions=[a for a in actors.get_all_level_actors() if isinstance(a,u.GreyfordReferenceRegion)]
assert regions, 'Village_Reference contains no collision regions; restore or create a region before opening the collision workspace.'
target=next((a for a in regions if a.get_actor_label()=='Reference_blocked_WellBase'),regions[0])
target.align_reference_view();actors.set_selected_level_actors([target])

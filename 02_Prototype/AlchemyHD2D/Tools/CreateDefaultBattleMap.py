"""Create the direct battle entry with an editor-visible preview of the production scene."""
import json,math
from pathlib import Path
import unreal as u
root=Path(u.Paths.project_dir()).resolve()
lib=u.EditorAssetLibrary;levels=u.get_editor_subsystem(u.LevelEditorSubsystem);actors=u.get_editor_subsystem(u.EditorActorSubsystem)
path='/Game/Greyford/Maps/BattleReference'
if lib.does_asset_exist(path):assert levels.load_level(path)
else:assert levels.new_level(path)
world=u.get_editor_subsystem(u.UnrealEditorSubsystem).get_editor_world()
persistent=levels.get_current_level()
assert persistent.get_path_name().startswith(path+'.'),persistent.get_path_name()
assert levels.set_current_level_by_name('BattleReference')
world.get_world_settings().set_editor_property('default_game_mode',u.GreyfordFlowMode.static_class())
for name in ('Village_Reference','Outskirts_Blockout','Greyford_Boss'):
 stream=u.GameplayStatics.get_streaming_level(world,'/Game/Greyford/Maps/'+name)
 if stream is None:stream=u.EditorLevelUtils.add_level_to_world(world,'/Game/Greyford/Maps/'+name,u.LevelStreamingDynamic)
 assert stream,name
 stream.set_editor_property('should_be_loaded',True);stream.set_editor_property('should_be_visible',False)
 u.EditorLevelUtils.set_level_visibility(stream.get_loaded_level(),False,False)
assert levels.set_current_level_by_name('BattleReference')
for actor in list(actors.get_all_level_actors()):
 if actor.actor_has_tag('BattleReferencePreview'):actors.destroy_actor(actor)
fwd=u.Vector(0,.5,-math.sqrt(3)/2);right=u.Vector(-1,0,0);up=u.Vector(0,math.sqrt(3)/2,.5)
distance=3201.4425;camera_pos=fwd*(-distance);width=1672;height=941;focal=width/(2*1.2*math.tan(math.radians(25)))
def ground(pixel):
 ray=fwd+right*((pixel[0]-width/2)/focal)+up*((height/2-pixel[1])/focal)
 return camera_pos+ray*(-camera_pos.z/ray.z)
manifest=json.loads((root/'ArtSource/ReferenceBattle60_20261031/layers.json').read_text(encoding='utf-8'))
plane=lib.load_asset('/Engine/BasicShapes/Plane')
for layer in manifest['layers']:
 depth=9000 if layer['name']=='Backdrop' else (ground(layer['foot'])-camera_pos).dot(fwd)-.5
 w=depth*2*math.tan(math.radians(25))*1.2
 actor=actors.spawn_actor_from_class(u.StaticMeshActor,camera_pos+fwd*depth,u.MathLibrary.make_rot_from_xz(right,fwd*(-1)))
 actor.set_actor_label('BattlePreview_'+layer['name']);actor.set_folder_path('BattleReference/EditorPreview')
 actor.set_editor_property('tags',['BattleReferencePreview']);actor.set_editor_property('is_editor_only_actor',True);actor.set_actor_hidden_in_game(True)
 actor.static_mesh_component.set_static_mesh(plane);actor.static_mesh_component.set_material(0,lib.load_asset('/Game/ReferenceBattle/M_'+layer['name']))
 actor.static_mesh_component.set_collision_profile_name('NoCollision');actor.static_mesh_component.set_cast_shadow(False)
 actor.set_actor_scale3d(u.Vector(w/100,w*height/width/100,1))
cam=actors.spawn_actor_from_class(u.CameraActor,camera_pos,u.Rotator(pitch=-60,yaw=90,roll=0))
cam.set_actor_label('BattleReference_PreviewCamera_60');cam.set_editor_property('tags',['BattleReferencePreview','BattleReferencePreviewCamera']);cam.set_editor_property('is_editor_only_actor',True);cam.set_actor_hidden_in_game(True)
c=cam.camera_component;c.set_editor_property('projection_mode',u.CameraProjectionMode.PERSPECTIVE);c.set_editor_property('field_of_view',50);c.set_editor_property('aspect_ratio',width/height);c.set_editor_property('constrain_aspect_ratio',True)
pp=c.get_editor_property('post_process_settings')
for name,value in [('tone_curve_amount',0.),('expand_gamut',0.),('vignette_intensity',0.),('bloom_intensity',0.),('auto_exposure_min_brightness',1.),('auto_exposure_max_brightness',1.)]:
 pp.set_editor_property('override_'+name,True);pp.set_editor_property(name,value)
c.set_editor_property('post_process_settings',pp)
u.get_editor_subsystem(u.UnrealEditorSubsystem).set_level_viewport_camera_info(camera_pos,u.Rotator(pitch=-60,yaw=90,roll=0))
levels.pilot_level_actor(cam)
assert levels.save_current_level()
u.log('DEFAULT_BATTLE_MAP_PASS '+path+' editor_cards=7 pitch=60 hfov=50 runtime_preview_hidden=1')

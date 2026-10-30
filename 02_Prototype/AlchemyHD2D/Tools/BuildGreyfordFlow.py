"""Author the shared Greyford flow, separate Boss scene and a depth-correct all-plane bridge."""
import unreal as u
import math,json,shutil
from pathlib import Path

root=Path(u.Paths.project_dir()).resolve();work=root.parents[1]
levels=u.get_editor_subsystem(u.LevelEditorSubsystem)
actors=u.get_editor_subsystem(u.EditorActorSubsystem)
lib=u.EditorAssetLibrary;tools=u.AssetToolsHelpers.get_asset_tools();edit=u.MaterialEditingLibrary
base='/Game/Greyford/Maps/'
evidence=root/'Evidence/Greyford/Flow';evidence.mkdir(parents=True,exist_ok=True)
backup=work/'01_Skill/tmp/greyford-flow-20261030';backup.mkdir(parents=True,exist_ok=True)
plane=lib.load_asset('/Engine/BasicShapes/Plane')


def material(name,color):
    path='/Game/Greyford/Materials/'+name
    if lib.does_asset_exist(path):return lib.load_asset(path)
    m=tools.create_asset(name,'/Game/Greyford/Materials',u.Material,u.MaterialFactoryNew())
    m.set_editor_property('two_sided',True);m.set_editor_property('shading_model',u.MaterialShadingModel.MSM_UNLIT)
    c=edit.create_material_expression(m,u.MaterialExpressionConstant3Vector)
    c.set_editor_property('constant',u.LinearColor(*color,1))
    assert edit.connect_material_property(c,'',u.MaterialProperty.MP_EMISSIVE_COLOR)
    edit.recompile_material(m);assert lib.save_loaded_asset(m);return m


def card(label,p,w,h,mat,rotation=None,tag='GreyfordFlowArt'):
    a=actors.spawn_actor_from_class(u.StaticMeshActor,u.Vector(*p))
    a.set_actor_label(label);a.set_folder_path('Greyford/FlowArt')
    a.set_editor_property('tags',['GreyfordGenerated',tag])
    a.static_mesh_component.set_static_mesh(plane);a.static_mesh_component.set_material(0,mat)
    a.static_mesh_component.set_collision_profile_name('NoCollision');a.static_mesh_component.set_cast_shadow(False)
    a.set_actor_scale3d(u.Vector(w/100,h/100,1))
    if rotation:a.set_actor_rotation(rotation,False)
    return a


def sprite(label,name,p,w,h):
    up=u.Vector(0,math.sin(math.radians(48)),math.cos(math.radians(48)))
    foot=u.Vector(*p);center=foot+up*((488/512-.5)*h)
    rot=u.MathLibrary.make_rot_from_xz(u.Vector(-1,0,0),u.Vector(0,-math.cos(math.radians(48)),math.sin(math.radians(48))))
    return card(label,(center.x,center.y,center.z),w,h,lib.load_asset('/Game/Greyford/Materials/M_GF_'+name),rot)


# Ground deck and separate upright rail/post cards participate in the normal depth buffer.
village_file=root/'Content/Greyford/Maps/Village_Blockout.umap'
if not (backup/'Village_Blockout.umap').exists():shutil.copy2(village_file,backup/'Village_Blockout.umap')
assert levels.load_level(base+'Village_Blockout')
for a in list(actors.get_all_level_actors()):
    if a.actor_has_tag('GreyfordBridgeGeometry') or a.actor_has_tag('GreyfordBridgeDeck'):actors.destroy_actor(a)
    elif a.get_actor_label()=='P2_木桥':a.static_mesh_component.set_visibility(False);a.set_actor_hidden_in_game(True)
wood=material('M_GF_BridgeWood',(.36,.17,.055))
blockers=[a.get_actor_bounds(True) for a in actors.get_all_level_actors() if a.actor_has_tag('GreyfordBlocker')]
starts=[p for p in [(1800,-500,80),(1300,0,80),(2300,0,80),(1800,500,80)] if all(abs(p[0]-c.x)>e.x+45 or abs(p[1]-c.y)>e.y+45 for c,e in blockers)]
assert starts,'No clear village character start near the plaza'
for a in actors.get_all_level_actors():
    if isinstance(a,u.PlayerStart):a.set_actor_location(u.Vector(*starts[0]),False,True)
side=material('M_GF_BridgeSide',(.19,.075,.022))
light=material('M_GF_BridgeEdge',(.57,.31,.10))
seam=material('M_GF_BridgeSeam',(.12,.045,.018))
cx,cy=2700,-3300
surface=card('Bridge_HeightGuide',(cx,cy,36),360,1100,seam,tag='GreyfordBridgeDeck')
surface.static_mesh_component.set_visibility(False);surface.set_actor_hidden_in_game(True)
card('Bridge_DeckSurface',(cx,cy,36),360,800,seam,tag='GreyfordBridgeGeometry')
for s in (-1,1):
    card('Bridge_EndRamp_%d'%s,(cx,cy+s*475,18),360,math.hypot(150,36),wood,u.Rotator(roll=-s*math.degrees(math.atan2(36,150))),tag='GreyfordBridgeGeometry')
for i in range(10):
    card('Bridge_Plank_%02d'%i,(cx,cy-360+i*80,37),340,76,wood,tag='GreyfordBridgeGeometry')
    card('Bridge_PlankEdge_%02d'%i,(cx,cy-397+i*80,38),340,4,light,tag='GreyfordBridgeGeometry')
front=u.MathLibrary.make_rot_from_xz(u.Vector(1,0,0),u.Vector(0,-1,0))
side_rotation=u.MathLibrary.make_rot_from_xz(u.Vector(0,1,0),u.Vector(1,0,0))
for s in (-1,1):
    x=cx+s*162
    # Horizontal top rail plus side face; the entrance/exit stay open.
    card('Bridge_RailTop_%d'%s,(x,cy,145),18,820,light,tag='GreyfordBridgeGeometry')
    card('Bridge_RailFace_%d'%s,(x,cy,135),820,20,wood,side_rotation,tag='GreyfordBridgeGeometry')
    for i in range(4):
        y=cy-360+i*240
        card('Bridge_PostFront_%d_%d'%(s,i),(x,y,98),26,124,wood,front,tag='GreyfordBridgeGeometry')
        card('Bridge_PostSide_%d_%d'%(s,i),(x+s*13,y,98),26,124,side,side_rotation,tag='GreyfordBridgeGeometry')
        card('Bridge_PostTop_%d_%d'%(s,i),(x,y,161),28,28,light,tag='GreyfordBridgeGeometry')
assert levels.save_current_level()


# The separate empty-center Boss level uses the confirmed 32x26m ellipse as its walkable bound.
boss=base+'Greyford_Boss'
if lib.does_asset_exist(boss):assert levels.load_level(boss)
else:assert levels.new_level(boss)
for a in list(actors.get_all_level_actors()):
    if a.actor_has_tag('GreyfordBossGenerated'):actors.destroy_actor(a)
before=set(a.get_path_name() for a in actors.get_all_level_actors())
card('Boss_GrassBackdrop',(0,0,0),8000,6800,lib.load_asset('/Game/Greyford/Materials/M_GF_OutskirtsSurfaceBlend'))
ring=lib.load_asset('/Game/Art/M_ArenaRing')
ring_path='/Game/Greyford/Materials/MI_GF_BossBoundary'
boundary=lib.load_asset(ring_path) if lib.does_asset_exist(ring_path) else tools.create_asset('MI_GF_BossBoundary','/Game/Greyford/Materials',u.MaterialInstanceConstant,u.MaterialInstanceConstantFactoryNew())
edit.set_material_instance_parent(boundary,ring)
edit.set_material_instance_vector_parameter_value(boundary,'Tint',u.LinearColor(.18,.65,.60,1))
assert lib.save_loaded_asset(boundary)
card('Boss_EllipseBoundary',(0,0,5),3200,2600,boundary)
for i,(name,p,w,h) in enumerate([
    ('Oak',(-2100,950,8),1200,1300),('Oak',(2050,1000,8),1100,1200),
    ('Bush',(-1800,-650,8),550,600),('Bush',(1750,-650,8),550,600),
    ('RuneStone',(-800,1550,8),350,550),('RuneStone',(900,1500,8),350,550),
    ('Cart',(-2300,-1200,8),800,750),('Fence',(2000,-1300,8),600,600)]):sprite('Boss_Rim_%02d'%i,name,p,w,h)
start=actors.spawn_actor_from_class(u.PlayerStart,u.Vector(0,-500,80));start.set_actor_label('Boss_PlayerSouth_Test10m')
sun=actors.spawn_actor_from_class(u.DirectionalLight,u.Vector(0,0,1500),u.Rotator(pitch=-55,yaw=-35));sun.light_component.set_intensity(3)
sky=actors.spawn_actor_from_class(u.SkyLight,u.Vector(0,0,2000));sky.light_component.set_intensity(1)
for a in actors.get_all_level_actors():
    if a.get_path_name() not in before:a.set_editor_property('tags',['GreyfordBossGenerated'])
assert levels.save_current_level()


flow=base+'Greyford_Flow'
if lib.does_asset_exist(flow):assert levels.load_level(flow)
else:assert levels.new_level(flow)
world=u.get_editor_subsystem(u.UnrealEditorSubsystem).get_editor_world()
world.get_world_settings().set_editor_property('default_game_mode',u.GreyfordFlowMode.static_class())
village_name='Village_Reference' if lib.does_asset_exist(base+'Village_Reference') else 'Village_Blockout'
for name in (village_name,'Outskirts_Blockout','Greyford_Boss'):
    path=base+name
    streaming=u.GameplayStatics.get_streaming_level(world,path)
    if streaming is None:streaming=u.EditorLevelUtils.add_level_to_world(world,path,u.LevelStreamingDynamic)
    assert streaming,path
    streaming.set_editor_property('should_be_loaded',True)
    streaming.set_editor_property('should_be_visible',name==village_name)
    u.EditorLevelUtils.set_level_visibility(streaming.get_loaded_level(),name==village_name,False)
assert u.EditorLoadingAndSavingUtils.save_dirty_packages(True,True)
report=dict(flow=flow,sublevels=['Village_Blockout','Outskirts_Blockout','Greyford_Boss'],
    boss_walkable_size_cm=[3200,2600],boss_test_spacing_cm=1000,bridge_surface_z_cm=36,
    bridge='Ground deck + separate rail/post plane cards, no whole-bridge billboard',
    save_slot='GreyfordDemo_v1, separate from Research')
(evidence/'authoring-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
u.log('GREYFORD_FLOW_AUTHOR_PASS '+json.dumps(report))
import runpy
runpy.run_path(str(root/'Tools/NormalizeGreyfordScale.py'))
if (root/'ArtSource/GreyfordVillageLife20261030/manifest.json').exists():runpy.run_path(str(root/'Tools/DressGreyfordVillageLife.py'))
else:runpy.run_path(str(root/'Tools/CompactGreyfordVillage.py'))

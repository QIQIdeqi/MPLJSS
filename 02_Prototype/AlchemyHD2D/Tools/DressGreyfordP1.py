"""Replace P1 visual proxies with saved editable sprite actors, keeping native blockers."""
import unreal as u
import json,math,shutil
from pathlib import Path

root=Path(u.Paths.project_dir()).resolve()
work=root.parents[1]
plan=json.loads((work/'00_Doc/场景设计/2026-10-30_Greyford/layout.json').read_text(encoding='utf-8'))
levels=u.get_editor_subsystem(u.LevelEditorSubsystem)
actors=u.get_editor_subsystem(u.EditorActorSubsystem)
lib=u.EditorAssetLibrary
evidence=root/'Evidence/Greyford/P1';evidence.mkdir(parents=True,exist_ok=True)
backup=work/'01_Skill/tmp/greyford-p1-20261030';backup.mkdir(parents=True,exist_ok=True)
plane=lib.load_asset('/Engine/BasicShapes/Plane')
cube=lib.load_asset('/Engine/BasicShapes/Cube')
angle=math.radians(48)
up=u.Vector(0,math.sin(angle),math.cos(angle))
rotation=u.MathLibrary.make_rot_from_xz(u.Vector(-1,0,0),u.Vector(0,-math.cos(angle),math.sin(angle)))
p1={'Cottage','House','Warehouse','Oak','Bush','RuneStone'}
sizes=json.loads((root/'Tools/GreyfordScale.json').read_text(encoding='utf-8'))['sprite_sizes']
reports=[]

def position(x,y,z=0):return u.Vector(-(x-12)*600,-(y-9)*600,z)

for scene in plan['maps']:
    name=scene['id']+'_Blockout'
    src=root/('Content/Greyford/Maps/'+name+'.umap')
    if not (backup/(name+'.umap')).exists():shutil.copy2(src,backup/(name+'.umap'))
    assert levels.load_level('/Game/Greyford/Maps/'+name)
    existing={a.get_actor_label():a for a in actors.get_all_level_actors()}
    entries=[]
    for obj in scene['objects']:
        asset=obj.get('asset')
        if asset not in p1:continue
        x,y,w,h=obj['rect'];proxy=existing.get(obj['name'])
        # Newly authored vegetation has no old proxy; buildings retain their existing edited transforms.
        if proxy is None:
            assert obj['kind'] in ('tree','decor'),obj['name']
            proxy=actors.spawn_actor_from_class(u.StaticMeshActor,position(x+w/2,y+h/2,175 if obj['kind']=='tree' else 4))
            proxy.set_actor_label(obj['name']);proxy.set_folder_path('Greyford/Collision' if obj['kind']=='tree' else 'Greyford/ZoneMarkers')
            proxy.static_mesh_component.set_static_mesh(cube)
            proxy.set_actor_scale3d(u.Vector(w*6,h*6,3.5 if obj['kind']=='tree' else .08))
            proxy.static_mesh_component.set_collision_profile_name('BlockAll' if obj['kind']=='tree' else 'NoCollision')
            proxy.set_editor_property('tags',['GreyfordGenerated']+(['GreyfordBlocker'] if obj['kind']=='tree' else []))
        center=proxy.get_actor_location();extent=proxy.get_actor_scale3d()
        # Building feet sit at the front edge of their actual footprint; trunk/stone at its center.
        foot=u.Vector(center.x,center.y-(abs(extent.y)*50 if obj['kind']=='building' else 0),8)
        label='P1_'+obj['name']
        visual=existing.get(label)
        if visual is None:
            visual=actors.spawn_actor_from_class(u.StaticMeshActor,foot)
            visual.set_actor_label(label);visual.set_folder_path('Greyford/P1Art')
            visual.set_editor_property('tags',['GreyfordGenerated','GreyfordP1Visual','GFAsset_'+asset])
            mesh=visual.static_mesh_component;mesh.set_static_mesh(plane)
            mesh.set_collision_profile_name('NoCollision');mesh.set_cast_shadow(False)
            material=lib.load_asset('/Game/Greyford/Materials/M_GF_'+asset);assert material
            mesh.set_material(0,material)
            width,height=sizes[asset]
            visual.set_actor_location(foot+up*((488/512-.5)*height),False,False)
            visual.set_actor_rotation(rotation,False)
            visual.set_actor_scale3d(u.Vector(width/100,height/100,1))
        # Visibility is separate from collision and is saved with the authored map.
        proxy.static_mesh_component.set_visibility(False)
        proxy.set_actor_hidden_in_game(True)
        entries.append(dict(label=label,asset=asset,foot_cm=[foot.x,foot.y,foot.z],
            visual=visual.get_path_name(),collision_proxy=proxy.get_path_name(),
            proxy_collision=str(proxy.static_mesh_component.get_collision_profile_name())))
    assert levels.save_current_level()
    assert levels.load_level('/Game/Greyford/Maps/'+name)
    found=[a for a in actors.get_all_level_actors() if a.actor_has_tag('GreyfordP1Visual')]
    assert len(found)==len(entries),(name,len(found),len(entries))
    assert all(a.static_mesh_component.get_material(0) for a in found)
    assert all(a.static_mesh_component.get_collision_enabled()==u.CollisionEnabled.NO_COLLISION for a in found)
    reports.append(dict(map=name,visual_count=len(found),entries=entries))

(evidence/'replacement-report.json').write_text(json.dumps(reports,ensure_ascii=False,indent=2),encoding='utf-8')
assert levels.load_level('/Game/Greyford/Maps/Village_Blockout')
u.log('GREYFORD_P1_REPLACEMENT_PASS '+str([(r['map'],r['visual_count']) for r in reports]))

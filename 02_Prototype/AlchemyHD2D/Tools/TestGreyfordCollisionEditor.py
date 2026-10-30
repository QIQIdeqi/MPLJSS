"""Migrate legacy polygons; check native edits/export/save-reload without changing final geometry."""
import json,shutil,math
from pathlib import Path
import unreal as u

root=Path(u.Paths.project_dir()).resolve();out=root/'Evidence/Greyford/CollisionEditor';out.mkdir(parents=True,exist_ok=True)
source=root/'Tools/GreyfordReference.json';original=source.read_bytes();spec=json.loads(original)
levels=u.get_editor_subsystem(u.LevelEditorSubsystem);actors=u.get_editor_subsystem(u.EditorActorSubsystem)
level='/Game/Greyford/Maps/Village_Reference'
backup=out/'Village_Reference_before_editor.umap'
if not backup.exists():shutil.copy2(root/'Content/Greyford/Maps/Village_Reference.umap',backup)
assert levels.load_level(level)
regions=[a for a in actors.get_all_level_actors() if isinstance(a,u.GreyfordReferenceRegion)]
expected={f'Reference_{kind}_{r["name"]}':r['points'] for kind in ['walk','blocked'] for r in spec[kind]}
def pixels(r):return [[round(836-v.x/(180/52),3),round(470.5-v.y*math.sin(math.radians(48))/(180/52),3)] for v in r.get_world_vertices()]
for r in regions:
    r.initialize_outline();assert pixels(r)==expected[r.get_actor_label()],r.get_actor_label()
assert len(regions)==len(expected)
target=next(r for r in regions if r.get_actor_label()=='Reference_blocked_WellFrontCrate')
outline=target.outline;local=[outline.get_location_at_spline_point(i,u.SplineCoordinateSpace.LOCAL) for i in range(outline.get_number_of_spline_points())]
before=pixels(target)
outline.set_location_at_spline_point(0,local[0]+u.Vector(40,0,0),u.SplineCoordinateSpace.LOCAL)
assert pixels(target)[0]!=before[0]
outline.add_spline_point(local[-1]+u.Vector(20,0,0),u.SplineCoordinateSpace.LOCAL);assert outline.get_number_of_spline_points()==len(local)+1
outline.remove_spline_point(len(local));assert outline.get_number_of_spline_points()==len(local)
try:
    target.save_collision_layout();saved=json.loads(source.read_bytes());export=next(r for r in saved['blocked'] if r['name']=='WellFrontCrate')
    assert export['points']==pixels(target)
    assert all(saved[k]==spec[k] for k in spec if k not in ('walk','blocked'))
    assert levels.save_current_level()
    assert levels.load_level('/Game/Maps/Research');assert levels.load_level(level)
    target=next(r for r in actors.get_all_level_actors() if r.get_actor_label()=='Reference_blocked_WellFrontCrate')
    outline=target.outline;assert pixels(target)==export['points']
finally:
    source.write_bytes(original);outline.set_spline_points(local,u.SplineCoordinateSpace.LOCAL);target.initialize_outline()
assert levels.save_current_level()
assert levels.load_level('/Game/Maps/Research');assert levels.load_level(level)
regions=[a for a in actors.get_all_level_actors() if isinstance(a,u.GreyfordReferenceRegion)]
for r in regions:assert pixels(r)==expected[r.get_actor_label()],r.get_actor_label()
(out/'editor-check.json').write_text(json.dumps(dict(result='PASS',regions=len(regions),legacy_migration=True,vertex_move=True,insert_remove=True,json_export=True,other_source_fields_preserved=True,edited_map_save_reload=True,final_geometry_unchanged=True),indent=2),encoding='utf-8')
u.log('GREYFORD_COLLISION_EDITOR_PASS')

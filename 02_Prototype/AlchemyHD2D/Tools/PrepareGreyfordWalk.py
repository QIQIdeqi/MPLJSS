"""Author a reproducible native-movement route; optionally widen two authored field passages."""
import unreal as u
import json
from pathlib import Path

root=Path(u.Paths.project_dir()).resolve()
levels=u.get_editor_subsystem(u.LevelEditorSubsystem)
actors=u.get_editor_subsystem(u.EditorActorSubsystem)
assert levels.load_level('/Game/Greyford/Maps/Outskirts_Blockout')
allactors=actors.get_all_level_actors()
byname={a.get_actor_label():a for a in allactors}
after='-GreyfordAdjust' in u.SystemLibrary.get_command_line()
changes=[]
if after:
    for name,new_y in [('西北短障碍',5.5),('东侧断篱',9.5)]:
        a=byname[name];old=a.get_actor_location()
        # Only these two specifically authorised footprint transforms change; preserve size and other authoring.
        h=a.get_actor_scale3d().y*100/600
        a.set_actor_location(u.Vector(old.x,-(new_y+h/2-9)*600,old.z),False,False)
        changes.append(dict(label=name,before_cm=[old.x,old.y,old.z],after_cm=[a.get_actor_location().x,a.get_actor_location().y,old.z]))
route=[[3.5,4.4],[7.5,4.4],[7.5,6],[16.5,6],[18.5,8.5],[21.8,8.5],[21.8,10.5],[17,10.5],[12,9]]
for i,(x,y) in enumerate(route):
    label='Walk_%02d'%i
    a=byname.get(label)
    if a is None:
        a=actors.spawn_actor_from_class(u.TargetPoint,u.Vector(-(x-12)*600,-(y-9)*600,80))
        a.set_actor_label(label);a.set_folder_path('Greyford/WalkReview')
        a.set_editor_property('tags',['GreyfordGenerated','GreyfordWalk_%02d'%i])
assert levels.save_current_level()
out=root/'Evidence/Greyford/P1';out.mkdir(parents=True,exist_ok=True)
# Read actual saved footprint transforms to measure the two passages, independent of plan text.
def design_bounds(label):
    a=byname[label];p=a.get_actor_location();s=a.get_actor_scale3d()
    cx,cy=12-p.x/600,9-p.y/600;w,h=abs(s.x)/6,abs(s.y)/6
    return cx-w/2,cy-h/2,cx+w/2,cy+h/2
tree=design_bounds('老橡树树干');north=design_bounds('西北短障碍')
cart=design_bounds('东侧田车');east=design_bounds('东侧断篱')
report=dict(stage='after' if after else 'before',northwest_clear_width_cm=round((north[1]-tree[3])*600),
    eastern_clear_width_cm=round((east[1]-cart[3])*600),changes=changes,route=route,
    note='Nominal axis-aligned footprint gap; dynamic enemies and dodge envelopes not validated.')
(out/('passages-'+report['stage']+'.json')).write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
u.log('GREYFORD_PASSAGES '+json.dumps(report))

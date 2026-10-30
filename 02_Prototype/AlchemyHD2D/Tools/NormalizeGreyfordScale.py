"""Normalize saved sprite sizes around the existing 220cm player canvas and 230cm doors."""
import unreal as u
import math,json,shutil
from pathlib import Path

root=Path(u.Paths.project_dir()).resolve();work=root.parents[1]
levels=u.get_editor_subsystem(u.LevelEditorSubsystem);actors=u.get_editor_subsystem(u.EditorActorSubsystem)
lib=u.EditorAssetLibrary;edit=u.MaterialEditingLibrary
out=root/'Evidence/Greyford/Scale';out.mkdir(parents=True,exist_ok=True)
backup=work/'01_Skill/tmp/greyford-scale-20261030';backup.mkdir(parents=True,exist_ok=True)
up=u.Vector(0,math.sin(math.radians(48)),math.cos(math.radians(48)))
anchor=488/512-.5
sizes=json.loads((root/'Tools/GreyfordScale.json').read_text(encoding='utf-8'))['sprite_sizes']
reports=[]
for name in ('Village_Blockout','Outskirts_Blockout','Greyford_Boss'):
    src=root/('Content/Greyford/Maps/'+name+'.umap')
    if not (backup/src.name).exists():shutil.copy2(src,backup/src.name)
    assert levels.load_level('/Game/Greyford/Maps/'+name)
    existing={a.get_actor_label():a for a in actors.get_all_level_actors()}
    entries=[]
    for label,a in existing.items():
        if not isinstance(a,u.StaticMeshActor):continue
        mat=a.static_mesh_component.get_material(0)
        if not mat:continue
        asset=mat.get_name().removeprefix('M_GF_')
        if asset not in sizes and asset!='Fence':continue
        if not (a.actor_has_tag('GreyfordP1Visual') or a.actor_has_tag('GreyfordP2Visual') or label.startswith('Layer_EdgeBush_') or label.startswith('Boss_Rim_')):continue
        old=a.get_actor_scale3d();old_w=abs(old.x)*100;old_h=abs(old.y)*100
        foot=a.get_actor_location()-up*(anchor*old_h)
        width,height=sizes.get(asset,(old_w,200))
        if asset=='Fence' and old_h>=400:width,height=260,230
        a.set_actor_scale3d(u.Vector(width/100,height/100,1))
        a.set_actor_location(foot+up*(anchor*height),False,True)
        # Refit the existing invisible blocker to the artwork; preserve its front/foot anchor.
        proxy=existing.get(label[3:]) if label.startswith(('P1_','P2_')) else None
        if proxy and proxy.actor_has_tag('GreyfordBlocker'):
            s=proxy.get_actor_scale3d();p=proxy.get_actor_location()
            if asset in ('Cottage','House','Warehouse'):
                sx=min(abs(s.x),width*.85/100);sy=min(abs(s.y),height*.58/100)
                proxy.set_actor_scale3d(u.Vector(sx,sy,s.z))
                proxy.set_actor_location(u.Vector(p.x,foot.y+sy*50,p.z),False,True)
            elif asset=='Oak':proxy.set_actor_scale3d(u.Vector(1.4,1.4,s.z))
            elif asset in ('Well','Cart','RuneStone'):
                proxy.set_actor_scale3d(u.Vector(min(abs(s.x),width*.8/100),min(abs(s.y),height*.55/100),s.z))
        for suffix,offset,sx,sy in [('Contact',u.Vector(0,0,3),.8,.3),('Cast',u.Vector(-width*.16,height*.14,2),1.15,.55)]:
            shadow=existing.get('Shadow_'+label+'_'+suffix)
            if shadow:
                shadow.set_actor_scale3d(u.Vector(width*sx/100,width*sy/100,1))
                shadow.set_actor_location(u.Vector(foot.x+offset.x,foot.y+offset.y,offset.z),False,True)
        entries.append(dict(label=label,asset=asset,before_cm=[old_w,old_h],after_cm=[width,height],foot_cm=[foot.x,foot.y,foot.z]))
    # The long fence stays the same length; its cross-section becomes a fence, not a 3m wall.
    for label,a in existing.items():
        if not a.actor_has_tag('GreyfordBlocker') or not any(x in label for x in ('短障碍','断篱')):continue
        s=a.get_actor_scale3d()
        a.set_actor_scale3d(u.Vector(s.x if abs(s.x)>abs(s.y) else .7,.7 if abs(s.x)>abs(s.y) else s.y,s.z))
    assert levels.save_current_level()
    reports.append(dict(map=name,entries=entries))

for scene in ('Village','Outskirts'):
    path='/Game/Greyford/Materials/M_GF_'+scene+'SurfaceBlend'
    src=root/('Content/Greyford/Materials/M_GF_'+scene+'SurfaceBlend.uasset')
    if not (backup/src.name).exists():shutil.copy2(src,backup/src.name)
    mat=lib.load_asset(path);node=edit.get_material_property_input_node(mat,u.MaterialProperty.MP_EMISSIVE_COLOR)
    assert isinstance(node,u.MaterialExpressionCustom),path
    code=node.get_editor_property('code')
    for key in ('Grass','Dirt','Stone','Water'):
        code=code.replace(f'Texture2DSample({key},{key}Sampler,p)',f'Texture2DSample({key},{key}Sampler,p*3)')
    node.set_editor_property('code',code);edit.recompile_material(mat);assert lib.save_loaded_asset(mat)
report=dict(player_canvas_cm=220,cottage_door_approx_cm=230,target_sizes_cm=sizes,
            surface_texture_repeat_cm=200,logical_cell_cm=600,world_bounds_changed=False,maps=reports)
(out/'scale-authoring-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
assert levels.load_level('/Game/Greyford/Maps/Greyford_Flow')
u.log('GREYFORD_SCALE_AUTHOR_PASS '+str([(x['map'],len(x['entries'])) for x in reports]))

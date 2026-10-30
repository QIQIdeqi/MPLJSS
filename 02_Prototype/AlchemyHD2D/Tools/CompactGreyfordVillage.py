"""Bake compact village paving from editable, nonblocking level markers; leave the field intact."""
import unreal as u
import json,re,struct,shutil
from pathlib import Path

root=Path(u.Paths.project_dir()).resolve();work=root.parents[1]
levels=u.get_editor_subsystem(u.LevelEditorSubsystem);actors=u.get_editor_subsystem(u.EditorActorSubsystem)
lib=u.EditorAssetLibrary;edit=u.MaterialEditingLibrary
config=json.loads((root/'Tools/GreyfordVillageLayout.json').read_text(encoding='utf-8'))
plan=json.loads((work/'00_Doc/场景设计/2026-10-30_Greyford/layout.json').read_text(encoding='utf-8'))
scene=next(s for s in plan['maps'] if s['id']=='Village')
out=root/'Evidence/Greyford/VillageCompact';out.mkdir(parents=True,exist_ok=True)
backup=work/'01_Skill/tmp/greyford-village-compact-20261030';backup.mkdir(parents=True,exist_ok=True)
for relative in ('Maps/Village_Blockout.umap','Materials/M_GF_VillageSurfaceBlend.uasset'):
    src=root/'Content/Greyford'/relative
    if not (backup/src.name).exists():shutil.copy2(src,backup/src.name)
assert levels.load_level('/Game/Greyford/Maps/Village_Blockout')
existing={a.get_actor_label():a for a in actors.get_all_level_actors()}
cube=lib.load_asset('/Engine/BasicShapes/Cube')

def marker(label,rect,kind):
    name='Compact_'+label;a=existing.get(name)
    if a is None:
        a=actors.spawn_actor_from_class(u.StaticMeshActor,u.Vector(rect[0],rect[1],5))
        a.set_actor_label(name);a.set_folder_path('Greyford/VillagePaving')
        a.set_editor_property('tags',['GreyfordVillagePaving',kind])
        a.static_mesh_component.set_static_mesh(cube)
        a.static_mesh_component.set_collision_profile_name('NoCollision')
        a.static_mesh_component.set_visibility(False);a.set_actor_hidden_in_game(True)
        a.set_actor_scale3d(u.Vector(rect[2]/100,rect[3]/100,.1))
    # Existing marker edits are authoritative when rebaking from the level editor.
    p=a.get_actor_location();s=a.get_actor_scale3d()
    return [p.x,p.y,abs(s.x)*100,abs(s.y)*100]

roads=[marker(label,[x,y,w,h],'VillageDirt') for label,x,y,w,h in config['roads']]
configured={'Compact_'+r[0] for r in config['roads']}
for name,a in existing.items():
    if name not in configured and a.actor_has_tag('GreyfordVillagePaving') and a.actor_has_tag('VillageDirt'):
        p=a.get_actor_location();s=a.get_actor_scale3d();roads.append([p.x,p.y,abs(s.x)*100,abs(s.y)*100])
plaza=marker('公共广场',config['plaza'],'VillageStone')
gate=marker('雾门台地',config['gate_pad'],'VillageStone')
soils=[]
for label,x,y,w,h in config.get('gardens',[]):soils.append(marker(label,[x,y,w,h],'VillageGardenSoil'))
facilities=[]
for i,p in enumerate(config['facilities']):
    label='Compact_Facility_%d'%i;a=existing.get(label)
    if a is None:
        a=actors.spawn_actor_from_class(u.TargetPoint,u.Vector(*p));a.set_actor_label(label)
        a.set_folder_path('Greyford/VillageFacilities');a.set_editor_property('tags',['GreyfordVillageFacility_%d'%i])
    p=a.get_actor_location();facilities.append([p.x,p.y,p.z])

well=existing['水井'];p=well.get_actor_location();dx,dy=config['well'][0]-p.x,config['well'][1]-p.y
for label in ('水井','P2_水井','Shadow_P2_水井_Contact','Shadow_P2_水井_Cast'):
    a=existing.get(label)
    if a:a.set_actor_location(a.get_actor_location()+u.Vector(dx,dy,0),False,True)
for a in actors.get_all_level_actors():
    if isinstance(a,u.PlayerStart):a.set_actor_location(u.Vector(*config['spawn']),False,True)

cells=[a for a in actors.get_all_level_actors() if isinstance(a,u.AlchemyTileCell) and a.get_owner()]
assert len(cells)==432
old={}
for c in cells:old[(c.get_editor_property('grid_x'),c.get_editor_property('grid_y'))]=c.get_editor_property('texture').get_name().removeprefix('T_GF_')
def inside(x,y,r):return abs(x-r[0])<=r[2]/2 and abs(y-r[1])<=r[3]/2
old_paving=[o['rect'] for o in scene['objects'] if o['kind'] in ('road','plaza','gate','garden')]
colors={'Grass':(255,0,0),'Dirt':(0,255,0),'Stone':(0,0,255),'Water':(0,0,0)}
pixels=[];counts={k:0 for k in colors}
pixel=config['mask_pixel_cm'];cols,rows=int(14400/pixel),int(10800/pixel)
for row in range(rows):
    for col in range(cols):
        x,y=7200-(col+.5)*pixel,5400-(row+.5)*pixel
        gx,gy=(col+.5)*pixel/600,(row+.5)*pixel/600
        kind=old[(int(gx),int(gy))]
        if kind in ('Dirt','Stone') and any(a<=gx<a+w and b<=gy<b+h for a,b,w,h in old_paving):kind='Grass'
        if any(inside(x,y,r) for r in roads+soils):kind='Dirt'
        if inside(x,y,plaza) or inside(x,y,gate):kind='Stone'
        pixels.extend(reversed(colors[kind]));counts[kind]+=1
mask_file=root/'ArtSource/Greyford20261030/SurfaceMasks/Village-compact-mask.tga'
mask_file.write_bytes(struct.pack('<BBBHHBHHHHBB',0,0,2,0,0,0,0,0,cols,rows,24,32)+bytes(pixels))
task=u.AssetImportTask();task.filename=str(mask_file);task.destination_path='/Game/Greyford/Textures'
task.destination_name='T_GF_VillageCompactMask';task.automated=True;task.replace_existing=True;task.save=True
u.AssetToolsHelpers.get_asset_tools().import_asset_tasks([task])
mask=lib.load_asset('/Game/Greyford/Textures/T_GF_VillageCompactMask')
mask.set_editor_property('srgb',False);mask.set_editor_property('filter',u.TextureFilter.TF_NEAREST)
mask.set_editor_property('mip_gen_settings',u.TextureMipGenSettings.TMGS_NO_MIPMAPS)
mask.set_editor_property('compression_settings',u.TextureCompressionSettings.TC_VECTOR_DISPLACEMENTMAP)
mask.set_editor_property('address_x',u.TextureAddress.TA_CLAMP);mask.set_editor_property('address_y',u.TextureAddress.TA_CLAMP)
assert lib.save_loaded_asset(mask)
mat=lib.load_asset('/Game/Greyford/Materials/M_GF_VillageSurfaceBlend')
node=edit.get_material_property_input_node(mat,u.MaterialProperty.MP_EMISSIVE_COLOR)
inputs=edit.get_inputs_for_material_expression(mat,node)
layout=[n for n in inputs if isinstance(n,u.MaterialExpressionTextureObject) and n.get_editor_property('texture').get_name() in ('T_GF_VillageSurfaceMask','T_GF_VillageCompactMask')]
assert len(layout)==1;layout[0].set_editor_property('texture',mask)
code=node.get_editor_property('code')
code=re.sub(r'float2 p=float2\([^;]+;', f'float2 p=float2({cols/2:g}-World.x/{pixel},{rows/2:g}-World.y/{pixel});',code)
code=re.sub(r'float2 dim=float2\([^;]+;', f'float2 dim=float2({cols},{rows});',code)
for key in colors:
    code=code.replace(f'{key}Sampler,p*3)',f'{key}Sampler,-World.xy/200)')
node.set_editor_property('code',code);edit.recompile_material(mat);assert lib.save_loaded_asset(mat)
assert levels.save_current_level()
report=dict(plaza_before_cm=[3600,3000],plaza_after_cm=plaza,main_road_before_cm=1200,
    road_markers=roads,soil_markers=soils,facilities_cm=facilities,mask_resolution=[cols,rows],mask_pixel_cm=pixel,
    terrain_repeat_cm=200,logical_cell_cm=600,painted_cells=432,pixel_counts=counts,
    editable_markers='Greyford/VillagePaving and Greyford/VillageFacilities',field_changed=False)
(out/'authoring-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
assert levels.load_level('/Game/Greyford/Maps/Greyford_Flow')
u.log('GREYFORD_VILLAGE_COMPACT_AUTHOR_PASS '+json.dumps(report))

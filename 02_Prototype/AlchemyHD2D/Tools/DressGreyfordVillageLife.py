"""Restore the village reference's building groups, gardens, farms, banks and everyday props."""
import unreal as u
import json,math,shutil,runpy
from pathlib import Path
root=Path(u.Paths.project_dir()).resolve();work=root.parents[1]
levels=u.get_editor_subsystem(u.LevelEditorSubsystem);actors=u.get_editor_subsystem(u.EditorActorSubsystem)
lib=u.EditorAssetLibrary;edit=u.MaterialEditingLibrary;tools=u.AssetToolsHelpers.get_asset_tools()
art=root/'ArtSource/GreyfordVillageLife20261030'
spec=json.loads((root/'Tools/GreyfordVillageLife.json').read_text(encoding='utf-8'))
out=root/'Evidence/Greyford/VillageLife';out.mkdir(parents=True,exist_ok=True)
backup=work/'01_Skill/tmp/greyford-village-life-20261030';backup.mkdir(parents=True,exist_ok=True)
for relative in ('Maps/Village_Blockout.umap','Materials/M_GF_VillageSurfaceBlend.uasset','Materials/M_GF_BridgeWood.uasset'):
    src=root/'Content/Greyford'/relative
    if not (backup/src.name).exists():shutil.copy2(src,backup/src.name)
materials={}
for item in json.loads((art/'manifest.json').read_text(encoding='utf-8')):
    name=item['asset'];task=u.AssetImportTask();task.filename=str(art/(name+'.png'))
    task.destination_path='/Game/Greyford/Textures';task.destination_name='T_GF_Life_'+name
    task.automated=True;task.replace_existing=True;task.save=True;tools.import_asset_tasks([task])
    tex=lib.load_asset(task.destination_path+'/'+task.destination_name)
    tex.set_editor_property('filter',u.TextureFilter.TF_NEAREST);tex.set_editor_property('mip_gen_settings',u.TextureMipGenSettings.TMGS_NO_MIPMAPS)
    tex.set_editor_property('compression_settings',u.TextureCompressionSettings.TC_EDITOR_ICON);assert lib.save_loaded_asset(tex)
    mat_name='M_GF_Life_'+name;path='/Game/Greyford/Materials/'+mat_name
    mat=lib.load_asset(path) if lib.does_asset_exist(path) else tools.create_asset(mat_name,'/Game/Greyford/Materials',u.Material,u.MaterialFactoryNew())
    edit.delete_all_material_expressions(mat);mat.set_editor_property('two_sided',True);mat.set_editor_property('shading_model',u.MaterialShadingModel.MSM_UNLIT)
    mat.set_editor_property('blend_mode',u.BlendMode.BLEND_OPAQUE if name=='WoodGrain' else u.BlendMode.BLEND_TRANSLUCENT if name=='FogGate' else u.BlendMode.BLEND_MASKED)
    sample=edit.create_material_expression(mat,u.MaterialExpressionTextureSample);sample.set_editor_property('texture',tex)
    assert edit.connect_material_property(sample,'RGB',u.MaterialProperty.MP_EMISSIVE_COLOR)
    if name!='WoodGrain':assert edit.connect_material_property(sample,'A',u.MaterialProperty.MP_OPACITY if name=='FogGate' else u.MaterialProperty.MP_OPACITY_MASK)
    edit.recompile_material(mat);assert lib.save_loaded_asset(mat);materials[name]=mat

assert levels.load_level('/Game/Greyford/Maps/Village_Blockout')
for a in list(actors.get_all_level_actors()):
    if a.actor_has_tag('GreyfordVillageLife'):actors.destroy_actor(a)
existing={a.get_actor_label():a for a in actors.get_all_level_actors()}
plane=lib.load_asset('/Engine/BasicShapes/Plane');cube=lib.load_asset('/Engine/BasicShapes/Cube')
up=u.Vector(0,math.sin(math.radians(48)),math.cos(math.radians(48)));anchor=488/512-.5
rotation=u.MathLibrary.make_rot_from_xz(u.Vector(-1,0,0),u.Vector(0,-math.cos(math.radians(48)),math.sin(math.radians(48))))
moved=[];placed=[];skipped=[]
def move_group(label,xy):
    visual=existing['P1_'+label];h=abs(visual.get_actor_scale3d().y)*100;foot=visual.get_actor_location()-up*(anchor*h)
    delta=u.Vector(xy[0]-foot.x,xy[1]-foot.y,0)
    for name in (label,'P1_'+label,'Shadow_P1_'+label+'_Contact','Shadow_P1_'+label+'_Cast'):
        a=existing.get(name)
        if a:a.set_actor_location(a.get_actor_location()+delta,False,True)
    moved.append(dict(label=label,before=[foot.x,foot.y],after=xy))
for label,xy in spec['primary'].items():move_group(label,xy)
for row,key in ((0,'north_houses'),(16,'south_houses')):
    for col,xy in zip(range(1,23,3),spec[key]):move_group('住宅_%d_%d'%(col,row),xy)
for label,xy in spec['side_houses'].items():move_group(label,xy)
for label,xy in [('小屋旁橡树',[800,2500]),('广场南侧橡树',[-800,2500])]:move_group(label,xy)

# The workshop now has its own identifiable open-front art, rather than another residential house.
workshop=existing['P1_作坊'];old_h=abs(workshop.get_actor_scale3d().y)*100;foot=workshop.get_actor_location()-up*(anchor*old_h)
workshop.static_mesh_component.set_material(0,materials['Workshop']);workshop.set_actor_scale3d(u.Vector(9,6.5,1));workshop.set_actor_location(foot+up*(anchor*650),False,True)
proxy=existing['作坊'];s=proxy.get_actor_scale3d();proxy.set_actor_scale3d(u.Vector(7.65,3.77,s.z));p=proxy.get_actor_location();proxy.set_actor_location(u.Vector(p.x,foot.y+188.5,p.z),False,True)
for label in ('北阵石','南阵石'):
    for n in (label,'P1_'+label,'Shadow_P1_'+label+'_Contact','Shadow_P1_'+label+'_Cast'):
        a=existing.get(n)
        if a:a.set_actor_hidden_in_game(True);a.set_actor_enable_collision(False);a.set_editor_property('tags',[t for t in a.get_editor_property('tags') if str(t)!='GreyfordBlocker'])

def set_marker(label,rect,kind='VillageDirt'):
    name='Compact_'+label;a=existing.get(name)
    if a is None:
        a=actors.spawn_actor_from_class(u.StaticMeshActor,u.Vector(rect[0],rect[1],5));a.set_actor_label(name);a.set_folder_path('Greyford/VillagePaving')
        a.static_mesh_component.set_static_mesh(cube);a.static_mesh_component.set_collision_profile_name('NoCollision')
        a.static_mesh_component.set_visibility(False);a.set_actor_hidden_in_game(True);a.set_editor_property('tags',['GreyfordVillagePaving',kind]);existing[name]=a
    a.set_actor_location(u.Vector(rect[0],rect[1],5),False,True);a.set_actor_scale3d(u.Vector(rect[2]/100,rect[3]/100,.1))
for label,x,y,w,h in spec['roads']:set_marker(label,[x,y,w,h])
for label,rect in [('药圃土壤',spec['herb_garden']),('农田土壤',spec['farm'])]:set_marker(label,rect,'VillageGardenSoil')
set_marker('雾门台地',[*spec['gate'][:2],600,600],'VillageStone')
existing['Compact_Facility_2'].set_actor_location(u.Vector(*spec['gate']),False,True)

def foot_move(label,xy):
    a=existing[label];h=abs(a.get_actor_scale3d().y)*100;old=a.get_actor_location()-up*(anchor*h);delta=u.Vector(xy[0]-old.x,xy[1]-old.y,0)
    for n in (label,'Shadow_'+label+'_Contact','Shadow_'+label+'_Cast'):
        obj=existing.get(n)
        if obj:obj.set_actor_location(obj.get_actor_location()+delta,False,True)
foot_move('P2_小屋晾药架',[2050,-950]);foot_move('P2_粮仓箱袋',[-2000,-250])
blockers=[]
for a in actors.get_all_level_actors():
    if a.actor_has_tag('GreyfordBlocker'):
        c,e=a.get_actor_bounds(True);blockers.append((c.x-e.x,c.y-e.y,c.x+e.x,c.y+e.y))
def clear(x,y,w=0,d=0):return not any(x+w/2>a and x-w/2<c and y+d/2>b and y-d/2<d2 for a,b,c,d2 in blockers)
def sprite(label,asset,x,y,w,h,solid=None):
    if asset!='Waterwheel' and not clear(x,y,*(solid or (0,0))):skipped.append(label);return None
    mat=materials.get(asset) or lib.load_asset('/Game/Greyford/Materials/M_GF_'+asset);assert mat,asset
    a=actors.spawn_actor_from_class(u.StaticMeshActor,u.Vector(x,y,8)+up*(anchor*h));a.set_actor_label('Life_'+label);a.set_folder_path('Greyford/VillageLife/'+asset)
    tags=['GreyfordVillageLife']+(['GreyfordVillageFogGate'] if asset=='FogGate' else [])
    a.set_editor_property('tags',tags);a.static_mesh_component.set_static_mesh(plane);a.static_mesh_component.set_material(0,mat)
    a.static_mesh_component.set_collision_profile_name('NoCollision');a.static_mesh_component.set_cast_shadow(False);a.set_actor_rotation(rotation,False);a.set_actor_scale3d(u.Vector(w/100,h/100,1))
    if solid:
        box=actors.spawn_actor_from_class(u.StaticMeshActor,u.Vector(x,y,60));box.set_actor_label('LifeBlock_'+label);box.set_folder_path('Greyford/Collision')
        box.set_editor_property('tags',['GreyfordVillageLife','GreyfordBlocker']);box.static_mesh_component.set_static_mesh(cube);box.static_mesh_component.set_collision_profile_name('BlockAll')
        box.static_mesh_component.set_visibility(False);box.set_actor_hidden_in_game(True);box.set_actor_scale3d(u.Vector(solid[0]/100,solid[1]/100,1.2))
        blockers.append((x-solid[0]/2,y-solid[1]/2,x+solid[0]/2,y+solid[1]/2))
    shadow=actors.spawn_actor_from_class(u.StaticMeshActor,u.Vector(x,y,4));shadow.set_actor_label('LifeShadow_'+label);shadow.set_folder_path('Greyford/GroundShadows')
    shadow.set_editor_property('tags',['GreyfordVillageLife']);shadow.static_mesh_component.set_static_mesh(plane);shadow.static_mesh_component.set_material(0,lib.load_asset('/Game/Art/M_SoftShadow'))
    shadow.static_mesh_component.set_collision_profile_name('NoCollision');shadow.static_mesh_component.set_cast_shadow(False);shadow.set_actor_scale3d(u.Vector(w*.7/100,w*.28/100,1))
    placed.append(dict(label=label,asset=asset,foot=[x,y],size=[w,h],collision=solid));return a
for s in (-1,1):
    sprite('长椅_%d'%s,'Bench',s*650,-450,260,140,(210,60))
    for i,y in enumerate((-350,450)):sprite('花盆_%d_%d'%(s,i),'Planter',s*750,y,120,150,(65,65))
    for i,y in enumerate((-900,700)):sprite('街灯_%d_%d'%(s,i),'Lantern',s*950,y,170,340,(35,35))
    for i,(x,y) in enumerate(((750,100),(1100,-950),(1900,-850))):sprite('木桶_%d_%d'%(s,i),'Barrel',s*x,y,140,150,(80,80))
for i,(x,y) in enumerate(((-800,650),(800,650),(-2200,-1000),(2100,-1000))):sprite('箱袋_%02d'%i,'Crates',x,y,180,180,(125,80))
sprite('村口雾门','FogGate',*spec['gate'][:2],700,620)
sprite('溪岸水车','Waterwheel',4050,-3100,420,420)
sprite('储运田车','Cart',-2400,-1050,400,300,(300,150))
for row,y in enumerate((650,950,1150)):
    for col,x in enumerate((2000,2700,3050)):sprite('药畦_%d_%d'%(row,col),'HerbBed',x,y,260,170,(170,70))
for row,y in enumerate((-2050,-1750,-1450)):
    for col,x in enumerate((3400,3800,4200,4600,5000,5400)):sprite('菜畦_%d_%d'%(row,col),'CropRow',x,y,280,100)
def fence_rect(prefix,rect,asset):
    x,y,w,d=rect
    for side in (-1,1):
        n=math.ceil(w/240)
        for i in range(n):
            px=x-w/2+(i+.5)*w/n
            if side==-1 and abs(px-2300)<260 and prefix=='药圃':continue
            sprite(prefix+'_横_%d_%d'%(side,i),asset,px,y+side*d/2,w/n*1.1,140,(w/n*.9,35))
        n=math.ceil(d/220)
        for i in range(n):sprite(prefix+'_侧_%d_%d'%(side,i),asset,x+side*w/2,y-d/2+(i+.5)*d/n,220,140,(35,d/n*.9))
fence_rect('药圃',spec['herb_garden'],'Fence');fence_rect('农田',spec['farm'],'StoneWall')
for side in (-1,1):
    for i,x in enumerate((1400,1800,2200,3200,3600,4200,4800,5400,6000)):
        sprite('溪岸_%d_%02d'%(side,i),'BankRocks',x,-3300+side*370,190,140,(110,50))
for i,(x,y) in enumerate(((-4200,2400),(-3000,2500),(-1200,2400),(1500,2500),(3400,2500),(5100,2500))):sprite('林缘橡树_%02d'%i,'Oak',x,y,780,850,(140,140))
for i,(x,y) in enumerate(((-900,650),(900,650),(-1100,750),(1100,750),(1750,1450),(3300,1450),(-4200,1200),(4300,1100),(-3500,-1450),(800,-1400),(1500,-1400),(3200,-2900))):sprite('花木层次_%02d'%i,'Bush',x,y,180,130)

# Give the already depth-correct bridge real wood grain without replacing its geometry.
bridge=lib.load_asset('/Game/Greyford/Materials/M_GF_BridgeWood');edit.delete_all_material_expressions(bridge)
sample=edit.create_material_expression(bridge,u.MaterialExpressionTextureSample);sample.set_editor_property('texture',lib.load_asset('/Game/Greyford/Textures/T_GF_Life_WoodGrain'))
assert edit.connect_material_property(sample,'RGB',u.MaterialProperty.MP_EMISSIVE_COLOR);edit.recompile_material(bridge);assert lib.save_loaded_asset(bridge)
walks=[(0,-100),(500,0),(-500,0),(-1500,-100),(-2850,-650),tuple(spec['gate'][:2]),(1500,-650),(2300,400),(2300,1050),(0,1450),(2700,-2650),(2700,-3300),(2700,-3950),(3300,-1750)]
for i,p in enumerate(walks):
    a=actors.spawn_actor_from_class(u.TargetPoint,u.Vector(*p,0));a.set_actor_label('LifeWalk_%02d'%i);a.set_folder_path('Greyford/WalkReview')
    a.set_editor_property('tags',['GreyfordVillageLife','GreyfordVillageLifeWalk'])
assert levels.save_current_level()
counts={}
for entry in placed:counts[entry['asset']]=counts.get(entry['asset'],0)+1
for name,minimum in {'Bench':2,'Barrel':4,'Planter':4,'Lantern':4,'HerbBed':6,'CropRow':12,'FogGate':1,'Waterwheel':1,'BankRocks':12,'StoneWall':8}.items():assert counts.get(name,0)>=minimum,(name,counts,skipped)
(out/'authoring-report.json').write_text(json.dumps(dict(moved_buildings=moved,props=placed,counts=counts,skipped_overlaps=skipped,workshop_replaced=True,wood_bridge_textured=True,walk_targets=walks,reference='village-concept-wolai.jpg'),ensure_ascii=False,indent=2),encoding='utf-8')
runpy.run_path(str(root/'Tools/CompactGreyfordVillage.py'))
u.log('GREYFORD_VILLAGE_LIFE_AUTHOR_PASS '+json.dumps(counts))

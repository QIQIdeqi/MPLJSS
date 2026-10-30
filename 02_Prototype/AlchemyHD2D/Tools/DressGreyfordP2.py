"""Dress saved Greyford maps with P2 props, editable surface blending and soft ground shadows.

Rerun after painting ground cells to refresh the per-map blend mask from their actual textures.
Existing collision footprints and previously positioned P1 actors are preserved.
"""
import unreal as u
import json,math,random,shutil
from pathlib import Path

root=Path(u.Paths.project_dir()).resolve()
work=root.parents[1]
plan=json.loads((work/'00_Doc/场景设计/2026-10-30_Greyford/layout.json').read_text(encoding='utf-8'))
levels=u.get_editor_subsystem(u.LevelEditorSubsystem)
actors=u.get_editor_subsystem(u.EditorActorSubsystem)
lib=u.EditorAssetLibrary
edit=u.MaterialEditingLibrary
tools=u.AssetToolsHelpers.get_asset_tools()
evidence=root/'Evidence/Greyford/P2';evidence.mkdir(parents=True,exist_ok=True)
mask_dir=root/'ArtSource/Greyford20261030/SurfaceMasks';mask_dir.mkdir(parents=True,exist_ok=True)
plane=lib.load_asset('/Engine/BasicShapes/Plane')
rotation=u.MathLibrary.make_rot_from_xz(u.Vector(-1,0,0),u.Vector(0,-math.cos(math.radians(48)),math.sin(math.radians(48))))
up=u.Vector(0,math.sin(math.radians(48)),math.cos(math.radians(48)))
reports=[]


def position(x,y,z=0):return u.Vector(-(x-12)*600,-(y-9)*600,z)


def mesh_actor(existing,label,foot,width,height,material,folder,tag,billboard=True):
    obj=existing.get(label)
    if obj is None:
        obj=actors.spawn_actor_from_class(u.StaticMeshActor,foot)
        obj.set_actor_label(label);obj.set_folder_path('Greyford/'+folder)
        obj.set_editor_property('tags',['GreyfordGenerated',tag])
        obj.static_mesh_component.set_static_mesh(plane)
        obj.static_mesh_component.set_collision_profile_name('NoCollision')
        obj.static_mesh_component.set_cast_shadow(False)
        obj.set_actor_rotation(rotation if billboard else u.Rotator(),False)
        obj.set_actor_location(foot+up*((488/512-.5)*height) if billboard else foot,False,False)
        obj.set_actor_scale3d(u.Vector(width/100,height/100,1))
        existing[label]=obj
    obj.static_mesh_component.set_material(0,material)
    return obj


def surface_material(scene,cells):
    # RGB encodes Grass/Dirt/Stone; Water is the remaining weight. This is data, not baked scene art.
    colors={'Grass':(255,0,0),'Dirt':(0,255,0),'Stone':(0,0,255),'Water':(0,0,0)}
    pixels=[colors['Grass']]*(24*18)
    for c in cells:
        name=c.get_editor_property('texture').get_name().removeprefix('T_GF_')
        assert name in colors,name
        pixels[c.get_editor_property('grid_y')*24+c.get_editor_property('grid_x')]=colors[name]
    filename=mask_dir/(scene['id']+'-surface-mask.tga')
    filename.write_bytes(bytes([0,0,2,0,0,0,0,0,0,0,0,0,24,0,18,0,24,32])+bytes(b for rgb in pixels for b in reversed(rgb)))
    task=u.AssetImportTask();task.filename=str(filename);task.destination_path='/Game/Greyford/Textures'
    task.destination_name='T_GF_'+scene['id']+'SurfaceMask';task.automated=True;task.replace_existing=True;task.save=True
    tools.import_asset_tasks([task]);mask=lib.load_asset(task.destination_path+'/'+task.destination_name);assert mask
    mask.set_editor_property('srgb',False);mask.set_editor_property('filter',u.TextureFilter.TF_NEAREST)
    mask.set_editor_property('mip_gen_settings',u.TextureMipGenSettings.TMGS_NO_MIPMAPS)
    mask.set_editor_property('compression_settings',u.TextureCompressionSettings.TC_VECTOR_DISPLACEMENTMAP)
    mask.set_editor_property('address_x',u.TextureAddress.TA_CLAMP);mask.set_editor_property('address_y',u.TextureAddress.TA_CLAMP)
    lib.save_loaded_asset(mask)
    name='M_GF_'+scene['id']+'SurfaceBlend';path='/Game/Greyford/Materials/'+name
    mat=lib.load_asset(path) if lib.does_asset_exist(path) else tools.create_asset(name,'/Game/Greyford/Materials',u.Material,u.MaterialFactoryNew())
    edit.delete_all_material_expressions(mat)
    mat.set_editor_property('shading_model',u.MaterialShadingModel.MSM_UNLIT)
    mat.set_editor_property('two_sided',True)
    custom=edit.create_material_expression(mat,u.MaterialExpressionCustom)
    custom.set_editor_property('output_type',u.CustomMaterialOutputType.CMOT_FLOAT3)
    inputs=[]
    for key in ['World','Layout','Grass','Dirt','Stone','Water']:
        pin=u.CustomInput();pin.set_editor_property('input_name',key);inputs.append(pin)
    custom.set_editor_property('inputs',inputs)
    world=edit.create_material_expression(mat,u.MaterialExpressionWorldPosition)
    assert edit.connect_material_expressions(world,'',custom,'World')
    for key in ['Layout','Grass','Dirt','Stone','Water']:
        node=edit.create_material_expression(mat,u.MaterialExpressionTextureObject)
        node.set_editor_property('texture',mask if key=='Layout' else lib.load_asset('/Game/Greyford/Textures/T_GF_'+key))
        if key=='Layout':node.set_editor_property('sampler_type',u.MaterialSamplerType.SAMPLERTYPE_LINEAR_COLOR)
        assert edit.connect_material_expressions(node,'',custom,key)
    custom.set_editor_property('code','''
float2 p=float2(12-World.x/600,9-World.y/600);
float2 cell=floor(p), f=frac(p), side=step(0.5,f)*2-1;
float2 edge=min(f,1-f);
float wobble=0.02*sin(World.x/48)*sin(World.y/67);
float2 t=0.5*(1-smoothstep(0,0.14,edge+wobble*edge*6));
float2 dim=float2(24,18);
float3 a=Texture2DSampleLevel(Layout,LayoutSampler,(cell+0.5)/dim,0).rgb;
float3 b=Texture2DSampleLevel(Layout,LayoutSampler,(cell+float2(side.x,0)+0.5)/dim,0).rgb;
float3 c=Texture2DSampleLevel(Layout,LayoutSampler,(cell+float2(0,side.y)+0.5)/dim,0).rgb;
float3 d=Texture2DSampleLevel(Layout,LayoutSampler,(cell+side+0.5)/dim,0).rgb;
float3 w=lerp(lerp(a,b,t.x),lerp(c,d,t.x),t.y);
float3 grass=Texture2DSample(Grass,GrassSampler,p).rgb;
float3 dirt=Texture2DSample(Dirt,DirtSampler,p).rgb;
float3 stone=Texture2DSample(Stone,StoneSampler,p).rgb;
float3 water=Texture2DSample(Water,WaterSampler,p).rgb;
float shade=0.96+0.04*sin(World.x/1200)*sin(World.y/850);
return (grass*w.r+dirt*w.g+stone*w.b+water*saturate(1-w.r-w.g-w.b))*shade;
''')
    assert edit.connect_material_property(custom,'',u.MaterialProperty.MP_EMISSIVE_COLOR)
    edit.recompile_material(mat);assert lib.save_loaded_asset(mat)
    for c in cells:c.set_editor_property('material_override',mat)
    cells[0].get_owner().refresh_cells()
    return mat


for scene in plan['maps']:
    name=scene['id']+'_Blockout';assert levels.load_level('/Game/Greyford/Maps/'+name)
    existing={a.get_actor_label():a for a in actors.get_all_level_actors()}
    entries=[]
    for obj in scene['objects']:
        asset=obj.get('asset')
        if asset not in ('Well','Cart','Fence','Bridge','HerbRack','Crates'):continue
        x,y,w,h=obj['rect'];proxy=existing.get(obj['name'])
        foot=proxy.get_actor_location() if proxy else position(x+w/2,y+h/2)
        foot=u.Vector(foot.x,foot.y,12)
        material=lib.load_asset('/Game/Greyford/Materials/M_GF_'+asset);assert material
        # Short modules keep the fence at character scale on either authored axis.
        count=max(1,math.ceil(max(w,h)/.6)) if asset=='Fence' else 1
        if asset=='Fence' and count>1:
            old='P2_'+obj['name']
            for obsolete in [old,'Shadow_'+old+'_Contact','Shadow_'+old+'_Cast']:
                actor=existing.get(obsolete)
                if actor and (actor.actor_has_tag('GreyfordP2Visual') or actor.actor_has_tag('GreyfordGroundShadow')):
                    actors.destroy_actor(actor);del existing[obsolete]
        dims={'Well':(780,850),'Cart':(1100,1000),'Bridge':(930,800),'HerbRack':(900,850),'Crates':(700,700)}
        width,height=dims.get(asset,(430,450)) if count==1 else ((w*600/count*1.10,350) if w>=h else (430,450))
        for i in range(count):
            p=foot if count==1 else u.Vector(foot.x+((i+.5)/count-.5)*w*600,foot.y,12) if w>=h else u.Vector(foot.x,foot.y+((i+.5)/count-.5)*h*600,12)
            label='P2_'+obj['name']+('_%02d'%i if count>1 else '')
            visual=mesh_actor(existing,label,p,width,height,material,'P2Art','GreyfordP2Visual')
            visual.set_editor_property('tags',['GreyfordGenerated','GreyfordP2Visual','GFAsset_'+asset])
            actual=visual.get_actor_location()-up*((488/512-.5)*visual.get_actor_scale3d().y*100)
            entries.append(dict(label=label,asset=asset,foot_cm=[actual.x,actual.y,actual.z],visual=visual.get_path_name(),collision_proxy=proxy.get_path_name() if proxy else None))
        if proxy:proxy.static_mesh_component.set_visibility(False);proxy.set_actor_hidden_in_game(True)
    cells=[a for a in actors.get_all_level_actors() if isinstance(a,u.AlchemyTileCell) and a.get_owner()]
    assert len(cells)==432
    blend=surface_material(scene,cells)
    # Hide colored zone/water/boundary volumes without changing authored collision.
    for a in existing.values():
        if isinstance(a,u.StaticMeshActor) and (str(a.get_folder_path())=='Greyford/ZoneMarkers' or a.get_actor_label().startswith('Boundary_') or a.get_actor_label() in ('溪流','溪流东段','南侧溪水','东南溪水')):
            a.static_mesh_component.set_visibility(False);a.set_actor_hidden_in_game(True)
    shadow_mat=lib.load_asset('/Game/Art/M_SoftShadow');assert shadow_mat
    shadow_count=0
    for a in list(existing.values()):
        if not isinstance(a,u.StaticMeshActor) or not (a.actor_has_tag('GreyfordP1Visual') or a.actor_has_tag('GreyfordP2Visual')):continue
        width=a.get_actor_scale3d().x*100;height=a.get_actor_scale3d().y*100
        foot=a.get_actor_location()-up*((488/512-.5)*height)
        # Two soft native ground cards give contact and a consistent upper-right light direction.
        for suffix,offset,sx,sy in [('Contact',u.Vector(0,0,3),.8,.3),('Cast',u.Vector(-width*.16,height*.14,2),1.15,.55)]:
            p=u.Vector(foot.x+offset.x,foot.y+offset.y,offset.z)
            mesh_actor(existing,'Shadow_'+a.get_actor_label()+'_'+suffix,p,width*sx,width*sy,shadow_mat,'GroundShadows','GreyfordGroundShadow',False)
            shadow_count+=1
    rng=random.Random(108 if scene['id']=='Village' else 208)
    # Low, nonblocking edge shrubs establish a foreground perimeter without closing battle routes.
    for i,(x,y) in enumerate([(1.2,2),(1,12.8),(4,16.7),(10,17),(18,17),(22.8,3.5),(22.8,11),(6,.7),(14,.7),(20,.7)]):
        width=rng.uniform(400,650)
        mesh_actor(existing,'Layer_EdgeBush_%02d'%i,position(x,y,8),width,width,lib.load_asset('/Game/Greyford/Materials/M_GF_Bush'),'LayerDetails','GreyfordLayerDetail')
    settings=u.get_editor_subsystem(u.UnrealEditorSubsystem).get_editor_world().get_world_settings()
    settings.set_editor_property('default_game_mode',u.GreyfordCombatMode.static_class() if scene['id']=='Outskirts' else u.GreyfordBlockoutMode.static_class())
    assert levels.save_current_level();assert levels.load_level('/Game/Greyford/Maps/'+name)
    allactors=actors.get_all_level_actors()
    p2=[a for a in allactors if a.actor_has_tag('GreyfordP2Visual')]
    assert len(p2)==len(entries) and all(a.static_mesh_component.get_collision_enabled()==u.CollisionEnabled.NO_COLLISION for a in p2)
    reports.append(dict(map=name,visual_count=len(p2),entries=entries,surface_material=blend.get_path_name(),ground_cells=len(cells),soft_shadow_cards=shadow_count,edge_detail_cards=10))

(evidence/'replacement-report.json').write_text(json.dumps(reports,ensure_ascii=False,indent=2),encoding='utf-8')
u.log('GREYFORD_P2_DRESS_PASS '+str([(r['map'],r['visual_count']) for r in reports]))

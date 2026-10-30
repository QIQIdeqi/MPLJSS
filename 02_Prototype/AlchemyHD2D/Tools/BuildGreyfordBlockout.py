"""Author two separate editable levels; never regenerate an existing authored level."""
import unreal as u
import json
from pathlib import Path

PROJECT=Path(u.Paths.project_dir()).resolve()
WORKSPACE=PROJECT.parents[1]
PLAN_DIR=WORKSPACE/'00_Doc/场景设计/2026-10-30_Greyford'
ART=PROJECT/'ArtSource/Greyford20261030'
PLAN=json.loads((PLAN_DIR/'layout.json').read_text(encoding='utf-8'))
MANIFEST=json.loads((ART/'asset-manifest.json').read_text(encoding='utf-8'))
lib=u.EditorAssetLibrary
assets=u.AssetToolsHelpers.get_asset_tools()
levels=u.get_editor_subsystem(u.LevelEditorSubsystem)
actors=u.get_editor_subsystem(u.EditorActorSubsystem)
edit=u.MaterialEditingLibrary
base='/Game/Greyford'
verify_only='-GreyfordVerifyOnly' in u.SystemLibrary.get_command_line()


def texture(item):
    name='T_GF_'+item['id']
    path=base+'/Textures/'+name
    if verify_only:assert lib.does_asset_exist(path),path
    if not lib.does_asset_exist(path):
        t=u.AssetImportTask();t.filename=str(ART/item['source']);t.destination_path=base+'/Textures'
        t.destination_name=name;t.automated=True;t.save=True
        assets.import_asset_tasks([t])
    tex=lib.load_asset(path);assert tex,path
    if verify_only:
        assert tex.get_editor_property('filter')==u.TextureFilter.TF_NEAREST
        return tex
    tex.set_editor_property('filter',u.TextureFilter.TF_NEAREST)
    tex.set_editor_property('mip_gen_settings',u.TextureMipGenSettings.TMGS_NO_MIPMAPS)
    tex.set_editor_property('compression_settings',u.TextureCompressionSettings.TC_EDITOR_ICON)
    lib.save_loaded_asset(tex)
    return tex


def make_material(name,tex=None,color=None):
    path=base+'/Materials/'+name
    if verify_only:assert lib.does_asset_exist(path),path
    if lib.does_asset_exist(path):return lib.load_asset(path)
    m=assets.create_asset(name,base+'/Materials',u.Material,u.MaterialFactoryNew())
    m.set_editor_property('two_sided',True)
    m.set_editor_property('shading_model',u.MaterialShadingModel.MSM_UNLIT)
    if tex:
        m.set_editor_property('blend_mode',u.BlendMode.BLEND_MASKED)
        sample=edit.create_material_expression(m,u.MaterialExpressionTextureSample);sample.texture=tex
        assert edit.connect_material_property(sample,'RGB',u.MaterialProperty.MP_EMISSIVE_COLOR)
        assert edit.connect_material_property(sample,'A',u.MaterialProperty.MP_OPACITY_MASK)
    else:
        c=edit.create_material_expression(m,u.MaterialExpressionConstant3Vector)
        c.set_editor_property('constant',u.LinearColor(*color,1))
        assert edit.connect_material_property(c,'',u.MaterialProperty.MP_EMISSIVE_COLOR)
    edit.recompile_material(m);assert lib.save_loaded_asset(m)
    return m


texs={i['id']:texture(i) for i in MANIFEST['items']}
mats={name:make_material('M_GF_'+name,tex=tex) for name,tex in texs.items()}
colors=dict(building=(.36,.39,.41),block=(.48,.43,.33),tree=(.19,.29,.24),
    water=(.16,.35,.43),garden=(.39,.43,.22),bridge=(.43,.3,.16),gate=(.23,.68,.61),
    decor=(.24,.38,.24),marker=(.25,.85,.88),boundary=(.2,.23,.25))
flat={k:make_material('M_GF_Block_'+k,color=v) for k,v in colors.items()}
cube=lib.load_asset('/Engine/BasicShapes/Cube')
cell=PLAN['cell_cm'];cols=PLAN['columns'];rows=PLAN['rows']


def pos(x,y,z=0):return u.Vector(-(x-cols/2)*cell,-(y-rows/2)*cell,z)


def label(a,name,folder):
    a.set_actor_label(name);a.set_folder_path('Greyford/'+folder)
    a.set_editor_property('tags',['GreyfordGenerated'])


def box(name,x,y,w,h,kind,height=300,solid=True):
    a=actors.spawn_actor_from_class(u.StaticMeshActor,pos(x+w/2,y+h/2,height/2))
    label(a,name,'Collision' if solid else 'ZoneMarkers')
    mesh=a.static_mesh_component;mesh.set_static_mesh(cube);mesh.set_material(0,flat[kind])
    a.set_actor_scale3d(u.Vector(w*cell/100,h*cell/100,height/100))
    mesh.set_collision_profile_name('BlockAll' if solid else 'NoCollision')
    mesh.set_cast_shadow(False)
    if solid:a.set_editor_property('tags',['GreyfordGenerated','GreyfordBlocker'])
    return a


def ground(designer,x,y,name):
    a=actors.spawn_actor_from_class(u.AlchemyTileCell,pos(x+.5,y+.5,0))
    label(a,'GF_%02d_%02d_%s'%(x,y,name),'GroundTiles');a.set_owner(designer)
    a.set_editor_property('grid_x',x);a.set_editor_property('grid_y',y)
    a.set_editor_property('ground',True);a.set_editor_property('lock_random',True)
    a.set_editor_property('visual_size',u.Vector2D(cell,cell))
    a.set_editor_property('texture',texs[name]);a.set_editor_property('material_override',mats[name])
    return a


def surface(scene,x,y):
    result='Grass'
    # Terrain layers are painted cells, not a giant baked map screenshot.
    priority=['plaza','road','garden','water','bridge','gate']
    for kind in priority:
        for obj in scene['objects']:
            a,b,w,h=obj['rect']
            if obj['kind']==kind and a<=x+.5<a+w and b<=y+.5<b+h:
                result=dict(plaza='Stone',road='Dirt',garden='Dirt',water='Water',bridge='Dirt',gate='Stone')[kind]
    return result


def check_level(scene):
    allactors=actors.get_all_level_actors()
    cells=[a for a in allactors if isinstance(a,u.AlchemyTileCell) and a.get_owner()]
    assert len(cells)==cols*rows,(scene['id'],len(cells))
    assert all(a.get_editor_property('material_override') for a in cells)
    assert all(a.get_editor_property('lock_random') for a in cells)
    starts=[a for a in allactors if a.actor_has_tag('GreyfordSpawn')]
    assert len(starts)==len(scene['spawn_candidates'])
    d=next(a for a in allactors if isinstance(a,u.AlchemyLevelDesigner))
    palette=d.get_editor_property('palette')
    assert len(palette)==len(MANIFEST['items'])
    assert all(b.get_editor_property('texture') and b.get_editor_property('material') for b in palette)
    mode=u.EditorLevelLibrary.get_editor_world().get_world_settings().get_editor_property('default_game_mode')
    assert mode==(u.GreyfordCombatMode.static_class() if scene['id']=='Outskirts' else u.GreyfordBlockoutMode.static_class())
    return dict(id=scene['id'],ground_tiles=len(cells),spawn_candidates=len(starts),
        blocking_actors=sum(a.actor_has_tag('GreyfordBlocker') for a in allactors),
        editable_palette=len(palette),game_mode=mode.get_name())


reports=[]
for scene in PLAN['maps']:
    package=base+'/Maps/'+scene['id']+'_Blockout'
    if lib.does_asset_exist(package):
        assert levels.load_level(package)
    else:
        assert not verify_only,package
        assert levels.new_level(package)
        world=u.EditorLevelLibrary.get_editor_world()
        world.get_world_settings().set_editor_property('default_game_mode',u.GreyfordCombatMode.static_class() if scene['id']=='Outskirts' else u.GreyfordBlockoutMode.static_class())
        designer=actors.spawn_actor_from_class(u.AlchemyLevelDesigner,u.Vector())
        label(designer,'GF_关卡编辑器_地块与素材库','EditorTools')
        designer.set_editor_property('columns',cols);designer.set_editor_property('rows',rows)
        designer.set_editor_property('cell_size',cell);designer.set_editor_property('use_in_game',False)
        palette=[]
        for item in MANIFEST['items']:
            b=u.AlchemyTileBrush();b.set_editor_property('name',item['label'])
            b.set_editor_property('texture',texs[item['id']]);b.set_editor_property('material',mats[item['id']])
            b.set_editor_property('ground',item['kind']=='ground');b.set_editor_property('random_weight',0)
            b.set_editor_property('visual_size',u.Vector2D(600,600) if item['kind']=='ground' else u.Vector2D(900,900))
            palette.append(b)
        designer.set_editor_property('palette',palette)
        for x in range(cols):
            for y in range(rows):ground(designer,x,y,surface(scene,x,y))
        for obj in scene['objects']:
            kind=obj['kind'];x,y,w,h=obj['rect']
            if kind in ('building','block','tree','water'):
                box(obj['name'],x,y,w,h,kind,height=650 if kind=='building' else 350)
            elif kind in ('gate','garden','decor','bridge'):
                # Low visual markers remain traversable; the bridge fills the gap in the water blockers.
                box(obj['name'],x,y,w,h,kind,height=8,solid=False)
        for name,x,y,w,h in [('North',-.2,-.2,24.4,.2),('South',-.2,18,24.4,.2),('West',-.2,0,.2,18),('East',24,0,.2,18)]:
            box('Boundary_'+name,x,y,w,h,'boundary',height=300)
        for i,(x,y) in enumerate(scene['spawn_candidates']):
            a=actors.spawn_actor_from_class(u.TargetPoint,pos(x,y,80));label(a,'出生候选_S%d'%(i+1),'Spawns')
            a.set_editor_property('tags',['GreyfordGenerated','GreyfordSpawn'])
            box('S%d_出生区'%(i+1),x-.15,y-.15,.3,.3,'marker',height=5,solid=False)
        start=actors.spawn_actor_from_class(u.PlayerStart,pos(*scene['spawn'],80));label(start,'玩家起点_500cm每秒','Spawns')
        sun=actors.spawn_actor_from_class(u.DirectionalLight,u.Vector(0,0,1500),u.Rotator(pitch=-55,yaw=-35))
        label(sun,'GreyboxSun','Lighting');sun.light_component.set_intensity(3)
        sky=actors.spawn_actor_from_class(u.SkyLight,u.Vector(0,0,2000));label(sky,'GreyboxSky','Lighting')
        camera=actors.spawn_actor_from_class(u.CameraActor,u.Vector(0,-10000,11105),u.Rotator(pitch=-48,yaw=90))
        label(camera,'布局总览_正交48度','Cameras')
        camera.camera_component.set_editor_property('projection_mode',u.CameraProjectionMode.ORTHOGRAPHIC)
        camera.camera_component.set_editor_property('ortho_width',21000)
        u.EditorLevelLibrary.set_level_viewport_camera_info(u.Vector(0,-10000,11105),u.Rotator(pitch=-48,yaw=90))
        designer.refresh_cells()
        assert levels.save_current_level()
    # Reload proves the authored cells/materials/mode are saved, rather than temporary runtime actors.
    assert levels.load_level(package)
    reports.append(check_level(scene))

evidence=PROJECT/'Evidence/Greyford';evidence.mkdir(parents=True,exist_ok=True)
(evidence/'editor-build.json').write_text(json.dumps(reports,ensure_ascii=False,indent=2),encoding='utf-8')
assert levels.load_level(base+'/Maps/Village_Blockout')
u.log('GREYFORD_EDITOR_BUILD_PASS '+json.dumps(reports))

"""Registered reference image + local clean plates, depth cards and ambient motion."""
import unreal as u
import json,math,shutil,sys
from pathlib import Path
root=Path(u.Paths.project_dir()).resolve();spec=json.loads((root/'Tools/GreyfordReference.json').read_text(encoding='utf-8'))
levels=u.get_editor_subsystem(u.LevelEditorSubsystem);actors=u.get_editor_subsystem(u.EditorActorSubsystem)
lib=u.EditorAssetLibrary;edit=u.MaterialEditingLibrary;tools=u.AssetToolsHelpers.get_asset_tools()
sys.path.insert(0,str(root/'Tools'))
import GreyfordAmbient as ambient
out=root/'Evidence/Greyford/Ambient';out.mkdir(parents=True,exist_ok=True)
backup=root.parents[1]/'01_Skill/tmp/greyford-ambient-20261030';backup.mkdir(parents=True,exist_ok=True)
src=root/'Content/Greyford/Maps/Village_Reference.umap'
if not (backup/src.name).exists():shutil.copy2(src,backup/src.name)
S=spec['centimeters_per_pixel'];sn=math.sin(math.radians(48));cs=math.cos(math.radians(48))
def world(p):return u.Vector((836-p[0])*S,(470.5-p[1])*S/sn,0)
path='/Game/Greyford/Maps/Village_Reference'
assert levels.load_level(path) if lib.does_asset_exist(path) else levels.new_level(path)
keep_collision='-GreyfordReplaceCollision' not in u.SystemLibrary.get_command_line()
existing_regions=[a for a in actors.get_all_level_actors() if isinstance(a,u.GreyfordReferenceRegion)]
for a in list(actors.get_all_level_actors()):
    if a.actor_has_tag('GreyfordReference') and not (keep_collision and isinstance(a,u.GreyfordReferenceRegion)):actors.destroy_actor(a)
task=u.AssetImportTask();task.filename=str(root/'ArtSource/GreyfordReference20261030/VillageReference.png');task.destination_path='/Game/Greyford/Reference';task.destination_name='T_VillageReference';task.automated=True;task.replace_existing=True;task.save=True
tools.import_asset_tasks([task]);tex=lib.load_asset(task.destination_path+'/'+task.destination_name)
tex.set_editor_property('compression_settings',u.TextureCompressionSettings.TC_EDITOR_ICON);tex.set_editor_property('mip_gen_settings',u.TextureMipGenSettings.TMGS_NO_MIPMAPS);tex.set_editor_property('filter',u.TextureFilter.TF_NEAREST);tex.set_editor_property('never_stream',True);assert lib.save_loaded_asset(tex)
clean=ambient.texture(root,'VillageCleanPlate');wheel=ambient.texture(root,'Waterwheel')
plane=lib.load_asset('/Engine/BasicShapes/Plane');rot=u.MathLibrary.make_rot_from_xz(u.Vector(-1,0,0),u.Vector(0,-cs,sn))
def card(name,foot=None,points=None,slope=0,parts=None,baseline=None,holes=None):
    matpath='/Game/Greyford/Reference/M_'+name
    m=lib.load_asset(matpath) if lib.does_asset_exist(matpath) else tools.create_asset('M_'+name,'/Game/Greyford/Reference',u.Material,u.MaterialFactoryNew())
    edit.delete_all_material_expressions(m);m.set_editor_property('use_material_attributes',False);m.set_editor_property('two_sided',True);m.set_editor_property('shading_model',u.MaterialShadingModel.MSM_UNLIT);m.set_editor_property('blend_mode',u.BlendMode.BLEND_MASKED if (points or parts) else u.BlendMode.BLEND_OPAQUE)
    uv=edit.create_material_expression(m,u.MaterialExpressionTextureCoordinate)
    ambient.patch_color(m,uv,tex,clean,spec['clean_patch_rects'])
    def custom(code,outtype,prop):
        e=edit.create_material_expression(m,u.MaterialExpressionCustom);i=u.CustomInput();i.set_editor_property('input_name','UV');e.set_editor_property('inputs',[i]);e.set_editor_property('code',code);e.set_editor_property('output_type',outtype)
        edit.connect_material_expressions(uv,'',e,'UV');assert edit.connect_material_property(e,'',prop)
    if points or parts:
        code='float2 p=UV*float2(1672,941);float mask=0;'
        for poly in parts or [points]:code+='{'+ambient.polygon(poly)+'mask=max(mask,hit?1:0);}'
        for poly in holes or []:code+='{'+ambient.polygon(poly)+'if(hit)mask=0;}'
        custom(code+'return mask;',u.CustomMaterialOutputType.CMOT_FLOAT1,u.MaterialProperty.MP_OPACITY_MASK)
    if baseline:
        # A quad has no intermediate vertices: use per-pixel depth for a bent ground line.
        foot=max(p[1] for p in baseline)
        code='float x=UV.x*1672;float y=%f;'%baseline[0][1]
        for (x0,y0),(x1,y1) in zip(baseline,baseline[1:]):code+='y=lerp(y,%f,saturate((x-%f)/%f));'%(y1,x0,x1-x0)
        code+='return max(0,(%f-y)*%f);'%(foot,S*cs/sn)
        # Python hides MP_PixelDepthOffset; the native MakeMaterialAttributes pin exposes it.
        attrs=edit.create_material_expression(m,u.MaterialExpressionMakeMaterialAttributes)
        for pin,prop in [('EmissiveColor',u.MaterialProperty.MP_EMISSIVE_COLOR),('OpacityMask',u.MaterialProperty.MP_OPACITY_MASK)]:
            assert edit.connect_material_expressions(edit.get_material_property_input_node(m,prop),'',attrs,pin)
        depth_expr=edit.create_material_expression(m,u.MaterialExpressionCustom);depth_expr.set_editor_property('code',code);depth_expr.set_editor_property('output_type',u.CustomMaterialOutputType.CMOT_FLOAT1)
        depth_input=u.CustomInput();depth_input.set_editor_property('input_name','UV');depth_expr.set_editor_property('inputs',[depth_input]);assert edit.connect_material_expressions(uv,'',depth_expr,'UV')
        assert edit.connect_material_expressions(depth_expr,'',attrs,'PixelDepthOffset')
        m.set_editor_property('use_material_attributes',True);assert edit.connect_material_property(attrs,'',u.MaterialProperty.MP_MATERIAL_ATTRIBUTES)
    elif slope:custom('return float3(0,%f,%f)*(-(UV.x*1672-836)*%f);'%(cs,-sn,slope*S*cs/sn),u.CustomMaterialOutputType.CMOT_FLOAT3,u.MaterialProperty.MP_WORLD_POSITION_OFFSET)
    edit.recompile_material(m);assert lib.save_loaded_asset(m)
    depth=10000 if foot is None else world((836,foot)).y*cs
    a=actors.spawn_actor_from_class(u.StaticMeshActor,u.Vector(0,cs*depth,-sn*depth));a.set_actor_label('Reference_'+name);a.set_folder_path('Greyford/Reference/DepthLayers');a.set_editor_property('tags',['GreyfordReference'])
    a.static_mesh_component.set_static_mesh(plane);a.static_mesh_component.set_material(0,m);a.static_mesh_component.set_collision_profile_name('NoCollision');a.static_mesh_component.set_cast_shadow(False)
    a.set_actor_rotation(rot,False);a.set_actor_scale3d(u.Vector(1672*S/100,941*S/100,1))
    if slope:a.static_mesh_component.set_editor_property('bounds_scale',4)
card('Background')
for layer in spec['layers']:card(**layer)
ambient.animate(actors,plane,rot,S,clean,wheel)
for kind in ('walk','blocked'):
    if keep_collision and existing_regions:continue
    for r in spec[kind]:
        a=actors.spawn_actor_from_class(u.GreyfordReferenceRegion,u.Vector());a.set_actor_label('Reference_'+kind+'_'+r['name']);a.set_folder_path('Greyford/Reference/'+kind);a.set_editor_property('tags',['GreyfordReference'])
        a.set_editor_property('vertices',[world(p) for p in r['points']]);a.set_editor_property('blocked',kind=='blocked')
        a.outline.clear_spline_points(False);a.initialize_outline()
def point(name,p,tags):
    a=actors.spawn_actor_from_class(u.TargetPoint,world(p));a.set_actor_label(name);a.set_editor_property('tags',['GreyfordReference']+tags);a.set_folder_path('Greyford/Reference/Navigation')
for i,p in enumerate(spec['facilities']):point('Reference_Facility_%d'%i,p,['GreyfordVillageFacility_%d'%i])
for i,p in enumerate(spec['nodes']):point('Reference_Node_%d'%i,p,['ReferencePathNode'])
for i,p in enumerate(spec['routes']):point('Reference_Route_%d'%i,p,['GreyfordVillageLifeWalk'])
a=actors.spawn_actor_from_class(u.PlayerStart,world(spec['spawn']));a.set_actor_label('Reference_PlayerStart');a.set_editor_property('tags',['GreyfordReference'])
assert levels.save_current_level()
assert levels.load_level('/Game/Greyford/Maps/Greyford_Flow')
w=u.get_editor_subsystem(u.UnrealEditorSubsystem).get_editor_world()
old=u.GameplayStatics.get_streaming_level(w,'/Game/Greyford/Maps/Village_Blockout')
if old and old.get_loaded_level():u.EditorLevelUtils.remove_level_from_world(old.get_loaded_level())
stream=u.GameplayStatics.get_streaming_level(w,path)
if not stream:stream=u.EditorLevelUtils.add_level_to_world(w,path,u.LevelStreamingDynamic)
assert stream;stream.set_editor_property('should_be_loaded',True);stream.set_editor_property('should_be_visible',True)
assert u.EditorLoadingAndSavingUtils.save_dirty_packages(True,True)
(out/'authoring-report.json').write_text(json.dumps(dict(source='VillageReference.png',source_size=spec['image_size'],projection='48 degrees, 2x follow camera; local clean plate patches; original source retained',camera_width_cm=1672*S/2,ambient_layers=3,removed_residents=8,depth_layers=len(spec['layers']),walk_regions=len(spec['walk']),blocked_regions=len(spec['blocked']),routes=len(spec['routes']),pixel_scale_cm=S,character_canvas_cm=224),indent=2),encoding='utf-8')
u.log('GREYFORD_REFERENCE_AUTHOR_PASS')

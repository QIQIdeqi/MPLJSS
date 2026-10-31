"""Native material animation on registered image layers; no raster repainting here."""
import math
import unreal as u

lib=u.EditorAssetLibrary
edit=u.MaterialEditingLibrary
tools=u.AssetToolsHelpers.get_asset_tools()
F1=u.CustomMaterialOutputType.CMOT_FLOAT1
F2=u.CustomMaterialOutputType.CMOT_FLOAT2
F3=u.CustomMaterialOutputType.CMOT_FLOAT3
F4=u.CustomMaterialOutputType.CMOT_FLOAT4

def texture(root,name):
    t=u.AssetImportTask();t.filename=str(root/'ArtSource/GreyfordAmbient20261030'/f'{name}.png')
    t.destination_path='/Game/Greyford/Reference';t.destination_name='T_'+name;t.automated=True;t.replace_existing=True;t.save=True
    tools.import_asset_tasks([t]);a=lib.load_asset(t.destination_path+'/'+t.destination_name)
    a.set_editor_property('compression_settings',u.TextureCompressionSettings.TC_EDITOR_ICON)
    a.set_editor_property('mip_gen_settings',u.TextureMipGenSettings.TMGS_NO_MIPMAPS)
    a.set_editor_property('filter',u.TextureFilter.TF_NEAREST);a.set_editor_property('never_stream',True)
    lib.save_loaded_asset(a);return a

def expr(m,kind,**props):
    e=edit.create_material_expression(m,kind)
    for k,v in props.items():e.set_editor_property(k,v)
    return e

def custom(m,code,output,inputs):
    fields=[]
    for name in inputs:
        i=u.CustomInput();i.set_editor_property('input_name',name);fields.append(i)
    e=expr(m,u.MaterialExpressionCustom,code=code,output_type=output,inputs=fields)
    for name,(node,pin) in inputs.items():assert edit.connect_material_expressions(node,pin,e,name)
    return e

def polygon(points):
    vertices=','.join('float2(%s,%s)'%tuple(p) for p in points);n=len(points)
    return f'float2 v[{n}]={{{vertices}}};bool hit=false;for(int i=0,j={n-1};i<{n};j=i++){{if(((v[i].y>p.y)!=(v[j].y>p.y))&&(p.x<(v[j].x-v[i].x)*(p.y-v[i].y)/(v[j].y-v[i].y)+v[i].x))hit=!hit;}}'

def reference_uv(m,S):
    """Default 0 preserves authored cards; runtime 1 preserves the painted image under affine pan/zoom."""
    raw=expr(m,u.MaterialExpressionTextureCoordinate)
    mode=expr(m,u.MaterialExpressionScalarParameter,parameter_name='VillagePerspective',default_value=0)
    position=expr(m,u.MaterialExpressionWorldPosition,
                  world_position_shader_offset=u.WorldPositionIncludedOffsets.WPT_EXCLUDE_ALL_SHADER_OFFSETS)
    camera=expr(m,u.MaterialExpressionCameraPositionWS)
    sn=math.sin(math.radians(48))
    focus=expr(m,u.MaterialExpressionVectorParameter,parameter_name='VillageFocus',default_value=u.LinearColor(0,0,0,0))
    width=expr(m,u.MaterialExpressionScalarParameter,parameter_name='VillageWidth',default_value=1672*S)
    tangent=expr(m,u.MaterialExpressionScalarParameter,parameter_name='VillageTangent',default_value=math.tan(math.radians(25)))
    # Position is the near camera-facing card. Ratios cancel its distance and preserve source-image shape.
    # Ground is logical navigation XY, not the physical z=0 ray intersection; native visuals use the inverse.
    code=f'float3 r=Position-Camera;float d=max(0.00001,dot(r,float3(0,0.5,-0.866025403784)));float k=Width/(2*max(0.00001,Tangent)*d);return float3(Focus.x+r.x*k,Focus.y+dot(r,float3(0,0.866025403784,0.5))*k/{sn:.12f},0);'
    ground=custom(m,code,F3,{'Position':(position,''),'Camera':(camera,''),'Focus':(focus,''),'Width':(width,''),'Tangent':(tangent,'')})
    code=f'if(Perspective<0.5)return RawUV;return float2((836-Ground.x/{S:.12f})/1672,(470.5-Ground.y*{sn:.12f}/{S:.12f})/941);'
    uv=custom(m,code,F2,{'RawUV':(raw,''),'Ground':(ground,''),'Perspective':(mode,'')})
    return dict(uv=uv,raw_uv=raw,mode=mode,position=position,ground=ground)

def reference_material(name,S,original,clean,rects,foot=None,points=None,slope=0,parts=None,baseline=None,holes=None):
    """Rebuild one material only. Original clean-plate patches, mask unions and holes remain unchanged."""
    path='/Game/Greyford/Reference/M_'+name
    m=lib.load_asset(path) if lib.does_asset_exist(path) else tools.create_asset('M_'+name,'/Game/Greyford/Reference',u.Material,u.MaterialFactoryNew())
    # Our PDO is view-forward depth; UE5.8 defaults to ray-length compensation, which would hide edge sprites.
    m.set_editor_property('pixel_depth_offset_mode',u.PixelDepthOffsetMode.PDOM_LEGACY)
    edit.delete_all_material_expressions(m);m.set_editor_property('use_material_attributes',False)
    m.set_editor_property('two_sided',True);m.set_editor_property('shading_model',u.MaterialShadingModel.MSM_UNLIT)
    m.set_editor_property('blend_mode',u.BlendMode.BLEND_MASKED if (points or parts) else u.BlendMode.BLEND_OPAQUE)
    mapping=reference_uv(m,S);uv=mapping['uv'];attrs=expr(m,u.MaterialExpressionMakeMaterialAttributes)
    color=patch_color(m,uv,original,clean,rects)
    assert edit.connect_material_expressions(color,'',attrs,'EmissiveColor')
    if points or parts:
        code='float2 p=UV*float2(1672,941);float mask=0;'
        for poly in parts or [points]:code+='{'+polygon(poly)+'mask=max(mask,hit?1:0);}'
        for poly in holes or []:code+='{'+polygon(poly)+'if(hit)mask=0;}'
        mask=custom(m,code+'return mask;',F1,{'UV':(uv,'')})
        assert edit.connect_material_expressions(mask,'',attrs,'OpacityMask')
    sn=math.sin(math.radians(48));cs=math.cos(math.radians(48))
    if baseline:
        legacy_foot=max(p[1] for p in baseline)
        foot_code=f'float x=UV.x*1672;float y={baseline[0][1]:.12f};'
        for (x0,y0),(x1,y1) in zip(baseline,baseline[1:]):
            assert x1!=x0,'A baseline segment must have nonzero source width'
            foot_code+=f'y=lerp(y,{y1:.12f},saturate((x-{x0:.12f})/{x1-x0:.12f}));'
        legacy=f'max(0,({legacy_foot:.12f}-y)*{S*cs/sn:.12f})'
    else:
        foot_code=f'float y={0 if foot is None else foot:.12f}+(UV.x*1672-836)*{slope:.12f};'
        legacy='0'
    desired='Ground' if foot is None and not baseline else f'float3(Ground.x,(470.5-y)*{S/sn:.12f},0)'
    depth_code=foot_code+f'if(Perspective<0.5)return {legacy};float3 desired={desired};return max(0,dot(float3(0,0.5,-0.866025403784),desired-Position));'
    depth=custom(m,depth_code,F1,{'UV':(uv,''),'Ground':(mapping['ground'],''),'Position':(mapping['position'],''),'Perspective':(mapping['mode'],'')})
    # PixelDepthOffset is not exposed in Python MaterialProperty; the native attributes pin is public.
    assert edit.connect_material_expressions(depth,'',attrs,'PixelDepthOffset')
    if slope and not baseline:
        offset_code=f'if(Perspective>=0.5)return float3(0,0,0);return float3(0,{cs:.12f},{-sn:.12f})*(-(UV.x*1672-836)*{slope*S*cs/sn:.12f});'
        offset=custom(m,offset_code,F3,{'UV':(mapping['raw_uv'],''),'Perspective':(mapping['mode'],'')})
        assert edit.connect_material_expressions(offset,'',attrs,'WorldPositionOffset')
    m.set_editor_property('use_material_attributes',True)
    assert edit.connect_material_property(attrs,'',u.MaterialProperty.MP_MATERIAL_ATTRIBUTES)
    edit.recompile_material(m);assert lib.save_loaded_asset(m)
    return m

def patch_color(m,uv,original,clean,rects):
    source=expr(m,u.MaterialExpressionTextureObject,texture=original)
    replacement=expr(m,u.MaterialExpressionTextureObject,texture=clean)
    code='float2 p=UV*float2(1672,941);float mask=0;'
    for x0,y0,x1,y1 in rects:
        code+=f'mask=max(mask,1-smoothstep(0,3,max(abs(p.x-{(x0+x1)/2})-{(x1-x0)/2},abs(p.y-{(y0+y1)/2})-{(y1-y0)/2})));'
    code+='return lerp(Texture2DSample(Original,OriginalSampler,UV).rgb,Texture2DSample(Clean,CleanSampler,UV).rgb,mask);'
    color=custom(m,code,F3,{'UV':(uv,''),'Original':(source,''),'Clean':(replacement,'')})
    assert edit.connect_material_property(color,'',u.MaterialProperty.MP_EMISSIVE_COLOR)
    return color

def animate(actors,plane,rot,S,clean,wheel,materials_only=False):
    def card(name,code,texture_asset,depth):
        path='/Game/Greyford/Reference/M_Ambient_'+name
        m=lib.load_asset(path) if lib.does_asset_exist(path) else tools.create_asset('M_Ambient_'+name,'/Game/Greyford/Reference',u.Material,u.MaterialFactoryNew())
        edit.delete_all_material_expressions(m);m.set_editor_property('use_material_attributes',False);m.set_editor_property('two_sided',True)
        m.set_editor_property('shading_model',u.MaterialShadingModel.MSM_UNLIT);m.set_editor_property('blend_mode',u.BlendMode.BLEND_TRANSLUCENT)
        uv=reference_uv(m,S)['uv'];time=expr(m,u.MaterialExpressionTime)
        inputs={'UV':(uv,''),'T':(time,'')}
        if texture_asset:inputs['Art']=(expr(m,u.MaterialExpressionTextureObject,texture=texture_asset),'')
        rgba=custom(m,code,F4,inputs)
        rgb=expr(m,u.MaterialExpressionComponentMask,r=True,g=True,b=True,a=False)
        alpha=expr(m,u.MaterialExpressionComponentMask,r=False,g=False,b=False,a=True)
        assert edit.connect_material_expressions(rgba,'',rgb,'');assert edit.connect_material_expressions(rgba,'',alpha,'')
        edit.connect_material_property(rgb,'',u.MaterialProperty.MP_EMISSIVE_COLOR);edit.connect_material_property(alpha,'',u.MaterialProperty.MP_OPACITY)
        edit.recompile_material(m);assert lib.save_loaded_asset(m)
        if materials_only:return
        sn=math.sin(math.radians(48));cs=math.cos(math.radians(48))
        a=actors.spawn_actor_from_class(u.StaticMeshActor,u.Vector(0,cs*depth,-sn*depth))
        a.set_actor_label('Reference_Ambient_'+name);a.set_folder_path('Greyford/Reference/Ambient')
        a.set_editor_property('tags',['GreyfordReference','GreyfordAmbient'])
        a.static_mesh_component.set_static_mesh(plane);a.static_mesh_component.set_material(0,m)
        a.static_mesh_component.set_collision_profile_name('NoCollision');a.static_mesh_component.set_cast_shadow(False)
        a.set_actor_rotation(rot,False);a.set_actor_scale3d(u.Vector(1672*S/100,941*S/100,1))

    wheel_code='''float2 p=UV*float2(1672,941);float2 q=(p-float2(5,515))/float2(48,63);
    if(dot(q,q)>1.04)return float4(0,0,0,0);
    float a=T*0.349066;float2 v=float2(cos(a)*q.x+sin(a)*q.y,-sin(a)*q.x+cos(a)*q.y);
    float4 c=Texture2DSample(Art,ArtSampler,0.5+v*0.48);return float4(c.rgb*0.78,c.a);'''
    card('Waterwheel',wheel_code,wheel,7000)
    river=[[61,385],[162,425],[218,470],[251,494],[354,520],[350,568],[395,620],[442,658],[515,702],[590,738],[693,795],[752,844],[715,881],[628,850],[516,824],[420,778],[338,740],[248,699],[199,653],[104,635],[0,595],[0,544],[87,566],[131,554],[132,528],[97,495],[61,460],[51,417]]
    water_code='float2 p=UV*float2(1672,941);'+polygon(river)+'''if(!hit)return float4(0,0,0,0);
    float3 base=Texture2DSample(Art,ArtSampler,UV).rgb;
    float gate=smoothstep(0.025,0.11,min(base.g-base.r,base.b-base.r));
    float phase=frac(T/6),other=frac(phase+0.5);float2 d=float2(16,11)/float2(1672,941);
    float3 c=lerp(Texture2DSample(Art,ArtSampler,UV-d*phase).rgb,Texture2DSample(Art,ArtSampler,UV-d*other).rgb,abs(phase*2-1));
    gate*=smoothstep(0.015,0.08,min(c.g-c.r,c.b-c.r));
    c*=0.98+0.045*sin(p.x*0.27+p.y*0.51-T*2.8);return float4(c,gate*0.80);'''
    card('Creek',water_code,clean,8000)
    smoke_code='''float2 p=floor(UV*float2(1672,941)*1.5)/1.5;float density=0;
    float2 chimneys[2]={float2(435,54),float2(849,782)};
    for(int k=0;k<2;k++){for(int i=0;i<9;i++){
        float age=frac(T/5.5+i/9.0+k*0.37);float drift=sin(age*4+i*2.4)*4+age*9;
        float2 center=chimneys[k]+float2(drift,-age*72);
        float radius=4+age*12;float2 q=(p-center)/float2(radius,radius*1.15);
        float puff=exp(-dot(q,q)*2.0)*smoothstep(0,0.12,age)*(1-smoothstep(0.55,1,age));density+=puff*0.19;
    }}return float4(0.56,0.56,0.51,saturate(density));'''
    card('ChimneySmoke',smoke_code,None,-3500)

"""Build an editable native-node blend; preserve authored Greyford materials."""
import unreal as u

lib=u.EditorAssetLibrary
path='/Game/Design/M_RandomGroundBlend'
if not lib.does_asset_exist(path):
    m=u.AssetToolsHelpers.get_asset_tools().create_asset('M_RandomGroundBlend','/Game/Design',u.Material,u.MaterialFactoryNew())
    m.set_editor_property('shading_model',u.MaterialShadingModel.MSM_UNLIT)
    m.set_editor_property('two_sided',True)
    edit=u.MaterialEditingLibrary
    def node(cls,**props):
        n=edit.create_material_expression(m,cls)
        for k,v in props.items():n.set_editor_property(k,v)
        return n
    def link(a,b,pin=''):
        assert edit.connect_material_expressions(a,'',b,pin),(type(a),type(b),pin)
    def op(cls,a,b=None):
        n=node(cls)
        link(a,n,'A' if b is not None else '')
        if b is not None:link(b,n,'B')
        return n
    constant=lambda value:node(u.MaterialExpressionConstant,r=value)
    world=node(u.MaterialExpressionWorldPosition)
    xy=node(u.MaterialExpressionComponentMask,r=True,g=True,b=False,a=False);link(world,xy)
    scale=node(u.MaterialExpressionScalarParameter,parameter_name='UVScale',default_value=600.)
    uv=op(u.MaterialExpressionDivide,xy,scale)
    local=node(u.MaterialExpressionTextureCoordinate)
    width=node(u.MaterialExpressionScalarParameter,parameter_name='BlendWidth',default_value=.20)
    half=constant(.5)
    weights=[]
    for horizontal in (True,False):
        axis=node(u.MaterialExpressionComponentMask,r=horizontal,g=not horizontal,b=False,a=False);link(local,axis)
        low=op(u.MaterialExpressionMultiply,op(u.MaterialExpressionSaturate,op(u.MaterialExpressionDivide,op(u.MaterialExpressionSubtract,width,axis),width)),half)
        high=op(u.MaterialExpressionMultiply,op(u.MaterialExpressionSaturate,op(u.MaterialExpressionDivide,op(u.MaterialExpressionSubtract,axis,op(u.MaterialExpressionOneMinus,width)),width)),half)
        middle=op(u.MaterialExpressionOneMinus,op(u.MaterialExpressionAdd,low,high))
        weights.append((low,middle,high))
    color=None
    for y in range(3):
        for x in range(3):
            tex=node(u.MaterialExpressionTextureSampleParameter2D,parameter_name=f'G{x}{y}',texture=lib.load_asset('/Game/Greyford/Textures/T_GF_Grass'))
            link(uv,tex,edit.get_material_expression_input_names(tex)[0])
            weighted=op(u.MaterialExpressionMultiply,tex,op(u.MaterialExpressionMultiply,weights[0][x],weights[1][y]))
            color=weighted if color is None else op(u.MaterialExpressionAdd,color,weighted)
    assert edit.connect_material_property(color,'',u.MaterialProperty.MP_EMISSIVE_COLOR)
    edit.recompile_material(m)
    assert lib.save_loaded_asset(m)
u.log('RANDOM_GROUND_MATERIAL_PASS')

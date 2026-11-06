"""Create the editable ground shadow used by Greyford TOD."""
import unreal as u

lib = u.EditorAssetLibrary
edit = u.MaterialEditingLibrary
asset_path = '/Game/Design/M_TODPropShadow'
exists = lib.does_asset_exist(asset_path)
if not exists or '-RebuildTODShadow' in u.SystemLibrary.get_command_line():
    if exists:
        material = lib.load_asset(asset_path)
        edit.delete_all_material_expressions(material)
    else:
        material = u.AssetToolsHelpers.get_asset_tools().create_asset(
            'M_TODPropShadow', '/Game/Design', u.Material, u.MaterialFactoryNew())
    material.set_editor_property('shading_model', u.MaterialShadingModel.MSM_UNLIT)
    material.set_editor_property('blend_mode', u.BlendMode.BLEND_TRANSLUCENT)
    material.set_editor_property('two_sided', True)

    def node(cls, **properties):
        expression = edit.create_material_expression(material, cls)
        for name, value in properties.items():
            expression.set_editor_property(name, value)
        return expression

    def connect(source, target, input_name='', output_name=''):
        assert edit.connect_material_expressions(source, output_name, target, input_name), input_name

    def op(cls, left, right=None):
        result = node(cls)
        connect(left, result, 'A' if right is not None else '')
        if right is not None:
            connect(right, result, 'B')
        return result

    def scalar(name, value):
        return node(u.MaterialExpressionScalarParameter, parameter_name=name, default_value=value)

    def constant(value):
        return node(u.MaterialExpressionConstant, r=value)

    def vector(name, r, g, b):
        return node(u.MaterialExpressionVectorParameter, parameter_name=name,
                    default_value=u.LinearColor(r, g, b, 1))

    world = node(u.MaterialExpressionWorldPosition,
                 world_position_shader_offset=u.WorldPositionIncludedOffsets.WPT_EXCLUDE_ALL_SHADER_OFFSETS)
    foot = vector('ShadowFoot', 0, 0, 0)
    direction = vector('ShadowDirection', 1, 0, 0)
    length = scalar('ShadowLength', 100)
    # Measure distance along the original quad before the width axis is sheared.
    delta = op(u.MaterialExpressionSubtract, world, foot)
    along = op(u.MaterialExpressionDotProduct, delta, direction)
    t = op(u.MaterialExpressionSaturate, op(u.MaterialExpressionDivide, along, length))
    fade = op(u.MaterialExpressionOneMinus, t)
    v = node(u.MaterialExpressionComponentMask, r=False, g=True, b=False, a=False)
    connect(node(u.MaterialExpressionTextureCoordinate), v)
    bottom = scalar('ShadowFootFraction', .953125)
    sprite_y = op(u.MaterialExpressionMultiply, bottom, fade)
    texture = lib.load_asset('/Game/Greyford/Textures/T_GF_Oak')

    def weighted_alpha(x, y, weight):
        uv = op(u.MaterialExpressionAppendVector, op(u.MaterialExpressionSaturate, x),
                op(u.MaterialExpressionSaturate, y))
        silhouette = node(u.MaterialExpressionTextureSampleParameter2D,
                          parameter_name='ShadowTexture', texture=texture)
        connect(uv, silhouette, edit.get_material_expression_input_names(silhouette)[0])
        result = node(u.MaterialExpressionMultiply)
        connect(silhouette, result, 'A', 'A')
        connect(constant(weight), result, 'B')
        return result

    # Keep the contact edge sharp and widen the soft edge with distance from the prop.
    spread = op(u.MaterialExpressionMultiply, op(u.MaterialExpressionMultiply, t, t),
                scalar('TailSoftness', .018))
    center = weighted_alpha(v, sprite_y, .5)
    left = weighted_alpha(op(u.MaterialExpressionSubtract, v, spread),
                          op(u.MaterialExpressionSubtract, sprite_y, spread), .25)
    right = weighted_alpha(op(u.MaterialExpressionAdd, v, spread),
                           op(u.MaterialExpressionAdd, sprite_y, spread), .25)
    mask = op(u.MaterialExpressionAdd, center, op(u.MaterialExpressionAdd, left, right))
    # Hold more of the crown before fading to zero at the far end.
    tail = op(u.MaterialExpressionOneMinus,
              op(u.MaterialExpressionMultiply, op(u.MaterialExpressionMultiply, t, t), t))
    opacity = op(u.MaterialExpressionMultiply, mask,
                 op(u.MaterialExpressionMultiply, tail, scalar('ShadowOpacity', .48)))

    # The caster's original image-width axis pins the entire base, even as the sun turns.
    lateral = op(u.MaterialExpressionSubtract, v, node(u.MaterialExpressionConstant, r=.5))
    shear = op(u.MaterialExpressionMultiply, lateral, vector('ShadowShear', 0, 0, 0))
    color = vector('ShadowColor', .035, .045, .06)
    assert edit.connect_material_property(color, '', u.MaterialProperty.MP_EMISSIVE_COLOR)
    assert edit.connect_material_property(opacity, '', u.MaterialProperty.MP_OPACITY)
    assert edit.connect_material_property(shear, '', u.MaterialProperty.MP_WORLD_POSITION_OFFSET)
    edit.recompile_material(material)
    assert lib.save_loaded_asset(material)
u.log('TOD_PROP_SHADOW_MATERIAL_READY')

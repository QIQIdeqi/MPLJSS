"""Import the 2026-11-08 ImageGen PNGs and author the UMG effect material.

The PNGs in ArtSource/AlchemyUI_20261108 are exact copies of the final elements
from outputs/figma_ui_20261108/imagegen_elements/png. Run with UE Editor Python.
"""
from pathlib import Path

import unreal as u


SOURCE = Path(u.Paths.project_dir()) / 'ArtSource' / 'AlchemyUI_20261108'
DESTINATION = '/Game/UI/Alchemy'
ASSETS = (
    'art_cauldron', 'art_damage', 'art_experience', 'art_heal',
    'button_disabled', 'button_focus', 'button_hover', 'button_normal', 'button_pressed',
    'icon_alchemy', 'icon_coin', 'icon_dew', 'icon_fire_powder', 'icon_magic_shard',
    'icon_skill_bag', 'icon_skull', 'icon_xp_orb', 'keycap', 'minimap_border',
    'ornament_divider', 'panel_ornate', 'panel_secondary', 'skill_slot', 'skill_tray',
    'title_plaque', 'upgrade_card', 'upgrade_selected_outline', 'xp_fill', 'xp_track',
)
LIB = u.EditorAssetLibrary
EDIT = u.MaterialEditingLibrary
TOOLS = u.AssetToolsHelpers.get_asset_tools()


def import_textures():
    tasks = []
    for stem in ASSETS:
        source = SOURCE / (stem + '.png')
        assert source.is_file(), str(source)
        task = u.AssetImportTask()
        task.filename = str(source)
        task.destination_path = DESTINATION
        task.destination_name = 'T_' + ''.join(part.capitalize() for part in stem.split('_'))
        task.automated = True
        task.replace_existing = True
        task.save = False
        tasks.append(task)
    TOOLS.import_asset_tasks(tasks)
    for task in tasks:
        path = DESTINATION + '/' + task.destination_name
        texture = LIB.load_asset(path)
        assert task.imported_object_paths and isinstance(texture, u.Texture2D), path
        for name, value in (
            ('compression_settings', u.TextureCompressionSettings.TC_EDITOR_ICON),
            ('mip_gen_settings', u.TextureMipGenSettings.TMGS_NO_MIPMAPS),
            ('filter', u.TextureFilter.TF_BILINEAR),
            ('lod_group', u.TextureGroup.TEXTUREGROUP_UI),
            ('srgb', True), ('never_stream', True),
            ('address_x', u.TextureAddress.TA_CLAMP),
            ('address_y', u.TextureAddress.TA_CLAMP),
        ):
            texture.set_editor_property(name, value)
        assert LIB.save_loaded_asset(texture), path


def create_effect_material():
    name = 'M_AlchemyUIFX'
    path = DESTINATION + '/' + name
    material = LIB.load_asset(path) if LIB.does_asset_exist(path) else TOOLS.create_asset(
        name, DESTINATION, u.Material, u.MaterialFactoryNew())
    assert isinstance(material, u.Material), path
    EDIT.delete_all_material_expressions(material)
    material.set_editor_property('material_domain', u.MaterialDomain.MD_UI)
    material.set_editor_property('blend_mode', u.BlendMode.BLEND_TRANSLUCENT)

    def node(cls, x, y, **properties):
        expression = EDIT.create_material_expression(material, cls, x, y)
        assert expression is not None, cls
        for key, value in properties.items():
            expression.set_editor_property(key, value)
        return expression

    def connect(source, target, pin, output=''):
        assert EDIT.connect_material_expressions(source, output, target, pin), pin

    mask = node(u.MaterialExpressionCustom, -180, 40,
                description='Glow / ring / swirl opacity',
                output_type=u.CustomMaterialOutputType.CMOT_FLOAT1)
    inputs = []
    names = ('UV', 'Clock', 'EffectMode', 'Strength', 'Speed', 'Progress')
    for name in names:
        item = u.CustomInput()
        item.set_editor_property('input_name', name)
        inputs.append(item)
    mask.set_editor_property('inputs', inputs)
    mask.set_editor_property('code', '''
float2 p = (UV - 0.5) * 2.0;
float r = length(p);
float phase = Clock * Speed * 6.2831853;
float pulse = 0.82 + 0.18 * sin(phase);
float alpha;
if (EffectMode < 0.5)
{
    alpha = pow(saturate(1.0 - r), 2.2) * pulse;
}
else if (EffectMode < 1.5)
{
    float radius = lerp(0.35, 0.76, saturate(Progress));
    alpha = (1.0 - smoothstep(0.018, 0.085, abs(r - radius))) * pulse;
}
else
{
    float theta = atan2(p.y, p.x + 0.000001);
    float arms = pow(saturate(0.5 + 0.5 * cos(3.0 * theta - 11.0 * r - Progress * Speed * 20.0)), 4.0);
    alpha = arms * smoothstep(0.05, 0.22, r) * (1.0 - smoothstep(0.48, 0.96, r));
}
return saturate(alpha * Strength);
''')
    connect(node(u.MaterialExpressionTextureCoordinate, -540, -160), mask, 'UV')
    connect(node(u.MaterialExpressionTime, -540, -70), mask, 'Clock')
    for index, (parameter, default) in enumerate((('EffectMode', 0.0), ('Strength', 0.85),
                                                  ('Speed', 0.65), ('Progress', 1.0))):
        connect(node(u.MaterialExpressionScalarParameter, -540, 30 + index * 110,
                     parameter_name=parameter, default_value=default), mask, parameter)
    tint = node(u.MaterialExpressionVectorParameter, 60, -180, parameter_name='Tint',
                default_value=u.LinearColor(0.30, 0.65, 1.0, 1.0))
    alpha = node(u.MaterialExpressionMultiply, 140, 80)
    connect(mask, alpha, 'A')
    connect(tint, alpha, 'B', 'A')
    assert EDIT.connect_material_property(tint, '', u.MaterialProperty.MP_EMISSIVE_COLOR)
    assert EDIT.connect_material_property(alpha, '', u.MaterialProperty.MP_OPACITY)
    EDIT.recompile_material(material)
    assert LIB.save_loaded_asset(material), path


import_textures()
create_effect_material()
u.log('ALCHEMY_UI_IMPORT_PASS textures=%d material=%s/M_AlchemyUIFX' % (len(ASSETS), DESTINATION))

"""Import the two approved pickup sprites and their unlit materials."""
from pathlib import Path
import unreal as u

source = Path(u.Paths.project_dir()) / 'ArtSource' / 'Drops'
destination = '/Game/Art'
assets = u.EditorAssetLibrary
editor = u.MaterialEditingLibrary
tools = u.AssetToolsHelpers.get_asset_tools()

for name in ('DropCoin', 'DropXP'):
    texture_name = 'T_' + name
    texture_path = destination + '/' + texture_name
    if not assets.does_asset_exist(texture_path):
        task = u.AssetImportTask()
        task.filename = str(source / (texture_name + '.png'))
        task.destination_path = destination
        task.automated = True
        task.save = True
        tools.import_asset_tasks([task])
    texture = assets.load_asset(texture_path)
    assert texture, texture_path
    texture.set_editor_property('filter', u.TextureFilter.TF_NEAREST)
    texture.set_editor_property('mip_gen_settings', u.TextureMipGenSettings.TMGS_NO_MIPMAPS)
    texture.set_editor_property('compression_settings', u.TextureCompressionSettings.TC_EDITOR_ICON)
    texture.set_editor_property('never_stream', True)
    assert assets.save_loaded_asset(texture)

    material_name = 'M_' + name
    material_path = destination + '/' + material_name
    if assets.does_asset_exist(material_path):
        material = assets.load_asset(material_path)
    else:
        material = tools.create_asset(material_name, destination, u.Material, u.MaterialFactoryNew())
    editor.delete_all_material_expressions(material)
    material.set_editor_property('blend_mode', u.BlendMode.BLEND_MASKED)
    material.set_editor_property('shading_model', u.MaterialShadingModel.MSM_UNLIT)
    material.set_editor_property('two_sided', True)
    sample = editor.create_material_expression(material, u.MaterialExpressionTextureSample, -500, 0)
    sample.set_editor_property('texture', texture)
    assert editor.connect_material_property(sample, 'A', u.MaterialProperty.MP_OPACITY_MASK)
    color = sample
    output = 'RGB'
    if name == 'DropCoin':
        uv = editor.create_material_expression(material, u.MaterialExpressionTextureCoordinate, -500, 240)
        phase = editor.create_material_expression(material, u.MaterialExpressionScalarParameter, -500, 390)
        phase.set_editor_property('parameter_name', 'SweepPhase')
        sheen = editor.create_material_expression(material, u.MaterialExpressionCustom, -150, 0)
        sheen.set_editor_property('output_type', u.CustomMaterialOutputType.CMOT_FLOAT3)
        inputs = []
        for pin in ('CoinColor', 'UV', 'Phase'):
            entry = u.CustomInput()
            entry.set_editor_property('input_name', pin)
            inputs.append(entry)
        sheen.set_editor_property('inputs', inputs)
        sheen.set_editor_property('code', '''
float travel = frac(Phase) * 3.8 - 0.7;
float stripe = 1 - smoothstep(0.025, 0.12, abs(UV.x + 0.52 * UV.y - travel));
return CoinColor + float3(1.0, 0.67, 0.24) * stripe * 0.72;
''')
        assert editor.connect_material_expressions(sample, 'RGB', sheen, 'CoinColor')
        assert editor.connect_material_expressions(uv, '', sheen, 'UV')
        assert editor.connect_material_expressions(phase, '', sheen, 'Phase')
        color = sheen
        output = ''
    assert editor.connect_material_property(color, output, u.MaterialProperty.MP_EMISSIVE_COLOR)
    editor.recompile_material(material)
    assert assets.save_loaded_asset(material)

u.log('DROP_ART_IMPORT_PASS')

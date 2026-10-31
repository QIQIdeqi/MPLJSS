"""Import the prepared clean scene and source-pixel masked foreground cards into Unreal."""
import json
from pathlib import Path
import unreal as u

root = Path(u.Paths.project_dir()).resolve()
source = root / 'ArtSource' / 'ReferenceBattle60_20261031'
manifest = json.loads((source / 'layers.json').read_text(encoding='utf-8'))
dest = '/Game/ReferenceBattle'
lib = u.EditorAssetLibrary
edit = u.MaterialEditingLibrary
tools = u.AssetToolsHelpers.get_asset_tools()
for layer in manifest['layers']:
    name = layer['name']
    task = u.AssetImportTask()
    task.filename = str(source / layer['file'])
    task.destination_path = dest
    task.destination_name = 'T_' + name
    task.automated = True
    task.replace_existing = True
    task.save = True
    tools.import_asset_tasks([task])
    texture = lib.load_asset(dest + '/T_' + name)
    assert texture, name
    texture.set_editor_property('compression_settings', u.TextureCompressionSettings.TC_EDITOR_ICON)
    texture.set_editor_property('mip_gen_settings', u.TextureMipGenSettings.TMGS_NO_MIPMAPS)
    texture.set_editor_property('filter', u.TextureFilter.TF_NEAREST)
    texture.set_editor_property('never_stream', True)
    assert lib.save_loaded_asset(texture)
    mat_name = 'M_' + name
    mat_path = dest + '/' + mat_name
    material = lib.load_asset(mat_path) if lib.does_asset_exist(mat_path) else tools.create_asset(
        mat_name, dest, u.Material, u.MaterialFactoryNew())
    edit.delete_all_material_expressions(material)
    material.set_editor_property('two_sided', True)
    material.set_editor_property('shading_model', u.MaterialShadingModel.MSM_UNLIT)
    material.set_editor_property('blend_mode', u.BlendMode.BLEND_OPAQUE if name == 'Backdrop' else u.BlendMode.BLEND_MASKED)
    sample = edit.create_material_expression(material, u.MaterialExpressionTextureSample)
    sample.set_editor_property('texture', texture)
    assert edit.connect_material_property(sample, 'RGB', u.MaterialProperty.MP_EMISSIVE_COLOR)
    if name != 'Backdrop':
        assert edit.connect_material_property(sample, 'A', u.MaterialProperty.MP_OPACITY_MASK)
    edit.recompile_material(material)
    assert lib.save_loaded_asset(material)
    u.log('BATTLE_REFERENCE_IMPORTED ' + mat_path)
u.log('BATTLE_REFERENCE_IMPORT_PASS layers=%d' % len(manifest['layers']))

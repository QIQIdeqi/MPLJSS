"""Producer-run UE import: only the two directional attack textures, no maps/materials."""
from pathlib import Path
import unreal as u

root = Path(u.Paths.project_dir()).resolve()
source = root / 'ArtSource/RoseMageAttack_20261101/Runtime'
target = '/Game/Characters/RoseMage'
library = u.EditorAssetLibrary
tools = u.AssetToolsHelpers.get_asset_tools()
library.make_directory(target)
for direction in ('Side', 'Back'):
    name = f'T_RoseMage{direction}Attack'
    filename = source / f'{name}.png'
    assert filename.is_file(), filename
    task = u.AssetImportTask()
    task.filename = str(filename)
    task.destination_path = target
    task.destination_name = name
    task.automated = True
    task.save = True
    task.replace_existing = True
    tools.import_asset_tasks([task])
    texture = library.load_asset(f'{target}/{name}')
    assert texture, name
    assert texture.blueprint_get_size_x() == 4096 and texture.blueprint_get_size_y() == 512
    texture.set_editor_property('filter', u.TextureFilter.TF_NEAREST)
    texture.set_editor_property('mip_gen_settings', u.TextureMipGenSettings.TMGS_NO_MIPMAPS)
    texture.set_editor_property('compression_settings', u.TextureCompressionSettings.TC_EDITOR_ICON)
    texture.set_editor_property('compression_no_alpha', False)
    library.save_loaded_asset(texture)
u.log('ROSE_MAGE_ATTACK_IMPORT_PASS textures=2 frames_per_texture=8 fps=10 release_seconds=0.4')

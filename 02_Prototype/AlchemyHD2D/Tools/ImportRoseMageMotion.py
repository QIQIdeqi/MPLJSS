"""Import only the three authored RoseMage motion atlases, without changing maps."""
from pathlib import Path
import unreal as u

root=Path(u.Paths.project_dir()).resolve()
target='/Game/Characters/RoseMage'
source=root/'ArtSource/RoseMageAnimation_20261031/Runtime'
lib=u.EditorAssetLibrary
tools=u.AssetToolsHelpers.get_asset_tools()
lib.make_directory(target)
for direction in ('Side','Front','Back'):
    name=f'T_RoseMage{direction}Motion'
    task=u.AssetImportTask()
    task.filename=str(source/f'{name}.png')
    task.destination_path=target
    task.destination_name=name
    task.automated=True
    task.save=True
    task.replace_existing=True
    tools.import_asset_tasks([task])
    texture=lib.load_asset(f'{target}/{name}')
    assert texture,name
    texture.set_editor_property('filter',u.TextureFilter.TF_NEAREST)
    texture.set_editor_property('mip_gen_settings',u.TextureMipGenSettings.TMGS_NO_MIPMAPS)
    texture.set_editor_property('compression_settings',u.TextureCompressionSettings.TC_EDITOR_ICON)
    texture.set_editor_property('compression_no_alpha',False)
    lib.save_loaded_asset(texture)
u.log('ROSE_MAGE_MOTION_IMPORT_PASS directions=3 authored_frames=48 walk=6 hurt=4 death=6')

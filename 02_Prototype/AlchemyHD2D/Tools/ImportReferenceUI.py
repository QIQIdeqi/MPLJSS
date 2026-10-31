"""Import extracted UI art, then build an editable Widget Blueprint with real child widgets."""
import json
from pathlib import Path
import unreal as u

root=Path(u.Paths.project_dir())/'ArtSource/UIReference20261031'
data=json.loads((root/'manifest.json').read_text(encoding='utf-8'))
tools=u.AssetToolsHelpers.get_asset_tools()
for part in data['parts']:
    task=u.AssetImportTask();task.filename=str(root/(part['name']+'.png'));task.destination_path='/Game/UI/Reference'
    task.destination_name='T_'+part['name'];task.automated=True;task.replace_existing=True
    tools.import_asset_tasks([task]);asset=u.EditorAssetLibrary.load_asset(task.destination_path+'/'+task.destination_name)
    asset.set_editor_property('compression_settings',u.TextureCompressionSettings.TC_EDITOR_ICON)
    asset.set_editor_property('mip_gen_settings',u.TextureMipGenSettings.TMGS_NO_MIPMAPS)
    asset.set_editor_property('filter',u.TextureFilter.TF_BILINEAR)
    asset.set_editor_property('never_stream',True);u.EditorAssetLibrary.save_loaded_asset(asset)
factory=u.FontFileImportFactory();factory.set_editor_property('batch_create_font_asset',u.BatchCreateFontAsset.NO)
font_task=u.AssetImportTask();font_task.filename=str(root/'Fonts/DejaVuSerif.ttf');font_task.destination_path='/Game/UI/Reference'
font_task.destination_name='FF_ReferenceSerif';font_task.automated=True;font_task.replace_existing=True;font_task.factory=factory
tools.import_asset_tasks([font_task])
face=u.EditorAssetLibrary.load_asset('/Game/UI/Reference/FF_ReferenceSerif');assert face,'Reference serif font import failed'
u.EditorAssetLibrary.save_loaded_asset(face)
assert u.BattleReferenceWidget.create_editable_blueprint(),'Editable Widget Blueprint creation failed'
u.log('REFERENCE_UI_IMPORT_PASS textures='+str(len(data['parts']))+' blueprint=/Game/UI/Reference/WBP_BattleReference')

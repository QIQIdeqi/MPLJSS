from pathlib import Path
import unreal as u
lib=u.EditorAssetLibrary;tools=u.AssetToolsHelpers.get_asset_tools()
for name in ('S_MerchantBuy','S_MerchantSell'):
    task=u.AssetImportTask();task.filename=str(Path(u.Paths.project_dir())/'ArtSource/MerchantAudio'/(name+'.wav'))
    task.destination_path='/Game/Art/Audio';task.destination_name=name
    task.automated=True;task.save=True;task.replace_existing=True
    tools.import_asset_tasks([task]);sound=lib.load_asset('/Game/Art/Audio/'+name);assert sound
    sound.set_editor_property('looping',False);lib.save_loaded_asset(sound)
u.log('MERCHANT_AUDIO_IMPORT_PASS')

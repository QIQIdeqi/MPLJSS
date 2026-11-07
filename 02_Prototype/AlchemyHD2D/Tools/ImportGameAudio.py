"""Import original game audio and route it through the existing master mix."""
from pathlib import Path
import unreal as u

library = u.EditorAssetLibrary
tools = u.AssetToolsHelpers.get_asset_tools()
root = Path(u.Paths.project_dir()) / 'ArtSource' / 'GameAudio'
destination = '/Game/Art/Audio'
master = library.load_asset('/Game/Audio/SC_Master')
assert master and library.does_asset_exist('/Game/Audio/SM_Master')

buses = {}
children = list(master.get_editor_property('child_classes'))
for category, gain in {'Music': .30, 'SFX': .62, 'UI': .45, 'Ambience': .25}.items():
    name = 'SC_' + category
    path = destination + '/' + name
    bus = library.load_asset(path) if library.does_asset_exist(path) else tools.create_asset(
        name, destination, u.SoundClass, u.SoundClassFactory())
    bus.set_editor_property('parent_class', master)
    properties = bus.get_editor_property('properties')
    properties.set_editor_property('volume', gain)
    bus.set_editor_property('properties', properties)
    if bus not in children:
        children.append(bus)
    buses[category] = bus
    assert library.save_loaded_asset(bus)
master.set_editor_property('child_classes', children)
assert library.save_loaded_asset(master)

files = sorted(root.glob('*.wav'))
assert files
for path in files:
    task = u.AssetImportTask()
    task.filename = str(path)
    task.destination_path = destination
    task.automated = True
    task.replace_existing = True
    task.save = False
    tools.import_asset_tasks([task])
    sound = library.load_asset(destination + '/' + path.stem)
    category = ('Music' if path.stem.startswith('Music_') else
                'Ambience' if path.stem.startswith('Ambient_') else
                'UI' if path.stem.startswith('S_UI') else 'SFX')
    sound.set_editor_property('sound_class_object', buses[category])
    sound.set_editor_property('looping', category in ('Music', 'Ambience'))
    assert library.save_loaded_asset(sound)

for name in ('S_BossLock', 'S_MerchantBuy', 'S_MerchantSell'):
    sound = library.load_asset(destination + '/' + name)
    if sound:
        sound.set_editor_property('sound_class_object', buses['SFX'])
        assert library.save_loaded_asset(sound)
u.log('GAME_AUDIO_IMPORT_PASS waves=%d buses=%d' % (len(files), len(buses)))

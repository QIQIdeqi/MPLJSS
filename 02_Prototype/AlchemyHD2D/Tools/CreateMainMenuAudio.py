"""创建主音量 SoundClass + SoundMix 资产，用于主界面总音量控制。

Master SoundClass（全局声音类）+ Master SoundMix（混音器），配合
UGameplayStatics::SetSoundMixClassOverride 应用音量。
"""
import unreal as u

lib = u.EditorAssetLibrary
tools = u.AssetToolsHelpers.get_asset_tools()

dest = '/Game/Audio'
if not lib.does_directory_exist(dest):
    lib.make_directory(dest)

# 1. Master SoundClass。
sc_path = dest + '/SC_Master'
sc = None
if lib.does_asset_exist(sc_path):
    sc = lib.load_asset(sc_path)
else:
    factory = u.SoundClassFactory()
    sc = tools.create_asset('SC_Master', dest, u.SoundClass, factory)
lib.save_loaded_asset(sc)

# 2. Master SoundMix。
sm_path = dest + '/SM_Master'
sm = None
if lib.does_asset_exist(sm_path):
    sm = lib.load_asset(sm_path)
else:
    factory = u.SoundMixFactory()
    sm = tools.create_asset('SM_Master', dest, u.SoundMix, factory)
lib.save_loaded_asset(sm)

u.log('MAIN_MENU_AUDIO_PASS sc=%s sm=%s' % (sc_path, sm_path))

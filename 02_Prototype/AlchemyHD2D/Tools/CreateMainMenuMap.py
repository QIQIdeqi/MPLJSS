"""创建主菜单关卡 MainMenu：空关卡 + PlayerStart + 默认 GameMode。

主菜单是纯屏幕空间 UMG（全屏底图 + 按钮），运行时由 AAlchemyMode::StartPlay
检测地图名并 Spawn AMainMenuWorld，无需预先放置 3D Actor 或相机。
"""
import unreal as u

lib = u.EditorAssetLibrary
levels = u.get_editor_subsystem(u.LevelEditorSubsystem)
actors = u.get_editor_subsystem(u.EditorActorSubsystem)
world = u.get_editor_subsystem(u.UnrealEditorSubsystem).get_editor_world()

path = '/Game/UI/MainMenu/MainMenu'
if lib.does_asset_exist(path):
    assert levels.load_level(path)
else:
    assert levels.new_level(path)

persistent = levels.get_current_level()
assert persistent.get_path_name().startswith(path + '.'), persistent.get_path_name()
assert levels.set_current_level_by_name('MainMenu')

# 使用全局默认 GameMode（AlchemyMode，Config/DefaultEngine.ini 已配置），StartPlay 会按地图名判断进入主菜单。

# 放置一个 PlayerStart，保证 PlayerController 正常。
player_start = actors.spawn_actor_from_class(u.PlayerStart, u.Vector(0, 0, 0), u.Rotator(0, 0, 0))
player_start.set_actor_label('MainMenu_PlayerStart')

assert levels.save_current_level()
u.log('MAIN_MENU_MAP_PASS ' + path)

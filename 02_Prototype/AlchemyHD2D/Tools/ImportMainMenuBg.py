"""导入主界面底图 start_screen_2560x1440.png 到 UE 为 Texture2D。

用于主菜单全屏背景，保持 2560×1440 分辨率、sRGB、可流送。
"""
from pathlib import Path
import unreal as u

root = Path(u.Paths.project_dir()) / 'ArtSource'
src = root / 'start_screen_2560x1440.png'
dest = '/Game/UI/MainMenu'
name = 'T_StartScreen'

lib = u.EditorAssetLibrary
tools = u.AssetToolsHelpers.get_asset_tools()

if not lib.does_directory_exist(dest):
    lib.make_directory(dest)

task = u.AssetImportTask()
task.filename = str(src)
task.destination_path = dest
task.destination_name = name
task.automated = True
task.replace_existing = True
tools.import_asset_tasks([task])

tex = lib.load_asset(dest + '/' + name)
# 主菜单背景保持默认 sRGB + 常规 mip，全分辨率不压缩细节。
tex.set_editor_property('never_stream', False)
lib.save_loaded_asset(tex)
u.log('MAIN_MENU_BG_IMPORT_PASS %s' % name)

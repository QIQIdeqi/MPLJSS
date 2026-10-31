import unreal as u
from pathlib import Path
root=Path(u.Paths.project_dir())
dirty=list(u.EditorLoadingAndSavingUtils.get_dirty_map_packages())+list(u.EditorLoadingAndSavingUtils.get_dirty_content_packages())
(root/'Evidence/DefaultEntry_20261031/editor-reload-check.txt').write_text('\n'.join(p.get_path_name() for p in dirty) if dirty else 'CLEAN',encoding='utf-8')
if dirty:u.log_warning('DEFAULT_BATTLE_RELOAD_BLOCKED_UNSAVED '+','.join(p.get_path_name() for p in dirty))
else:u.SystemLibrary.quit_editor()

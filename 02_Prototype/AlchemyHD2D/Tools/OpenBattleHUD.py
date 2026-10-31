import unreal as u
asset=u.EditorAssetLibrary.load_asset('/Game/UI/Reference/WBP_BattleReference')
assert asset, 'Run Tools/SetupReference60.ps1 first.'
u.get_editor_subsystem(u.AssetEditorSubsystem).open_editor_for_assets([asset])

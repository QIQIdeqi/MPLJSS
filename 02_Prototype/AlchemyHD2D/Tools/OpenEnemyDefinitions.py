"""Open the production monster table and its placeable authoring Blueprint."""
import unreal as u

assets = [u.load_asset(path) for path in (
    '/Game/Design/DT_Enemies', '/Game/Design/BP_EnemyDesigner')]
assert all(assets), 'Run Tools/SetupEnemyDefinitions.py after building the project first.'
u.get_editor_subsystem(u.AssetEditorSubsystem).open_editor_for_assets(assets)

"""Reimport only the two cleaned textures and resize the existing HPBar slot."""
import hashlib
import json
import shutil
from pathlib import Path
import unreal as u

root = Path(u.Paths.project_dir()).resolve()
out = root / 'Evidence/HUDAssetCleanup_20261101'
out.mkdir(parents=True, exist_ok=True)
bp = u.EditorAssetLibrary.load_asset('/Game/UI/Reference/WBP_BattleReference')
assert bp, 'Existing HUD blueprint missing'
tree = u.find_object(bp, 'WidgetTree')
bar = u.find_object(tree, 'HPBar')
assert isinstance(bar, u.ProgressBar), 'Existing HPBar missing'
slot = bar.get_editor_property('slot')
assert isinstance(slot, u.CanvasPanelSlot)
p, size = slot.get_position(), slot.get_size()
assert (p.x, p.y, size.x, size.y) in ((213., 35., 270., 16.), (213., 34., 271., 17.)), 'Unexpected authored HP slot'
for name in ('HPFrame', 'MinimapDark'):
    assert isinstance(u.EditorAssetLibrary.load_asset('/Game/UI/Reference/T_' + name), u.Texture2D), name
for name in ('T_HPFrame', 'T_MinimapDark', 'WBP_BattleReference'):
    source = root / 'Content/UI/Reference' / (name + '.uasset')
    backup = out / 'original' / source.name
    backup.parent.mkdir(parents=True, exist_ok=True)
    if not backup.exists():
        shutil.copy2(source, backup)

records = []
for name in ('HPFrame', 'MinimapDark'):
    source = root / 'ArtSource/UIReference20261031' / (name + '.png')
    task = u.AssetImportTask()
    task.filename = str(source)
    task.destination_path = '/Game/UI/Reference'
    task.destination_name = 'T_' + name
    task.automated = True
    task.replace_existing = True
    u.AssetToolsHelpers.get_asset_tools().import_asset_tasks([task])
    asset = u.EditorAssetLibrary.load_asset('/Game/UI/Reference/T_' + name)
    assert isinstance(asset, u.Texture2D) and task.imported_object_paths, name
    asset.set_editor_property('compression_settings', u.TextureCompressionSettings.TC_EDITOR_ICON)
    asset.set_editor_property('mip_gen_settings', u.TextureMipGenSettings.TMGS_NO_MIPMAPS)
    asset.set_editor_property('filter', u.TextureFilter.TF_BILINEAR)
    asset.set_editor_property('never_stream', True)
    assert u.EditorAssetLibrary.save_loaded_asset(asset), name
    records.append({'asset': asset.get_path_name(), 'png_sha256': hashlib.sha256(source.read_bytes()).hexdigest()})

if (p.y, size.x, size.y) != (34., 271., 17.):
    with u.ScopedEditorTransaction('Fit dynamic HP to cleaned frame interior'):
        bp.modify()
        slot.modify()
        slot.set_position(u.Vector2D(213., 34.))
        slot.set_size(u.Vector2D(271., 17.))
        assert u.BlueprintEditorLibrary.compile_blueprint(bp), 'HUD compile failed'
        assert u.EditorAssetLibrary.save_loaded_asset(bp), 'HUD save failed'
(out / 'import.json').write_text(json.dumps({'textures': records, 'hp_slot_before': [p.x, p.y, size.x, size.y],
    'hp_slot_after': [213, 34, 271, 17], 'tree_rebuilt': False}, indent=2) + '\n', encoding='utf-8')
u.log('REFERENCE_UI_CLEANUP_IMPORT_PASS')

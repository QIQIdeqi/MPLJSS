"""Align existing HUD text slots; never regenerate the widget tree or replace fonts."""
import json
from pathlib import Path
import unreal as u

root = Path(u.Paths.project_dir()).resolve()
out = root / 'Evidence/HUDTextAlignment_20261101'
out.mkdir(parents=True, exist_ok=True)
bp = u.EditorAssetLibrary.load_asset('/Game/UI/Reference/WBP_BattleReference')
assert bp, 'Reference widget blueprint missing'
tree = u.find_object(bp, 'WidgetTree')
assert tree, 'Existing designer tree missing'
targets = []
records = []
for name, previous_y, target_y in [('LevelText', 20., 26.), ('KillText', 10., 16.),
                                   ('TimerText', 16., 17.), ('CoinText', 10., 16.)]:
    text = u.find_object(tree, name)
    assert isinstance(text, u.TextBlock), name
    if name == 'LevelText':
        fit = u.find_object(tree, 'LevelNumberFit')
        if fit:
            assert isinstance(fit, u.ScaleBox) and text.get_parent() == fit
            text = fit
    slot = text.get_editor_property('slot')
    assert isinstance(slot, u.CanvasPanelSlot), name
    p = slot.get_position()
    assert min(abs(p.y - previous_y), abs(p.y - target_y)) < .001, f'{name}: unexpected designer Y {p.y}'
    targets.append((slot, p, target_y))
    records.append({'name': name, 'before': [p.x, p.y], 'after': [p.x, target_y]})

# All nodes are validated before the first edit. Absolute targets make reruns idempotent.
changed = any(abs(p.y - y) > .001 for slot, p, y in targets)
if changed:
    with u.ScopedEditorTransaction('Align reference HUD text baselines'):
        bp.modify()
        for slot, p, y in targets:
            slot.modify()
            slot.set_position(u.Vector2D(p.x, y))
        assert u.BlueprintEditorLibrary.compile_blueprint(bp), 'Blueprint compile failed'
        assert u.EditorAssetLibrary.save_loaded_asset(bp), 'Blueprint save failed'
for slot, p, y in targets:
    actual = slot.get_position()
    assert abs(actual.x - p.x) < .001 and abs(actual.y - y) < .001
(out / 'designer-update.json').write_text(json.dumps({'changed': changed, 'tree': tree.get_path_name(), 'targets': records}, indent=2) + '\n', encoding='utf-8')
u.log('REFERENCE_HUD_TEXT_CALIBRATION_PASS')

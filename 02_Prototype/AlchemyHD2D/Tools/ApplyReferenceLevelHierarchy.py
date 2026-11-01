"""Add an Lv prefix and down-only number container to the existing designer tree."""
import json
from pathlib import Path
import unreal as u

root = Path(u.Paths.project_dir()).resolve()
out = root / 'Evidence/LevelTypography_20261101'
out.mkdir(parents=True, exist_ok=True)
bp = u.EditorAssetLibrary.load_asset('/Game/UI/Reference/WBP_BattleReference')
assert bp
tree = u.find_object(bp, 'WidgetTree')
canvas = u.find_object(tree, 'ReferenceCanvas')
level = u.find_object(tree, 'LevelText')
assert isinstance(canvas, u.CanvasPanel) and isinstance(level, u.TextBlock)
prefix = u.find_object(tree, 'LevelPrefixText')
fit = u.find_object(tree, 'LevelNumberFit')
changed = not prefix and not fit
if changed:
    assert level.get_parent() == canvas, 'Unexpected original level parent'
    old = level.get_editor_property('slot').get_position()
    assert abs(old.x - 126) < .001 and abs(old.y - 26) < .001, 'Unexpected designer level position'
    assert abs(level.get_editor_property('font').size - 18) < .001, 'Unexpected designer number font size'
    with u.ScopedEditorTransaction('Separate reference level prefix and number'):
        bp.modify()
        canvas.modify()
        level.modify()
        prefix = u.new_object(u.TextBlock, outer=tree, name='LevelPrefixText')
        font = level.get_editor_property('font').copy()
        font.size = 14
        prefix.set_font(font)
        prefix.set_color_and_opacity(level.get_editor_property('color_and_opacity'))
        prefix.set_shadow_offset(level.get_editor_property('shadow_offset'))
        prefix.set_shadow_color_and_opacity(level.get_editor_property('shadow_color_and_opacity'))
        prefix.set_visibility(u.SlateVisibility.HIT_TEST_INVISIBLE)
        prefix.set_text('Lv')
        prefix_slot = canvas.add_child_to_canvas(prefix)
        prefix_slot.set_position(u.Vector2D(129, 30))
        prefix_slot.set_size(u.Vector2D(30, 27))
        fit = u.new_object(u.ScaleBox, outer=tree, name='LevelNumberFit')
        fit.set_stretch(u.Stretch.SCALE_TO_FIT)
        fit.set_stretch_direction(u.StretchDirection.DOWN_ONLY)
        fit.set_clipping(u.WidgetClipping.CLIP_TO_BOUNDS)
        fit.set_visibility(u.SlateVisibility.HIT_TEST_INVISIBLE)
        fit_slot = canvas.add_child_to_canvas(fit)
        fit_slot.set_position(u.Vector2D(160, 26))
        fit_slot.set_size(u.Vector2D(37, 33))
        font = level.get_editor_property('font').copy()
        font.letter_spacing = -83
        level.set_font(font)
        level.set_text('1')
        number_slot = fit.add_child(level)
        number_slot.set_horizontal_alignment(u.HorizontalAlignment.H_ALIGN_LEFT)
        number_slot.set_vertical_alignment(u.VerticalAlignment.V_ALIGN_TOP)
        assert u.BattleReferenceWidget.register_designer_widget_names()
        assert u.BlueprintEditorLibrary.compile_blueprint(bp)
        assert u.EditorAssetLibrary.save_loaded_asset(bp)
assert isinstance(prefix, u.TextBlock) and isinstance(fit, u.ScaleBox)
assert prefix.get_parent() == canvas and fit.get_parent() == canvas and level.get_parent() == fit
assert abs(prefix.get_editor_property('font').size - 14) < .001
assert abs(level.get_editor_property('font').size - 18) < .001 and level.get_editor_property('font').letter_spacing == -83
assert not fit.get_editor_property('ignore_inherited_scale')
assert fit.get_editor_property('stretch_direction') == u.StretchDirection.DOWN_ONLY
for widget, position, size in [(prefix, (129, 30), (30, 27)), (fit, (160, 26), (37, 33))]:
    slot = widget.get_editor_property('slot')
    p, s = slot.get_position(), slot.get_size()
    assert abs(p.x - position[0]) < .001 and abs(p.y - position[1]) < .001
    assert abs(s.x - size[0]) < .001 and abs(s.y - size[1]) < .001
(out / 'designer-update.json').write_text(json.dumps({'changed': changed, 'preserved_number_widget': level.get_path_name(), 'prefix': prefix.get_path_name(), 'fit': fit.get_path_name()}, indent=2) + '\n', encoding='utf-8')
u.log('REFERENCE_LEVEL_HIERARCHY_PASS')

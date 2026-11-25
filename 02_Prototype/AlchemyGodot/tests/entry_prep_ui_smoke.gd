extends SceneTree

const UI := preload("res://scenes/entry_select_ui.tscn")
const PROFILE := preload("res://scripts/run/profile_store.gd")
const LEVEL_ENTRY := preload("res://scripts/levels/level_entry.gd")
const LEVEL_CATALOG := preload("res://scripts/levels/level_catalog.gd")
var checks := 0
var failures: Array[String] = []
var confirmations := 0
var cancellations := 0

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var catalog = load("res://levels/catalog.tres")
	var save := ConfigFile.new()
	var profile = PROFILE.new()
	profile.setup(save)
	profile.ability_inventory["burst"] = 2
	var initial_inventory: Dictionary = profile.ability_inventory.duplicate(true)
	var ui = UI.instantiate()
	root.add_child(ui)
	await process_frame
	ui.setup(null, profile, catalog)
	ui.confirmed.connect(func(_level, _ability): confirmations += 1)
	ui.cancelled.connect(func(): cancellations += 1)
	ui.open()
	await process_frame
	await process_frame
	check(ui.level_buttons.size() == catalog.selectable_levels().size(), "actual catalog drives visible destinations")
	check(ui.level_buttons.size() == 1 and ui.level_buttons.has(&"greyford_01"), "only real normal level is selectable")
	check(not ui.level_buttons.has(&"greyford_01_boss"), "Boss is not a village destination")
	check(ui.ability_buttons.size() == 7, "initial plus six abilities are present")
	check(ui.ability_buttons[&"bounce"].disabled, "out-of-stock ability cannot be selected")
	check(not ui.confirm_button.disabled, "free initial entry is available")
	var ability_viewport: Rect2 = ui.initial_list.get_parent().get_parent().get_global_rect()
	for button in ui.ability_buttons.values():
		check(ability_viewport.grow(1).encloses(button.get_global_rect()), "%s visible without scrolling" % button.name)
		check(button.get_child(0).get_combined_minimum_size().y <= button.size.y + 1, "%s content fits card height" % button.name)
	check(ui.ability_summary.size.x >= 100, "ability summary has space for its full name")
	ui.select_ability(&"burst")
	check(ui.selected_ability == &"burst", "in-stock ability can be selected")
	check(profile.ability_inventory == initial_inventory, "draft selection does not consume inventory")
	ui.select_ability(&"bounce")
	check(ui.selected_ability == &"burst", "unavailable selection leaves draft intact")
	var many = LEVEL_CATALOG.new()
	for i in 12:
		var entry = LEVEL_ENTRY.new()
		entry.level_id = StringName("fixture_%d" % i)
		entry.display_name = "测试目的地 %d" % i
		entry.kind = 1
		entry.selectable = true
		entry.enabled = true
		entry.sort_order = i
		entry.description = "仅在自动检查中创建，不写入正式总表。"
		many.entries.append(entry)
	ui.catalog = many
	ui.build_ui()
	await process_frame
	await process_frame
	check(ui.level_buttons.size() == 12, "future multiple destinations populate a scrolling list")
	ui.select_level(&"fixture_11")
	check(ui.selected_level == &"fixture_11" and ui.selected_ability == &"burst", "switching level preserves ability draft")
	check(ui.level_list.size.y > ui.level_list.get_parent().size.y, "many destinations overflow into vertical scrolling")
	for dimensions in [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(1600, 1000)]:
		root.size = dimensions
		await process_frame
		ui._fit_panel()
		await process_frame
		var bounds := Rect2(ui.panel.position, ui.panel.size * ui.panel.scale)
		var viewport_bounds := Rect2(Vector2.ZERO, root.get_visible_rect().size)
		check(viewport_bounds.encloses(bounds), "preparation fits viewport %s" % dimensions)
		check(ui.confirm_button.get_global_rect().end.x <= viewport_bounds.end.x + 1, "confirm remains in viewport %s" % dimensions)
	ui._confirm()
	ui._confirm()
	check(confirmations == 1 and ui.busy, "duplicate confirmation is blocked while entry is pending")
	check(ui.visible and profile.ability_inventory == initial_inventory, "UI does not hide or consume on confirm")
	ui.show_error("测试场景不可用")
	check(not ui.busy and ui.feedback.text == "测试场景不可用", "failed entry returns to an editable draft with an error")
	var cancel_event := InputEventAction.new()
	cancel_event.action = &"ui_cancel"
	cancel_event.pressed = true
	ui._input(cancel_event)
	check(not ui.visible and cancellations == 1, "Escape closes once and emits cancellation")
	check(profile.ability_inventory == initial_inventory, "cancellation leaves inventory unchanged")
	ui.free()
	await process_frame
	print("ENTRY_PREP_UI_SMOKE: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

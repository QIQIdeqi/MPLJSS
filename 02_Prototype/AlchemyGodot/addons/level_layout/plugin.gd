@tool
extends EditorPlugin

const Generator = preload("res://scripts/level_layout.gd")
const Preview = preload("res://addons/level_layout/map_preview.gd")
const Preset = preload("res://levels/preset.gd")
const PRESET_PATHS := ["res://levels/normal.tres", "res://levels/boss.tres"]

var dock: VBoxContainer
var preview: Preview
var settings: Preset
var seed_input: SpinBox
var brushes: OptionButton
var status: Label

func _enter_tree() -> void:
	dock = VBoxContainer.new()
	dock.custom_minimum_size.y = 260
	var tools := HBoxContainer.new()
	dock.add_child(tools)
	var stages := OptionButton.new()
	stages.add_item("普通战斗")
	stages.add_item("Boss 场地")
	stages.item_selected.connect(_select_stage)
	tools.add_child(stages)
	seed_input = SpinBox.new()
	seed_input.min_value = -2147483648
	seed_input.max_value = 2147483647
	seed_input.tooltip_text = "预览 Seed"
	tools.add_child(seed_input)
	_button(tools, "按 Seed 生成", _reroll.bind(0))
	_button(tools, "重摇地面", _reroll.bind(1))
	_button(tools, "重摇物件", _reroll.bind(2))
	_button(tools, "编辑配置", func() -> void: EditorInterface.edit_resource(settings))
	_button(tools, "保存配置", _save_preset)

	var painting := HBoxContainer.new()
	dock.add_child(painting)
	brushes = OptionButton.new()
	painting.add_child(brushes)
	var legend := Label.new()
	legend.text = "左键涂格并锁定，右键解除对应层的锁定。预览锁格不进入正式开局。"
	painting.add_child(legend)
	status = Label.new()
	dock.add_child(status)
	preview = Preview.new()
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.cell_pressed.connect(_paint_cell)
	dock.add_child(preview)
	add_control_to_bottom_panel(dock, "Alchemy 关卡")
	_select_stage(0)

func _exit_tree() -> void:
	remove_control_from_bottom_panel(dock)
	dock.queue_free()

func _button(row: HBoxContainer, title: String, action: Callable) -> void:
	var button := Button.new()
	button.text = title
	button.pressed.connect(action)
	row.add_child(button)

func _select_stage(index: int) -> void:
	settings = load(PRESET_PATHS[index])
	preview.layout = {}
	preview.preset = settings
	preview.spawn = Vector2(640, 450) if settings.boss else Vector2(640, 430)
	seed_input.value = settings.preview_seed
	_reroll(0)

func _reroll(layer: int) -> void:
	var old_ground := settings.ground_seed_offset
	var old_prop := settings.prop_seed_offset
	var old_seed := settings.preview_seed
	if layer == 0:
		settings.preview_seed = int(seed_input.value)
	elif layer == 1:
		settings.ground_seed_offset += 1
	elif layer == 2:
		settings.prop_seed_offset += 1
	if not _refresh():
		settings.preview_seed = old_seed
		settings.ground_seed_offset = old_ground
		settings.prop_seed_offset = old_prop
	seed_input.set_value_no_signal(settings.preview_seed)

func _refresh() -> bool:
	var selected := brushes.get_selected_id()
	brushes.clear()
	brushes.add_item("物件 · 留空", settings.palette.size())
	for i in settings.palette.size():
		var brush := settings.palette[i]
		if brush != null:
			brushes.add_item(("地面 · " if brush.ground else "物件 · ") + brush.display_name, i)
	var selected_index := brushes.get_item_index(selected)
	brushes.select(maxi(0, selected_index))
	var result := Generator.build(settings, settings.preview_seed, Preview.BOUNDS, preview.spawn, Vector2.ZERO, true)
	if not result.error.is_empty():
		status.text = result.error + "。保留上一次成功预览。"
		preview.queue_redraw()
		return false
	preview.layout = result
	preview.queue_redraw()
	status.text = "Seed %d · 地面 %d 格 · 物件 %d 个" % [settings.preview_seed, result.tiles.size(), result.props.size()]
	return true

func _paint_cell(cell: int, unlock: bool) -> void:
	var selected := brushes.get_selected_id()
	if selected < 0:
		return
	var ground := selected < settings.palette.size() and settings.palette[selected].ground
	var locks := settings.locked_ground if ground else settings.locked_props
	var had_cell := locks.has(cell)
	var previous: int = locks.get(cell, -1)
	if unlock:
		locks.erase(cell)
	else:
		locks[cell] = selected if selected < settings.palette.size() else -1
	if not _refresh():
		if had_cell:
			locks[cell] = previous
		else:
			locks.erase(cell)

func _save_preset() -> void:
	if not _refresh():
		return
	var result := Generator.build(settings, settings.preview_seed, Preview.BOUNDS, preview.spawn)
	if not result.error.is_empty():
		status.text = "正式生成校验失败 · " + result.error
		return
	var outcome := ResourceSaver.save(settings)
	status.text += " · 已保存" if outcome == OK else " · 保存失败（%d）" % outcome

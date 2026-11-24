@tool
extends EditorPlugin

const Generator = preload("res://scripts/level_layout.gd")
const Preview = preload("res://addons/level_layout/map_preview.gd")
const EnemyWaveDock = preload("res://addons/level_layout/enemy_wave_dock.gd")
const CatalogDock = preload("res://addons/level_layout/catalog_dock.gd")
const Preset = preload("res://levels/preset.gd")

var dock: VBoxContainer
var enemy_dock: EnemyWaveDock
var catalog_dock: CatalogDock
var stages: OptionButton
var stage_entries: Array[Resource] = []
var current_entry: Resource
var preview: Preview
var settings: Preset
var seed_input: SpinBox
var width_input: SpinBox
var height_input: SpinBox
var brushes: OptionButton
var status: Label

func _enter_tree() -> void:
	dock = VBoxContainer.new()
	var tools := HBoxContainer.new()
	dock.add_child(tools)
	stages = OptionButton.new()
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
	_button(tools, "编辑配置", func() -> void:
		if settings:
			EditorInterface.edit_resource(settings))
	_button(tools, "保存配置", _save_preset)

	var area := HBoxContainer.new()
	dock.add_child(area)
	width_input = _size_input(area, "区域宽度", Preset.MIN_PLAYABLE_SIZE.x, Preset.MAX_PLAYABLE_SIZE.x)
	height_input = _size_input(area, "区域高度", Preset.MIN_PLAYABLE_SIZE.y, Preset.MAX_PLAYABLE_SIZE.y)
	width_input.name = "PlayableWidth"
	height_input.name = "PlayableHeight"
	width_input.value_changed.connect(_update_playable_size)
	height_input.value_changed.connect(_update_playable_size)

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
	preview.custom_minimum_size.y = 200.0 * EditorInterface.get_editor_scale()
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.cell_pressed.connect(_paint_cell)
	dock.add_child(preview)
	add_control_to_bottom_panel(dock, "Alchemy 关卡")
	enemy_dock = EnemyWaveDock.new()
	add_control_to_bottom_panel(enemy_dock, "怪物波次")
	catalog_dock = CatalogDock.new()
	catalog_dock.level_selected.connect(_catalog_selected)
	catalog_dock.editor_requested.connect(_open_level_settings)
	add_control_to_bottom_panel(catalog_dock, "关卡总表")
	_refresh_stages()
	if not stage_entries.is_empty():
		_select_stage(0)

func _exit_tree() -> void:
	if settings:
		settings.changed.disconnect(_on_preset_changed)
	remove_control_from_bottom_panel(catalog_dock)
	catalog_dock.queue_free()
	remove_control_from_bottom_panel(enemy_dock)
	enemy_dock.queue_free()
	remove_control_from_bottom_panel(dock)
	dock.queue_free()

func _button(row: HBoxContainer, title: String, action: Callable) -> void:
	var button := Button.new()
	button.text = title
	button.pressed.connect(action)
	row.add_child(button)

func _size_input(row: HBoxContainer, title: String, minimum: int, maximum: int) -> SpinBox:
	var label := Label.new()
	label.text = title
	row.add_child(label)
	var spin := SpinBox.new()
	spin.custom_minimum_size.x = 112.0 * EditorInterface.get_editor_scale()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.suffix = "px"
	spin.update_on_text_changed = true
	spin.tooltip_text = "%d–%d px。红线实时更新，保存配置后用于开局。" % [minimum, maximum]
	row.add_child(spin)
	return spin

func _select_stage(index: int) -> void:
	if index < 0 or index >= stage_entries.size():
		return
	var entry: Resource = stage_entries[index]
	catalog_dock.select_level(entry.level_id)

func _refresh_stages() -> void:
	stages.clear()
	stage_entries.clear()
	var catalog: Resource = catalog_dock.catalog
	if catalog == null:
		return
	for entry: Resource in catalog.entries:
		if entry != null and entry.kind != 0 and entry.layout is Preset:
			stage_entries.append(entry)
			stages.add_item(entry.display_name)
			stages.set_item_tooltip(stages.item_count - 1, String(entry.level_id))

func _catalog_selected(entry: Resource) -> void:
	_refresh_stages()
	if entry == null or entry.kind == 0 or not entry.layout is Preset:
		if settings:
			settings.changed.disconnect(_on_preset_changed)
		settings = null
		current_entry = entry
		preview.preset = null
		preview.layout = {}
		preview.queue_redraw()
		width_input.editable = false
		height_input.editable = false
		stages.select(-1)
		enemy_dock.set_table(null)
		status.text = "村庄使用独立手工场景。请在“关卡总表”点击“打开场景”；随机预览仅用于战斗关卡。"
		return
	var index := stage_entries.find(entry)
	if index >= 0:
		stages.select(index)
	_apply_entry(entry)

func _open_level_settings(entry: Resource, section: StringName) -> void:
	_catalog_selected(entry)
	if entry == null or entry.kind == 0:
		return
	if section == &"layout" and settings:
		EditorInterface.edit_resource(settings)
		make_bottom_panel_item_visible(dock)
	elif section == &"waves" and entry.enemy_config:
		EditorInterface.edit_resource(entry.enemy_config)
		make_bottom_panel_item_visible(enemy_dock)

func _apply_entry(entry: Resource) -> void:
	if settings:
		settings.changed.disconnect(_on_preset_changed)
	current_entry = entry
	settings = entry.layout as Preset
	width_input.editable = true
	height_input.editable = true
	preview.layout = {}
	preview.preset = settings
	preview.spawn = entry.spawn_position
	enemy_dock.set_table(entry.enemy_config, String(entry.level_id))
	_sync_size_inputs()
	settings.changed.connect(_on_preset_changed)
	seed_input.value = settings.preview_seed
	_reroll(0)

func _update_playable_size(_value: float) -> void:
	if settings == null:
		return
	settings.playable_size = Vector2i(int(width_input.value), int(height_input.value))

func _sync_size_inputs() -> void:
	if int(width_input.value) != settings.playable_size.x:
		width_input.set_value_no_signal(settings.playable_size.x)
	if int(height_input.value) != settings.playable_size.y:
		height_input.set_value_no_signal(settings.playable_size.y)

func _on_preset_changed() -> void:
	_sync_size_inputs()
	_refresh()

func _reroll(layer: int) -> void:
	if settings == null:
		return
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
	if settings == null:
		return false
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
		status.text = result.error + "。红线显示当前范围，地块保留上一次成功预览。"
		preview.queue_redraw()
		return false
	preview.layout = result
	preview.queue_redraw()
	status.text = "Seed %d · 地面 %d 格 · 物件 %d 个" % [settings.preview_seed, result.tiles.size(), result.props.size()]
	return true

func _paint_cell(cell: int, unlock: bool) -> void:
	if settings == null:
		return
	var selected := brushes.get_selected_id()
	if selected < 0:
		return
	var ground := selected < settings.palette.size() and settings.palette[selected].ground
	var locks := settings.locked_ground if ground else settings.locked_props
	if unlock:
		locks.erase(cell)
		_refresh()
		return
	var had_cell := locks.has(cell)
	var previous: int = locks.get(cell, -1)
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

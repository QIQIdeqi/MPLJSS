@tool
extends VBoxContainer

const WaveTable = preload("res://levels/enemy_wave_table.gd")
const TABLE_PATH := "res://levels/first_level_enemies.tres"

var table: WaveTable
var level_name: LineEdit
var opening_count: SpinBox
var grid: GridContainer
var status: Label
var save_button: Button

func _ready() -> void:
	name = "EnemyWaveDock"
	custom_minimum_size.y = 430
	var toolbar := HBoxContainer.new()
	add_child(toolbar)
	_label(toolbar, "关卡", 0)
	level_name = LineEdit.new()
	level_name.custom_minimum_size.x = 234
	level_name.tooltip_text = "关卡显示名称"
	level_name.text_changed.connect(_set_level_name)
	toolbar.add_child(level_name)
	_label(toolbar, "开局怪物", 0)
	opening_count = _number(toolbar, 0, 0, 1, _set_opening_count, 48)
	opening_count.name = "OpeningCount"
	save_button = _button(toolbar, "保存怪物表", _save)
	_button(toolbar, "在 Inspector 打开", _inspect)
	_button(toolbar, "刷新表格", _refresh)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	grid = GridContainer.new()
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	scroll.add_child(grid)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)

	if ResourceLoader.exists(TABLE_PATH):
		table = ResourceLoader.load(TABLE_PATH) as WaveTable
	_refresh()

func _refresh() -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	if table == null:
		status.text = "无法读取怪物表 " + TABLE_PATH
		save_button.disabled = true
		level_name.editable = false
		opening_count.editable = false
		return
	level_name.text = table.level_name
	opening_count.set_value_no_signal(table.opening_count)
	var wave_count := table.start_seconds.size()
	if wave_count == 0 or table.spawn_intervals.size() != wave_count or table.alive_caps.size() != wave_count:
		status.text = "波次数组长度不一致。请在 Inspector 修复后刷新。"
		save_button.disabled = true
		return
	for row in table.rows:
		if row == null or row.wave_weights.size() != wave_count:
			status.text = "怪物行或权重列缺失。请在 Inspector 修复后刷新。"
			save_button.disabled = true
			return
	grid.columns = wave_count + 2
	_label(grid, "怪物", 128)
	_label(grid, "素材图集", 222)
	for wave in wave_count:
		_label(grid, "第 %d 波" % (wave + 1), 100)

	_label(grid, "波次开始（秒）", 128)
	_label(grid, "从开局计时", 222)
	for wave in wave_count:
		var start := _number(grid, table.start_seconds[wave], 0, 0.01, _set_wave_value.bind(wave, &"start_seconds"))
		start.name = "Start%d" % wave
		if wave == 0:
			start.editable = false
			start.tooltip_text = "第 1 波固定从开局开始"
	_label(grid, "刷怪间隔（秒）", 128)
	_label(grid, "每隔多少秒刷出一只", 222)
	for wave in wave_count:
		var interval := _number(grid, table.spawn_intervals[wave], 0.25, 0.01, _set_wave_value.bind(wave, &"spawn_intervals"))
		interval.name = "Interval%d" % wave
	_label(grid, "同屏上限", 128)
	_label(grid, "存活怪物总数", 222)
	for wave in wave_count:
		var cap := _number(grid, table.alive_caps[wave], 0, 1, _set_wave_value.bind(wave, &"alive_caps"), 48)
		cap.name = "Cap%d" % wave
	_label(grid, "怪物名称", 128)
	_label(grid, "点击图集可查看或替换", 222)
	for wave in wave_count:
		_label(grid, "权重", 100)
	for row_index in table.rows.size():
		_add_monster_row(row_index, wave_count)
	_update_status()

func _add_monster_row(row_index: int, wave_count: int) -> void:
	var row = table.rows[row_index]
	var display := LineEdit.new()
	display.custom_minimum_size.x = 128
	display.text = row.display_name
	display.tooltip_text = "怪物类型 %d" % row.kind
	display.text_changed.connect(_set_monster_name.bind(row_index))
	grid.add_child(display)
	var picker := EditorResourcePicker.new()
	picker.name = "Atlas%d" % row_index
	picker.custom_minimum_size.x = 222
	picker.base_type = "Texture2D"
	picker.edited_resource = row.atlas
	picker.resource_selected.connect(func(texture: Resource, _inspect_only: bool) -> void: EditorInterface.edit_resource(texture))
	picker.resource_changed.connect(_set_monster_atlas.bind(row_index))
	grid.add_child(picker)
	for wave in wave_count:
		var weight := _number(grid, row.wave_weights[wave], 0, 0.01, _set_monster_weight.bind(row_index, wave))
		weight.name = "Weight%d_%d" % [row_index, wave]

func _label(parent: Container, title: String, width: float) -> void:
	var label := Label.new()
	label.text = title
	label.custom_minimum_size.x = width
	parent.add_child(label)

func _button(parent: Container, title: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _number(parent: Container, value: float, minimum: float, step: float, action: Callable, maximum := 100000.0) -> SpinBox:
	var spin := SpinBox.new()
	spin.custom_minimum_size.x = 118
	spin.min_value = minimum
	spin.max_value = maximum
	spin.allow_greater = maximum == 100000.0
	spin.step = step
	spin.set_value_no_signal(value)
	spin.value_changed.connect(action)
	parent.add_child(spin)
	return spin

func _set_level_name(value: String) -> void:
	table.level_name = value
	_update_status()

func _set_opening_count(value: float) -> void:
	table.opening_count = int(value)
	_update_status()

func _set_wave_value(value: float, wave: int, key: StringName) -> void:
	var values = table.get(key)
	values[wave] = int(value) if key == &"alive_caps" else value
	table.set(key, values)
	_update_status()

func _set_monster_name(value: String, row_index: int) -> void:
	table.rows[row_index].display_name = value
	_update_status()

func _set_monster_atlas(value: Resource, row_index: int) -> void:
	table.rows[row_index].atlas = value as Texture2D
	_update_status()

func _set_monster_weight(value: float, row_index: int, wave: int) -> void:
	var row = table.rows[row_index]
	var weights: PackedFloat32Array = row.wave_weights
	weights[wave] = value
	row.wave_weights = weights
	_update_status()

func _inspect() -> void:
	if table != null:
		EditorInterface.edit_resource(table)

func _update_status() -> void:
	var problem := table.validation_error()
	save_button.disabled = not problem.is_empty()
	status.text = problem if save_button.disabled else "悬停权重可查看出场概率。保存后，下次进入首关时使用新配置。"
	for wave in table.start_seconds.size():
		var total := 0.0
		for row in table.rows:
			total += table.weight(row, wave)
		for row_index in table.rows.size():
			var spin := grid.get_node_or_null("Weight%d_%d" % [row_index, wave]) as SpinBox
			if spin:
				var chance := table.weight(table.rows[row_index], wave) / total if total > 0.0 else 0.0
				spin.tooltip_text = "本波出场概率 %.1f%% · 权重为 0 时不出场" % (chance * 100.0)

func _save() -> void:
	_update_status()
	if save_button.disabled:
		return
	var error := ResourceSaver.save(table, TABLE_PATH)
	if error == OK:
		status.text = "已保存 " + TABLE_PATH
	else:
		status.text = "保存失败（%d）" % error

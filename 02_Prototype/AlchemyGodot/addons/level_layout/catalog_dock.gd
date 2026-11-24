@tool
extends VBoxContainer

signal level_selected(entry: Resource)
signal editor_requested(entry: Resource, section: StringName)
const Catalog = preload("res://scripts/levels/level_catalog.gd")
const Entry = preload("res://scripts/levels/level_entry.gd")
const WaveTable = preload("res://levels/enemy_wave_table.gd")
const Preset = preload("res://levels/preset.gd")
const CATALOG_PATH := "res://levels/catalog.tres"

var catalog: Catalog
var current: Entry
var rows: Tree
var fields := {}
var message: Label
var updating := false
var new_dialog: ConfirmationDialog
var new_id: LineEdit
var new_name: LineEdit
var new_kind: OptionButton
var boss_picker: OptionButton
var layout_button: Button
var waves_button: Button
var boss_button: Button

func _ready() -> void:
	custom_minimum_size.y = 400
	var toolbar := HBoxContainer.new()
	add_child(toolbar)
	_button(toolbar, "新建独立关卡", _new_level_dialog)
	_button(toolbar, "校验总表", _validate)
	_button(toolbar, "保存总表和选中配置", _save)
	_button(toolbar, "打开场景", _open_scene)
	_button(toolbar, "在 Inspector 打开总表", func() -> void: EditorInterface.edit_resource(catalog))
	var shortcuts := HBoxContainer.new()
	add_child(shortcuts)
	layout_button = _button(shortcuts, "地块与物件设置", _request_editor.bind(&"layout"))
	waves_button = _button(shortcuts, "怪物波次设置", _request_editor.bind(&"waves"))
	boss_button = _button(shortcuts, "打开关联 Boss", _open_boss_scene)
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(split)
	rows = Tree.new()
	rows.custom_minimum_size = Vector2(570, 220)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.columns = 5
	rows.hide_root = true
	rows.select_mode = Tree.SELECT_ROW
	rows.column_titles_visible = true
	for i in 5:
		rows.set_column_title(i, ["关卡 ID", "名称", "类型", "村庄可选", "启用"][i])
	rows.item_selected.connect(_select_row)
	rows.item_activated.connect(_open_scene)
	split.add_child(rows)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 410
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(scroll)
	var form := GridContainer.new()
	form.columns = 2
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(form)
	_text_field(form, "level_id", "稳定 ID")
	_text_field(form, "display_name", "显示名称")
	var type := OptionButton.new()
	for title in ["局外村庄", "普通战斗", "Boss 场"]:
		type.add_item(title)
	type.item_selected.connect(func(value: int) -> void: _set_value(value, &"kind"))
	_field(form, "kind", "类型", type)
	_text_field(form, "scene_path", "独立场景 .tscn")
	boss_picker = OptionButton.new()
	boss_picker.fit_to_longest_item = false
	boss_picker.item_selected.connect(_choose_boss)
	_field(form, "boss_level_id", "关联 Boss", boss_picker)
	for key in ["enabled", "selectable"]:
		var check := CheckBox.new()
		check.toggled.connect(_set_value.bind(StringName(key)))
		_field(form, key, "启用" if key == "enabled" else "村庄可选", check)
	var order := SpinBox.new()
	order.min_value = -10000
	order.max_value = 10000
	order.value_changed.connect(func(value: float) -> void: _set_value(int(value), &"sort_order"))
	_field(form, "sort_order", "排序", order)
	for key in ["layout", "enemy_config", "preview"]:
		var picker := EditorResourcePicker.new()
		picker.custom_minimum_size.x = 250
		picker.base_type = "Texture2D" if key == "preview" else "Resource"
		picker.resource_changed.connect(_set_value.bind(StringName(key)))
		picker.resource_selected.connect(func(resource: Resource, _inspect: bool) -> void: EditorInterface.edit_resource(resource))
		_field(form, key, {"layout":"地块 / 物件配置", "enemy_config":"怪物波次表", "preview":"出战预览图"}[key], picker)
	for axis in ["x", "y"]:
		var number := SpinBox.new()
		number.min_value = -10000
		number.max_value = 10000
		number.suffix = "px"
		number.custom_minimum_size.x = 160
		number.value_changed.connect(_set_spawn.bind(axis))
		_field(form, "spawn_" + axis, "出生点 " + axis.to_upper(), number)
	var description := TextEdit.new()
	description.custom_minimum_size = Vector2(260, 78)
	description.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	description.text_changed.connect(func() -> void: _set_value(description.text, &"description"))
	_field(form, "description", "出战说明", description)
	message = Label.new()
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(message)
	catalog = load(CATALOG_PATH) as Catalog
	_refresh_rows()
	if catalog != null and not catalog.entries.is_empty():
		select_level(&"greyford_01")

func _button(parent: Container, title: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _field(parent: Container, key: String, title: String, control: Control) -> void:
	var label := Label.new()
	label.text = title
	parent.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(control)
	fields[key] = control

func _text_field(parent: Container, key: String, title: String) -> void:
	var input := LineEdit.new()
	input.custom_minimum_size.x = 260
	input.text_changed.connect(_set_value.bind(StringName(key)))
	_field(parent, key, title, input)

func _set_value(value: Variant, key: StringName) -> void:
	if updating or current == null:
		return
	if key == &"level_id" or key == &"boss_level_id":
		value = StringName(value)
	current.set(key, value)
	current.emit_changed()
	_refresh_rows()
	_sync_boss_picker()
	_update_shortcuts()
	level_selected.emit(current)
	message.text = "已修改，尚未保存。ID 是存档与场景路由标识，发布后不要随意改名。"

func _set_spawn(value: float, axis: String) -> void:
	if updating or current == null:
		return
	var spawn := current.spawn_position
	if axis == "x":
		spawn.x = value
	else:
		spawn.y = value
	_set_value(spawn, &"spawn_position")

func _refresh_rows() -> void:
	rows.set_block_signals(true)
	rows.clear()
	var root := rows.create_item()
	if catalog == null:
		rows.set_block_signals(false)
		return
	for entry in catalog.entries:
		if entry == null:
			continue
		var item := rows.create_item(root)
		item.set_metadata(0, entry)
		item.set_text(0, String(entry.level_id))
		item.set_text(1, entry.display_name)
		item.set_text(2, ["村庄", "普通战斗", "Boss"][clampi(entry.kind, 0, 2)])
		item.set_text(3, "是" if entry.selectable else "否")
		item.set_text(4, "是" if entry.enabled else "否")
		item.set_tooltip_text(0, "%s\n%s" % [entry.level_id, entry.scene_path])
		if entry == current:
			item.select(0)
	rows.set_block_signals(false)

func select_level(id: StringName) -> void:
	if catalog == null:
		return
	var entry := catalog.find_level(id)
	if entry == null:
		return
	current = entry
	_sync_fields()
	_refresh_rows()
	level_selected.emit(current)

func _select_row() -> void:
	var selected := rows.get_selected()
	if selected == null:
		return
	current = selected.get_metadata(0)
	_sync_fields()
	level_selected.emit(current)

func _sync_fields() -> void:
	updating = true
	for key: String in fields:
		var control: Control = fields[key]
		if key == "boss_level_id":
			continue
		elif key.begins_with("spawn_"):
			(control as SpinBox).set_value_no_signal(current.spawn_position.x if key == "spawn_x" else current.spawn_position.y)
		elif control is LineEdit:
			control.text = String(current.get(key))
			control.tooltip_text = control.text
		elif control is TextEdit:
			control.text = String(current.get(key))
		elif control is CheckBox:
			control.set_pressed_no_signal(bool(current.get(key)))
		elif control is OptionButton:
			control.select(int(current.get(key)))
		elif control is SpinBox:
			control.set_value_no_signal(float(current.get(key)))
		elif control is EditorResourcePicker:
			control.edited_resource = current.get(key)
	updating = false
	_sync_boss_picker()
	_update_shortcuts()

func _sync_boss_picker() -> void:
	boss_picker.clear()
	boss_picker.add_item("不关联 Boss")
	boss_picker.set_item_metadata(0, &"")
	var chosen := 0
	for entry in catalog.entries:
		if entry == null or not entry.enabled or entry.kind != Entry.Kind.BOSS:
			continue
		var index := boss_picker.item_count
		boss_picker.add_item("%s [%s]" % [entry.display_name, entry.level_id])
		boss_picker.set_item_metadata(index, entry.level_id)
		boss_picker.set_item_tooltip(index, entry.scene_path)
		if current.boss_level_id == entry.level_id:
			chosen = index
	if chosen == 0 and not current.boss_level_id.is_empty():
		chosen = boss_picker.item_count
		boss_picker.add_item("无效或已停用 [%s]" % current.boss_level_id)
		boss_picker.set_item_metadata(chosen, current.boss_level_id)
		boss_picker.set_item_disabled(chosen, true)
	boss_picker.select(chosen)
	boss_picker.disabled = current.kind != Entry.Kind.NORMAL
	boss_picker.tooltip_text = "为普通关选择已启用的 Boss，关联的是稳定 ID。当前：%s" % current.boss_level_id

func _choose_boss(index: int) -> void:
	if not updating and current.kind == Entry.Kind.NORMAL:
		_set_value(boss_picker.get_item_metadata(index), &"boss_level_id")

func _update_shortcuts() -> void:
	layout_button.disabled = current == null or current.kind == Entry.Kind.VILLAGE or not current.layout is Preset
	waves_button.disabled = current == null or current.kind == Entry.Kind.VILLAGE or not current.enemy_config is WaveTable
	var target = catalog.find_level(current.boss_level_id) if current else null
	boss_button.disabled = current == null or current.kind != Entry.Kind.NORMAL or target == null or not target.enabled or target.kind != Entry.Kind.BOSS

func _request_editor(section: StringName) -> void:
	if current != null:
		editor_requested.emit(current, section)

func _open_boss_scene() -> void:
	var target = catalog.find_level(current.boss_level_id) if current else null
	if target and target.enabled and target.kind == Entry.Kind.BOSS and ResourceLoader.exists(target.scene_path, "PackedScene"):
		EditorInterface.open_scene_from_path(target.scene_path)
		select_level(target.level_id)
	else:
		message.text = "请先为普通关选择一个启用的 Boss 场景。"

func _validate() -> bool:
	if catalog == null:
		message.text = "无法读取关卡总表：" + CATALOG_PATH
		return false
	var errors := catalog.validation_errors()
	message.text = "校验通过 · %d 个独立场景，%d 个村庄可选关卡" % [catalog.entries.size(), catalog.selectable_levels().size()] if errors.is_empty() else "\n".join(errors)
	return errors.is_empty()

func _save() -> bool:
	if not _validate():
		return false
	if current != null:
		for resource: Resource in [current.layout, current.enemy_config]:
			if resource == null:
				continue
			var error := ResourceSaver.save(resource)
			if error != OK:
				message.text = "配置保存失败（%d）：%s" % [error, resource.resource_path]
				return false
	var result := ResourceSaver.save(catalog, CATALOG_PATH)
	message.text = "已保存总表和选中关卡配置。下次进入关卡使用新值。" if result == OK else "总表保存失败（%d）" % result
	EditorInterface.get_resource_filesystem().scan()
	return result == OK

func _open_scene() -> void:
	if current != null and ResourceLoader.exists(current.scene_path, "PackedScene"):
		EditorInterface.open_scene_from_path(current.scene_path)
	else:
		message.text = "请先指定存在的 .tscn 场景。"

func _new_level_dialog() -> void:
	if new_dialog == null:
		new_dialog = ConfirmationDialog.new()
		new_dialog.title = "新建独立关卡"
		new_dialog.ok_button_text = "创建场景和配置"
		var box := VBoxContainer.new()
		new_dialog.add_child(box)
		var note := Label.new()
		note.text = "生成独立场景、随机配置和怪物表，并登记稳定 ID。\n优先复制同类型关卡作为起点，创建后可以分别调整。"
		box.add_child(note)
		new_id = LineEdit.new()
		new_id.placeholder_text = "稳定 ID，例如 forest_02（小写字母 / 数字 / 下划线）"
		new_id.custom_minimum_size.x = 580
		box.add_child(new_id)
		new_name = LineEdit.new()
		new_name.placeholder_text = "显示名称"
		box.add_child(new_name)
		new_kind = OptionButton.new()
		new_kind.add_item("普通战斗")
		new_kind.add_item("Boss 场")
		box.add_child(new_kind)
		new_dialog.confirmed.connect(_create_level)
		add_child(new_dialog)
	new_dialog.popup_centered()

func _create_level() -> void:
	var id := new_id.text.strip_edges()
	var valid := RegEx.new()
	valid.compile("^[a-z][a-z0-9_]*$")
	if valid.search(id) == null or catalog.find_level(StringName(id)) != null or new_name.text.strip_edges().is_empty():
		message.text = "创建失败：需要未占用的小写字母 ID，以及显示名称。"
		return
	var scene_path := "res://scenes/levels/%s.tscn" % id
	var layout_path := "res://levels/%s_layout.tres" % id
	var wave_path := "res://levels/%s_enemies.tres" % id
	for path in [scene_path, layout_path, wave_path]:
		if FileAccess.file_exists(path):
			message.text = "创建失败，文件已存在，未覆盖：" + path
			return
	var is_boss := new_kind.selected == 1
	var source := template_for_kind(Entry.Kind.BOSS if is_boss else Entry.Kind.NORMAL)
	if source == null or not source.layout is Preset or not source.enemy_config is WaveTable:
		message.text = "创建失败：请先选中含有效随机配置和怪物表的关卡。"
		return
	var configs := catalog.duplicate_battle_configs(source, is_boss, new_name.text.strip_edges())
	var layout: Resource = configs.layout
	var waves: Resource = configs.waves
	for pair in [[layout, layout_path], [waves, wave_path]]:
		var result := ResourceSaver.save(pair[0], pair[1], ResourceSaver.FLAG_CHANGE_PATH)
		if result != OK:
			_remove_created_files([layout_path, wave_path])
			message.text = "创建配置失败（%d）：%s" % [result, pair[1]]
			return
		(pair[0] as Resource).take_over_path(pair[1])
	var spawn := Vector2(640, 450) if is_boss else Vector2(640, 430)
	var scene_text := build_scene_text(id, layout_path, wave_path, spawn, is_boss)
	var file := FileAccess.open(scene_path, FileAccess.WRITE)
	if file == null:
		_remove_created_files([layout_path, wave_path])
		message.text = "无法写入场景：" + scene_path
		return
	file.store_string(scene_text)
	file.close()
	var entry := Entry.new()
	entry.level_id = StringName(id)
	entry.display_name = new_name.text.strip_edges()
	entry.kind = Entry.Kind.BOSS if is_boss else Entry.Kind.NORMAL
	entry.scene_path = scene_path
	entry.layout = layout
	entry.enemy_config = waves
	entry.spawn_position = spawn
	entry.selectable = not is_boss
	entry.sort_order = catalog.entries.size() * 10
	entry.preview = source.preview
	entry.description = "新关卡配置，请补充出战说明。"
	catalog.entries.append(entry)
	current = entry
	_sync_fields()
	_refresh_rows()
	if not _save():
		catalog.entries.erase(entry)
		_remove_created_files([scene_path, layout_path, wave_path])
		current = source
		_sync_fields()
		_refresh_rows()
		return
	level_selected.emit(current)

func template_for_kind(kind: int) -> Entry:
	if current != null and current.kind == kind and current.layout is Preset and current.enemy_config is WaveTable:
		return current
	for entry in catalog.entries:
		if entry != null and entry.kind == kind and entry.layout is Preset and entry.enemy_config is WaveTable:
			return entry
	# 尚无 Boss 时允许从普通关创建第一个；普通关不从 Boss 继承零开局数量。
	if kind == Entry.Kind.BOSS:
		return template_for_kind(Entry.Kind.NORMAL)
	return null

func build_scene_text(id: String, layout_path: String, wave_path: String, spawn: Vector2, is_boss: bool) -> String:
	var text := '[gd_scene load_steps=4 format=3]\n[ext_resource type="PackedScene" path="res://scenes/battle.tscn" id="base"]\n[ext_resource type="Resource" path="%s" id="layout"]\n[ext_resource type="Resource" path="%s" id="waves"]\n[node name="Level" instance=ExtResource("base")]\nlevel_id = &"%s"\nlayout_preset = ExtResource("layout")\nenemy_config = ExtResource("waves")\nspawn_position = Vector2(%s, %s)\nstage_is_boss = %s\n[node name="EntrySpawn" type="Marker2D" parent="." index="3"]\nposition = Vector2(%s, %s)\n' % [layout_path, wave_path, id, spawn.x, spawn.y, "true" if is_boss else "false", spawn.x, spawn.y]
	if not is_boss:
		text += '[node name="BossPortal" type="Marker2D" parent="." index="4"]\nposition = Vector2(1120, 330)\n'
	return text

func _remove_created_files(paths: Array) -> void:
	for path: String in paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

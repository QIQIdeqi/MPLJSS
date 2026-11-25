@tool
extends Control

const Document = preload("res://scripts/story_editor/story_document.gd")
const StoryNode = preload("res://scripts/story_editor/story_node.gd")
const Book = preload("res://scripts/picture_book/book.gd")
const PictureWorkspace = preload("res://addons/picture_book/workspace.gd")

var document: Resource
var document_path: String = ""
var selected_node_id: String = ""
var dirty: bool = false
var syncing: bool = false
var node_list: ItemList
var node_title: LineEdit
var node_id_label: Label
var condition_enabled: CheckBox
var level_id: LineEdit
var details: VBoxContainer
var slot_labels: Dictionary = {}
var slot_buttons: Dictionary = {}
var status: Label
var caption: Label
var delete_dialog: ConfirmationDialog
var discard_dialog: ConfirmationDialog
var return_dialog: ConfirmationDialog
var document_dialog: FileDialog
var book_dialog: FileDialog
var pending_action: Callable
var pending_delete_id: String = ""
var choosing_slot: String = ""
var book_overlay: PanelContainer
var book_workspace: Control
var book_caption: Label
var editing_node_id: String = ""
var editing_slot: String = ""
var arrival_container: VBoxContainer
var arrival_editor_factories: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	new_document()
	if not Engine.is_editor_hint() and get_parent() == get_tree().root:
		get_tree().auto_accept_quit = false

func _button(parent: Node, text: String, action: Callable, node_name: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _label(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.text = text
	parent.add_child(label)
	return label

func _panel(parent: Node) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("20252e")
	style.set_content_margin_all(12)
	style.set_corner_radius_all(5)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel

func _build_ui() -> void:
	theme = Theme.new()
	theme.default_font_size = 15
	var background := ColorRect.new()
	background.color = Color("151a22")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var outer := MarginContainer.new()
	add_child(outer)
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		outer.add_theme_constant_override("margin_" + side, 14)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	outer.add_child(column)
	var toolbar := HBoxContainer.new()
	column.add_child(toolbar)
	var heading := _label(toolbar, "剧情工作台")
	heading.add_theme_font_size_override("font_size", 23)
	_button(toolbar, "新建", func(): _guard(new_document), "NewStory")
	_button(toolbar, "打开…", func(): _guard(_open_dialog), "OpenStory")
	_button(toolbar, "保存", _save_clicked, "SaveStory")
	_button(toolbar, "另存为…", _save_as, "SaveStoryAs")
	caption = _label(column, "")
	var warning := _label(column, "仅编辑剧情配置：条件、到达事件尚未连接选关 / 战斗 / 存档；关卡 ID 不作真实目录校验。")
	warning.add_theme_color_override("font_color", Color("e9bd72"))
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 260
	column.add_child(split)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 245
	split.add_child(left)
	var row := HBoxContainer.new()
	left.add_child(row)
	_button(row, "+ 剧情节点", add_node, "AddStoryNode")
	_button(row, "删除…", request_delete, "DeleteStoryNode")
	node_list = ItemList.new()
	node_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	node_list.item_selected.connect(_list_selected)
	left.add_child(node_list)
	var right := _panel(split)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	right.add_child(scroll)
	details = VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 10)
	scroll.add_child(details)
	_label(details, "节点名称")
	node_title = LineEdit.new()
	node_title.placeholder_text = "为此剧情节点命名"
	node_title.text_changed.connect(_title_changed)
	details.add_child(node_title)
	node_id_label = _label(details, "")
	node_id_label.add_theme_color_override("font_color", Color("9eafc2"))
	condition_enabled = CheckBox.new()
	condition_enabled.text = "启用条件：completed_level（已完成关卡）"
	condition_enabled.toggled.connect(_condition_toggled)
	details.add_child(condition_enabled)
	_label(details, "稳定关卡 ID（不是名称 / 序号；尚未验证真实关卡目录）")
	level_id = LineEdit.new()
	level_id.placeholder_text = "例如 level_...，请填写项目约定的稳定 ID"
	level_id.text_changed.connect(_level_changed)
	details.add_child(level_id)
	for slot: String in ["before", "after"]:
		var slot_panel := _panel(details)
		var slot_column := VBoxContainer.new()
		slot_panel.add_child(slot_column)
		_label(slot_column, "战前绘本" if slot == "before" else "战后绘本")
		var path_label := _label(slot_column, "未绑定 · 空槽")
		path_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		slot_labels[slot] = path_label
		var slot_row := HBoxContainer.new()
		slot_column.add_child(slot_row)
		var prefix := "Before" if slot == "before" else "After"
		var buttons: Array[Button] = []
		buttons.append(_button(slot_row, "选择绘本…", _choose_book.bind(slot), prefix + "ChooseBook"))
		buttons.append(_button(slot_row, "编辑 / 新建", edit_book.bind(slot), prefix + "EditBook"))
		buttons.append(_button(slot_row, "清空引用", clear_slot.bind(slot), prefix + "ClearBook"))
		slot_buttons[slot] = buttons
	_label(details, "到达事件 · 扩展接口（尚未执行）")
	arrival_container = VBoxContainer.new()
	details.add_child(arrival_container)
	status = _label(column, "")
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	delete_dialog = ConfirmationDialog.new()
	delete_dialog.title = "删除剧情节点"
	delete_dialog.ok_button_text = "确认删除节点"
	delete_dialog.confirmed.connect(_confirm_delete)
	delete_dialog.canceled.connect(func(): pending_delete_id = "")
	add_child(delete_dialog)
	discard_dialog = ConfirmationDialog.new()
	discard_dialog.title = "未保存修改"
	discard_dialog.dialog_text = "剧情或内嵌绘本有未保存修改，是否放弃这些修改继续？"
	discard_dialog.ok_button_text = "放弃并继续"
	discard_dialog.confirmed.connect(func():
		if pending_action.is_valid():
			pending_action.call())
	add_child(discard_dialog)
	return_dialog = ConfirmationDialog.new()
	return_dialog.title = "返回剧情编辑器"
	return_dialog.dialog_text = "当前绘本有未保存修改，放弃修改并返回？\n已保存的绘本文件及槽位引用不会被删除。"
	return_dialog.ok_button_text = "放弃修改并返回"
	return_dialog.confirmed.connect(_finish_book_edit)
	add_child(return_dialog)
	document_dialog = FileDialog.new()
	document_dialog.access = FileDialog.ACCESS_RESOURCES
	document_dialog.filters = PackedStringArray(["*.tres ; 剧情配置资源"])
	document_dialog.file_selected.connect(_document_file_selected)
	add_child(document_dialog)
	book_dialog = FileDialog.new()
	book_dialog.access = FileDialog.ACCESS_RESOURCES
	book_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	book_dialog.filters = PackedStringArray(["*.tres ; 绘本资源"])
	book_dialog.file_selected.connect(_book_file_selected)
	add_child(book_dialog)
	_build_book_overlay()

func _build_book_overlay() -> void:
	book_overlay = _panel(self)
	book_overlay.name = "EmbeddedPictureBook"
	book_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	book_overlay.add_child(column)
	var row := HBoxContainer.new()
	column.add_child(row)
	_button(row, "← 返回剧情", request_return, "ReturnToStory")
	book_caption = _label(row, "")
	book_caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	book_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	book_workspace = PictureWorkspace.new()
	book_workspace.name = "PictureWorkspace"
	book_workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(book_workspace)
	book_workspace.document_saved.connect(_book_saved)
	book_overlay.hide()

func _current() -> Resource:
	return document.find_node(selected_node_id) if document != null else null

func new_document() -> void:
	book_workspace.stop_preview()
	book_overlay.hide()
	editing_node_id = ""
	editing_slot = ""
	document = Document.new()
	document_path = ""
	selected_node_id = ""
	dirty = false
	_refresh()
	status.text = "新剧情配置 · 点击“+ 剧情节点”开始，不会创建游戏触发。"

func add_node() -> void:
	var item := StoryNode.new()
	item.node_id = StoryNode.create_id()
	while document.find_node(item.node_id) != null:
		item.node_id = StoryNode.create_id()
	document.nodes.append(item)
	selected_node_id = item.node_id
	dirty = true
	_refresh()

func _list_selected(index: int) -> void:
	if index >= 0 and index < document.nodes.size():
		selected_node_id = document.nodes[index].node_id
		_refresh()

func _title_changed(value: String) -> void:
	if syncing or _current() == null:
		return
	_current().title = value
	dirty = true
	_refresh_list()
	_refresh_caption()

func _condition_toggled(value: bool) -> void:
	if syncing or _current() == null:
		return
	_current().condition_enabled = value
	dirty = true
	level_id.editable = value
	_refresh_caption()

func _level_changed(value: String) -> void:
	if syncing or _current() == null:
		return
	_current().completed_level_id = value
	dirty = true
	_refresh_caption()

func request_delete() -> void:
	var item := _current()
	if item == null:
		return
	pending_delete_id = item.node_id
	delete_dialog.dialog_text = "删除节点“%s”？\n%s\n只删除此节点，引用的绘本文件不会删除。" % [item.title, item.node_id]
	delete_dialog.popup_centered()

func _confirm_delete() -> void:
	var item: Resource = document.find_node(pending_delete_id)
	if item != null:
		document.nodes.erase(item)
		selected_node_id = document.nodes[0].node_id if not document.nodes.is_empty() else ""
		dirty = true
	pending_delete_id = ""
	_refresh()
	status.text = "已删除节点，绘本资源文件保持不变。"

func _choose_book(slot: String) -> void:
	if _current() == null:
		return
	choosing_slot = slot
	book_dialog.current_dir = "res://picture_books"
	book_dialog.popup_centered_ratio(0.75)

func _load_valid_book(path: String) -> Resource:
	if not path.begins_with("res://") or path.get_extension() != "tres" or not ResourceLoader.exists(path):
		return null
	var loaded: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if loaded == null or loaded.get_script() != Book or not loaded.validate().is_empty():
		return null
	return loaded

func _book_file_selected(path: String) -> void:
	if _current() == null or choosing_slot not in ["before", "after"]:
		return
	if _load_valid_book(path) == null:
		status.text = "选择失败：请选择校验通过的项目内绘本 .tres，不是剧情配置。"
		return
	_current().set(choosing_slot + "_book_path", path)
	dirty = true
	_refresh()
	status.text = "已绑定绘本；保存剧情配置后保留此引用。"

func clear_slot(slot: String) -> void:
	if _current() == null or slot not in ["before", "after"]:
		return
	_current().set(slot + "_book_path", "")
	dirty = true
	_refresh()
	status.text = "已清空槽位引用，未删除绘本文件。"

func edit_book(slot: String) -> void:
	var item := _current()
	if item == null or slot not in ["before", "after"]:
		return
	var path: String = item.get(slot + "_book_path")
	if not path.is_empty() and not book_workspace.open_document(path):
		status.text = "无法编辑引用的绘本：" + book_workspace.status.text
		return
	if path.is_empty():
		book_workspace.new_document()
		book_workspace.book.title = item.title + (" · 战前" if slot == "before" else " · 战后")
	editing_node_id = item.node_id
	editing_slot = slot
	book_caption.text = "%s · %s | 保存绘本后自动绑定此槽；返回保留当前节点" % [item.title, "战前" if slot == "before" else "战后"]
	book_overlay.show()

func _book_saved(path: String) -> void:
	if editing_node_id.is_empty() or editing_slot not in ["before", "after"]:
		return
	var item: Resource = document.find_node(editing_node_id)
	if item == null or _load_valid_book(path) == null:
		status.text = "绘本已保存，但目标节点或资源校验失败，未更改引用。"
		return
	if item.get(editing_slot + "_book_path") != path:
		item.set(editing_slot + "_book_path", path)
		dirty = true
	_refresh()
	status.text = "绘本已保存并绑定；请保存剧情配置。"

func request_return() -> void:
	book_workspace.canvas.finish_text()
	book_workspace.stop_preview()
	if book_workspace.dirty:
		return_dialog.popup_centered()
	else:
		_finish_book_edit()

func _finish_book_edit() -> void:
	book_workspace.stop_preview()
	book_overlay.hide()
	if document.find_node(editing_node_id) != null:
		selected_node_id = editing_node_id
	editing_node_id = ""
	editing_slot = ""
	# Unsaved editing objects are dropped, never written or deleted on return.
	book_workspace.new_document()
	_refresh()

## Extension factory signature: factory(event: Dictionary, on_changed: Callable)
## -> Control. Unknown event types remain preserved in the resource.
func register_arrival_event_editor(event_type: String, factory: Callable) -> void:
	if event_type.strip_edges().is_empty() or not factory.is_valid():
		return
	arrival_editor_factories[event_type] = factory
	if is_instance_valid(arrival_container):
		_refresh_arrival()

func _update_arrival(node_id: String, index: int, event: Dictionary) -> void:
	var item: Resource = document.find_node(node_id)
	if item == null or index < 0 or index >= item.arrival_events.size():
		return
	item.arrival_events[index] = event.duplicate(true)
	dirty = true
	_refresh_caption()

func _refresh_arrival() -> void:
	for child: Node in arrival_container.get_children():
		arrival_container.remove_child(child)
		child.queue_free()
	var item := _current()
	if item == null or item.arrival_events.is_empty():
		_label(arrival_container, "暂无到达事件；已预留注册接口，不会运行剧情触发。")
		return
	for i: int in range(item.arrival_events.size()):
		var event: Dictionary = item.arrival_events[i]
		var event_type: String = str(event.get("type", "未命名"))
		if arrival_editor_factories.has(event_type):
			var factory: Callable = arrival_editor_factories[event_type]
			var target_id: String = item.node_id
			var control: Variant = factory.call(event.duplicate(true), func(value: Dictionary): _update_arrival(target_id, i, value))
			if control is Control:
				arrival_container.add_child(control)
				continue
		_label(arrival_container, "%d · %s（数据保留，未注册编辑器 / 未执行）" % [i + 1, event_type])

func _refresh_list() -> void:
	node_list.clear()
	for i: int in range(document.nodes.size()):
		var item: Resource = document.nodes[i]
		node_list.add_item("%02d  %s" % [i + 1, item.title])
		node_list.set_item_tooltip(i, item.node_id)
		if item.node_id == selected_node_id:
			node_list.select(i)

func _refresh_caption() -> void:
	caption.text = ("● 未保存 · " if dirty else "") + (document_path.get_file() if not document_path.is_empty() else "未命名剧情") + " | %d 个节点" % document.nodes.size()

func _refresh() -> void:
	if document == null:
		return
	syncing = true
	_refresh_list()
	_refresh_caption()
	var item := _current()
	details.visible = item != null
	if item != null:
		node_title.text = item.title
		node_id_label.text = "稳定 ID · " + item.node_id
		condition_enabled.set_pressed_no_signal(item.condition_enabled)
		level_id.text = item.completed_level_id
		level_id.editable = item.condition_enabled
		for slot: String in ["before", "after"]:
			var path: String = item.get(slot + "_book_path")
			slot_labels[slot].text = path if not path.is_empty() else "未绑定 · 空槽"
			slot_labels[slot].tooltip_text = path
	_refresh_arrival()
	syncing = false

func has_unsaved_changes() -> bool:
	book_workspace.canvas.finish_text()
	return dirty or (book_overlay.visible and book_workspace.dirty)

func _guard(action: Callable) -> void:
	if has_unsaved_changes():
		pending_action = action
		discard_dialog.popup_centered()
	else:
		action.call()

func save_document(path: String) -> bool:
	if not path.begins_with("res://") or path.get_extension() != "tres":
		status.text = "保存失败：请选择项目内 .tres 路径。"
		return false
	var issues: PackedStringArray = document.validate()
	if not issues.is_empty():
		status.text = "保存失败：" + "; ".join(issues)
		return false
	var result := ResourceSaver.save(document, path)
	if result != OK:
		status.text = "保存失败，修改保留：" + error_string(result)
		return false
	document_path = path
	dirty = false
	_refresh_caption()
	status.text = "已保存剧情配置：" + path
	return true

func open_document(path: String) -> bool:
	if not path.begins_with("res://") or path.get_extension() != "tres" or not ResourceLoader.exists(path):
		status.text = "打开失败：请选择项目内剧情 .tres。"
		return false
	var loaded: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if loaded == null or loaded.get_script() != Document:
		status.text = "打开失败：这不是剧情配置资源。"
		return false
	var issues: PackedStringArray = loaded.validate()
	if not issues.is_empty():
		status.text = "打开失败：" + "; ".join(issues)
		return false
	book_workspace.stop_preview()
	book_overlay.hide()
	editing_node_id = ""
	editing_slot = ""
	document = loaded.duplicate(true)
	document_path = path
	selected_node_id = document.nodes[0].node_id if not document.nodes.is_empty() else ""
	dirty = false
	_refresh()
	status.text = "已打开剧情配置：" + path
	return true

func _open_dialog() -> void:
	document_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	document_dialog.current_dir = "res://"
	document_dialog.popup_centered_ratio(0.75)

func _save_as() -> void:
	document_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	document_dialog.current_dir = "res://"
	document_dialog.current_file = "new_story.tres"
	document_dialog.popup_centered_ratio(0.75)

func _save_clicked() -> void:
	if document_path.is_empty():
		_save_as()
	else:
		save_document(document_path)

func _document_file_selected(path: String) -> void:
	if document_dialog.file_mode == FileDialog.FILE_MODE_SAVE_FILE:
		save_document(path)
	else:
		open_document(path)

func save_existing_documents() -> void:
	book_workspace.canvas.finish_text()
	if book_overlay.visible and book_workspace.dirty and not book_workspace.document_path.is_empty():
		book_workspace.save_document(book_workspace.document_path)
	if dirty and not document_path.is_empty():
		save_document(document_path)

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventKey or not event.pressed or event.echo:
		return
	if not book_overlay.visible and (event.ctrl_pressed or event.meta_pressed) and event.keycode == KEY_S:
		_save_clicked()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not Engine.is_editor_hint() and get_parent() == get_tree().root:
		_guard(func(): get_tree().quit())

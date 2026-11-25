@tool
extends Control

signal document_saved(path: String)

const Book = preload("res://scripts/picture_book/book.gd")
const Page = preload("res://scripts/picture_book/page.gd")
const Player = preload("res://scripts/picture_book/player.gd")
const Canvas = preload("res://addons/picture_book/canvas.gd")
const Card = preload("res://addons/picture_book/page_card.gd")
const SAMPLE := "res://picture_books/demo/sample.tres"

var book: Resource
var selected_index := 0
var document_path := ""
var dirty := false
var syncing := false
var undo_stack: Array[Dictionary] = []
var redo_stack: Array[Dictionary] = []
var page_list: VBoxContainer
var canvas: Control
var preview: Control
var preview_panel: PanelContainer
var status: Label
var caption: Label
var page_title: LineEdit
var image_mode: OptionButton
var text_mode: OptionButton
var image_path: Label
var text_input: TextEdit
var preset: OptionButton
var layer: OptionButton
var values: Dictionary = {}
var color_input: ColorPickerButton
var auto_input: CheckBox
var file_dialog: FileDialog
var image_dialog: FileDialog
var discard_dialog: ConfirmationDialog
var pending_action: Callable
var image_batch := false
var preview_caption: Label
var previous_button: Button
var next_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	if not Engine.is_editor_hint() and get_parent() == get_tree().root:
		get_tree().auto_accept_quit = false
	if not Engine.is_editor_hint() and ResourceLoader.exists(SAMPLE):
		open_document(SAMPLE)
	else:
		new_document()

func _panel(parent: Node, padding: int = 12) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("20252e")
	style.set_content_margin_all(padding)
	style.set_corner_radius_all(5)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel

func _button(parent: Node, title: String, action: Callable, node_name := "") -> Button:
	var button := Button.new()
	button.text = title
	if not node_name.is_empty():
		button.name = node_name
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _label(parent: Node, title: String) -> Label:
	var label := Label.new()
	label.text = title
	parent.add_child(label)
	return label

func _heading(parent: Node, title: String) -> void:
	var label := _label(parent, title)
	label.add_theme_color_override("font_color", Color("80d7c7"))
	label.add_theme_font_size_override("font_size", 16)

func _choice(parent: Node, title: String, options: Array) -> OptionButton:
	_label(parent, title)
	var option := OptionButton.new()
	for item: String in options:
		option.add_item(item)
	parent.add_child(option)
	return option

func _spin(parent: Node, title: String, key: String, minimum: float, maximum: float, step: float) -> SpinBox:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := _label(row, title)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var input := SpinBox.new()
	input.min_value = minimum
	input.max_value = maximum
	input.step = step
	input.custom_minimum_size.x = 108
	input.allow_greater = false
	input.allow_lesser = false
	row.add_child(input)
	values[key] = input
	input.value_changed.connect(_number_changed.bind(key))
	return input

func _build_ui() -> void:
	theme = Theme.new()
	theme.default_font_size = 14
	var background := ColorRect.new()
	background.color = Color("151a22")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	var title := _label(top, "绘本工作台")
	title.add_theme_font_size_override("font_size", 22)
	caption = _label(top, "")
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var toolbar := HBoxContainer.new()
	column.add_child(toolbar)
	_button(toolbar, "新建", func(): _guard(new_document), "NewBook")
	_button(toolbar, "打开…", func(): _guard(_open_dialog), "OpenBook")
	_button(toolbar, "示例", func(): _guard(func(): open_document(SAMPLE)), "OpenSample")
	_button(toolbar, "保存", _save_clicked, "SaveBook")
	_button(toolbar, "另存为…", _save_as, "SaveAs")
	_button(toolbar, "撤销", undo_edit, "Undo")
	_button(toolbar, "重做", redo_edit, "Redo")
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer)
	_button(toolbar, "重播入场", func(): start_preview(true), "ReplayEntrance")
	_button(toolbar, "从此页放映", func(): start_preview(false), "Present")
	var columns := HSplitContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.split_offset = 192
	column.add_child(columns)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 186
	columns.add_child(left)
	_heading(left, "页面 · 拖动缩略图排序")
	var actions := HBoxContainer.new()
	left.add_child(actions)
	_button(actions, "+ 页", add_page, "AddPage")
	_button(actions, "复制", duplicate_page, "DuplicatePage")
	_button(actions, "删除", delete_page, "DeletePage")
	var order := HBoxContainer.new()
	left.add_child(order)
	_button(order, "上移", func(): move_page(selected_index, selected_index - 1), "MoveUp")
	_button(order, "下移", func(): move_page(selected_index, selected_index + 1), "MoveDown")
	_button(left, "批量加入项目内图片…", func(): _choose_image(true), "ImportImages")
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	page_list = VBoxContainer.new()
	page_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_list.add_theme_constant_override("separation", 8)
	scroll.add_child(page_list)
	var right_split := HSplitContainer.new()
	right_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right_split)
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.custom_minimum_size.x = 310
	right_split.add_child(center)
	_heading(center, "画布 · 16:9")
	_label(center, "单击选图 / 文字 · 拖动位置 · 右下角缩放 · 双击文字编辑")
	canvas = Canvas.new()
	canvas.name = "Canvas"
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(canvas)
	canvas.gesture_started.connect(_record)
	canvas.rect_changed.connect(_canvas_rect)
	canvas.text_committed.connect(_commit_text)
	canvas.layer_selected.connect(_select_layer)
	var edit_row := HBoxContainer.new()
	center.add_child(edit_row)
	_button(edit_row, "在画布写字", func(): canvas.edit_text(), "EditTextOnCanvas")
	_button(edit_row, "图片铺满", func(): _set_rect("image", Rect2(0, 0, 1280, 720)), "ImageFull")
	_button(edit_row, "文字置底", func(): _set_rect("text", Rect2(96, 540, 1088, 130)), "TextBottom")
	var inspector_scroll := ScrollContainer.new()
	inspector_scroll.custom_minimum_size.x = 290
	inspector_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_split.add_child(inspector_scroll)
	var inspector := VBoxContainer.new()
	inspector.custom_minimum_size.x = 270
	inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector.add_theme_constant_override("separation", 7)
	inspector_scroll.add_child(inspector)
	_heading(inspector, "当前页 · 内容")
	page_title = LineEdit.new()
	page_title.placeholder_text = "页面名称"
	inspector.add_child(page_title)
	page_title.text_changed.connect(func(value: String):
		if not syncing:
			_record()
			_page().title = value
			_render())
	image_mode = _choice(inspector, "图片", ["保留前页图片", "换成新图片", "清空图片"])
	image_mode.item_selected.connect(_action_changed.bind("image"))
	image_path = _label(inspector, "")
	image_path.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	image_path.custom_minimum_size.x = 250
	_button(inspector, "选择项目内图片…", func(): _choose_image(false), "ChooseImage")
	text_mode = _choice(inspector, "文字", ["保留前页文字", "换成新文字", "清空文字"])
	text_mode.item_selected.connect(_action_changed.bind("text"))
	text_input = TextEdit.new()
	text_input.custom_minimum_size.y = 90
	text_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	inspector.add_child(text_input)
	text_input.text_changed.connect(func():
		if not syncing:
			_record()
			_page().text_action = Page.Action.REPLACE
			_page().text = text_input.text
			text_mode.select(Page.Action.REPLACE)
			_render())
	_heading(inspector, "版式 · 像素坐标")
	layer = _choice(inspector, "选中元素", ["文字", "图片"])
	layer.item_selected.connect(func(i: int): _select_layer("text" if i == 0 else "image"))
	for entry: Array in [["X", "x", 0, 1240], ["Y", "y", 0, 680], ["宽", "w", 40, 1280], ["高", "h", 40, 720]]:
		_spin(inspector, entry[0], entry[1], entry[2], entry[3], 1)
	_spin(inspector, "字号", "font_size", 12, 120, 1)
	color_input = ColorPickerButton.new()
	color_input.custom_minimum_size.y = 28
	inspector.add_child(color_input)
	color_input.color_changed.connect(func(value: Color):
		if not syncing:
			_record()
			_page().text_color = value
			_render())
	_heading(inspector, "入场 · 图片与文字独立")
	preset = _choice(inspector, "快捷预设", ["一起淡变", "图先文后", "文先图后", "直接切换", "自定义"])
	preset.item_selected.connect(apply_preset)
	_spin(inspector, "图片延迟 / 秒", "image_delay", 0, 30, 0.1)
	_spin(inspector, "图片时长 / 秒", "image_duration", 0, 30, 0.1)
	_spin(inspector, "文字延迟 / 秒", "text_delay", 0, 30, 0.1)
	_spin(inspector, "文字时长 / 秒", "text_duration", 0, 30, 0.1)
	_heading(inspector, "翻页")
	auto_input = CheckBox.new()
	auto_input.text = "入场完成后自动翻页"
	inspector.add_child(auto_input)
	auto_input.toggled.connect(func(value: bool):
		if not syncing:
			_record()
			_page().auto_advance = value
			_render())
	_spin(inspector, "完成后停留 / 秒", "hold_seconds", 0.1, 120, 0.1)
	var tip := _label(inspector, "默认手动翻页；入场中确认只补完。\n保留仅继承内容，版式属于本页。\n首张保留 = 空内容；预览按当前顺序解析。")
	tip.add_theme_font_size_override("font_size", 12)
	status = _label(column, "")
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	file_dialog = FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_RESOURCES
	file_dialog.filters = PackedStringArray(["*.tres ; 绘本资源"])
	file_dialog.file_selected.connect(_file_selected)
	add_child(file_dialog)
	image_dialog = FileDialog.new()
	image_dialog.access = FileDialog.ACCESS_RESOURCES
	image_dialog.filters = PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp,*.svg ; 图片"])
	image_dialog.files_selected.connect(_images_selected)
	add_child(image_dialog)
	discard_dialog = ConfirmationDialog.new()
	discard_dialog.dialog_text = "当前绘本有未保存修改，继续将放弃这些修改。"
	discard_dialog.ok_button_text = "放弃并继续"
	discard_dialog.confirmed.connect(func(): pending_action.call())
	add_child(discard_dialog)
	_build_preview()

func _build_preview() -> void:
	preview_panel = _panel(self, 18)
	preview_panel.name = "Presentation"
	preview_panel.focus_mode = Control.FOCUS_ALL
	preview_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	preview_panel.add_child(column)
	var toolbar := HBoxContainer.new()
	column.add_child(toolbar)
	preview_caption = _label(toolbar, "放映")
	preview_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(toolbar, "关闭预览 · Esc", stop_preview, "ClosePreview").focus_mode = Control.FOCUS_NONE
	preview = Player.new()
	preview.name = "RuntimePlayer"
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(preview)
	preview.page_changed.connect(func(i: int): preview_caption.text = "放映 · %d / %d  |  确认：入场中补完，完成后下一页" % [i + 1, book.pages.size()])
	preview.finished.connect(func(): preview_caption.text = "放映结束 · 可关闭预览继续编辑")
	var controls := HBoxContainer.new()
	column.add_child(controls)
	previous_button = _button(controls, "上一页", func(): preview.play(book, maxi(0, preview.index - 1)), "Previous")
	next_button = _button(controls, "确认 / 下一页", func(): preview.advance(), "Next")
	previous_button.focus_mode = Control.FOCUS_NONE
	next_button.focus_mode = Control.FOCUS_NONE
	preview.mouse_filter = Control.MOUSE_FILTER_STOP
	preview.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			preview.advance()
			preview.accept_event()
	)
	preview_panel.hide()

func _page() -> Resource:
	return book.pages[selected_index]

func _record() -> void:
	if syncing or book == null:
		return
	undo_stack.append({"book": book.duplicate(true), "index": selected_index})
	if undo_stack.size() > 60:
		undo_stack.pop_front()
	redo_stack.clear()
	dirty = true

func undo_edit() -> void:
	canvas.finish_text()
	if undo_stack.is_empty():
		return
	redo_stack.append({"book": book.duplicate(true), "index": selected_index})
	var snapshot: Dictionary = undo_stack.pop_back()
	book = snapshot.book
	selected_index = snapshot.index
	dirty = true
	_refresh()

func redo_edit() -> void:
	if redo_stack.is_empty():
		return
	undo_stack.append({"book": book.duplicate(true), "index": selected_index})
	var snapshot: Dictionary = redo_stack.pop_back()
	book = snapshot.book
	selected_index = snapshot.index
	dirty = true
	_refresh()

func _guard(action: Callable) -> void:
	canvas.finish_text()
	if dirty:
		pending_action = action
		discard_dialog.popup_centered()
	else:
		action.call()

func new_document() -> void:
	stop_preview()
	book = Book.new()
	book.title = "未命名绘本"
	book.pages.append(Page.new())
	selected_index = 0
	document_path = ""
	dirty = false
	undo_stack.clear()
	redo_stack.clear()
	_refresh()
	status.text = "新绘本 · 选择图片或在画布双击文字框开始"

func open_document(path: String) -> bool:
	if not path.begins_with("res://") or path.get_extension() != "tres":
		status.text = "请选择项目内 .tres 绘本资源"
		return false
	var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if loaded == null or loaded.get_script() != Book:
		status.text = "打开失败：这不是绘本资源"
		return false
	var issues: PackedStringArray = loaded.validate()
	if not issues.is_empty():
		status.text = "打开失败：" + "; ".join(issues)
		return false
	stop_preview()
	book = loaded.duplicate(true)
	document_path = path
	selected_index = 0
	dirty = false
	undo_stack.clear()
	redo_stack.clear()
	_refresh()
	status.text = "已打开 " + path
	return true

func save_document(path: String) -> bool:
	canvas.finish_text()
	if not path.begins_with("res://") or path.get_extension() != "tres":
		status.text = "保存失败：请使用项目内 .tres 路径"
		return false
	var issues: PackedStringArray = book.validate()
	if not issues.is_empty():
		status.text = "保存失败：" + "; ".join(issues)
		return false
	var result := ResourceSaver.save(book, path)
	if result != OK:
		status.text = "保存失败，修改仍保留：" + error_string(result)
		return false
	document_path = path
	dirty = false
	_render()
	status.text = "已保存 " + path
	document_saved.emit(path)
	return true

func _open_dialog() -> void:
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.current_dir = "res://picture_books"
	file_dialog.popup_centered_ratio(0.75)

func _save_clicked() -> void:
	if document_path.is_empty():
		_save_as()
	else:
		save_document(document_path)

func _save_as() -> void:
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.current_dir = "res://picture_books"
	file_dialog.current_file = "new_book.tres"
	file_dialog.popup_centered_ratio(0.75)

func _file_selected(path: String) -> void:
	if file_dialog.file_mode == FileDialog.FILE_MODE_SAVE_FILE:
		save_document(path)
	else:
		open_document(path)

func select_page(index: int) -> void:
	canvas.finish_text()
	selected_index = clampi(index, 0, book.pages.size() - 1)
	_refresh()

func add_page() -> void:
	canvas.finish_text()
	_record()
	var page := Page.new()
	page.title = "新页面"
	page.image_action = Page.Action.KEEP
	page.text_action = Page.Action.REPLACE
	book.pages.insert(selected_index + 1, page)
	selected_index += 1
	_refresh()

func duplicate_page() -> void:
	canvas.finish_text()
	_record()
	var copy: Resource = _page().duplicate(true)
	copy.title += " · 副本"
	book.pages.insert(selected_index + 1, copy)
	selected_index += 1
	_refresh()

func delete_page() -> void:
	canvas.finish_text()
	_record()
	book.pages.remove_at(selected_index)
	if book.pages.is_empty():
		book.pages.append(Page.new())
	selected_index = mini(selected_index, book.pages.size() - 1)
	_refresh()
	status.text = "页面已删除 · 可撤销"

func move_page(from: int, to: int) -> void:
	canvas.finish_text()
	if from < 0 or from >= book.pages.size() or to < 0 or to >= book.pages.size() or from == to:
		return
	_record()
	var page: Resource = book.pages[from]
	book.pages.remove_at(from)
	book.pages.insert(to, page)
	selected_index = to
	_refresh()
	status.text = "页面已重排 · 保留内容按新顺序重新解析"

func _action_changed(action: int, channel: String) -> void:
	if syncing:
		return
	_record()
	if action == Page.Action.REPLACE:
		var effective: Dictionary = book.resolve(selected_index)
		_page().set(channel, effective[channel])
	_page().set(channel + "_action", action)
	_refresh()

func _choose_image(batch: bool) -> void:
	image_batch = batch
	image_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	image_dialog.current_dir = "res://picture_books"
	image_dialog.popup_centered_ratio(0.75)

func _images_selected(paths: PackedStringArray) -> void:
	var textures: Array[Texture2D] = []
	for path: String in paths:
		if path.begins_with("res://"):
			var resource := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
			if resource is Texture2D:
				textures.append(resource)
	if textures.is_empty():
		status.text = "没有可用的项目内图片，请先将图片加入工程"
		return
	_record()
	if image_batch:
		for texture: Texture2D in textures:
			var page := Page.new()
			page.title = texture.resource_path.get_file().get_basename()
			page.image = texture
			page.image_action = Page.Action.REPLACE
			page.text_action = Page.Action.CLEAR
			selected_index += 1
			book.pages.insert(selected_index, page)
	else:
		_page().image = textures[0]
		_page().image_action = Page.Action.REPLACE
	_refresh()

func _commit_text(value: String) -> void:
	_record()
	_page().text_action = Page.Action.REPLACE
	_page().text = value
	_refresh()

func _select_layer(value: String) -> void:
	canvas.selected_layer = value
	layer.select(0 if value == "text" else 1)
	canvas.queue_redraw()
	_sync_rect()

func _set_rect(channel: String, rect: Rect2) -> void:
	_record()
	_page().set(channel + "_rect", rect)
	_select_layer(channel)
	_refresh()

func _canvas_rect(channel: String, rect: Rect2, final: bool) -> void:
	_page().set(channel + "_rect", rect)
	canvas.display(book, selected_index)
	_sync_rect()
	if final:
		_render()

func _number_changed(value: float, key: String) -> void:
	if syncing:
		return
	_record()
	if key in ["x", "y", "w", "h"]:
		var rect: Rect2 = _page().get(canvas.selected_layer + "_rect")
		match key:
			"x": rect.position.x = value
			"y": rect.position.y = value
			"w": rect.size.x = value
			"h": rect.size.y = value
		rect.size = rect.size.clamp(Vector2(40, 40), Vector2(1280, 720))
		rect.position = rect.position.clamp(Vector2.ZERO, Vector2(1280, 720) - rect.size)
		_page().set(canvas.selected_layer + "_rect", rect)
		_sync_rect()
	else:
		_page().set(key, int(value) if key == "font_size" else value)
		if key.ends_with("delay") or key.ends_with("duration"):
			preset.select(4)
	_render()

func apply_preset(choice: int) -> void:
	if syncing or choice == 4:
		return
	_record()
	_page().image_delay = 0.5 if choice == 2 else 0.0
	_page().text_delay = 0.5 if choice == 1 else 0.0
	_page().image_duration = 0.0 if choice == 3 else 0.5
	_page().text_duration = 0.0 if choice == 3 else 0.5
	_refresh()

func _sync_rect() -> void:
	if book == null:
		return
	var rect: Rect2 = _page().get(canvas.selected_layer + "_rect")
	syncing = true
	values.x.set_value_no_signal(rect.position.x)
	values.y.set_value_no_signal(rect.position.y)
	values.w.set_value_no_signal(rect.size.x)
	values.h.set_value_no_signal(rect.size.y)
	syncing = false

func _refresh() -> void:
	if book == null:
		return
	syncing = true
	var page: Resource = _page()
	var effective: Dictionary = book.resolve(selected_index)
	page_title.text = page.title
	image_mode.select(page.image_action)
	text_mode.select(page.text_action)
	text_input.text = effective.text
	image_path.text = effective.image.resource_path.get_file() if effective.image != null else "（当前无图片）"
	image_path.tooltip_text = effective.image.resource_path if effective.image != null else ""
	for key: String in ["font_size", "image_delay", "image_duration", "text_delay", "text_duration", "hold_seconds"]:
		values[key].set_value_no_signal(page.get(key))
	color_input.color = page.text_color
	auto_input.set_pressed_no_signal(page.auto_advance)
	var preset_index := 4
	if page.image_delay == 0 and page.text_delay == 0 and page.image_duration == 0 and page.text_duration == 0:
		preset_index = 3
	elif page.image_duration == 0.5 and page.text_duration == 0.5:
		if page.image_delay == 0 and page.text_delay == 0:
			preset_index = 0
		elif page.image_delay == 0 and page.text_delay == 0.5:
			preset_index = 1
		elif page.image_delay == 0.5 and page.text_delay == 0:
			preset_index = 2
	preset.select(preset_index)
	syncing = false
	_sync_rect()
	_render()

func _render() -> void:
	for child: Node in page_list.get_children():
		page_list.remove_child(child)
		child.queue_free()
	for i: int in range(book.pages.size()):
		var card := Card.new()
		page_list.add_child(card)
		card.setup(book, i, i == selected_index, get_instance_id())
		card.selected.connect(select_page)
		card.moved.connect(move_page)
	canvas.display(book, selected_index)
	caption.text = ("● 未保存  ·  " if dirty else "") + (document_path.get_file() if not document_path.is_empty() else "未命名绘本") + "  |  %d 页" % book.pages.size()

func start_preview(replay_only: bool = false) -> void:
	canvas.finish_text()
	var issues: PackedStringArray = book.validate()
	if not issues.is_empty():
		status.text = "无法预览：" + "; ".join(issues)
		return
	preview_panel.show()
	preview_panel.grab_focus()
	if replay_only:
		preview.replay(book, selected_index)
	else:
		preview.play(book, selected_index)
	previous_button.disabled = replay_only
	next_button.disabled = replay_only
	preview_caption.text = ("重播入场" if replay_only else "放映") + " · %d / %d  |  Enter / 空格：先补完，再翻页" % [selected_index + 1, book.pages.size()]

func stop_preview() -> void:
	if is_instance_valid(preview):
		preview.stop()
	if is_instance_valid(preview_panel):
		preview_panel.hide()

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE and preview_panel.visible:
		stop_preview()
		get_viewport().set_input_as_handled()
	elif not preview_panel.visible and (event.ctrl_pressed or event.meta_pressed):
		if event.keycode == KEY_S:
			_save_clicked()
			get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not Engine.is_editor_hint() and get_parent() == get_tree().root:
		canvas.finish_text()
		_guard(func(): get_tree().quit())

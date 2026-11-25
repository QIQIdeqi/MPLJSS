@tool
extends Control

signal gesture_started
signal rect_changed(layer: String, rect: Rect2, final: bool)
signal text_committed(value: String)
signal layer_selected(layer: String)
const Player = preload("res://scripts/picture_book/player.gd")
class SelectionOverlay extends Control:
	var host: Control
	func _draw() -> void:
		host.draw_selection(self)

var overlay: Control
var book: Resource
var index := -1
var selected_layer := "text"
var view: Control
var inline_edit: TextEdit
var factor := 1.0
var origin := Vector2.ZERO
var dragging := false
var resizing := false
var start_mouse := Vector2.ZERO
var start_rect := Rect2()
var inline_original := ""

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	view = Player.new()
	add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay = SelectionOverlay.new()
	overlay.host = self
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_layout)
	_layout()

func _layout() -> void:
	factor = maxf(0.01, minf(size.x / 1280.0, size.y / 720.0))
	origin = (size - Vector2(1280, 720) * factor) * 0.5
	queue_redraw()

func display(document: Resource, page_index: int) -> void:
	book = document
	index = page_index
	if is_instance_valid(view):
		view.show_static(book, index)
	queue_redraw()

func _draw() -> void:
	if is_instance_valid(overlay):
		overlay.queue_redraw()

func draw_selection(surface: Control) -> void:
	surface.draw_rect(Rect2(origin, Vector2(1280, 720) * factor), Color("738093"), false, 1)
	if book == null or index < 0 or index >= book.pages.size():
		return
	var rect: Rect2 = book.pages[index].get(selected_layer + "_rect")
	rect = Rect2(origin + rect.position * factor, rect.size * factor)
	surface.draw_rect(rect, Color("78e2cd"), false, 2)
	surface.draw_rect(Rect2(rect.end - Vector2(6, 6), Vector2(12, 12)), Color("78e2cd"))

func _gui_input(event: InputEvent) -> void:
	if book == null or index < 0:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed:
			if dragging:
				dragging = false
				rect_changed.emit(selected_layer, book.pages[index].get(selected_layer + "_rect"), true)
			return
		grab_focus()
		var point: Vector2 = (event.position - origin) / factor
		var page: Resource = book.pages[index]
		var selected_rect: Rect2 = page.get(selected_layer + "_rect")
		resizing = point.distance_to(selected_rect.end) < 16.0 / factor
		if not resizing:
			if page.text_rect.has_point(point):
				selected_layer = "text"
			elif page.image_rect.has_point(point):
				selected_layer = "image"
			else:
				return
		layer_selected.emit(selected_layer)
		if event.double_click and selected_layer == "text":
			edit_text()
			return
		start_mouse = point
		start_rect = page.get(selected_layer + "_rect")
		dragging = true
		gesture_started.emit()
		queue_redraw()
		accept_event()
	elif event is InputEventMouseMotion and dragging:
		var diff: Vector2 = (event.position - origin) / factor - start_mouse
		var next := start_rect
		if resizing:
			next.size = (start_rect.size + diff).clamp(Vector2(40, 40), Vector2(1280, 720) - next.position)
		else:
			next.position = (start_rect.position + diff).clamp(Vector2.ZERO, Vector2(1280, 720) - next.size)
		rect_changed.emit(selected_layer, next, false)
		queue_redraw()
		accept_event()

func edit_text() -> void:
	if is_instance_valid(inline_edit) or book == null or index < 0:
		return
	var state: Dictionary = book.resolve(index)
	var page: Resource = book.pages[index]
	inline_original = state.text
	inline_edit = TextEdit.new()
	add_child(inline_edit)
	inline_edit.position = origin + page.text_rect.position * factor
	inline_edit.size = page.text_rect.size * factor
	inline_edit.add_theme_font_size_override("font_size", maxi(12, int(page.font_size * factor)))
	inline_edit.text = inline_original
	inline_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	inline_edit.focus_exited.connect(finish_text)
	inline_edit.gui_input.connect(_inline_input)
	inline_edit.grab_focus()
	inline_edit.select_all()

func _inline_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			inline_edit.text = inline_original
			finish_text()
			accept_event()
		elif event.keycode == KEY_ENTER and (event.ctrl_pressed or event.meta_pressed):
			finish_text()
			accept_event()

func finish_text() -> void:
	if not is_instance_valid(inline_edit):
		return
	var value := inline_edit.text
	var old := inline_edit
	inline_edit = null
	old.queue_free()
	if value != inline_original:
		text_committed.emit(value)

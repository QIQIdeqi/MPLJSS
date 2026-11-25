@tool
extends Control
## Shared by editor previews and exported games. No save-game access.

signal finished
signal page_changed(page_index: int)

const DESIGN_SIZE := Vector2(1280, 720)

var book: Resource
var index: int = -1
var is_transitioning: bool = false
var is_playing: bool = false

# Public for inspection/testing; these are the actual displayed buffers.
var image_current: TextureRect
var image_previous: TextureRect
var text_current: Label
var text_previous: Label
var canvas: Control
var background: ColorRect

var _single_page: bool = false
var _elapsed: float = 0.0
var _transition_end: float = 0.0
var _hold_elapsed: float = 0.0
var _image_changed: bool = false
var _text_changed: bool = false
var _target: Dictionary = {}
var _image_delay: float = 0.0
var _image_duration: float = 0.0
var _text_delay: float = 0.0
var _text_duration: float = 0.0

func _ready() -> void:
	_ensure_nodes()
	resized.connect(_fit)
	_fit()

func _ensure_nodes() -> void:
	if is_instance_valid(canvas):
		return
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	canvas = Control.new()
	canvas.name = "SlideCanvas"
	canvas.size = DESIGN_SIZE
	canvas.clip_contents = true
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	background = ColorRect.new()
	background.color = Color("18212b")
	background.size = DESIGN_SIZE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(background)
	image_previous = _make_image("PreviousImage")
	image_current = _make_image("CurrentImage")
	text_previous = _make_text("PreviousText")
	text_current = _make_text("CurrentText")
	_fit()

func _make_image(node_name: String) -> TextureRect:
	var view := TextureRect.new()
	view.name = node_name
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(view)
	return view

func _make_text(node_name: String) -> Label:
	var view := Label.new()
	view.name = node_name
	view.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	view.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	view.clip_text = true
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	view.add_theme_constant_override("shadow_offset_x", 2)
	view.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(view)
	return view

func _fit() -> void:
	if not is_instance_valid(canvas):
		return
	var factor: float = maxf(0.001, minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y))
	canvas.scale = Vector2.ONE * factor
	canvas.position = (size - DESIGN_SIZE * factor) * 0.5

func _set_image(view: TextureRect, state: Dictionary) -> void:
	view.texture = state.get("image") as Texture2D
	var rect: Rect2 = state.get("image_rect", Rect2(Vector2.ZERO, DESIGN_SIZE))
	view.position = rect.position
	view.size = rect.size
	view.visible = view.texture != null
	view.modulate.a = 1.0

func _set_text(view: Label, state: Dictionary) -> void:
	view.text = str(state.get("text", ""))
	var rect: Rect2 = state.get("text_rect", Rect2(96, 540, 1088, 130))
	view.position = rect.position
	view.size = rect.size
	view.add_theme_font_size_override("font_size", int(state.get("font_size", 32)))
	view.add_theme_color_override("font_color", state.get("text_color", Color.WHITE))
	view.add_theme_color_override("font_shadow_color", state.get("text_shadow_color", Color(0, 0, 0, 0.85)))
	view.visible = not view.text.is_empty()
	view.modulate.a = 1.0

func _valid_page(source: Resource, page_index: int) -> bool:
	return source != null and source.has_method("resolve") and page_index >= 0 and page_index < source.pages.size() and source.pages[page_index] != null

func show_static(source: Resource, page_index: int) -> void:
	stop()
	_ensure_nodes()
	book = source
	if not _valid_page(source, page_index):
		index = -1
		_clear()
		return
	background.color = book.background_color
	index = page_index
	_target = book.resolve(index)
	_set_image(image_current, _target)
	_set_text(text_current, _target)
	_hide_previous()
	page_changed.emit(index)

func play(source: Resource, page_index: int = 0) -> void:
	_start(source, page_index, false)

func replay(source: Resource, page_index: int) -> void:
	_start(source, page_index, true)

func _start(source: Resource, page_index: int, single: bool) -> void:
	stop()
	_ensure_nodes()
	book = source
	if not _valid_page(source, page_index):
		index = -1
		_clear()
		return
	background.color = book.background_color
	is_playing = true
	_single_page = single
	_enter_page(page_index)

func _enter_page(page_index: int) -> void:
	index = page_index
	var previous: Dictionary = book.resolve(index - 1)
	_target = book.resolve(index)
	_image_changed = (previous.image != null or _target.image != null) and (previous.image != _target.image or previous.image_rect != _target.image_rect)
	_text_changed = (not str(previous.text).is_empty() or not str(_target.text).is_empty()) and (previous.text != _target.text or previous.text_rect != _target.text_rect or previous.font_size != _target.font_size or previous.text_color != _target.text_color)
	var page: Resource = book.pages[index]
	_image_delay = maxf(0.0, page.image_delay)
	_image_duration = maxf(0.0, page.image_duration)
	_text_delay = maxf(0.0, page.text_delay)
	_text_duration = maxf(0.0, page.text_duration)
	_elapsed = 0.0
	_hold_elapsed = 0.0
	_transition_end = maxf(_image_delay + _image_duration if _image_changed else 0.0, _text_delay + _text_duration if _text_changed else 0.0)
	_set_image(image_previous, previous)
	_set_text(text_previous, previous)
	_set_image(image_current, _target)
	_set_text(text_current, _target)
	is_transitioning = _transition_end > 0.0
	_apply_transition()
	if not is_transitioning:
		_complete_transition()
	page_changed.emit(index)

func _progress(delay: float, duration: float) -> float:
	if _elapsed < delay:
		return 0.0
	if duration <= 0.0:
		return 1.0
	return clampf((_elapsed - delay) / duration, 0.0, 1.0)

func _apply_transition() -> void:
	var image_alpha: float = _progress(_image_delay, _image_duration) if _image_changed else 1.0
	image_current.modulate.a = image_alpha
	image_previous.modulate.a = 1.0 - image_alpha if _image_changed else 0.0
	var text_alpha: float = _progress(_text_delay, _text_duration) if _text_changed else 1.0
	text_current.modulate.a = text_alpha
	text_previous.modulate.a = 1.0 - text_alpha if _text_changed else 0.0

func _complete_transition() -> void:
	is_transitioning = false
	_elapsed = _transition_end
	image_current.modulate.a = 1.0
	text_current.modulate.a = 1.0
	_hide_previous()
	_hold_elapsed = 0.0
	if _single_page:
		is_playing = false

func _hide_previous() -> void:
	image_previous.visible = false
	image_previous.texture = null
	text_previous.visible = false
	text_previous.text = ""

func _clear() -> void:
	image_current.texture = null
	image_current.visible = false
	text_current.text = ""
	text_current.visible = false
	_hide_previous()

func stop() -> void:
	if is_instance_valid(canvas) and is_transitioning:
		_complete_transition()
	is_transitioning = false
	is_playing = false
	_single_page = false
	_elapsed = 0.0
	_hold_elapsed = 0.0

func advance() -> void:
	if not is_playing:
		return
	if is_transitioning:
		_complete_transition()
		return
	if index + 1 < book.pages.size():
		_enter_page(index + 1)
	else:
		stop()
		finished.emit()

func _process(delta: float) -> void:
	if not is_playing or book == null or index < 0:
		return
	var remaining: float = maxf(0.0, delta)
	if is_transitioning:
		var step: float = minf(remaining, maxf(0.0, _transition_end - _elapsed))
		_elapsed += step
		remaining -= step
		_apply_transition()
		if _elapsed >= _transition_end:
			_complete_transition()
	if is_transitioning or not is_playing:
		return
	var page: Resource = book.pages[index]
	if page.auto_advance:
		_hold_elapsed += remaining
		if _hold_elapsed >= maxf(0.0, page.hold_seconds):
			advance()

func _unhandled_input(event: InputEvent) -> void:
	if not is_playing or not is_visible_in_tree():
		return
	var confirm: bool = false
	if event is InputEventKey:
		confirm = event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
	elif event is InputEventMouseButton:
		confirm = event.pressed and event.button_index == MOUSE_BUTTON_LEFT and get_global_rect().has_point(event.position)
	if confirm:
		get_viewport().set_input_as_handled()
		advance()

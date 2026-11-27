@tool
extends Control
## Shared by editor previews and exported games. No save-game access.

signal finished
signal page_changed(page_index: int)
signal phase_changed(value: String)

const DESIGN_SIZE := Vector2(1280, 720)

var book: Resource
var index: int = -1
var is_transitioning: bool = false
var is_playing: bool = false
var input_enabled: bool = true

# Public for inspection/testing; these are the actual displayed buffers.
var image_current: TextureRect
var image_previous: TextureRect
var text_current: Label
var text_previous: Label
var canvas: Control
var background: ColorRect
var background_image: TextureRect

var phase: String = "done"
var timeline_time: float = 0.0
var entrance_duration: float = 0.0
var _single_page: bool = false
var _phase_time: float = 0.0
var _target: Dictionary = {}
var _finished_sent: bool = false

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
	canvas.clip_contents = false
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	background = ColorRect.new()
	background.color = Color("18212b")
	background.size = DESIGN_SIZE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	move_child(background, 0)
	background_image = TextureRect.new()
	background_image.name = "BookPaper"
	background_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background_image)
	move_child(background_image, 1)
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
	view.clip_text = false
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
	background.position = Vector2.ZERO
	background.size = size
	background_image.position = Vector2.ZERO
	background_image.size = size
	if not _target.is_empty():
		_layout_image(image_current, _target)

func _set_image(view: TextureRect, state: Dictionary) -> void:
	view.texture = state.get("image") as Texture2D
	_layout_image(view, state)
	view.visible = view.texture != null
	view.modulate.a = 1.0

func _layout_image(view: TextureRect, state: Dictionary) -> void:
	var rect: Rect2 = state.get("image_rect", Rect2(Vector2.ZERO, DESIGN_SIZE))
	var cover: bool = int(state.get("image_fit", 0)) == 0
	if cover and rect == Rect2(Vector2.ZERO, DESIGN_SIZE) and canvas.scale.x > 0:
		rect = Rect2(-canvas.position / canvas.scale.x, size / canvas.scale.x)
	view.position = rect.position
	view.size = rect.size
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if cover else TextureRect.STRETCH_KEEP_ASPECT_CENTERED

func _set_text(view: Label, state: Dictionary) -> void:
	view.text = str(state.get("text", ""))
	var rect: Rect2 = state.get("text_rect", Rect2(96, 540, 1088, 130))
	view.position = rect.position
	view.size = rect.size
	var fitted_size: int = int(state.get("font_size", 32))
	var font: Font = view.get_theme_font("font")
	while fitted_size > 8:
		var measured: Vector2 = font.get_multiline_string_size(view.text, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, fitted_size)
		if measured.y <= rect.size.y:
			break
		fitted_size -= 1
	view.add_theme_font_size_override("font_size", fitted_size)
	view.size = rect.size
	view.add_theme_color_override("font_color", state.get("text_color", Color.WHITE))
	view.add_theme_color_override("font_shadow_color", state.get("text_shadow_color", Color(0, 0, 0, 0.85)))
	var shadow_offset: Vector2 = state.get("text_shadow_offset", Vector2(2, 2))
	view.add_theme_constant_override("shadow_offset_x", int(shadow_offset.x))
	view.add_theme_constant_override("shadow_offset_y", int(shadow_offset.y))
	view.add_theme_constant_override("shadow_outline_size", int(state.get("text_shadow_outline_size", 0)))
	var backdrop := StyleBoxFlat.new()
	backdrop.bg_color = state.get("text_backdrop_color", Color.TRANSPARENT)
	var padding: float = state.get("text_backdrop_padding", 20.0)
	backdrop.expand_margin_left = padding
	backdrop.expand_margin_right = padding
	backdrop.expand_margin_top = padding
	backdrop.expand_margin_bottom = padding
	backdrop.set_corner_radius_all(16)
	backdrop.content_margin_left = 0
	backdrop.content_margin_right = 0
	backdrop.content_margin_top = 0
	backdrop.content_margin_bottom = 0
	view.add_theme_stylebox_override("normal", backdrop)
	view.visible = not view.text.is_empty()
	view.modulate.a = 1.0

func _valid_page(source: Resource, page_index: int) -> bool:
	return source != null and source.has_method("resolve") and page_index >= 0 and page_index < source.pages.size() and source.pages[page_index] != null

func _phase(value: String) -> void:
	var changed: bool = phase != value
	phase = value
	is_transitioning = value in ["enter", "exit"]
	if changed:
		phase_changed.emit(phase)

func _load_page(source: Resource, page_index: int) -> bool:
	_ensure_nodes()
	book = source
	if not _valid_page(source, page_index):
		index = -1
		_clear()
		return false
	index = page_index
	background.color = book.background_color
	background_image.texture = book.background_texture
	background_image.visible = book.background_texture != null
	background_image.modulate = Color.WHITE
	_target = book.resolve(index)
	_set_image(image_current, _target)
	_set_text(text_current, _target)
	_hide_previous()
	var page: Resource = book.pages[index]
	entrance_duration = maxf(page.image_delay + page.image_duration if image_current.visible else 0.0, page.text_delay + page.text_duration if text_current.visible else 0.0)
	return true

func show_static(source: Resource, page_index: int) -> void:
	stop()
	if _load_page(source, page_index):
		timeline_time = entrance_duration
		_phase("hold")
		page_changed.emit(index)

func play(source: Resource, page_index: int = 0) -> void:
	_start(source, page_index, false)

func replay(source: Resource, page_index: int) -> void:
	_start(source, page_index, true)

func _start(source: Resource, page_index: int, single: bool) -> void:
	stop()
	_single_page = single
	_finished_sent = false
	if not _load_page(source, page_index):
		return
	is_playing = true
	_begin_enter()

func _begin_enter() -> void:
	_phase_time = 0.0
	timeline_time = 0.0
	_phase("enter")
	_apply_enter()
	if entrance_duration <= 0.0:
		_complete_enter()
	page_changed.emit(index)

func _progress(time: float, delay: float, duration: float) -> float:
	if time < delay:
		return 0.0
	return 1.0 if duration <= 0.0 else clampf((time - delay) / duration, 0.0, 1.0)

func _apply_enter() -> void:
	var page: Resource = book.pages[index]
	image_current.modulate.a = _progress(_phase_time, page.image_delay, page.image_duration)
	text_current.modulate.a = _progress(_phase_time, page.text_delay, page.text_duration)

func _complete_enter() -> void:
	image_current.modulate.a = 1.0
	text_current.modulate.a = 1.0
	timeline_time = entrance_duration
	_phase_time = 0.0
	_phase("hold")
	if _single_page:
		is_playing = false

func _begin_exit() -> void:
	_phase_time = 0.0
	timeline_time = entrance_duration + book.pages[index].hold_seconds
	_phase("exit")
	_apply_exit()
	# Even a zero-duration exit remains a separate click migration.

func _apply_exit() -> void:
	var alpha: float = 1.0 - _progress(_phase_time, 0.0, book.pages[index].exit_duration)
	image_current.modulate.a = alpha
	text_current.modulate.a = alpha

func _complete_exit() -> void:
	timeline_time = entrance_duration + book.pages[index].hold_seconds + book.pages[index].exit_duration
	image_current.modulate.a = 0.0
	text_current.modulate.a = 0.0
	if index + 1 < book.pages.size():
		_load_page(book, index + 1)
		_begin_enter()
	else:
		is_playing = false
		_phase("done")
		if not _finished_sent:
			_finished_sent = true
			finished.emit()

## Scrub the complete finite timeline, including hold on manual pages.
## Does not run, advance, or emit finished; out-of-range times clamp.
func seek(source: Resource, page_index: int, time: float) -> void:
	stop()
	if not _load_page(source, page_index):
		return
	var page: Resource = book.pages[index]
	var exit_start: float = entrance_duration + page.hold_seconds
	var total: float = exit_start + page.exit_duration
	timeline_time = clampf(time if is_finite(time) else 0.0, 0.0, total)
	if timeline_time < entrance_duration:
		_phase_time = timeline_time
		_phase("enter")
		_apply_enter()
	elif timeline_time < exit_start:
		_phase("hold")
	elif timeline_time < total:
		_phase_time = timeline_time - exit_start
		_phase("exit")
		_apply_exit()
	else:
		_phase("done")
		image_current.modulate.a = 0.0
		text_current.modulate.a = 0.0
	page_changed.emit(index)

func _hide_previous() -> void:
	image_previous.visible = false
	image_previous.texture = null
	text_previous.visible = false
	text_previous.text = ""

func _clear() -> void:
	background_image.texture = null
	background_image.hide()
	image_current.texture = null
	image_current.visible = false
	text_current.text = ""
	text_current.visible = false
	_hide_previous()

func stop() -> void:
	is_playing = false
	_single_page = false
	_phase_time = 0.0
	timeline_time = 0.0
	_phase("done")

func advance() -> void:
	if not is_playing:
		return
	match phase:
		"enter": _complete_enter()
		"hold": _begin_exit()
		"exit": _complete_exit()

func _process(delta: float) -> void:
	if not is_playing or book == null or index < 0:
		return
	var remaining: float = maxf(0.0, delta)
	# Bound zero-length automatic pages by the number of remaining phases.
	for iteration in range((book.pages.size() - index) * 3 + 3):
		if not is_playing:
			return
		var page: Resource = book.pages[index]
		var duration: float = entrance_duration if phase == "enter" else page.exit_duration
		if phase == "hold":
			if not page.auto_advance:
				_phase_time += remaining
				timeline_time = entrance_duration + minf(_phase_time, page.hold_seconds)
				return
			duration = page.hold_seconds
		var step: float = minf(remaining, maxf(0.0, duration - _phase_time))
		_phase_time += step
		remaining -= step
		timeline_time = _phase_time
		if phase == "hold":
			timeline_time += entrance_duration
		elif phase == "exit":
			timeline_time += entrance_duration + page.hold_seconds
		if phase == "enter":
			_apply_enter()
		elif phase == "exit":
			_apply_exit()
		if _phase_time < duration and not is_equal_approx(_phase_time, duration):
			return
		match phase:
			"enter": _complete_enter()
			"hold": _begin_exit()
			"exit": _complete_exit()
		if remaining <= 0.0:
			return

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or not is_playing or not is_visible_in_tree():
		return
	var confirm: bool = false
	if event is InputEventKey:
		confirm = event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
	elif event is InputEventMouseButton:
		confirm = event.pressed and event.button_index == MOUSE_BUTTON_LEFT and get_global_rect().has_point(event.position)
	if confirm:
		get_viewport().set_input_as_handled()
		advance()

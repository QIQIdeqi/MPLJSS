extends Control
## Presentation only; the menu owns saving and the transition into the village.

signal completed
signal back_requested

@export var book: Resource
@onready var player: Control = $Player
var completion_requested := false
var leaving := false
var modal := ""
var confirmation_source := ""
var saved_processing := true
var saved_input_enabled := true
const UI_FADE_SECONDS := 0.18
const QUICK_FADE_SECONDS := 0.22
var overlay_alpha := 0.0
var pause_alpha := 0.0
var confirm_alpha := 0.0
var quick_alpha := 0.0
var pending_action := ""
var quick_idle := 3.0
var quick_hover := false
var previous_scale_aspect: int = -1
var pause_base_offsets := Vector2.ZERO
var confirm_base_offsets := Vector2.ZERO

func _ready() -> void:
	pause_base_offsets = Vector2($Modal/Pause.offset_top, $Modal/Pause.offset_bottom)
	confirm_base_offsets = Vector2($Modal/Confirm.offset_top, $Modal/Confirm.offset_bottom)
	previous_scale_aspect = get_window().content_scale_aspect
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	$Controls/Previous.pressed.connect(previous_page)
	$Controls/Next.pressed.connect(next_page)
	$Controls/Skip.pressed.connect(request_skip)
	$Controls/Back.pressed.connect(return_to_menu)
	player.page_changed.connect(_page_changed)
	player.finished.connect(finish_prologue)
	player.phase_changed.connect(_phase_changed)
	$QuickSkip.pressed.connect(request_skip)
	$QuickSkip.mouse_entered.connect(func() -> void: quick_hover = true; wake_quick_skip())
	$QuickSkip.mouse_exited.connect(func() -> void: quick_hover = false; wake_quick_skip())
	$Modal/Pause/Resume.pressed.connect(resume_playback)
	$Modal/Pause/Replay.pressed.connect(replay_book)
	$Modal/Pause/Skip.pressed.connect(request_skip)
	$Modal/Confirm/Cancel.pressed.connect(cancel_skip)
	$Modal/Confirm/Accept.pressed.connect(confirm_skip)
	$QuickSkip.modulate.a = 0.0
	$QuickSkip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Modal.modulate.a = 0.0
	grab_focus()
	if book == null or not book.validate().is_empty():
		show_error("序章绘本无效，请返回开始界面检查剧情配置。")
		return
	player.play(book)

func _page_changed(index: int) -> void:
	$Caption.text = "序章 · %d / %d" % [index + 1, book.pages.size()]
	$Controls/Previous.disabled = index == 0
	_phase_changed(player.phase)
	$Error.hide()

func _phase_changed(value: String) -> void:
	match value:
		"enter": $Controls/Next.text = "立即显示"
		"hold": $Controls/Next.text = "淡出并结束" if player.index == book.pages.size() - 1 else "淡出 / 下一页"
		"exit": $Controls/Next.text = "完成序章" if player.index == book.pages.size() - 1 else "跳过淡出"

func previous_page() -> void:
	if book != null and not completion_requested and not leaving and modal.is_empty():
		player.play(book, maxi(0, player.index - 1))

func next_page() -> void:
	if completion_requested or leaving or not modal.is_empty():
		return
	if player.is_playing:
		player.advance()
	else:
		finish_prologue()

func finish_prologue() -> void:
	if completion_requested or leaving:
		return
	completion_requested = true
	player.stop()
	completed.emit()

func return_to_menu() -> void:
	if leaving:
		return
	leaving = true
	player.stop()
	back_requested.emit()

func show_error(text: String) -> void:
	# The menu may report a synchronous save failure from completed.emit().
	# Unlock only here so a deliberate retry works, but successful completion stays single-shot.
	completion_requested = false
	player.stop()
	$Error.text = text + "\n按 Enter / 空格重试。"
	$Error.show()
	$Controls/Next.text = "重试进入村庄"

func wake_quick_skip() -> void:
	if not modal.is_empty() or completion_requested or leaving:
		return
	quick_idle = 0.0

func _process(delta: float) -> void:
	var dt := maxf(delta, 0.0)
	var previous_idle := quick_idle
	var quick_allowed := modal.is_empty() and not completion_requested and not leaving
	if quick_allowed and $QuickSkip.visible and (quick_hover or $QuickSkip.get_global_rect().has_point(get_global_mouse_position())):
		quick_idle = 0.0
	else:
		quick_idle += dt
	var quick_target := 1.0 if quick_allowed and quick_idle < 3.0 else 0.0
	var quick_step := dt
	if quick_target == 0.0 and quick_allowed:
		quick_step = maxf(0.0, quick_idle - maxf(3.0, previous_idle))
	quick_alpha = move_toward(quick_alpha, quick_target, quick_step / QUICK_FADE_SECONDS)
	$QuickSkip.modulate.a = quick_alpha
	$QuickSkip.offset_top = -55.0 + 4.0 * (1.0 - quick_alpha)
	$QuickSkip.offset_bottom = -33.0 + 4.0 * (1.0 - quick_alpha)
	$QuickSkip.visible = quick_alpha > 0.0
	$QuickSkip.mouse_filter = Control.MOUSE_FILTER_STOP if quick_alpha > 0.0 and quick_allowed else Control.MOUSE_FILTER_IGNORE
	var modal_target := 1.0 if modal in ["pause", "confirm", "return_pause"] else 0.0
	var pause_target := 1.0 if modal in ["pause", "return_pause"] else (0.2 if modal == "confirm" and confirmation_source == "pause" else 0.0)
	var confirm_target := 1.0 if modal == "confirm" else 0.0
	overlay_alpha = move_toward(overlay_alpha, modal_target, dt / UI_FADE_SECONDS)
	pause_alpha = move_toward(pause_alpha, pause_target, dt / UI_FADE_SECONDS)
	confirm_alpha = move_toward(confirm_alpha, confirm_target, dt / UI_FADE_SECONDS)
	$Modal.modulate.a = overlay_alpha
	$Modal.visible = not modal.is_empty()
	$Modal/Pause.visible = pause_alpha > 0.0
	$Modal/Pause.modulate.a = pause_alpha
	$Modal/Pause.offset_top = pause_base_offsets.x + 4.0 * (1.0 - pause_alpha)
	$Modal/Pause.offset_bottom = pause_base_offsets.y + 4.0 * (1.0 - pause_alpha)
	for name: String in ["Resume", "Replay", "Skip"]:
		var button: Button = get_node("Modal/Pause/" + name)
		button.modulate.a = clampf((pause_alpha - 0.12) / 0.88, 0.0, 1.0)
		button.disabled = modal != "pause"
	$Modal/Confirm.visible = confirm_alpha > 0.0
	$Modal/Confirm.modulate.a = confirm_alpha
	$Modal/Confirm.offset_top = confirm_base_offsets.x + 4.0 * (1.0 - confirm_alpha)
	$Modal/Confirm.offset_bottom = confirm_base_offsets.y + 4.0 * (1.0 - confirm_alpha)
	$Modal/Confirm/Cancel.disabled = modal != "confirm"
	$Modal/Confirm/Accept.disabled = modal != "confirm"
	if modal == "return_pause" and is_zero_approx(confirm_alpha):
		modal = "pause"
		$Modal/Pause/Skip.disabled = false
		$Modal/Pause/Skip.grab_focus()
	if modal == "closing" and is_zero_approx(overlay_alpha) and is_zero_approx(pause_alpha) and is_zero_approx(confirm_alpha):
		_finish_close()

func _finish_close() -> void:
	var action := pending_action
	pending_action = ""
	modal = ""
	$Modal.hide()
	player.set_process(saved_processing)
	player.input_enabled = saved_input_enabled
	grab_focus()
	if action == "skip":
		finish_prologue()
	elif action == "replay":
		var session_book: Resource = player.book
		player.play(session_book if session_book != null else book, 0)

func _freeze() -> void:
	if modal.is_empty():
		saved_processing = player.is_processing()
		saved_input_enabled = player.input_enabled
	player.set_process(false)
	player.input_enabled = false
	quick_idle = 3.0
	$QuickSkip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quick_hover = false

func pause_playback() -> void:
	if completion_requested or leaving or (not modal.is_empty() and modal != "closing") or pending_action == "skip":
		return
	_freeze()
	pending_action = ""
	modal = "pause"
	$Modal.show()
	$Modal/Pause.show()
	$Modal/Pause/Resume.disabled = false
	$Modal/Pause/Resume.grab_focus()

func resume_playback() -> void:
	if modal != "pause":
		return
	_close_modal()

func _close_modal() -> void:
	modal = "closing"
	# Keep both the mouse shield and player input guard until the fade is gone.
	grab_focus()

func replay_book() -> void:
	if modal != "pause" or book == null:
		return
	pending_action = "replay"
	_close_modal()

func request_skip() -> void:
	if completion_requested or leaving or modal not in ["", "pause"]:
		return
	confirmation_source = modal
	_freeze()
	modal = "confirm"
	$Modal.show()
	$Modal/Confirm.show()
	$Modal/Confirm/Cancel.disabled = false
	$Modal/Confirm/Cancel.grab_focus()

func cancel_skip() -> void:
	if modal != "confirm":
		return
	if confirmation_source == "pause":
		modal = "return_pause"
		grab_focus()
	else:
		_close_modal()

func confirm_skip() -> void:
	if modal != "confirm":
		return
	pending_action = "skip"
	_close_modal()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and not event.relative.is_zero_approx():
		wake_quick_skip()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_unhandled_key_input(event)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if modal.is_empty():
			wake_quick_skip()
			if not completion_requested and not leaving and player.is_playing:
				player.advance()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if modal == "confirm":
			cancel_skip()
		elif modal in ["pause", "return_pause"]:
			_close_modal()
		else:
			pause_playback()
	elif event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] and modal.is_empty():
		if $Error.visible and not completion_requested and not leaving:
			get_viewport().set_input_as_handled()
			next_page()

func _exit_tree() -> void:
	if previous_scale_aspect >= 0:
		get_window().content_scale_aspect = previous_scale_aspect

extends SceneTree
## Signal-driven production overlay checks, with no profile writes.
const SCENE = preload("res://scenes/story/prologue.tscn")
var failures := 0
var checks := 0
func _initialize() -> void:
	run.call_deferred()
func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("PROLOGUE_PAUSE: " + message)
func key(overlay: Control, code: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = code
	overlay._unhandled_key_input(event)
func run() -> void:
	var overlay: Control = SCENE.instantiate()
	overlay.book = load("res://picture_books/prologue/prologue.tres").duplicate(true)
	root.add_child(overlay)
	await process_frame
	var player: Control = overlay.player
	var completions := [0]
	overlay.completed.connect(func() -> void: completions[0] += 1)
	expect(not overlay.get_node("QuickSkip").visible and not overlay.get_node("Modal").visible, "HUD starts hidden")
	player.set_process(false)
	for phase: String in ["enter", "hold", "exit"]:
		player.play(overlay.book, 2)
		if phase != "enter": player.advance()
		if phase == "exit": player.advance()
		var before: float = player.timeline_time
		key(overlay, KEY_ESCAPE)
		expect(overlay.modal == "pause" and not player.is_processing() and not player.input_enabled, "Escape freezes " + phase)
		await create_timer(0.03).timeout
		expect(player.phase == phase and player.timeline_time == before and player.index == 2, "paused timeline unchanged: " + phase)
		var confirm := InputEventKey.new()
		confirm.keycode = KEY_ENTER
		confirm.pressed = true
		player._unhandled_input(confirm)
		expect(player.phase == phase, "paused player ignores confirm: " + phase)
		overlay.request_skip()
		expect(overlay.modal == "confirm" and completions[0] == 0, "pause skip opens confirmation only")
		key(overlay, KEY_ESCAPE)
		overlay._process(0.5)
		expect(overlay.modal == "pause" and player.phase == phase and player.timeline_time == before, "Escape returns confirmation to pause")
		key(overlay, KEY_ESCAPE)
		overlay._process(0.5)
		expect(overlay.modal.is_empty() and player.input_enabled and not player.is_processing(), "resume restores pre-pause process and input settings")
	player.play(overlay.book, 3)
	for code: Key in [KEY_R, KEY_S]:
		key(overlay, code)
		expect(player.index == 3 and player.phase == "enter" and completions[0] == 0, "removed shortcut cannot restart or skip")
	overlay.wake_quick_skip()
	overlay._process(0.25)
	expect(overlay.get_node("QuickSkip").visible, "pointer activity reveals fast-forward")
	overlay.quick_hover = true
	overlay._process(4.0)
	expect(overlay.get_node("QuickSkip").visible, "hover keeps fast-forward visible")
	overlay.quick_hover = false
	overlay.wake_quick_skip()
	overlay._process(2.9)
	overlay._process(0.15)
	expect(overlay.get_node("QuickSkip").modulate.a < 1.0, "idle HUD fades")
	overlay._process(0.3)
	expect(not overlay.get_node("QuickSkip").visible, "idle HUD disappears")
	overlay.wake_quick_skip()
	overlay._process(0.25)
	overlay.get_node("QuickSkip").pressed.emit()
	expect(overlay.modal == "confirm" and player.index == 3 and player.phase == "enter", "quick skip does not pass through to page")
	key(overlay, KEY_ESCAPE)
	overlay._process(0.5)
	expect(overlay.modal.is_empty() and player.index == 3 and player.phase == "enter", "cancel returns to playing source unchanged")
	for automatic: bool in [false, true]:
		overlay.book.pages[0].auto_advance = automatic
		overlay.pause_playback()
		overlay.get_node("Modal/Pause/Replay").pressed.emit()
		overlay._process(0.5)
		expect(player.index == 0 and player.phase == "enter" and player.book.pages[0].auto_advance == automatic, "restart begins whole book and preserves session auto/manual setting")
	player.set_process(true)
	overlay.pause_playback()
	expect(not player.is_processing(), "pause freezes a running process")
	overlay.resume_playback()
	overlay._process(0.5)
	expect(player.is_processing(), "resume restores a running process")
	player.set_process(false)
	overlay.request_skip()
	overlay.get_node("Modal/Confirm/Accept").pressed.emit()
	overlay._process(0.5)
	overlay.confirm_skip()
	overlay.finish_prologue()
	expect(completions[0] == 1, "confirmed skip emits completion once")
	overlay.queue_free()
	await process_frame
	if failures == 0:
		print("PROLOGUE_PAUSE_PASS checks=%d enter_hold_exit resume restart confirm cancel hud removed_shortcuts" % checks)
	quit(0 if failures == 0 else 1)

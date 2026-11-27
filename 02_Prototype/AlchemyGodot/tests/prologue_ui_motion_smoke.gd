extends SceneTree
const SCENE = preload("res://scenes/story/prologue.tscn")
var failures := 0
var checks := 0
func _initialize() -> void:
	run.call_deferred()
func expect(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("PROLOGUE_UI_MOTION: " + description)
func run() -> void:
	root.size = Vector2i(1280, 720)
	var overlay: Control = SCENE.instantiate()
	overlay.book = load("res://picture_books/prologue/prologue.tres").duplicate(true)
	root.add_child(overlay)
	await process_frame
	overlay.set_process(false)
	overlay.player.set_process(false)
	var quick: Button = overlay.get_node("QuickSkip")
	var motion := InputEventMouseMotion.new()
	overlay._input(motion)
	overlay._process(0.1)
	expect(not quick.visible and quick.mouse_filter == Control.MOUSE_FILTER_IGNORE, "zero relative motion cannot wake invisible HUD")
	motion.relative = Vector2(2, 0)
	overlay._input(motion)
	overlay._process(0.1)
	expect(quick.modulate.a > 0.0 and quick.modulate.a < 1.0, "real movement fades in continuously")
	overlay._process(0.15)
	overlay.quick_hover = true
	overlay._process(5.0)
	expect(quick.visible and is_equal_approx(quick.modulate.a, 1.0), "hover keeps visible hot area alive beyond three seconds")
	overlay.quick_hover = false
	overlay.wake_quick_skip()
	quick.grab_focus()
	overlay._process(2.9)
	expect(is_equal_approx(quick.modulate.a, 1.0), "leaving begins full three-second idle window")
	overlay._process(0.1)
	expect(is_equal_approx(quick.modulate.a, 1.0), "exactly three seconds is the start boundary, not an early fade")
	overlay._process(0.05)
	var fading: float = quick.modulate.a
	expect(fading > 0.0 and fading < 1.0, "focused button still fades after idle window")
	overlay._input(motion)
	expect(is_equal_approx(quick.modulate.a, fading), "new motion does not snap alpha")
	overlay._process(0.04)
	expect(quick.modulate.a > fading and quick.offset_top >= -55.0 and quick.offset_top <= -51.0, "fade reverses smoothly with bounded displacement")
	overlay._process(4.0)
	expect(not quick.visible and quick.mouse_filter == Control.MOUSE_FILTER_IGNORE, "fully faded HUD cannot intercept picture clicks")
	overlay.player.play(overlay.book, 0)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = quick.get_global_rect().get_center()
	Input.parse_input_event(click)
	await process_frame
	expect(overlay.modal.is_empty() and overlay.player.index == 0 and overlay.player.phase == "hold", "viewport click on hidden shortcut footprint completes picture instead of opening confirmation")
	click.pressed = false
	Input.parse_input_event(click)
	await process_frame
	overlay.pause_playback()
	expect(not overlay.player.input_enabled and overlay.modal == "pause", "pause freezes synchronously before animation")
	overlay._process(0.09)
	var before: float = overlay.overlay_alpha
	overlay.resume_playback()
	expect(overlay.modal == "closing" and not overlay.player.input_enabled, "resume keeps input barrier during exit")
	overlay._process(0.03)
	var closing: float = overlay.overlay_alpha
	expect(closing < before and closing > 0.0, "pause exit is continuous")
	overlay.pause_playback()
	expect(is_equal_approx(overlay.overlay_alpha, closing), "reversing exit does not flash")
	overlay._process(0.03)
	expect(overlay.overlay_alpha > closing and not overlay.player.input_enabled, "reverse pause remains frozen")
	overlay._process(0.3)
	overlay.request_skip()
	overlay._process(0.1)
	expect(overlay.pause_alpha > 0.0 and overlay.get_node("Modal/Pause/Skip").disabled, "confirmation retains dim pause layer without interactive underlying buttons")
	overlay.cancel_skip()
	expect(overlay.modal == "return_pause" and not overlay.player.input_enabled, "cancel keeps shield while confirmation exits")
	overlay._process(0.3)
	expect(overlay.modal == "pause", "cancel restores pause source after fade")
	overlay.replay_book()
	expect(overlay.pending_action == "replay" and overlay.modal == "closing", "restart queues one action behind exit")
	overlay.pause_playback()
	expect(overlay.pending_action.is_empty() and overlay.modal == "pause", "reverse pause cancels queued restart")
	overlay.resume_playback()
	overlay._process(0.3)
	expect(overlay.modal.is_empty() and overlay.player.input_enabled, "finished exit releases barrier once")
	overlay.queue_free()
	await process_frame
	if failures == 0:
		print("PROLOGUE_UI_MOTION_PASS checks=%d hover idle reverse modal_barrier" % checks)
	quit(0 if failures == 0 else 1)

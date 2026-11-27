extends SceneTree
const EDITOR = preload("res://addons/picture_book/editor.tscn")
const TEMP := "res://tests/.timeline_roundtrip.tres"
var failures := 0
var w: Control
func _initialize() -> void:
	run.call_deferred()
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error("TIMELINE_EDITOR: " + message)
func mouse(pos: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = pos
	w.timeline._gui_input(e)
func drag(a: Vector2, b: Vector2) -> void:
	mouse(a, true)
	var e := InputEventMouseMotion.new()
	e.position = b
	w.timeline._gui_input(e)
	mouse(b, false)
func run() -> void:
	root.size = Vector2i(1280, 720)
	if FileAccess.file_exists(TEMP):
		quit(2)
		return
	w = EDITOR.instantiate()
	root.add_child(w)
	await process_frame
	w.open_document("res://picture_books/demo/sample.tres")
	w.values.image_delay.value = 1.0
	w.values.image_duration.value = 2.0
	w.values.text_delay.value = 4.0
	w.values.text_duration.value = 1.0
	var before: int = w.undo_stack.size()
	var r: Rect2 = w.timeline.clip_rect("image")
	var unit: float = w.timeline.time_x(1) - w.timeline.time_x(0)
	drag(r.get_center(), r.get_center() + Vector2(unit, 0))
	check(is_equal_approx(w.book.pages[0].image_delay, 2), "clip body shifts independent image start")
	check(w.undo_stack.size() == before + 1, "one drag creates one undo action")
	r = w.timeline.clip_rect("text")
	unit = w.timeline.time_x(1) - w.timeline.time_x(0)
	drag(Vector2(r.end.x, r.get_center().y), Vector2(r.end.x + unit, r.get_center().y))
	check(is_equal_approx(w.book.pages[0].text_duration, 2), "right edge changes duration")
	r = w.timeline.clip_rect("text")
	unit = w.timeline.time_x(1) - w.timeline.time_x(0)
	drag(Vector2(r.position.x, r.get_center().y), Vector2(r.position.x + unit, r.get_center().y))
	check(is_equal_approx(w.book.pages[0].text_delay, 5), "left edge changes start while keeping end")
	w.values.image_delay.value = 0.37
	w.values.image_duration.value = 1.23
	w.values.text_delay.value = 3.0
	w.values.text_duration.value = 1.0
	w.values.exit_duration.value = 0.73
	w.timeline_time.value = 2.0
	check(w.canvas.previewing and w.canvas.view.phase == "enter", "scrub is separate from layout editing")
	check(w.canvas.view.image_current.modulate.a == 1 and w.canvas.view.text_current.modulate.a == 0, "gap preview holds image with text invisible")
	mouse(Vector2(w.timeline.time_x(3.5), 20), true)
	mouse(Vector2(w.timeline.time_x(3.5), 20), false)
	check(absf(w.canvas.view.text_current.modulate.a - 0.5) < 0.02, "ruler scrubs actual runtime fade")
	check(w.save_document(TEMP), "save new timing fields")
	check(w.open_document(TEMP), "reopen new timing fields")
	check(is_equal_approx(w.book.pages[0].image_delay, .37) and is_equal_approx(w.book.pages[0].exit_duration, .73), "precise values survive save/reopen")
	check(not w.canvas.previewing and not w.timeline_scrubbing, "reopen restores editable layout")
	w.preview.set_process(false)
	w.start_preview()
	await process_frame
	await process_frame
	check(not w.preview_caption.is_visible_in_tree() and not w.next_button.is_visible_in_tree() and not w.previous_button.is_visible_in_tree(), "presentation has no visible hints or buttons")
	for expected in ["hold", "exit", "enter"]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
		event.position = w.preview.get_global_rect().get_center()
		Input.parse_input_event(event)
		await process_frame
		event.pressed = false
		Input.parse_input_event(event)
		await process_frame
		check(w.preview.phase == expected, "actual viewport mouse routes exactly one transition: " + expected)
	check(w.preview.index == 1 and w.preview.image_current.modulate.a == 0, "third click enters next page without swallowing its fade")
	w.stop_preview()
	w.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP))
	if failures == 0:
		print("PICTURE_BOOK_TIMELINE_EDITOR_PASS body edges precise-input scrub gap save reopen three-click isolation")
	quit(0 if failures == 0 else 1)

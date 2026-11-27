extends SceneTree
## Signal/input-driven integration test of the actual editor scene.
## This is not manual mouse/keyboard or visual acceptance testing.

const EDITOR = preload("res://addons/picture_book/editor.tscn")
const Page = preload("res://scripts/picture_book/page.gd")
const SAMPLE := "res://picture_books/demo/sample.tres"
const TEMP := "res://tests/.picture_book_editor_test.tres"
const EVENING := "res://picture_books/demo/evening.svg"
const MORNING := "res://picture_books/demo/morning.svg"

var workspace: Control
var failures: int = 0
var wrote_temp: bool = false
var sample_hash: String

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, message: String) -> bool:
	if not condition:
		failures += 1
		push_error("PICTURE_BOOK_EDITOR: " + message)
	return condition

func press(node_name: String) -> void:
	var button := workspace.find_child(node_name, true, false) as Button
	if expect(button != null, "actual tool button exists: " + node_name):
		button.pressed.emit()

func click_card(page_index: int) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	event.position = Vector2(10, 10)
	workspace.page_list.get_child(page_index)._gui_input(event)

func image_path(page_index: int) -> String:
	var image: Texture2D = workspace.book.resolve(page_index).image
	return image.resource_path if image != null else ""

func run() -> void:
	if FileAccess.file_exists(TEMP):
		push_error("Refusing to overwrite an existing temporary test book: " + TEMP)
		quit(1)
		return
	sample_hash = FileAccess.get_sha256(SAMPLE)
	workspace = EDITOR.instantiate()
	root.add_child(workspace)
	await process_frame
	press("OpenSample")
	if not expect(workspace.document_path == SAMPLE and workspace.book.pages.size() == 4, "sample opened through toolbar"):
		await finish()
		return
	click_card(1)
	expect(workspace.selected_index == 1, "second page selected through card input")
	var original_text: String = workspace.book.pages[1].text
	press("DuplicatePage")
	expect(workspace.book.pages.size() == 5 and workspace.selected_index == 2, "duplicate toolbar inserts and selects an independent copy")
	expect(workspace.book.pages[1] != workspace.book.pages[2], "duplicate is a separate page resource")
	workspace.text_input.text = "重排后的副本仍可独立编辑。"
	workspace.text_input.text_changed.emit()
	expect(workspace.book.pages[1].text == original_text, "editing copy through inspector leaves original intact")
	var target: Control = workspace.page_list.get_child(3)
	var payload := {"picture_book_page": 2, "owner_token": workspace.get_instance_id()}
	expect(target._can_drop_data(Vector2.ZERO, payload), "same-document card accepts drag")
	expect(not target._can_drop_data(Vector2.ZERO, {"picture_book_page": 2, "owner_token": -1}), "foreign-document drag rejected")
	target._drop_data(Vector2.ZERO, payload)
	expect(workspace.selected_index == 3 and workspace.book.pages[3].image_action == Page.Action.KEEP, "actual card drop callback moves KEEP page after evening")
	expect(image_path(3) == EVENING and image_path(1) == MORNING, "inheritance follows new order rather than cached original image")
	expect(workspace.canvas.view.image_current.texture.resource_path == EVENING, "editing canvas renders newly inherited evening image")
	# The file-selected signal is the same save-dialog completion path used by
	# the GUI; no real user file or sample resource is written by this test.
	workspace.file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	workspace.file_dialog.file_selected.emit(TEMP)
	wrote_temp = FileAccess.file_exists(TEMP)
	expect(wrote_temp and not workspace.dirty and workspace.document_path == TEMP, "save-dialog completion persists the reordered document")
	if not wrote_temp:
		await finish()
		return
	var saved_hash := FileAccess.get_sha256(TEMP)
	workspace.page_title.text = "保存验证中的副本"
	workspace.page_title.text_changed.emit(workspace.page_title.text)
	workspace.book.pages[3].text_duration = -1.0
	press("SaveBook")
	expect(workspace.dirty, "failed validation keeps dirty state and edits")
	expect(FileAccess.get_sha256(TEMP) == saved_hash, "failed validation does not overwrite last saved bytes")
	workspace.book.pages[3].text_duration = 1.0
	press("SaveBook")
	expect(not workspace.dirty, "normal save button succeeds after correcting invalid duration")
	expect(workspace.open_document(TEMP), "saved book can be reopened through the editor loader")
	expect(workspace.book.pages.size() == 5 and workspace.book.pages[3].title == "保存验证中的副本", "reopen retains page order and edited metadata")
	expect(image_path(3) == EVENING, "reopen resolves the same inherited image")
	click_card(3)
	workspace.preview.set_process(false)
	press("Present")
	expect(workspace.preview_panel.visible and workspace.preview.index == 3, "present toolbar starts from selected middle page")
	expect(workspace.preview.image_current.texture.resource_path == EVENING and workspace.preview.image_current.modulate.a == 0.0, "middle-page entry starts inherited image transparently")
	workspace.preview._process(0.5)
	expect(workspace.preview.is_transitioning and workspace.preview.text_current.text == workspace.book.pages[3].text, "entry keeps current narration stable while fading")
	var confirm := InputEventKey.new()
	confirm.keycode = KEY_ENTER
	confirm.pressed = true
	Input.parse_input_event(confirm)
	await process_frame
	expect(workspace.preview.index == 3 and not workspace.preview.is_transitioning, "first Enter completes entry and does not consume the current page")
	confirm.echo = true
	Input.parse_input_event(confirm)
	await process_frame
	expect(workspace.preview.index == 3, "held Enter cannot advance via echo")
	confirm.echo = false
	Input.parse_input_event(confirm)
	await process_frame
	expect(workspace.preview.index == 3 and workspace.preview.phase == "exit", "second deliberate Enter starts the current page exit")
	Input.parse_input_event(confirm)
	await process_frame
	expect(workspace.preview.index == 4 and workspace.preview.phase == "enter", "third Enter skips exit but leaves the next entry intact")
	workspace.preview.advance()
	expect(workspace.preview.image_current.texture == null and workspace.preview.text_current.text != "", "text-only page clears the inherited image")
	press("ClosePreview")
	click_card(3)
	workspace.auto_input.set_pressed_no_signal(true)
	workspace.auto_input.toggled.emit(true)
	workspace.values.hold_seconds.value = 0.1
	press("ReplayEntrance")
	workspace.preview._process(20.0)
	expect(workspace.preview.index == 3 and not workspace.preview.is_playing, "replay toolbar stops after one entry despite automatic page mode")
	expect(workspace.previous_button.disabled and workspace.next_button.disabled, "replay navigation disabled")
	press("ClosePreview")
	var count_before: int = workspace.book.pages.size()
	press("DeletePage")
	expect(workspace.book.pages.size() == count_before - 1, "delete toolbar removes selected page")
	press("Undo")
	expect(workspace.book.pages.size() == count_before and workspace.selected_index == 3 and image_path(3) == EVENING, "undo restores deleted KEEP page and effective content")
	workspace.image_mode.select(Page.Action.CLEAR)
	workspace.image_mode.item_selected.emit(Page.Action.CLEAR)
	expect(image_path(3).is_empty() and workspace.book.resolve(3).text != "", "image clear control produces a text-only page")
	workspace.text_mode.select(Page.Action.CLEAR)
	workspace.text_mode.item_selected.emit(Page.Action.CLEAR)
	expect(workspace.book.resolve(3).image == null and workspace.book.resolve(3).text == "", "independent clear controls produce an empty page")
	press("Undo")
	expect(workspace.book.resolve(3).text != "" and image_path(3).is_empty(), "undo text clear preserves image clear")
	press("Undo")
	expect(image_path(3) == EVENING, "undo image clear restores inherited image")
	workspace.canvas.edit_text()
	workspace.canvas.inline_edit.text = "内联修改保存检查"
	expect(workspace.save_document(TEMP), "save commits active inline text before serialization")
	expect(workspace.book.pages[3].text == "内联修改保存检查", "inline text retained")
	workspace.page_title.text_changed.emit("关闭保护检查")
	workspace._notification(Control.NOTIFICATION_WM_CLOSE_REQUEST)
	expect(workspace.discard_dialog.visible, "standalone close asks before discarding edits")
	workspace.discard_dialog.canceled.emit()
	workspace.discard_dialog.hide()
	expect(workspace.dirty and workspace.book.pages.size() == count_before, "cancel close preserves edits")
	await finish()

func finish() -> void:
	if is_instance_valid(workspace):
		workspace.stop_preview()
		workspace.queue_free()
	await process_frame
	if wrote_temp:
		expect(DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP)) == OK, "temporary saved book removed")
	expect(FileAccess.get_sha256(SAMPLE) == sample_hash, "real sample bytes unchanged")
	if failures == 0:
		print("PICTURE_BOOK_EDITOR_PASS toolbar card-drop duplicate reorder save reopen middle-entry confirm replay undo clear sample-preserved")
	quit(0 if failures == 0 else 1)

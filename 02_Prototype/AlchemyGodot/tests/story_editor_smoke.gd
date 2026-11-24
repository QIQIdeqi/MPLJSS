extends SceneTree
## Actual scene/control-signal integration; not manual GUI acceptance.

const EDITOR = preload("res://addons/story_editor/editor.tscn")
const SAMPLE := "res://picture_books/demo/sample.tres"
const TEMP_STORY := "res://tests/.story_editor_test.tres"
const TEMP_BOOK := "res://tests/.story_editor_book_test.tres"

var workspace: Control
var failures: int = 0
var sample_hash: String = ""
var wrote_story: bool = false
var wrote_book: bool = false

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, message: String) -> bool:
	if not condition:
		failures += 1
		push_error("STORY_EDITOR: " + message)
	return condition

func press(name_text: String) -> void:
	var button := workspace.find_child(name_text, true, false) as Button
	if expect(button != null, "button exists: " + name_text):
		button.pressed.emit()

func run() -> void:
	for path: String in [TEMP_STORY, TEMP_BOOK]:
		if FileAccess.file_exists(path):
			push_error("Refusing to overwrite existing test resource: " + path)
			quit(1)
			return
	sample_hash = FileAccess.get_sha256(SAMPLE)
	workspace = EDITOR.instantiate()
	root.add_child(workspace)
	await process_frame
	expect(workspace.document.nodes.is_empty(), "new story has no formal story nodes")
	press("AddStoryNode")
	var first_id: String = workspace.selected_node_id
	expect(first_id.begins_with("story_") and workspace.document.nodes.size() == 1, "new node receives stable ID")
	workspace.node_title.text = "测试节点甲"
	workspace.node_title.text_changed.emit(workspace.node_title.text)
	workspace.condition_enabled.set_pressed_no_signal(true)
	workspace.condition_enabled.toggled.emit(true)
	workspace.level_id.text = "test_stable_level_id"
	workspace.level_id.text_changed.emit(workspace.level_id.text)
	expect(workspace.document.nodes[0].node_id == first_id, "renaming keeps stable node ID")
	expect(workspace.document.nodes[0].condition_enabled and workspace.document.nodes[0].completed_level_id == "test_stable_level_id", "completed_level parameter edited through controls")
	expect(workspace.document.nodes[0].before_book_path == "" and workspace.document.nodes[0].after_book_path == "", "before/after slots initially independent and empty")
	press("BeforeChooseBook")
	workspace.book_dialog.file_selected.emit(SAMPLE)
	workspace.book_dialog.hide()
	expect(workspace.document.nodes[0].before_book_path == SAMPLE and workspace.document.nodes[0].after_book_path == "", "choosing valid book only fills the selected slot")
	workspace.choosing_slot = "after"
	workspace.book_dialog.file_selected.emit("res://levels/normal.tres")
	expect(workspace.document.nodes[0].after_book_path == "", "non-book resource rejected without changing slot")
	press("AddStoryNode")
	var second_id: String = workspace.selected_node_id
	expect(second_id != first_id and workspace.document.nodes.size() == 2, "second node gets another stable ID")
	workspace.node_list.item_selected.emit(0)
	press("BeforeEditBook")
	expect(workspace.book_overlay.visible and workspace.editing_node_id == first_id and workspace.book_workspace.document_path == SAMPLE, "existing slot opens same embedded picture workspace")
	var old_text: String = workspace.book_workspace.book.pages[0].text
	workspace.book_workspace.text_input.text = "这项修改应在放弃返回时丢弃。"
	workspace.book_workspace.text_input.text_changed.emit()
	press("ReturnToStory")
	expect(workspace.return_dialog.visible and workspace.book_overlay.visible, "dirty book return requests confirmation")
	workspace.return_dialog.canceled.emit()
	workspace.return_dialog.hide()
	expect(workspace.book_overlay.visible and workspace.book_workspace.dirty and workspace.selected_node_id == first_id, "cancel return stays in book and retains selected node")
	press("ReturnToStory")
	workspace.return_dialog.confirmed.emit()
	workspace.return_dialog.hide()
	expect(not workspace.book_overlay.visible and workspace.selected_node_id == first_id, "confirmed discard returns to same node")
	expect(workspace.document.find_node(first_id).before_book_path == SAMPLE and FileAccess.get_sha256(SAMPLE) == sample_hash, "discard does not rewrite referenced sample or detach slot")
	press("BeforeEditBook")
	expect(workspace.book_workspace.book.pages[0].text == old_text, "reopening existing book discards unpersisted text")
	press("ReturnToStory")
	press("AfterEditBook")
	expect(workspace.book_overlay.visible and workspace.editing_slot == "after" and workspace.book_workspace.document_path == "", "empty slot opens a new unsaved picture book")
	workspace.book_workspace.text_input.text = "独立的战后绘本。"
	workspace.book_workspace.text_input.text_changed.emit()
	workspace.book_workspace.file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	workspace.book_workspace.file_dialog.file_selected.emit(TEMP_BOOK)
	wrote_book = FileAccess.file_exists(TEMP_BOOK)
	if not expect(wrote_book, "new embedded book saved through file-dialog completion"):
		await finish()
		return
	expect(workspace.document.find_node(first_id).after_book_path == TEMP_BOOK and workspace.document.find_node(first_id).before_book_path == SAMPLE, "document_saved automatically binds only originating empty slot")
	press("ReturnToStory")
	expect(workspace.selected_node_id == first_id and not workspace.book_overlay.visible, "saved-book return preserves selected stable node")
	press("AfterEditBook")
	workspace.book_workspace.text_input.text = "再次保存仍绑定同一战后绘本。"
	workspace.book_workspace.text_input.text_changed.emit()
	press("SaveBook")
	expect(workspace.document.find_node(first_id).after_book_path == TEMP_BOOK and not workspace.book_workspace.dirty, "existing-book save retains its reference")
	press("ReturnToStory")
	# Extension data remains round-trippable; no event execution is performed.
	workspace.document.find_node(first_id).arrival_events.append({"type": "test_event", "value": 7})
	workspace.register_arrival_event_editor("test_event", func(event: Dictionary, _changed: Callable) -> Control:
		var label := Label.new()
		label.text = "扩展占位 " + str(event.value)
		return label)
	expect(workspace.arrival_container.get_child_count() == 1 and workspace.arrival_container.get_child(0).text == "扩展占位 7", "registered arrival-event editor renders preserved data")
	workspace.document_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	workspace.document_dialog.file_selected.emit(TEMP_STORY)
	wrote_story = FileAccess.file_exists(TEMP_STORY)
	if not expect(wrote_story and not workspace.dirty, "story configuration saved"):
		await finish()
		return
	var valid_hash := FileAccess.get_sha256(TEMP_STORY)
	workspace.level_id.text = ""
	workspace.level_id.text_changed.emit("")
	press("SaveStory")
	expect(workspace.dirty and FileAccess.get_sha256(TEMP_STORY) == valid_hash, "invalid enabled condition blocks save and retains pending edits")
	workspace.level_id.text = "test_stable_level_id"
	workspace.level_id.text_changed.emit(workspace.level_id.text)
	press("SaveStory")
	expect(workspace.open_document(TEMP_STORY), "story reopens from saved resource")
	var reloaded: Resource = workspace.document.find_node(first_id)
	expect(reloaded != null and reloaded.title == "测试节点甲", "stable ID and title survive reopen")
	expect(reloaded.condition_enabled and reloaded.completed_level_id == "test_stable_level_id", "condition survives reopen")
	expect(reloaded.before_book_path == SAMPLE and reloaded.after_book_path == TEMP_BOOK and reloaded.arrival_events[0].value == 7, "independent book references and extension data survive reopen")
	var book_hash := FileAccess.get_sha256(TEMP_BOOK)
	press("DeleteStoryNode")
	expect(workspace.delete_dialog.visible and workspace.document.nodes.size() == 2, "delete first asks rather than immediately mutating nodes")
	workspace.delete_dialog.canceled.emit()
	workspace.delete_dialog.hide()
	expect(workspace.document.find_node(first_id) != null and workspace.document.nodes.size() == 2, "cancel delete preserves node")
	press("DeleteStoryNode")
	workspace.delete_dialog.confirmed.emit()
	workspace.delete_dialog.hide()
	expect(workspace.document.find_node(first_id) == null and workspace.document.find_node(second_id) != null and workspace.document.nodes.size() == 1, "confirmed delete only removes target node")
	expect(FileAccess.get_sha256(TEMP_BOOK) == book_hash and FileAccess.get_sha256(SAMPLE) == sample_hash, "deleting a node never alters referenced book files")
	press("NewStory")
	expect(workspace.discard_dialog.visible, "leaving dirty story asks for confirmation")
	workspace.discard_dialog.canceled.emit()
	workspace.discard_dialog.hide()
	expect(workspace.document.nodes.size() == 1, "cancel dirty leave retains story")
	press("SaveStory")
	expect(not workspace.dirty and workspace.open_document(TEMP_STORY), "confirmed deletion saves and reopens")
	expect(workspace.document.find_node(first_id) == null and workspace.document.find_node(second_id) != null and workspace.document.nodes.size() == 1, "deleted node remains absent after saving and reopening")
	expect(FileAccess.get_sha256(TEMP_BOOK) == book_hash and FileAccess.get_sha256(SAMPLE) == sample_hash, "persisting deletion leaves both referenced book files unchanged")
	await finish()

func finish() -> void:
	if is_instance_valid(workspace):
		workspace.book_workspace.stop_preview()
		workspace.queue_free()
	await process_frame
	if wrote_story:
		expect(DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_STORY)) == OK, "temporary story removed")
	if wrote_book:
		expect(DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_BOOK)) == OK, "temporary picture book removed")
	expect(FileAccess.get_sha256(SAMPLE) == sample_hash, "real sample remains byte-identical")
	if failures == 0:
		print("STORY_EDITOR_PASS stable-id condition slots embedded-edit return-cancel saved-binding delete-confirm save-reopen extension-data no-runtime-triggers")
	quit(0 if failures == 0 else 1)

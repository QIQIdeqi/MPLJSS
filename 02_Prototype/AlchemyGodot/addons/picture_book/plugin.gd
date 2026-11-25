@tool
extends EditorPlugin

const Workspace = preload("res://addons/picture_book/workspace.gd")
var workspace: Control

func _enter_tree() -> void:
	workspace = Workspace.new()
	workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	EditorInterface.get_editor_main_screen().add_child(workspace)
	workspace.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_make_visible(false)

func _has_main_screen() -> bool:
	return true

func _get_plugin_name() -> String:
	return "绘本"

func _make_visible(visible: bool) -> void:
	if is_instance_valid(workspace):
		workspace.visible = visible
		if not visible:
			workspace.stop_preview()

func _get_unsaved_status(_for_scene: String) -> String:
	if is_instance_valid(workspace):
		workspace.canvas.finish_text()
	if is_instance_valid(workspace) and workspace.dirty:
		return "绘本有未保存修改，请在绘本页签保存。"
	return ""

func _save_external_data() -> void:
	if is_instance_valid(workspace):
		workspace.canvas.finish_text()
	if is_instance_valid(workspace) and workspace.dirty and not workspace.document_path.is_empty():
		workspace.save_document(workspace.document_path)

func _exit_tree() -> void:
	if is_instance_valid(workspace):
		workspace.stop_preview()
		workspace.queue_free()

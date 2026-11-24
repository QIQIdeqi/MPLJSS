@tool
extends EditorPlugin

const Workspace = preload("res://addons/story_editor/workspace.gd")
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
	return "剧情"

func _make_visible(value: bool) -> void:
	if is_instance_valid(workspace):
		workspace.visible = value
		if not value:
			workspace.book_workspace.stop_preview()

func _get_unsaved_status(_for_scene: String) -> String:
	if is_instance_valid(workspace) and workspace.has_unsaved_changes():
		return "剧情配置或内嵌绘本有未保存修改，请回剧情页签保存。"
	return ""

func _save_external_data() -> void:
	if is_instance_valid(workspace):
		workspace.save_existing_documents()

func _exit_tree() -> void:
	if is_instance_valid(workspace):
		workspace.book_workspace.stop_preview()
		workspace.queue_free()

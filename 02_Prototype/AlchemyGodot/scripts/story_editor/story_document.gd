@tool
extends Resource

const StoryNode = preload("res://scripts/story_editor/story_node.gd")
const Book = preload("res://scripts/picture_book/book.gd")

@export var title: String = "未命名剧情"
@export var nodes: Array[Resource] = []

func find_node(node_id: String) -> Resource:
	for item: Resource in nodes:
		if item is StoryNode and item.node_id == node_id:
			return item
	return null

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var ids: Dictionary = {}
	for i: int in range(nodes.size()):
		var item: Resource = nodes[i]
		var prefix := "节点 %d：" % (i + 1)
		if not item is StoryNode:
			errors.append(prefix + "不是有效的剧情节点。")
			continue
		if not item.node_id.begins_with("story_") or item.node_id.length() <= 6 or not item.node_id.is_valid_identifier():
			errors.append(prefix + "稳定 ID 必须以 story_ 开头。")
		elif ids.has(item.node_id):
			errors.append(prefix + "稳定 ID 重复。")
		ids[item.node_id] = true
		if item.title.strip_edges().is_empty():
			errors.append(prefix + "名称不能为空。")
		if item.condition_enabled and item.completed_level_id.strip_edges().is_empty():
			errors.append(prefix + "completed_level 条件需要稳定关卡 ID。")
		for field: String in ["before_book_path", "after_book_path"]:
			var path: String = item.get(field)
			if path.is_empty():
				continue
			if not path.begins_with("res://") or path.get_extension() != "tres" or not ResourceLoader.exists(path):
				errors.append(prefix + "绘本引用必须为存在的项目内 .tres。")
				continue
			var resource: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
			if resource == null or resource.get_script() != Book:
				errors.append(prefix + "引用不是绘本资源。")
			elif not resource.validate().is_empty():
				errors.append(prefix + "引用的绘本校验失败。")
	return errors

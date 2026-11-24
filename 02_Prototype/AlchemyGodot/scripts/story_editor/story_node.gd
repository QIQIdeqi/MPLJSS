@tool
extends Resource
## Configuration only. This resource does not execute conditions or events.

@export var node_id: String = ""
@export var title: String = "新剧情节点"
@export var condition_enabled: bool = false
@export var completed_level_id: String = ""
@export_file("*.tres") var before_book_path: String = ""
@export_file("*.tres") var after_book_path: String = ""
@export var arrival_events: Array[Dictionary] = []

static func create_id() -> String:
	return "story_" + Crypto.new().generate_random_bytes(8).hex_encode()

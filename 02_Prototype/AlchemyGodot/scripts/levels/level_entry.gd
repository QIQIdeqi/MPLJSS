@tool
class_name LevelEntry
extends Resource
## A stable ID is independent of row order, display name and scene filename.

enum Kind { VILLAGE, NORMAL, BOSS }

@export var level_id: StringName
@export var display_name := "新关卡"
@export var kind := Kind.NORMAL
@export_file("*.tscn") var scene_path := ""
@export var enabled := true
@export var selectable := false
@export var sort_order := 0
@export_multiline var description := ""
@export var preview: Texture2D
@export var boss_level_id: StringName
@export var layout: Resource
@export var enemy_config: Resource
@export var spawn_position := Vector2(640, 430)
@export_group("Boss 玩法")
@export_enum("冲锋与扇射", "织网与落网", "孢子分区", "俯冲与转向", "冲锋与分区落击") var boss_style := 0
@export var boss_name := "腐化之源"

func validation_error() -> String:
	if String(level_id).strip_edges().is_empty():
		return "关卡 ID 不能为空"
	if display_name.strip_edges().is_empty():
		return "%s 缺少显示名称" % level_id
	if kind < Kind.VILLAGE or kind > Kind.BOSS:
		return "%s 的关卡类型无效" % level_id
	if not scene_path.begins_with("res://") or not ResourceLoader.exists(scene_path, "PackedScene"):
		return "%s 缺少有效的场景文件" % level_id
	if selectable and kind != Kind.NORMAL:
		return "%s：只有普通战斗可从村庄出战，Boss 保留局内自愿挑战" % level_id
	if kind == Kind.BOSS and (boss_style < 0 or boss_style > 4 or boss_name.strip_edges().is_empty()):
		return "%s 缺少有效的 Boss 名称或玩法" % level_id
	if kind != Kind.VILLAGE:
		if layout == null or not layout.has_method("playable_bounds"):
			return "%s 缺少地块与物件随机配置" % level_id
		if bool(layout.get("boss")) != (kind == Kind.BOSS):
			return "%s 的随机配置类型与关卡类型不一致" % level_id
		if kind == Kind.BOSS and bool(layout.get("infinite")):
			return "%s：Boss 使用独立有限竞技场，请关闭无限地图" % level_id
		if not layout.playable_bounds().has_point(spawn_position):
			return "%s 的出生点不在可行走区域内" % level_id
		if enemy_config == null or not enemy_config.has_method("validation_error"):
			return "%s 缺少怪物波次表" % level_id
		var wave_error: String = enemy_config.validation_error()
		if not wave_error.is_empty():
			return "%s：%s" % [level_id, wave_error]
	return ""

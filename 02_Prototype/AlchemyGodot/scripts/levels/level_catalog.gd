@tool
class_name LevelCatalog
extends Resource

const Entry = preload("res://scripts/levels/level_entry.gd")
@export var entries: Array[Entry] = []

func find_level(id: StringName) -> Entry:
	for entry in entries:
		if entry != null and entry.level_id == id:
			return entry
	return null

func selectable_levels() -> Array[Entry]:
	var result: Array[Entry] = []
	for entry in entries:
		if entry != null and entry.enabled and entry.selectable and entry.kind == Entry.Kind.NORMAL:
			result.append(entry)
	result.sort_custom(func(a: Entry, b: Entry) -> bool:
		return a.sort_order < b.sort_order if a.sort_order != b.sort_order else String(a.level_id) < String(b.level_id))
	return result

func duplicate_battle_configs(source: Entry, is_boss: bool, title: String) -> Dictionary:
	if source == null or source.layout == null or source.enemy_config == null:
		return {}
	var layout := source.layout.duplicate(true)
	layout.boss = is_boss
	if is_boss:
		layout.infinite = false
	layout.locked_ground = {}
	layout.locked_props = {}
	var waves := source.enemy_config.duplicate(true)
	waves.level_name = title
	if is_boss:
		waves.opening_count = 0
	return {"layout": layout, "waves": waves}

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var ids := {}
	var scenes := {}
	for entry in entries:
		if entry == null:
			errors.append("总表存在空白行")
			continue
		var problem := entry.validation_error()
		if not problem.is_empty():
			errors.append(problem)
		if ids.has(entry.level_id):
			errors.append("关卡 ID 重复：%s" % entry.level_id)
		ids[entry.level_id] = true
		if scenes.has(entry.scene_path):
			errors.append("%s 与 %s 共用场景文件，请为每关创建独立 .tscn" % [entry.level_id, scenes[entry.scene_path]])
		scenes[entry.scene_path] = entry.level_id
	for entry in entries:
		if entry == null or entry.boss_level_id.is_empty():
			continue
		var boss := find_level(entry.boss_level_id)
		if entry.kind != Entry.Kind.NORMAL or boss == null or boss.kind != Entry.Kind.BOSS:
			errors.append("%s 的 Boss ID 必须指向 Boss 类型关卡" % entry.level_id)
		elif entry.enabled and not boss.enabled:
			errors.append("%s 关联的 Boss 关卡尚未启用" % entry.level_id)
	if selectable_levels().is_empty():
		errors.append("至少需要一个启用且可从村庄出战的普通关卡")
	return errors

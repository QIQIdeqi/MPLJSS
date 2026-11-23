class_name SkillRuntime
extends RefCounted

const SKILLS := preload("res://data/skills/skill_data.gd")

var skill_id: StringName
var base: Dictionary = {}
var config: Dictionary = {}
var cooldown_left := 0.0
var level := 1

func setup(p_skill_id: StringName, _ability_id: StringName = &"", _upgrades: Array = []) -> void:
	skill_id = p_skill_id
	base = SKILLS.by_id(skill_id)
	config = base.duplicate(true)

func value(key: String, fallback = null) -> Variant:
	var source: Variant = config.get(key, fallback)
	if source is Array:
		if source.is_empty():
			return fallback
		return source[clampi(level - 1, 0, source.size() - 1)]
	return source

func damage() -> float:
	return float(config.get("base_damage", 0.0)) * float(value("power", 1.0))

func cooldown() -> float:
	return float(value("cooldowns", 1.0))

func range_px() -> float:
	return float(value("range_units", 6.0)) * SKILLS.UNIT

func radius_px() -> float:
	return float(value("radius_units", 0.0)) * SKILLS.UNIT

func tick(delta: float) -> void:
	cooldown_left = maxf(0.0, cooldown_left - delta)

func ready() -> bool:
	return cooldown_left <= 0.0

func reset_cooldown() -> void:
	cooldown_left = cooldown()

func behavior() -> StringName:
	return StringName(config.get("behavior", SKILLS.BEHAVIOR_BOTTLE))

func element() -> StringName:
	return SKILLS.ELEMENT_NONE

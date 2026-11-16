class_name SkillRuntime
extends RefCounted
# 技能运行时（策划案第9章）
# 运行时配置与静态 Resource 分离：SkillRuntime 持有本局合并后的配置，
# 由 SkillData（基础）+ 能力改造 + 升级结果合成，不污染原始数据。

const SKILLS := preload("res://data/skills/skill_data.gd")
const ABILITIES := preload("res://data/alchemy_abilities/alchemy_ability_data.gd")
const SYNERGIES := preload("res://data/synergies/synergy_data.gd")

var skill_id: StringName
var base: Dictionary = {}          # 基础技能数据（只读引用）
var config: Dictionary = {}        # 本局合并后的运行时配置
var ability_id: StringName = &""   # 本局能力
var ability: Dictionary = {}       # 能力数据
var upgrades: Array = []           # 本局已应用的升级

var cooldown_left := 0.0
var level := 1


func setup(p_skill_id: StringName, p_ability_id: StringName, p_upgrades: Array) -> void:
	skill_id = p_skill_id
	ability_id = p_ability_id
	upgrades = p_upgrades
	base = SKILLS.by_id(skill_id)
	ability = ABILITIES.by_id(ability_id) if ability_id != ABILITIES.ABILITY_INITIAL else {}
	config = base.duplicate(true) if not base.is_empty() else {}
	# 初始能力不施加改造，普通技能按基础机制运行。
	apply_upgrade_config()

func apply_upgrade_config() -> void:
	for up in upgrades:
		if up.get("target_skill_id", &"") == skill_id:
			for key in up.get("effect_params", {}):
				config[key] = up.effect_params[key]

# 是否深度改造（能力对该技能的改造深度）
func is_deep() -> bool:
	if ability.is_empty():
		return false
	return (ability.get("deep_skills", []) as Array).has(skill_id)

func effect_type() -> StringName:
	return ability.get("effect_type", &"") if not ability.is_empty() else &""

func param(key: String, fallback) -> Variant:
	var params: Dictionary = ability.get("param_keys", {})
	return params.get(key, config.get(key, fallback))

# 伤害（已含等级成长，简单线性）
func damage() -> float:
	var d: float = config.get("damage", 0.0)
	d *= 1.0 + 0.12 * (level - 1)
	return d

func cooldown() -> float:
	return config.get("cooldown", 1.0)

func tick(delta: float) -> void:
	cooldown_left = maxf(0.0, cooldown_left - delta)

func ready() -> bool:
	return cooldown_left <= 0.0

func reset_cooldown() -> void:
	cooldown_left = cooldown()

func element() -> StringName:
	return config.get("element", SKILLS.ELEMENT_NONE)

func behavior() -> StringName:
	return config.get("behavior", SKILLS.BEHAVIOR_PROJECTILE)

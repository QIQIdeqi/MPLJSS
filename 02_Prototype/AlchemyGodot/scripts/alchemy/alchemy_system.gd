extends Node
# 新炼金能力与技能联动系统总集成（策划案第9章架构的运行时入口）
# 统一管理：技能、元素联动、升级三选一、能力库存。挂在 battle/village 场景。

signal upgrade_offered(candidates: Array)
signal ability_selected(ability_id: StringName)

const SKILLS := preload("res://data/skills/skill_data.gd")
const ABILITIES := preload("res://data/alchemy_abilities/alchemy_ability_data.gd")

# 可视化可调参数（@export，挂在本节点 Inspector 可直接调）
@export var max_skill_slots := 6                    # 技能槽位（策划案7.5）
@export var starting_skills: Array[String] = []  # V2：魔法弹为独立普攻，十技能从升级池获得。
@export var ability_id: String = ABILITIES.ABILITY_INITIAL    # 本局能力
@export var debug_verbose := false                  # 调试日志

var field
var skills: SkillManager
var synergies: SynergyManager
var upgrades: UpgradeManager
var alchemy: AlchemyManager

var save: ConfigFile


func setup(p_field, p_save: ConfigFile) -> void:
	field = p_field
	save = p_save
	skills = SkillManager.new()
	skills.max_skill_slots = max_skill_slots
	skills.setup(ability_id, self)  # skills.field 指向本系统，用于联动回调
	synergies = SynergyManager.new()
	synergies.setup(field)
	upgrades = UpgradeManager.new()
	upgrades.setup(field, skills, ability_id)
	alchemy = AlchemyManager.new()
	alchemy.setup(save)
	# 开局送技能
	for sid in starting_skills:
		skills.add_skill(StringName(sid))
		upgrades.mark_owned(StringName(sid))

# 主循环：tick 技能、联动
func tick(delta: float, player_pos: Vector2, enemies: Array, apply_hit: Callable) -> void:
	skills.cast_equipped(delta, player_pos, enemies, apply_hit)
	synergies.tick(delta)

# 元素联动回调（由 SkillManager 触发）
func on_synergy_trigger(skill_id: StringName, element: StringName, at: Vector2, radius: float, ctx) -> void:
	var syn := synergies.check(element, at, radius, ctx)
	if syn.is_empty():
		return
	if debug_verbose:
		print("[Alchemy] 联动触发：", syn.name)
	if field.has_method("on_synergy_effect"):
		field.on_synergy_effect(syn, at)

# 区域类技能释放时登记元素区域
func register_region(skill_id: StringName, element: StringName, at: Vector2, radius: float, duration: float) -> void:
	synergies.add_region(element, at, radius, duration, skill_id)

# 技能特效转发（SkillManager 回调 → field 层渲染）
func play_skill_fx(info: Dictionary) -> void:
	if field != null and field.has_method("play_skill_fx"):
		field.play_skill_fx(info)

# 升级三选一
func roll_upgrades() -> Array:
	return upgrades.roll_candidates()

func apply_upgrade(pick: Dictionary) -> void:
	upgrades.apply(pick)

func clear_run() -> void:
	skills.clear()
	synergies.clear()
	upgrades.clear()

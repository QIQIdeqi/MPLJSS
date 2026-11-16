class_name UpgradeManager
extends RefCounted
# 局内升级三选一（策划案第7章）
# 候选池生成：新技能 / 普通技能强化 / 炼金改造强化 / 元素联动强化。

const SKILLS := preload("res://data/skills/skill_data.gd")
const ABILITIES := preload("res://data/alchemy_abilities/alchemy_ability_data.gd")
const SYNERGIES := preload("res://data/synergies/synergy_data.gd")

var field
var skill_manager  # SkillManager 实例
var ability_id: StringName = ABILITIES.ABILITY_INITIAL
var rng := RandomNumberGenerator.new()

# 候选类别
const CAT_NEW_SKILL := "new_skill"
const CAT_SKILL_UPGRADE := "skill_upgrade"
const CAT_ABILITY_UPGRADE := "ability_upgrade"
const CAT_SYNERGY_UPGRADE := "synergy_upgrade"

# 每技能等级上限
const MAX_SKILL_LEVEL := 5

var owned_levels: Dictionary = {}  # skill_id → level


func setup(p_field, p_skill_manager, p_ability_id: StringName) -> void:
	field = p_field
	skill_manager = p_skill_manager
	ability_id = p_ability_id
	rng.randomize()

func clear() -> void:
	owned_levels.clear()

func mark_owned(skill_id: StringName) -> void:
	if not owned_levels.has(skill_id):
		owned_levels[skill_id] = 1

# 生成三选一候选
func roll_candidates() -> Array:
	var pool := _build_pool()
	if pool.is_empty():
		return []
	var picks: Array = []
	var used: Array = []
	for i in mini(3, pool.size()):
		var idx := _weighted_pick(pool, used)
		if idx < 0:
			break
		used.append(idx)
		picks.append(pool[idx])
	return picks

func _weighted_pick(pool: Array, used: Array) -> int:
	var total := 0.0
	for i in pool.size():
		if not used.has(i):
			total += float(pool[i].get("weight", 1.0))
	if total <= 0.0:
		return -1
	var roll := rng.randf() * total
	for i in pool.size():
		if used.has(i):
			continue
		roll -= float(pool[i].get("weight", 1.0))
		if roll <= 0.0:
			return i
	return -1

func _build_pool() -> Array:
	var pool: Array = []
	# 1. 新技能：尚未拥有且未达槽位上限
	for s in SKILLS.ROWS:
		if not skill_manager.has_skill(s.id) and skill_manager.runtimes.size() < skill_manager.max_skill_slots:
			pool.append({"type": CAT_NEW_SKILL, "skill_id": s.id, "weight": 1.0,
				"label": "获得技能「%s」" % s.name, "desc": _skill_desc(s)})
	# 2. 普通技能强化：已拥有且未达等级上限
	for rt in skill_manager.runtimes:
		var lv := int(owned_levels.get(rt.skill_id, 1))
		if lv < MAX_SKILL_LEVEL:
			pool.append({"type": CAT_SKILL_UPGRADE, "skill_id": rt.skill_id, "weight": 1.0,
				"label": "强化「%s」 Lv.%d→%d" % [rt.base.name, lv, lv + 1],
				"desc": "伤害 +12%，冷却 −4%"})
	# 3. 炼金改造强化：当前携带非初始能力
	if ability_id != ABILITIES.ABILITY_INITIAL:
		var ab := ABILITIES.by_id(ability_id)
		if not ab.is_empty():
			pool.append({"type": CAT_ABILITY_UPGRADE, "ability_id": ability_id, "weight": 0.8,
				"label": "强化「%s」" % ab.name, "desc": ab.desc})
	# 4. 元素联动强化：已拥有联动所需元素技能
	var owned_elements: Array = []
	for rt in skill_manager.runtimes:
		var el: StringName = rt.element()
		if el != SKILLS.ELEMENT_NONE and not owned_elements.has(el):
			owned_elements.append(el)
	for syn in SYNERGIES.SYNERGIES:
		if owned_elements.has(syn.element_a) and owned_elements.has(syn.element_b):
			pool.append({"type": CAT_SYNERGY_UPGRADE, "synergy_id": syn.id, "weight": 0.7,
				"label": "联动「%s」强化" % syn.name, "desc": "范围 +20%，伤害 +15%"})
	return pool

func apply(pick: Dictionary) -> void:
	match pick.get("type", ""):
		CAT_NEW_SKILL:
			skill_manager.add_skill(pick.skill_id)
			mark_owned(pick.skill_id)
		CAT_SKILL_UPGRADE:
			owned_levels[pick.skill_id] = int(owned_levels.get(pick.skill_id, 1)) + 1
			for rt in skill_manager.runtimes:
				if rt.skill_id == pick.skill_id:
					rt.level = int(owned_levels[pick.skill_id])
					# 伤害/冷却成长
					rt.config["damage"] = float(rt.base.damage) * (1.0 + 0.12 * (rt.level - 1))
					rt.config["cooldown"] = float(rt.base.cooldown) * maxf(0.6, 1.0 - 0.04 * (rt.level - 1))
		CAT_ABILITY_UPGRADE:
			# 能力强化：提高能力参数（占位，后续细化）
			if skill_manager.has_method("upgrade_ability"):
				skill_manager.upgrade_ability()
		CAT_SYNERGY_UPGRADE:
			# 联动强化（占位，后续细化）
			pass

func _skill_desc(s: Dictionary) -> String:
	var el_name: String = _element_name(s.element)
	return "%s · %s元素 · 冷却 %.1fs" % [_behavior_name(s.behavior), el_name, s.cooldown]

func _element_name(el: StringName) -> String:
	match el:
		SKILLS.ELEMENT_FIRE: return "火"
		SKILLS.ELEMENT_ICE: return "冰"
		SKILLS.ELEMENT_THUNDER: return "雷"
		SKILLS.ELEMENT_WIND: return "风"
		SKILLS.ELEMENT_POISON: return "毒"
		_: return "无"

func _behavior_name(b: StringName) -> String:
	match b:
		SKILLS.BEHAVIOR_PROJECTILE: return "投射"
		SKILLS.BEHAVIOR_BLAST: return "爆裂"
		SKILLS.BEHAVIOR_LINE: return "直线"
		SKILLS.BEHAVIOR_INSTANT: return "瞬间"
		SKILLS.BEHAVIOR_BOOMERANG: return "往返"
		SKILLS.BEHAVIOR_ORBIT: return "环绕"
		SKILLS.BEHAVIOR_ZONE: return "区域"
		SKILLS.BEHAVIOR_AOE: return "区域打击"
		SKILLS.BEHAVIOR_BEAM: return "射线"
		SKILLS.BEHAVIOR_SPIKE: return "突刺"
		_: return "?"

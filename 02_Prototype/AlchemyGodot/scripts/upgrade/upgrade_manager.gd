class_name UpgradeManager
extends RefCounted
# 局内升级三选一（策划案第7章）
# 候选只包含基础技能的获取与强化。

const SKILLS := preload("res://data/skills/skill_data.gd")
var skill_manager: SkillManager
var rng := RandomNumberGenerator.new()

# 候选类别
const CAT_NEW_SKILL := "new_skill"
const CAT_SKILL_UPGRADE := "skill_upgrade"

# 每技能等级上限
const MAX_SKILL_LEVEL := 5

func setup(skills: SkillManager) -> void:
	skill_manager = skills
	rng.randomize()

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
	if skill_manager.runtimes.size() < skill_manager.max_skill_slots:
		for s: Dictionary in SKILLS.ROWS:
			if not skill_manager.has_skill(StringName(s.id)):
				pool.append({"type": CAT_NEW_SKILL, "skill_id": s.id, "weight": 1.0,
					"label": "获得技能「%s」" % s.name, "desc": _new_skill_desc(s)})
	for rt in skill_manager.runtimes:
		var lv := rt.level
		if lv < MAX_SKILL_LEVEL:
			pool.append({"type": CAT_SKILL_UPGRADE, "skill_id": rt.skill_id, "weight": 1.0,
				"label": "强化「%s」 Lv.%d→%d" % [rt.base.name, lv, lv + 1],
				"desc": "伤害 +12%，冷却 −4%"})
	return pool

func apply(pick: Dictionary) -> void:
	var skill_id := StringName(pick.get("skill_id", ""))
	match pick.get("type", ""):
		CAT_NEW_SKILL:
			skill_manager.add_skill(skill_id)
		CAT_SKILL_UPGRADE:
			var runtime := skill_manager.runtime_for(skill_id)
			if runtime != null and runtime.level < MAX_SKILL_LEVEL:
				runtime.level += 1

func _new_skill_desc(skill: Dictionary) -> String:
	var description := "%s · 冷却 %.1fs" % [_behavior_name(skill.behavior), float(skill.cooldowns[0])]
	for chain: Dictionary in SKILLS.CHAINS:
		var pair_index: int = chain.parents.find(skill.id)
		if pair_index >= 0 and skill_manager.has_skill(StringName(chain.parents[1 - pair_index])):
			return description + "\n自动解锁组合「%s」" % chain.name
	return description

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
		SKILLS.BEHAVIOR_BOTTLE: return "预判投瓶"
		SKILLS.BEHAVIOR_SUMMON: return "召唤追击"
		SKILLS.BEHAVIOR_BOUNCE: return "弹射命中"
		SKILLS.BEHAVIOR_PULL: return "落点牵引"
		SKILLS.BEHAVIOR_POOL: return "腐蚀区域"
		SKILLS.BEHAVIOR_MIST: return "减速迷雾"
		SKILLS.BEHAVIOR_CRYSTAL: return "地面晶簇"
		SKILLS.BEHAVIOR_BLADE: return "穿透飞刃"
		SKILLS.BEHAVIOR_GEL: return "追踪附着"
		SKILLS.BEHAVIOR_NEEDLE: return "高速针群"
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

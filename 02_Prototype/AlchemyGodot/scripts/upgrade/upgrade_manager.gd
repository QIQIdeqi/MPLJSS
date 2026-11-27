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
const EXPANSION_UPGRADE_STATS := {
	SKILLS.BEHAVIOR_MARK: ["vulnerability", "脆弱增伤", 100.0, "%"],
	SKILLS.BEHAVIOR_THUNDER_SALT: ["power", "基础伤害", 1.0, ""],
	SKILLS.BEHAVIOR_FIRE_OIL: ["power", "每跳伤害", 1.0, ""],
	SKILLS.BEHAVIOR_MERCURY_RING: ["power", "每环伤害", 1.0, ""],
	SKILLS.BEHAVIOR_FROST_POWDER: ["duration", "冻结", 1.0, " 秒"],
	SKILLS.BEHAVIOR_WIND_FLASK: ["push_units", "推距", SKILLS.UNIT, " 像素"],
	SKILLS.BEHAVIOR_FEATHER_DRAUGHT: ["speed_bonus", "跑速提升", 100.0, "%"],
	SKILLS.BEHAVIOR_WIND_BOOTS: ["dodge_bonus", "闪避距离提升", 100.0, "%"],
	SKILLS.BEHAVIOR_RETURN_WIND_POWDER: ["window", "追加闪避窗口", 1.0, " 秒"],
	SKILLS.BEHAVIOR_RENEWAL_FLASK: ["heal", "每跳回复", 1.0, ""],
	SKILLS.BEHAVIOR_DEW_TONIC: ["heal", "每次回复", 1.0, ""],
}

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
					"label": "获得技能「%s」" % s.name, "desc": _new_skill_desc(s),
					"attribute": s.attribute, "category": _category(s)})
	for rt in skill_manager.runtimes:
		var lv := rt.level
		if lv < MAX_SKILL_LEVEL:
			pool.append({"type": CAT_SKILL_UPGRADE, "skill_id": rt.skill_id, "weight": 1.0,
				"label": "强化「%s」 Lv.%d→%d" % [rt.base.name, lv, lv + 1],
				"attribute": rt.base.attribute,
				"desc": _upgrade_desc(rt.base, lv + 1), "category": _category(rt.base)})
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
	var effect := String(skill.get("description", ""))
	if effect.is_empty():
		effect = _behavior_name(skill.behavior)
	var description := "%s\n冷却 %.1f 秒" % [effect, float(skill.cooldowns[0])]
	for chain: Dictionary in SKILLS.CHAINS:
		var pair_index: int = chain.parents.find(skill.id)
		if pair_index >= 0 and skill_manager.has_skill(StringName(chain.parents[1 - pair_index])):
			return description + "\n自动解锁组合「%s」" % chain.name
	return description

func _upgrade_desc(skill: Dictionary, level: int) -> String:
	var stat: Array = EXPANSION_UPGRADE_STATS.get(StringName(skill.behavior), [])
	if stat.is_empty():
		return "伤害 +12%，冷却 −4%"
	var values: Array = skill[stat[0]]
	var before := _format_upgrade_stat(float(values[level - 2]) * float(stat[2]))
	var after := _format_upgrade_stat(float(values[level - 1]) * float(stat[2]))
	var cooldowns: Array = skill.cooldowns
	return "%s %s→%s%s\n升级后冷却 %.1f 秒" % [stat[1], before, after, stat[3], float(cooldowns[level - 1])]

func _format_upgrade_stat(value: float) -> String:
	return ("%.2f" % value).rstrip("0").trim_suffix(".")

func _category(skill: Dictionary) -> String:
	if skill.has("category"):
		return String(skill.category)
	match StringName(skill.behavior):
		SKILLS.BEHAVIOR_PULL, SKILLS.BEHAVIOR_MIST, SKILLS.BEHAVIOR_GEL:
			return "控制"
		_:
			return "进攻"

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
		SKILLS.BEHAVIOR_MARK: return "投瓶落地后对范围内的敌人施加脆弱"
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

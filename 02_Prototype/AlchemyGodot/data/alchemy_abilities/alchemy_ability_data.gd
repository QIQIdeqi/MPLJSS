extends RefCounted
# 六种炼金能力 + 初始能力（策划案第3章）
# 能力决定普通技能如何被改造（"职业规则"），是局外制作的一次性消耗品。
# 数据驱动：每种能力 = 一组 transformation_rules，作用于全部十种技能。

# 能力 id 常量
const ABILITY_INITIAL := "initial"    # 初始能力（永久可用，不施加改造）
const ABILITY_BURST := "burst"        # 爆裂炼金
const ABILITY_BOUNCE := "bounce"      # 弹射炼金
const ABILITY_PIERCE := "pierce"      # 穿透炼金
const ABILITY_SPLIT := "split"        # 分裂炼金
const ABILITY_HOMING := "homing"      # 追踪炼金
const ABILITY_ECHO := "echo"          # 回响炼金

# 改造效果类型（effect_type）
const EFFECT_BURST := "burst"         # 范围爆发
const EFFECT_BOUNCE := "bounce"       # 弹射转移
const EFFECT_PIERCE := "pierce"       # 贯穿
const EFFECT_SPLIT := "split"         # 分裂子攻击
const EFFECT_HOMING := "homing"       # 追踪转向
const EFFECT_ECHO := "echo"           # 延迟复现

# 六种能力（不含初始）。字段：
# id / name / desc（说明）/ 全局上限字段
const ABILITIES := [
	{
		"id": ABILITY_BURST, "name": "爆裂炼金",
		"desc": "攻击命中、结束或满足条件时产生范围爆发",
		"effect_type": EFFECT_BURST,
		"deep_skills": ["magic_bolt", "fireball", "ice_spike", "poison_fog", "rockfall"],  # 深度改造
		"param_keys": {"radius": 70.0, "damage_ratio": 0.5, "trigger_count": 3, "shockwave": false},
	},
	{
		"id": ABILITY_BOUNCE, "name": "弹射炼金",
		"desc": "攻击命中后将攻击效果转移至其他目标",
		"effect_type": EFFECT_BOUNCE,
		"deep_skills": ["magic_bolt", "fireball", "ice_spike", "thunder", "rockfall"],
		"param_keys": {"count": 2, "search_range": 180.0, "decay": 0.8, "filter": "unhit"},
	},
	{
		"id": ABILITY_PIERCE, "name": "穿透炼金",
		"desc": "攻击不因首次命中而终止，可继续影响路径上的目标",
		"effect_type": EFFECT_PIERCE,
		"deep_skills": ["magic_bolt", "fireball", "ice_spike", "wind_blade", "poison_fog", "beam", "earth_spike"],
		"param_keys": {"count": 3, "width": 30.0, "decay": 0.9},
	},
	{
		"id": ABILITY_SPLIT, "name": "分裂炼金",
		"desc": "攻击在命中或结束后生成多个子攻击",
		"effect_type": EFFECT_SPLIT,
		"deep_skills": ["magic_bolt", "fireball", "ice_spike", "cyclone", "poison_fog", "beam"],
		"param_keys": {"count": 3, "damage_ratio": 0.45, "spread": 0.7, "depth": 1},
	},
	{
		"id": ABILITY_HOMING, "name": "追踪炼金",
		"desc": "攻击自动修正方向或位置，持续追踪有效目标",
		"effect_type": EFFECT_HOMING,
		"deep_skills": ["magic_bolt", "fireball", "wind_blade", "cyclone", "poison_fog", "beam"],
		"param_keys": {"turn_rate": 6.0, "lock_range": 260.0, "relock": 2, "max_offset": 80.0},
	},
	{
		"id": ABILITY_ECHO, "name": "回响炼金",
		"desc": "攻击结束后延迟复现一次或多次攻击行为",
		"effect_type": EFFECT_ECHO,
		"deep_skills": ["magic_bolt", "fireball", "thunder", "cyclone", "poison_fog", "beam"],
		"param_keys": {"count": 1, "interval": 0.35, "damage_ratio": 0.6},
	},
]

static func by_id(id: String) -> Dictionary:
	for ab in ABILITIES:
		if ab.id == id:
			return ab
	return {}

static func ids() -> Array[String]:
	var result: Array[String] = []
	for ab in ABILITIES:
		result.append(ab.id)
	return result

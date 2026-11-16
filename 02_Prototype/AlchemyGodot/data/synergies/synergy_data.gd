extends RefCounted
# 元素系统与技能联动（策划案第6章）
# 联动由玩家技能之间触发，不依赖怪物弱点。第一阶段做四种联动。

const SYNERGY_FIRE_POISON := "fire_poison"    # 毒气爆燃：火+毒
const SYNERGY_FIRE_WIND := "fire_wind"        # 火焰风暴：火+风
const SYNERGY_ICE_THUNDER := "ice_thunder"    # 冰晶雷暴：冰+雷
const SYNERGY_ICE_POISON := "ice_poison"      # 冰封毒雾：冰+毒

const SYNERGIES := [
	{
		"id": SYNERGY_FIRE_POISON, "name": "毒气爆燃",
		"element_a": "fire", "element_b": "poison",
		"trigger": "区域相交",  # 火球爆炸范围与毒雾区域相交
		"consume_a": false, "consume_b": true,  # 毒雾被消耗
		"damage": 20.0, "radius": 110.0, "cooldown": 1.5, "max_trigger": 2,
		"color": Color(1.00, 0.55, 0.15),
	},
	{
		"id": SYNERGY_FIRE_WIND, "name": "火焰风暴",
		"element_a": "fire", "element_b": "wind",
		"trigger": "风系攻击进入火焰区域",
		"consume_a": false, "consume_b": false,  # 风系攻击获得短时火焰效果
		"damage": 12.0, "radius": 120.0, "cooldown": 1.0, "max_trigger": 3,
		"color": Color(1.00, 0.45, 0.08),
	},
	{
		"id": SYNERGY_ICE_THUNDER, "name": "冰晶雷暴",
		"element_a": "ice", "element_b": "thunder",
		"trigger": "雷击命中冰晶区域",
		"consume_a": false, "consume_b": false,  # 冰晶释放电流
		"damage": 24.0, "radius": 100.0, "cooldown": 1.2, "max_trigger": 3,
		"color": Color(0.55, 0.75, 1.00),
	},
	{
		"id": SYNERGY_ICE_POISON, "name": "冰封毒雾",
		"element_a": "ice", "element_b": "poison",
		"trigger": "冰锥攻击进入毒雾区域",
		"consume_a": false, "consume_b": true,  # 毒雾冻结为冰晶毒域
		"damage": 16.0, "radius": 100.0, "cooldown": 1.5, "max_trigger": 2,
		"color": Color(0.55, 0.90, 0.95),
	},
]

static func by_id(id: String) -> Dictionary:
	for s in SYNERGIES:
		if s.id == id:
			return s
	return {}

static func match_pair(a: StringName, b: StringName) -> Dictionary:
	for s in SYNERGIES:
		if (s.element_a == a and s.element_b == b) or (s.element_a == b and s.element_b == a):
			return s
	return {}

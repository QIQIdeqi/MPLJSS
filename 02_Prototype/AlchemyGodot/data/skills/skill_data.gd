extends RefCounted
# 技能数据定义（策划案第4章：十种普通技能）
# 全部数据驱动，字段可扩展；基础形态先独立成立，再叠加炼金能力改造。

# 元素标签常量
const ELEMENT_NONE := "none"
const ELEMENT_FIRE := "fire"
const ELEMENT_ICE := "ice"
const ELEMENT_THUNDER := "thunder"
const ELEMENT_WIND := "wind"
const ELEMENT_POISON := "poison"

# 基础行为类型
const BEHAVIOR_PROJECTILE := "projectile"   # 投射型（魔法弹）
const BEHAVIOR_BLAST := "blast"             # 爆裂型（火球）
const BEHAVIOR_LINE := "line"               # 直线型（冰锥）
const BEHAVIOR_INSTANT := "instant"         # 瞬间打击型（雷击）
const BEHAVIOR_BOOMERANG := "boomerang"     # 往返型（风刃）
const BEHAVIOR_ORBIT := "orbit"             # 环绕型（旋风）
const BEHAVIOR_ZONE := "zone"               # 区域持续型（毒雾）
const BEHAVIOR_AOE := "aoe"                 # 指定区域打击型（落石）
const BEHAVIOR_BEAM := "beam"               # 射线型（光束）
const BEHAVIOR_SPIKE := "spike"             # 地面突刺型（地刺）

# 十种普通技能。数值为「建议基准」，未冻结，可在 Inspector 或此处调整。
# 字段：id / name / behavior / element / damage / cooldown / range / radius /
#       duration / speed / targets / color
const ROWS := [
	{"id": "magic_bolt",   "name": "魔法弹", "behavior": BEHAVIOR_PROJECTILE, "element": ELEMENT_NONE,    "damage": 20.0, "cooldown": 1.0,  "range": 520.0, "radius": 0.0,   "duration": 0.0, "speed": 620.0, "targets": 1, "color": Color(0.65, 0.30, 1.00)},
	{"id": "fireball",     "name": "火球",   "behavior": BEHAVIOR_BLAST,      "element": ELEMENT_FIRE,    "damage": 26.0, "cooldown": 1.8,  "range": 480.0, "radius": 90.0,  "duration": 0.0, "speed": 520.0, "targets": 1, "color": Color(1.00, 0.25, 0.04)},
	{"id": "ice_spike",    "name": "冰锥",   "behavior": BEHAVIOR_LINE,       "element": ELEMENT_ICE,     "damage": 18.0, "cooldown": 1.6,  "range": 460.0, "radius": 0.0,   "duration": 0.0, "speed": 900.0, "targets": 1, "color": Color(0.15, 0.65, 1.00)},
	{"id": "thunder",      "name": "雷击",   "behavior": BEHAVIOR_INSTANT,    "element": ELEMENT_THUNDER, "damage": 30.0, "cooldown": 2.8,  "range": 480.0, "radius": 46.0,  "duration": 0.0, "speed": 0.0,   "targets": 1, "color": Color(0.98, 0.90, 0.20)},
	{"id": "wind_blade",   "name": "风刃",   "behavior": BEHAVIOR_BOOMERANG,  "element": ELEMENT_WIND,    "damage": 16.0, "cooldown": 1.4,  "range": 420.0, "radius": 0.0,   "duration": 0.0, "speed": 560.0, "targets": 1, "color": Color(0.40, 0.85, 0.62)},
	{"id": "cyclone",      "name": "旋风",   "behavior": BEHAVIOR_ORBIT,      "element": ELEMENT_WIND,    "damage": 14.0, "cooldown": 3.2,  "range": 110.0, "radius": 66.0,  "duration": 3.0, "speed": 0.0,   "targets": 1, "color": Color(0.45, 0.88, 0.66)},
	{"id": "poison_fog",   "name": "毒雾",   "behavior": BEHAVIOR_ZONE,       "element": ELEMENT_POISON,  "damage": 10.0, "cooldown": 3.8,  "range": 380.0, "radius": 90.0,  "duration": 3.0, "speed": 0.0,   "targets": 1, "color": Color(0.30, 1.00, 0.20)},
	{"id": "rockfall",     "name": "落石",   "behavior": BEHAVIOR_AOE,        "element": ELEMENT_NONE,    "damage": 34.0, "cooldown": 2.4,  "range": 420.0, "radius": 80.0,  "duration": 0.0, "speed": 0.0,   "targets": 1, "color": Color(0.60, 0.52, 0.42)},
	{"id": "beam",         "name": "光束",   "behavior": BEHAVIOR_BEAM,       "element": ELEMENT_NONE,    "damage": 22.0, "cooldown": 2.6,  "range": 480.0, "radius": 0.0,   "duration": 0.7, "speed": 0.0,   "targets": 1, "color": Color(0.85, 0.60, 1.00)},
	{"id": "earth_spike",  "name": "地刺",   "behavior": BEHAVIOR_SPIKE,      "element": ELEMENT_NONE,    "damage": 28.0, "cooldown": 2.2,  "range": 380.0, "radius": 44.0,  "duration": 0.0, "speed": 0.0,   "targets": 1, "color": Color(0.72, 0.62, 0.48)},
]

# 按 id 查询技能数据
static func by_id(id: String) -> Dictionary:
	for row in ROWS:
		if row.id == id:
			return row
	return {}

static func ids() -> Array[String]:
	var result: Array[String] = []
	for row in ROWS:
		result.append(row.id)
	return result

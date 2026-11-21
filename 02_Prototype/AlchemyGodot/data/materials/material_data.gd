extends RefCounted
# 素材静态定义（讨论版第6、11章 MaterialData）
# 首版素材为怪物掉落，用于局外炼金工房实验制作炼金能力。
# 字段：id / name / max_amount（单种上限，可配置，0 表示无上限）
# 讨论版扩充为 5 种素材，以支撑隐藏配方组合覆盖 6 种炼金能力 + 阶段投入上限。

# 素材 ID 常量
const MATERIAL_FIRE_POWDER := "fire_powder"    # 火粉
const MATERIAL_DEW := "dew"                    # 露水
const MATERIAL_MAGIC_SHARD := "magic_shard"    # 魔法碎片
const MATERIAL_WIND_CRYSTAL := "wind_crystal"  # 风晶
const MATERIAL_EARTH_CORE := "earth_core"      # 土髓

# 素材定义表（材料 ID 与显示名，后续可扩展）
const MATERIALS := [
	{"id": MATERIAL_FIRE_POWDER, "name": "火粉",     "max_amount": 10},
	{"id": MATERIAL_DEW,          "name": "露水",     "max_amount": 10},
	{"id": MATERIAL_MAGIC_SHARD,  "name": "魔法碎片", "max_amount": 10},
	{"id": MATERIAL_WIND_CRYSTAL, "name": "风晶",     "max_amount": 10},
	{"id": MATERIAL_EARTH_CORE,   "name": "土髓",     "max_amount": 10},
]

static func by_id(id: String) -> Dictionary:
	for m in MATERIALS:
		if m.id == id:
			return m
	return {}

static func ids() -> Array[String]:
	var result: Array[String] = []
	for m in MATERIALS:
		result.append(m.id)
	return result

static func name_of(id: String) -> String:
	var m := by_id(id)
	return m.get("name", String(id)) if not m.is_empty() else String(id)

extends RefCounted
# 素材静态定义（V1.1 第8.1节 MaterialData）
# 首版素材为怪物掉落，用于局外炼金工房制作炼金能力。
# 字段：id / name / icon（预留）/ max_amount（单种上限，可配置，0 表示无上限）

# 素材 ID 常量
const MATERIAL_FIRE_POWDER := "fire_powder"    # 火粉
const MATERIAL_DEW := "dew"                    # 露水
const MATERIAL_MAGIC_SHARD := "magic_shard"    # 魔法碎片

# 素材定义表（材料 ID 与显示名，后续可扩展）
const MATERIALS := [
	{"id": MATERIAL_FIRE_POWDER, "name": "火粉",   "max_amount": 0},
	{"id": MATERIAL_DEW,          "name": "露水",   "max_amount": 0},
	{"id": MATERIAL_MAGIC_SHARD,  "name": "魔法碎片", "max_amount": 0},
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

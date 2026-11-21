extends RefCounted
# 怪物掉落表（V1.1 第8.1节 DropTableData）
# 绑定 material_id，由数据表控制概率与数量，不硬编码在怪物脚本。
# 字段：enemy_id / entries（掉落条目）/ chance（概率）/ min_amount / max_amount

# 掉落条目：{"material_id": String, "chance": float(0~1), "min": int, "max": int}

# 普通怪物掉落：基础素材，稳定低量
const COMMON_DROPS := [
	{"material_id": "fire_powder",  "chance": 0.5, "min": 1, "max": 1},
	{"material_id": "dew",          "chance": 0.5, "min": 1, "max": 1},
	{"material_id": "magic_shard",  "chance": 0.2, "min": 1, "max": 1},
	{"material_id": "wind_crystal", "chance": 0.3, "min": 1, "max": 1},
	{"material_id": "earth_core",   "chance": 0.3, "min": 1, "max": 1},
]

# 精英怪物掉落：更高概率、更多数量（高于普通怪的额外素材收益）
const ELITE_DROPS := [
	{"material_id": "fire_powder",  "chance": 1.0, "min": 1, "max": 2},
	{"material_id": "dew",          "chance": 1.0, "min": 1, "max": 2},
	{"material_id": "magic_shard",  "chance": 0.6, "min": 1, "max": 2},
	{"material_id": "wind_crystal", "chance": 0.7, "min": 1, "max": 2},
	{"material_id": "earth_core",   "chance": 0.7, "min": 1, "max": 2},
]

# BOSS 掉落：固定、可预期的素材收益
const BOSS_DROPS := [
	{"material_id": "fire_powder",  "chance": 1.0, "min": 3, "max": 4},
	{"material_id": "dew",          "chance": 1.0, "min": 3, "max": 4},
	{"material_id": "magic_shard",  "chance": 1.0, "min": 2, "max": 3},
	{"material_id": "wind_crystal", "chance": 1.0, "min": 2, "max": 3},
	{"material_id": "earth_core",   "chance": 1.0, "min": 2, "max": 3},
]

# 按敌人类型取掉落表
static func for_enemy_type(enemy_type: String) -> Array:
	match enemy_type:
		"elite":
			return ELITE_DROPS
		"boss":
			return BOSS_DROPS
		_:
			return COMMON_DROPS

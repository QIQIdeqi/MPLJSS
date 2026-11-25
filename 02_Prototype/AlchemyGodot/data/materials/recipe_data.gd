extends RefCounted
# 炼金配方表（讨论版第7、11章 RecipeData）
# 隐藏配方：由策划预设，玩家通过实验发现；正确组合固定获得对应能力，不随机。
# 字段：recipe_id / ability_id（产出能力）/ inputs（材料ID集合，每种0/1份）/ tier（阶段）
# 匹配逻辑：无序组合，忽略顺序，每种材料最多1份。

const ABILITIES := preload("res://data/alchemy_abilities/alchemy_ability_data.gd")

# 阶段投入种类上限（讨论版第7章）
const TIER_EARLY := 2    # 前期：最多 2 种材料
const TIER_MID := 3      # 中期：最多 3 种材料
const TIER_LATE := 4     # 后期：最多 4 种材料

# 六种自制能力的配方（材料集合，无序，每种0/1份）
# inputs 用数组表示材料集合（顺序无关），匹配时规范化为无序集合。
const RECIPES := [
	{"recipe_id": "recipe_burst",  "ability_id": ABILITIES.ABILITY_BURST,  "tier": TIER_EARLY,
	 "inputs": ["fire_powder", "dew"]},
	{"recipe_id": "recipe_bounce", "ability_id": ABILITIES.ABILITY_BOUNCE, "tier": TIER_EARLY,
	 "inputs": ["wind_crystal", "dew"]},
	{"recipe_id": "recipe_pierce", "ability_id": ABILITIES.ABILITY_PIERCE, "tier": TIER_EARLY,
	 "inputs": ["earth_core", "magic_shard"]},
	{"recipe_id": "recipe_homing", "ability_id": ABILITIES.ABILITY_HOMING, "tier": TIER_MID,
	 "inputs": ["wind_crystal", "magic_shard", "dew"]},
	{"recipe_id": "recipe_split",  "ability_id": ABILITIES.ABILITY_SPLIT,  "tier": TIER_EARLY,
	 "inputs": ["fire_powder", "earth_core"], "legacy_inputs": ["fire_powder", "earth_core", "magic_shard"]},
	{"recipe_id": "recipe_echo",   "ability_id": ABILITIES.ABILITY_ECHO,   "tier": TIER_LATE,
	 "inputs": ["fire_powder", "dew", "wind_crystal", "earth_core"]},
]

# 将材料集合规范化为无序组合键（排序后拼接），忽略顺序、去重。
static func combo_key(materials: Array) -> String:
	var sorted := materials.duplicate()
	sorted.sort()
	var result := ""
	for m in sorted:
		if result != "":
			result += "+"
		result += String(m)
	return result

# 按无序材料组合匹配配方（忽略顺序，每种材料0/1份）
static func match(materials: Array) -> Dictionary:
	var key := combo_key(materials)
	for r in RECIPES:
		if combo_key(r.inputs) == key or (r.has("legacy_inputs") and combo_key(r.legacy_inputs) == key):
			return r
	return {}

# 按产出能力查配方（供图鉴/展示）
static func by_ability(ability_id: String) -> Dictionary:
	for r in RECIPES:
		if r.ability_id == ability_id:
			return r
	return {}

static func all() -> Array:
	return RECIPES

# 某材料组合的材料种类数
static func material_kind_count(materials: Array) -> int:
	var uniq := {}
	for m in materials:
		uniq[String(m)] = true
	return uniq.size()

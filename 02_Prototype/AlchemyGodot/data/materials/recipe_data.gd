extends RefCounted
# 炼金配方表（V1.1 第8.1节 RecipeData）
# 局外炼金工房用：素材 → 炼金能力。每条配方输入材料+数量，产出固定能力 ID。
# 字段：recipe_id / ability_id（产出能力）/ inputs（材料清单）/ is_unlocked

const ABILITIES := preload("res://data/alchemy_abilities/alchemy_ability_data.gd")
const MATERIALS := preload("res://data/materials/material_data.gd")

# 六种自制能力的配方。输入材料数量为占位基准（V1.1 第13.2节[待数据确认]）。
# inputs 格式：{"material_id": 数量, ...}
const RECIPES := [
	{"recipe_id": "recipe_burst",  "ability_id": ABILITIES.ABILITY_BURST,  "is_unlocked": true,
	 "inputs": {"fire_powder": 3, "dew": 1, "magic_shard": 1}},
	{"recipe_id": "recipe_bounce", "ability_id": ABILITIES.ABILITY_BOUNCE, "is_unlocked": true,
	 "inputs": {"fire_powder": 2, "dew": 2, "magic_shard": 1}},
	{"recipe_id": "recipe_pierce", "ability_id": ABILITIES.ABILITY_PIERCE, "is_unlocked": true,
	 "inputs": {"dew": 3, "magic_shard": 2}},
	{"recipe_id": "recipe_split",  "ability_id": ABILITIES.ABILITY_SPLIT,  "is_unlocked": true,
	 "inputs": {"fire_powder": 2, "magic_shard": 3}},
	{"recipe_id": "recipe_homing", "ability_id": ABILITIES.ABILITY_HOMING, "is_unlocked": true,
	 "inputs": {"fire_powder": 1, "dew": 2, "magic_shard": 2}},
	{"recipe_id": "recipe_echo",   "ability_id": ABILITIES.ABILITY_ECHO,   "is_unlocked": true,
	 "inputs": {"dew": 2, "magic_shard": 3}},
]

static func by_ability(ability_id: String) -> Dictionary:
	for r in RECIPES:
		if r.ability_id == ability_id:
			return r
	return {}

static func all() -> Array:
	return RECIPES

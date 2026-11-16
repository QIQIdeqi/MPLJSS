class_name AlchemyService
extends RefCounted
# 局外炼金服务（V1.1 第5.5、8.2节 AlchemyService）
# 负责炼金事务：校验配方、扣除素材、生成能力库存。UI 不得直接改库存。

signal alchemy_crafted(recipe_id: String, ability_id: String, new_count: int)

const RECIPES := preload("res://data/materials/recipe_data.gd")
const ABILITIES := preload("res://data/alchemy_abilities/alchemy_ability_data.gd")

var profile: ProfileStore
var crafting := false  # 按钮锁，防止快速连点重复发奖


func setup(p_profile: ProfileStore) -> void:
	profile = p_profile

# 炼制一份能力（V1.1 第8.6节 craft_recipe）
func craft_recipe(ability_id: String) -> bool:
	if crafting:
		return false
	var recipe := RECIPES.by_ability(ability_id)
	if recipe.is_empty():
		return false
	if not bool(recipe.get("is_unlocked", false)):
		return false
	var inputs: Dictionary = recipe.get("inputs", {})
	if inputs.is_empty():
		return false
	if ability_id == ABILITIES.ABILITY_INITIAL:
		return false
	crafting = true
	var committed := profile.commit_craft_transaction(inputs, ability_id, 1)
	if committed:
		profile.save_profile()
		alchemy_crafted.emit(String(recipe.get("recipe_id", "")), ability_id, profile.ability_count(ability_id))
	crafting = false
	return committed

# 查询某配方所需材料（供 UI 显示）
func recipe_inputs(ability_id: String) -> Dictionary:
	var recipe := RECIPES.by_ability(ability_id)
	return recipe.get("inputs", {}) if not recipe.is_empty() else {}

# 某配方当前缺料数量（material_id -> 缺少数量）
func missing_materials(ability_id: String) -> Dictionary:
	var missing := {}
	var inputs := recipe_inputs(ability_id)
	for id in inputs:
		var need := int(inputs[id])
		var have := profile.material_count(id)
		if have < need:
			missing[id] = need - have
	return missing

func can_craft(ability_id: String) -> bool:
	var recipe := RECIPES.by_ability(ability_id)
	if recipe.is_empty():
		return false
	if not bool(recipe.get("is_unlocked", false)):
		return false
	return profile.has_materials(recipe.get("inputs", {}))

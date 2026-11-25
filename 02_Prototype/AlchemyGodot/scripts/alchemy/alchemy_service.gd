class_name AlchemyService
extends RefCounted
# 局外炼金服务（讨论版第5、7、12章 AlchemyService）
# 隐藏配方实验：玩家提交材料组合，系统匹配预设配方，命中固定获得能力。
# 成功：扣料 + 生成能力 + 标记配方发现；失败：不扣料（全返还），标记失败状态。
# UI 不得直接改库存。

signal experiment_result(result: Dictionary)

const RECIPES := preload("res://data/materials/recipe_data.gd")
const ABILITIES := preload("res://data/alchemy_abilities/alchemy_ability_data.gd")

var profile: ProfileStore
var processing := false  # 状态锁，防止快速连点重复扣料/产出


func setup(p_profile: ProfileStore) -> void:
	profile = p_profile

# 实验：提交无序材料组合，返回结果字典。
# 返回 {"success": bool, "ability_id": String, "recipe_id": String, "error": String}
func experiment(materials: Array) -> Dictionary:
	if processing:
		return {"success": false, "ability_id": "", "recipe_id": "", "error": "正在炼制中"}
	# 去重（每种材料最多 1 份，禁止重复种类）
	var uniq: Array = []
	var seen := {}
	for m in materials:
		var mid := String(m)
		if seen.has(mid):
			return {"success": false, "ability_id": "", "recipe_id": "", "error": "同种材料不能重复投入"}
		seen[mid] = true
		uniq.append(mid)
	# 最低投入种类数（暂定 2 种）
	if uniq.size() < 2:
		return {"success": false, "ability_id": "", "recipe_id": "", "error": "至少投入 2 种不同材料"}
	# 阶段投入上限
	if uniq.size() > profile.tier_limit():
		return {"success": false, "ability_id": "", "recipe_id": "", "error": "超过当前阶段投入种类上限"}
	# 库存校验（每种投入材料至少 1 份）
	for mid in uniq:
		if profile.material_count(mid) < 1:
			return {"success": false, "ability_id": "", "recipe_id": "", "error": "材料不足"}
	# 匹配配方
	var recipe := RECIPES.match(uniq)
	processing = true
	var before := profile.snapshot()
	if recipe.is_empty():
		# 失败：不扣料（全返还），标记失败状态
		profile.mark_recipe_failed(RECIPES.combo_key(uniq))
		if not profile.save_profile():
			profile.restore(before)
			processing = false
			return {"success": false, "ability_id": "", "recipe_id": "", "error": "保存失败，未消耗材料，请重试"}
		processing = false
		return {"success": false, "ability_id": "", "recipe_id": "", "error": "实验失败，未产出能力"}
	# 成功：扣料（每种 1 份）+ 生成能力 + 标记发现
	var ability_id := String(recipe.ability_id)
	var inputs := {}
	for mid in uniq:
		inputs[mid] = 1
	var committed := profile.commit_craft_transaction(inputs, ability_id, 1)
	if not committed:
		processing = false
		return {"success": false, "ability_id": "", "recipe_id": "", "error": "炼制事务失败"}
	profile.mark_recipe_found(String(recipe.recipe_id))
	if not profile.save_profile():
		profile.restore(before)
		processing = false
		return {"success": false, "ability_id": "", "recipe_id": "", "error": "保存失败，材料和能力库存未改变，请重试"}
	processing = false
	var result := {"success": true, "ability_id": ability_id, "recipe_id": String(recipe.recipe_id), "error": ""}
	experiment_result.emit(result)
	return result

# 配方是否已发现（供图鉴）
func is_recipe_found(recipe_id: String) -> bool:
	return profile.recipe_state(recipe_id) == ProfileStore.RECIPE_STATE_FOUND

# 查询能力名称（供反馈展示）
func ability_name(ability_id: String) -> String:
	var ab := ABILITIES.by_id(ability_id)
	return ab.get("name", ability_id) if not ab.is_empty() else ability_id

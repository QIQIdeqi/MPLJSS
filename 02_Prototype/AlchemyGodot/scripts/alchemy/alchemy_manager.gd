class_name AlchemyManager
extends RefCounted
# 炼金能力管理器（策划案第2、10章）
# 局外制作、入场选择、入场消耗。纯逻辑，UI 由 field/menu 层调用。

const ABILITIES := preload("res://data/alchemy_abilities/alchemy_ability_data.gd")
const SKILLS := preload("res://data/skills/skill_data.gd")

const MATERIAL_NAMES := ["火粉", "露水", "魔法碎片"]  # 素材显示名（后续可配置）

var inventory: AlchemyInventory
var save: ConfigFile
# 配方：能力 → 素材需求 [火粉, 露水, 魔法碎片]（策划案第13章[待确认]，先占位）
var recipes: Dictionary = {}


func setup(p_save: ConfigFile) -> void:
	save = p_save
	inventory = AlchemyInventory.new()
	inventory.load_from(save)
	_build_recipes()

func _build_recipes() -> void:
	# 占位配方：每种能力消耗 3 火粉 + 2 露水 + 1 魔法碎片（建议基准，未冻结）
	var cost := [3, 2, 1]
	for ab in ABILITIES.ABILITIES:
		recipes[ab.id] = cost

func recipe_cost(ability_id: String) -> Array:
	return recipes.get(ability_id, [0, 0, 0])

# 是否有足够素材制作
func can_craft(ability_id: String, materials: Array) -> bool:
	var cost: Array = recipe_cost(ability_id)
	for i in mini(cost.size(), materials.size()):
		if int(materials[i]) < int(cost[i]):
			return false
	return true

# 制作：扣素材 + 库存 +1。返回是否成功。
func craft(ability_id: String, materials: Array) -> bool:
	if not can_craft(ability_id, materials):
		return false
	var cost: Array = recipe_cost(ability_id)
	for i in mini(cost.size(), materials.size()):
		materials[i] = int(materials[i]) - int(cost[i])
	inventory.add(ability_id, 1)
	inventory.save_to(save)
	return true

# 入场确认消耗（策划案第2.2节）：确认入场时消耗，初始能力不消耗。
func consume_on_entry(ability_id: String) -> bool:
	var ok := inventory.consume(ability_id)
	if ok:
		inventory.save_to(save)
	return ok

func save_inventory() -> void:
	inventory.save_to(save)

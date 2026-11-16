class_name AlchemyInventory
extends RefCounted
# 炼金能力库存（策划案第2.4节）
# 每种能力独立整数库存，初始能力永久可用不进入库存。

const ABILITIES := preload("res://data/alchemy_abilities/alchemy_ability_data.gd")

const SAVE_SECTION := "alchemy_abilities"

var quantities: Dictionary = {}  # ability_id → int 库存


func load_from(save: ConfigFile) -> void:
	quantities.clear()
	for id in ABILITIES.ids():
		quantities[id] = int(save.get_value(SAVE_SECTION, String(id), 0))

func save_to(save: ConfigFile) -> void:
	for id in quantities:
		save.set_value(SAVE_SECTION, String(id), int(quantities[id]))

func quantity(ability_id: String) -> int:
	return int(quantities.get(ability_id, 0))

func add(ability_id: String, amount := 1) -> void:
	quantities[ability_id] = quantity(ability_id) + amount

func consume(ability_id: String) -> bool:
	if ability_id == ABILITIES.ABILITY_INITIAL:
		return true  # 初始能力不消耗
	if quantity(ability_id) <= 0:
		return false
	quantities[ability_id] = quantity(ability_id) - 1
	return true

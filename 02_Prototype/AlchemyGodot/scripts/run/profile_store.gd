class_name ProfileStore
extends RefCounted
# 永久档案存储（V1.1 第8.2节 ProfileStore）
# 统一管理：永久素材库存、炼金能力库存、已结算 run_id（防重复结算）、存档读写。
# 只负责数据，不包含游戏逻辑。

const MATERIALS := preload("res://data/materials/material_data.gd")
const ABILITIES := preload("res://data/alchemy_abilities/alchemy_ability_data.gd")

const SAVE_SECTION_MATERIAL := "material_inventory"
const SAVE_SECTION_ABILITY := "ability_inventory"
const SAVE_SECTION_SETTLED := "settled_runs"

var save: ConfigFile
var material_inventory: Dictionary = {}   # material_id -> int（永久素材库存）
var ability_inventory: Dictionary = {}    # ability_id -> int（炼金能力库存）
var settled_runs: Array = []              # 已结算的 run_id（幂等防重复）


func setup(p_save: ConfigFile) -> void:
	save = p_save
	load_profile()

func load_profile() -> void:
	material_inventory.clear()
	ability_inventory.clear()
	settled_runs.clear()
	for id in MATERIALS.ids():
		material_inventory[id] = int(save.get_value(SAVE_SECTION_MATERIAL, String(id), 0))
	for id in ABILITIES.ids():
		ability_inventory[id] = int(save.get_value(SAVE_SECTION_ABILITY, String(id), 0))
	settled_runs = save.get_value(SAVE_SECTION_SETTLED, "ids", [])

func save_profile() -> void:
	for id in material_inventory:
		save.set_value(SAVE_SECTION_MATERIAL, String(id), int(material_inventory[id]))
	for id in ability_inventory:
		save.set_value(SAVE_SECTION_ABILITY, String(id), int(ability_inventory[id]))
	save.set_value(SAVE_SECTION_SETTLED, "ids", settled_runs)

# ---- 素材库存 ----
func material_count(material_id: String) -> int:
	return int(material_inventory.get(material_id, 0))

func has_materials(inputs: Dictionary) -> bool:
	for id in inputs:
		if material_count(id) < int(inputs[id]):
			return false
	return true

# ---- 能力库存 ----
func ability_count(ability_id: String) -> int:
	return int(ability_inventory.get(ability_id, 0))

# ---- 结算幂等 ----
func has_settled(run_id: String) -> bool:
	return settled_runs.has(run_id)

func mark_settled(run_id: String) -> void:
	if not settled_runs.has(run_id):
		settled_runs.append(run_id)
		if settled_runs.size() > 200:  # 防止无限增长
			settled_runs.pop_front()

# 合并结算数据到永久素材库存（幂等由调用方保证，本函数只做加法）
func commit_run_materials(run_id: String, summary: Dictionary) -> bool:
	if has_settled(run_id):
		return false
	for id in summary:
		material_inventory[id] = material_count(id) + int(summary[id])
	mark_settled(run_id)
	return true

# 炼制事务：扣除输入材料 + 增加能力库存（原子，失败不扣料）
func commit_craft_transaction(inputs: Dictionary, ability_id: String, output_amount: int) -> bool:
	if not has_materials(inputs):
		return false
	if output_amount <= 0:
		return false
	for id in inputs:
		material_inventory[id] = material_count(id) - int(inputs[id])
	ability_inventory[ability_id] = ability_count(ability_id) + output_amount
	return true

# 入场消耗能力（失败不扣）
func consume_ability(ability_id: String) -> bool:
	if ability_id == ABILITIES.ABILITY_INITIAL:
		return true
	if ability_count(ability_id) <= 0:
		return false
	ability_inventory[ability_id] = ability_count(ability_id) - 1
	return true

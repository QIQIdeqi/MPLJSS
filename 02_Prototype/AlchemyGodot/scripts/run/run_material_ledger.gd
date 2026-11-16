class_name RunMaterialLedger
extends RefCounted
# 本局临时素材账本（V1.1 第1.2、8.1节 RunMaterialLedger）
# 暂存本局已拾取的素材数量，只在局内增加，返回时统一结算到永久库存。

const SETTLE_ACTIVE := "ACTIVE"
const SETTLE_SETTLING := "SETTLING"
const SETTLE_SETTLED := "SETTLED"

var run_id := ""
var materials: Dictionary = {}   # material_id -> int（本局已拾取数量）
var settlement_status := SETTLE_ACTIVE


func add_material(material_id: String, amount: int) -> void:
	if amount <= 0:
		return
	if settlement_status != SETTLE_ACTIVE:
		return  # 结算中/已结算，禁止再入账
	materials[material_id] = count(material_id) + amount

func count(material_id: String) -> int:
	return int(materials.get(material_id, 0))

func total() -> int:
	var sum := 0
	for k in materials:
		sum += int(materials[k])
	return sum

func is_empty() -> bool:
	return materials.is_empty()

func summary() -> Dictionary:
	return materials.duplicate(true)

func clear() -> void:
	materials.clear()
	settlement_status = SETTLE_ACTIVE

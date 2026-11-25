class_name RunManager
extends RefCounted
# 本局运行管理（V1.1 第8.2节 RunManager）
# 持有本局账本、统一素材结算。所有正常返回入口调用 settle_run_materials。

signal material_collected(run_id: String, material_id: String, amount: int)
signal run_materials_settled(run_id: String, summary: Dictionary)

var profile: ProfileStore
var ledger: RunMaterialLedger
var run_id := ""
var started := false


func setup(p_profile: ProfileStore) -> void:
	profile = p_profile

func start_run(p_run_id: String) -> void:
	run_id = p_run_id
	ledger = RunMaterialLedger.new()
	ledger.run_id = run_id
	started = true

func is_run_active() -> bool:
	return started and ledger != null and ledger.settlement_status == RunMaterialLedger.SETTLE_ACTIVE

# 本局拾取入账（V1.1 第8.4节 collect_material）
func collect_material(material_id: String, amount: int) -> void:
	if not is_run_active():
		return
	if amount <= 0:
		return
	ledger.add_material(material_id, amount)
	material_collected.emit(run_id, material_id, amount)

# 统一素材结算（V1.1 第8.5节 settle_run_materials，幂等）
func settle_run_materials(exit_reason: String) -> bool:
	if ledger == null:
		return false
	if ledger.settlement_status == RunMaterialLedger.SETTLE_SETTLED:
		return true  # 已结算，重复调用直接返回，不重复入账
	if profile.has_settled(run_id):
		ledger.settlement_status = RunMaterialLedger.SETTLE_SETTLED
		return true
	var before := profile.snapshot()
	ledger.settlement_status = RunMaterialLedger.SETTLE_SETTLING
	var summary := ledger.summary()
	var ok := profile.commit_run_materials(run_id, summary)
	if not ok:
		ledger.settlement_status = RunMaterialLedger.SETTLE_ACTIVE
		return false
	if not profile.save_profile():
		profile.restore(before)
		ledger.settlement_status = RunMaterialLedger.SETTLE_ACTIVE
		return false
	ledger.settlement_status = RunMaterialLedger.SETTLE_SETTLED
	run_materials_settled.emit(run_id, summary)
	return true

# 本局素材统计（供 HUD 显示）
func material_count(material_id: String) -> int:
	if ledger == null:
		return 0
	return ledger.count(material_id)

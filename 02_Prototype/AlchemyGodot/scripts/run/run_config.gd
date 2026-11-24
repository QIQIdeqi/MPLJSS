extends Node
# 全局运行时配置（autoload 单例）
# 跨场景传递：本局选择的炼金能力、入场消耗状态等。

const ABILITIES := preload("res://data/alchemy_abilities/alchemy_ability_data.gd")

var selected_ability: StringName = ABILITIES.ABILITY_INITIAL  # 本局能力
var selected_level_id: StringName = &"greyford_01"
var entry_confirmed := false  # 是否已确认入场（用于消耗判定）
var entry_id := ""
var pending_run: Dictionary = {}


func set_ability(id: StringName) -> void:
	selected_ability = id

func begin_entry(level_id: StringName, ability_id: StringName) -> String:
	selected_level_id = level_id
	selected_ability = ability_id
	entry_confirmed = false
	entry_id = new_run_id()
	pending_run.clear()
	return entry_id

func confirm_entry() -> void:
	entry_confirmed = true

func cancel_entry() -> void:
	entry_confirmed = false
	entry_id = ""
	pending_run.clear()

func set_handoff(state: Dictionary) -> void:
	pending_run = state.duplicate(true)

func take_handoff() -> Dictionary:
	var state := pending_run
	pending_run = {}
	return state

func new_run_id() -> String:
	# 不使用进程启动计时，避免重启后与永久结算记录碰号。
	return "run_%s_%s" % [str(Time.get_unix_time_from_system()).replace(".", "_"), Crypto.new().generate_random_bytes(12).hex_encode()]

func reset() -> void:
	selected_ability = ABILITIES.ABILITY_INITIAL
	selected_level_id = &"greyford_01"
	cancel_entry()

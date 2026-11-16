class_name AttackContext
extends RefCounted
# 攻击上下文（策划案第9.8节）
# 每个攻击单元携带本上下文，用于递归保护与联动去重。

# 全局上限（策划案第8.2节，建议基准值，可调）
var max_chain_depth := 3          # 攻击链最大深度
var max_children_per_attack := 4  # 单次攻击最多子攻击数
var max_bounce_count := 3         # 单次攻击最大弹射次数
var max_pierce_count := 5         # 单个攻击单元最大贯穿数
var max_echo_count := 2           # 单次攻击最大回响次数
var max_synergy_triggers := 4     # 单次攻击链最大联动触发数

var source_skill_id: StringName = &""
var source_ability_id: StringName = &""
var generation_depth := 0
var chain_id := 0
var trigger_flags: Dictionary = {}   # 本攻击链已执行过的改造类型
var already_hit_targets: Array = []  # 已命中的目标（弹射/贯穿去重用）
var synergy_triggered_ids: Array = []  # 已触发的联动 id
var is_echo := false
var is_child_attack := false

static var _next_chain := 0

static func new_chain_id() -> int:
	_next_chain += 1
	return _next_chain

func child() -> AttackContext:
	# 子攻击继承 chain_id 与来源，深度 +1
	var c := AttackContext.new()
	c.source_skill_id = source_skill_id
	c.source_ability_id = source_ability_id
	c.generation_depth = generation_depth + 1
	c.chain_id = chain_id
	c.trigger_flags = trigger_flags.duplicate()
	c.already_hit_targets = already_hit_targets.duplicate()
	c.synergy_triggered_ids = synergy_triggered_ids.duplicate()
	c.is_child_attack = true
	return c

func can_spawn_child() -> bool:
	return generation_depth < max_chain_depth

func can_echo() -> bool:
	return not is_echo and int(trigger_flags.get("echo", 0)) < max_echo_count

func can_split() -> bool:
	return not is_child_attack or int(trigger_flags.get("split_allow_child", 0)) > 0

func mark_trigger(effect_type: StringName) -> void:
	trigger_flags[effect_type] = int(trigger_flags.get(effect_type, 0)) + 1

func trigger_count(effect_type: StringName) -> int:
	return int(trigger_flags.get(effect_type, 0))

func can_synergy(synergy_id: StringName) -> bool:
	return not synergy_triggered_ids.has(synergy_id) and synergy_triggered_ids.size() < max_synergy_triggers

func mark_synergy(synergy_id: StringName) -> void:
	if not synergy_triggered_ids.has(synergy_id):
		synergy_triggered_ids.append(synergy_id)

func has_hit(target) -> bool:
	return already_hit_targets.has(target)

func mark_hit(target) -> void:
	if not already_hit_targets.has(target):
		already_hit_targets.append(target)

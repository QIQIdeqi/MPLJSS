class_name SynergyManager
extends RefCounted
# 元素区域与联动管理（策划案第6章）
# 维护本局活跃元素区域，检测元素配对触发联动。

const SKILLS := preload("res://data/skills/skill_data.gd")
const SYNERGIES := preload("res://data/synergies/synergy_data.gd")

var field  # field.gd 实例
var regions: Array = []  # 活跃元素区域
# 每个区域：{"element": StringName, "pos": Vector2, "radius": float, "remaining": float, "skill_id": StringName, "synergy_lock": bool}
var cooldowns: Dictionary = {}  # 联动 id → 剩余冷却


func setup(p_field) -> void:
	field = p_field

func clear() -> void:
	regions.clear()
	cooldowns.clear()

func tick(delta: float) -> void:
	for id in cooldowns:
		cooldowns[id] = maxf(0.0, float(cooldowns[id]) - delta)
	for i in range(regions.size() - 1, -1, -1):
		regions[i].remaining -= delta
		if regions[i].remaining <= 0.0:
			regions.remove_at(i)

# 添加一个元素区域（由区域类技能释放时调用）
func add_region(element: StringName, pos: Vector2, radius: float, duration: float, skill_id: StringName) -> void:
	if element == SKILLS.ELEMENT_NONE:
		return
	regions.append({"element": element, "pos": pos, "radius": radius,
		"remaining": duration, "skill_id": skill_id, "synergy_lock": false})

# 检测一个元素攻击命中是否触发联动
# 返回触发的联动信息（若无返回空 Dictionary）
func check(element: StringName, at: Vector2, attack_radius: float, ctx) -> Dictionary:
	if element == SKILLS.ELEMENT_NONE:
		return {}
	for region in regions:
		if region.synergy_lock or region.element == element:
			continue
		# 区域相交判断（攻击范围与区域范围相交，或攻击点落入区域）
		var dist: float = at.distance_to(region.pos)
		if dist > region.radius + attack_radius + 20.0:
			continue
		var syn := SYNERGIES.match_pair(element, region.element)
		if syn.is_empty():
			continue
		if cooldowns.get(syn.id, 0.0) > 0.0:
			continue
		if not ctx.can_synergy(syn.id):
			continue
		# 触发联动
		ctx.mark_synergy(syn.id)
		cooldowns[syn.id] = syn.cooldown
		region.synergy_lock = syn.consume_b  # 毒雾等被消耗
		if syn.consume_b:
			region.remaining = 0.0  # 标记销毁（tick 会移除）
		return syn
	return {}

# 区域销毁（联动消耗）
func consume_region(index: int) -> void:
	if index >= 0 and index < regions.size():
		regions.remove_at(index)

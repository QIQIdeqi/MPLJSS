extends Control

signal brew_settled(accepted: bool, result: Dictionary)

const ICONS := [preload("res://art/icon_fire_powder.png"), preload("res://art/icon_dew.png"), preload("res://art/icon_magic_shard.png")]
const NAMES := ["火粉", "露水", "魔法碎片"]
const TRAITS := ["火 · 伤害 +10%", "露 · 范围 +15%", "魔 · 冷却 −10%"]
const QUALITY := ["普通", "优质", "上品"]
const OPERATIONS := ["新制丹药", "同方强化", "换主材", "换辅材"]
# Active V0.2 tables in Unreal AlchemyBrew.inl and DesignerCSV/DT_Skills.csv.
const POOLS := [[1, 6, 10, 11, 12], [2, 13, 14, 15, 21], [3, 16, 17, 18, 23]]
const EQUIPPED_LIMIT := 6
const BAG_LIMIT := 6
const STATIONARY_RADIUS := 24.0
const WORLD_SCALE := 0.2
const SKILLS := preload("res://data/brew_skills.gd").ROWS
const TRAIL := preload("res://scenes/fx/trail.tscn")
const FX := preload("res://scripts/battle_fx.gd")

var field
var main := -1
var support := -1
var main_count := 0
var support_count := 0
var operation := 0
var target := -1
var convert_trait := false
var stationary := false
var phase := 0
var pills: Dictionary = {}
var equipped: Array[int] = []
var bag: Array[int] = []
var cooldowns: Dictionary = {}
var bolts: Array[Dictionary] = []
var pending: Dictionary = {}
var rng := RandomNumberGenerator.new()
var origin := Vector2.ZERO
var progress := 0.0
var duration := 0.0
var spark_origin := Vector2.ZERO

@onready var panel: Control = $Panel
@onready var shade: ColorRect = $Shade
@onready var main_slot: Button = $Panel/MainSlot
@onready var support_slot: Button = $Panel/SupportSlot
@onready var confirm: Button = $Panel/Confirm
@onready var clear_button: Button = $Panel/Clear
@onready var close_button: Button = $Panel/Close
@onready var reject: Button = $Panel/Reject
@onready var message: Label = $Panel/Message
@onready var cauldron: TextureRect = $Panel/Cauldron
@onready var sparks: CPUParticles2D = $Panel/Sparks
@onready var sound: AudioStreamPlayer = $Sound
@onready var mode_picker: OptionButton = $Panel/Mode
@onready var operation_picker: OptionButton = $Panel/Operation
@onready var target_picker: OptionButton = $Panel/Target
@onready var convert_button: CheckButton = $Panel/Convert
@onready var progress_label: Label = $Progress
@onready var equip_button: Button = $Panel/Equip

func attach(world: Node) -> void:
	field = world

func _ready() -> void:
	hide()
	spark_origin = sparks.position
	rng.randomize()
	main_slot.ingredient_dropped.connect(select_material)
	support_slot.ingredient_dropped.connect(select_material)
	main_slot.pressed.connect(clear_slot.bind(false))
	support_slot.pressed.connect(clear_slot.bind(true))
	for row in [$Panel/MainBag, $Panel/SupportBag]:
		for button in row.get_children():
			button.icon = ICONS[button.material_id]
			button.pressed.connect(select_material.bind(button.material_id, button.is_support))
	confirm.pressed.connect(confirm_brew)
	clear_button.pressed.connect(reset)
	close_button.pressed.connect(toggle)
	reject.pressed.connect(settle.bind(false))
	mode_picker.add_item("随身试剂 · 2.5 秒")
	mode_picker.add_item("驻留坩埚 · 1.2 秒")
	mode_picker.item_selected.connect(change_mode)
	for label in OPERATIONS:
		operation_picker.add_item(label)
	operation_picker.item_selected.connect(change_operation)
	target_picker.item_selected.connect(change_target)
	convert_button.toggled.connect(change_conversion)
	equip_button.pressed.connect(equip_from_bag)
	$Panel/MainMinus.pressed.connect(change_count.bind(false, -1))
	$Panel/MainPlus.pressed.connect(change_count.bind(false, 1))
	$Panel/SupportMinus.pressed.connect(change_count.bind(true, -1))
	$Panel/SupportPlus.pressed.connect(change_count.bind(true, 1))

func is_open() -> bool:
	return visible

func blocks_world() -> bool:
	return visible and phase != 2

func toggle() -> void:
	if phase >= 2:
		return
	visible = not visible
	field.player.locked = blocks_world()
	if visible:
		refresh()
		close_button.grab_focus()
	else:
		phase = 0

func cancel_run() -> void:
	phase = 0
	pending.clear()
	clear_projectiles()
	sparks.emitting = false
	hide()

func clear_projectiles() -> void:
	for shot in bolts:
		shot.body.queue_free()
	bolts.clear()

func reset() -> void:
	main = -1
	support = -1
	main_count = 0
	support_count = 0
	operation = 0
	target = -1
	convert_trait = false
	phase = 0
	refresh()

func change_mode(index: int) -> void:
	stationary = index == 1
	draft_changed()

func change_operation(index: int) -> void:
	operation = index
	if operation != 0 and not pills.has(target):
		target = pills.keys()[0] if not pills.is_empty() else -1
	if operation == 1 or operation == 2:
		support = -1
		support_count = 0
		convert_trait = false
	if operation == 1 and pills.has(target):
		main = pills[target].main
		main_count = 1
	draft_changed()

func change_target(index: int) -> void:
	target = target_picker.get_item_id(index)
	if operation == 1:
		main = pills[target].main
		main_count = 1
	draft_changed()

func equip_from_bag() -> void:
	if not bag.has(target):
		return
	bag.erase(target)
	if equipped.size() >= EQUIPPED_LIMIT - 1:
		bag.append(equipped.pop_back())
	equipped.append(target)
	draft_changed()

func change_conversion(pressed: bool) -> void:
	convert_trait = pressed
	draft_changed()

func draft_changed() -> void:
	phase = 0
	refresh()

func clear_slot(is_support: bool) -> void:
	if not uses_slot(is_support):
		return
	if is_support:
		support = -1
		support_count = 0
		convert_trait = false
	else:
		main = -1
		main_count = 0
	draft_changed()

func select_material(kind: int, is_support: bool) -> void:
	if phase >= 2 or not available(kind, is_support):
		return
	if is_support:
		support = kind
		support_count = maxi(1, support_count)
	else:
		main = kind
		main_count = maxi(1, main_count)
	draft_changed()

func uses_slot(is_support: bool) -> bool:
	return (operation == 0 or operation == 3) if is_support else (operation == 0 or operation == 2)

func stock(kind: int) -> int:
	return int(field.inventory[kind]) if kind >= 0 and kind < field.inventory.size() else 0

func available(kind: int, is_support: bool) -> bool:
	if kind < 0 or kind >= ICONS.size() or not uses_slot(is_support):
		return false
	var other := main if is_support else support
	var reserved := main_count if is_support and operation != 3 else support_count if not is_support else 0
	var requested := support_count if is_support else main_count
	return stock(kind) >= maxi(1, requested) + (reserved if kind == other else 0)

func change_count(is_support: bool, difference: int) -> void:
	var kind := support if is_support else main
	if not uses_slot(is_support) or kind < 0:
		return
	var count := support_count if is_support else main_count
	var maximum := 1 if (is_support and convert_trait) or (not is_support and candidate_weights().size() <= 1) else 3
	var next := clampi(count + difference, 1, maximum)
	var other := main if is_support else support
	var reserved := main_count if is_support and operation != 3 else support_count if not is_support else 0
	if next > count and stock(kind) < next + (reserved if kind == other else 0):
		return
	if is_support:
		support_count = next
	else:
		main_count = next
	draft_changed()

func candidate_weights() -> Dictionary:
	var weights := {}
	if main >= 0:
		for index in POOLS[main].size():
			var skill: int = POOLS[main][index]
			if not pills.has(skill):
				weights[skill] = 6 - index + (main_count - 1) * index
	return weights

func trait_weights() -> Dictionary:
	var weights := {0: 20, 1: 20, 2: 20}
	weights[support] += 40 + 15 * (support_count - 1)
	return weights

func roll_weighted(weights: Dictionary) -> int:
	var total := 0
	for weight in weights.values():
		total += int(weight)
	var roll := rng.randi_range(0, total - 1)
	for candidate in weights:
		roll -= int(weights[candidate])
		if roll < 0:
			return candidate
	return -1

func costs() -> Dictionary:
	var cost := {}
	if operation != 3 and main >= 0:
		cost[main] = main_count
	if support >= 0 and support_count > 0:
		cost[support] = int(cost.get(support, 0)) + support_count
	if convert_trait:
		cost[4] = 1
	return cost

func validate_recipe() -> String:
	if operation != 0 and not pills.has(target):
		return "请选择已有的丹药"
	if operation == 0 and equipped.size() >= EQUIPPED_LIMIT - 1 and bag.size() >= BAG_LIMIT:
		return "丹药容量已满"
	if operation != 3 and (main < 0 or main_count < 1 or main_count > 3):
		return "点击或拖入 1–3 份主材"
	if operation == 1 and (main != pills[target].main or main_count != 1 or pills[target].level >= 5):
		return "同方强化消耗 1 份原主材，等级上限 Lv.5"
	if operation == 2 and main == pills[target].main:
		return "换主材请选择不同的主材"
	if operation == 3 and support_count == 0:
		return "换辅材至少投入 1 份辅材"
	if convert_trait and (support_count != 1 or support < 0 or not (operation == 0 or operation == 3)):
		return "定向转换需要 1 份辅材"
	for kind in costs():
		if costs()[kind] > stock(kind):
			return "%s不足" % (NAMES[kind] if kind < 3 else "虚空晶")
	if operation == 0 or operation == 2:
		var candidate_count := candidate_weights().size()
		if candidate_count == 0:
			return "该主材没有新的本体候选"
		if candidate_count == 1 and main_count > 1:
			return "仅剩 1 种本体候选，主材减至 1 份"
	return ""

func refresh() -> void:
	panel.visible = phase != 2
	shade.visible = phase != 2
	'progress_label.visible = phase == 2
	var spark_parent: Node = progress_label if phase == 2 else panel
	if sparks.get_parent() != spark_parent:
		sparks.reparent(spark_parent, false)
		sparks.position = Vector2(32, -10) if phase == 2 else spark_origin
	message.position.y = 344 if phase == 3 else 375
	message.size.y = 111 if phase == 3 else 76
	convert_button.visible = phase != 3'
	mouse_filter = Control.MOUSE_FILTER_IGNORE if phase == 2 else Control.MOUSE_FILTER_STOP
	for row in [$Panel/MainBag, $Panel/SupportBag]:
		for button in row.get_children():
			var kind: int = button.material_id
			button.text = "%s ×%d" % [NAMES[kind], stock(kind)]
			button.disabled = phase >= 2 or not available(kind, button.is_support)
	var visible_main := int(pills[target].main) if operation == 3 and pills.has(target) else main
	main_slot.icon = ICONS[visible_main] if visible_main >= 0 else null
	support_slot.icon = ICONS[support] if support >= 0 else null
	main_slot.text = "主材" if visible_main < 0 else "%s%s" % [NAMES[visible_main], " ×%d" % main_count if operation != 3 else ""]
	support_slot.text = "辅材（可选）" if support < 0 else "%s ×%d" % [NAMES[support], support_count]
	main_slot.disabled = phase >= 2 or not uses_slot(false)
	support_slot.disabled = phase >= 2 or not uses_slot(true)
	for button in [clear_button, close_button, mode_picker, operation_picker, target_picker]:
		button.disabled = phase >= 2
	$Panel/MainMinus.disabled = phase >= 2 or not uses_slot(false) or main_count <= 1
	$Panel/MainPlus.disabled = phase >= 2 or not uses_slot(false) or main_count == 0 or main_count >= 3 or candidate_weights().size() <= 1
	$Panel/SupportMinus.disabled = phase >= 2 or not uses_slot(true) or support_count <= 1
	$Panel/SupportPlus.disabled = phase >= 2 or not uses_slot(true) or support_count == 0 or support_count >= 3 or convert_trait
	mode_picker.select(int(stationary))
	operation_picker.select(operation)
	target_picker.clear()
	for id in pills:
		target_picker.add_item("%s Lv.%d · %s" % [SKILLS[id].name, pills[id].level, "已装配" if equipped.has(id) else "背包"], id)
		if id == target:
			target_picker.select(target_picker.item_count - 1)
	target_picker.visible = operation != 0
	equip_button.visible = operation != 0 and bag.has(target)
	equip_button.disabled = phase >= 2
	convert_button.disabled = phase >= 2 or not uses_slot(true) or support_count != 1 or stock(4) == 0
	convert_button.set_pressed_no_signal(convert_trait)
	convert_button.text = "虚空晶定向词条 ×%d" % stock(4)
	reject.visible = phase == 3
	var reason := validate_recipe() if phase < 2 else ""
	confirm.disabled = phase == 2 or not reason.is_empty()
	confirm.text = ["确认炼丹", "再次确认", "炼制中…", "接受成品"][phase]
	if phase == 3:
		var preview := describe(pending)
		message.text = "%s\n原丹：%s" % [preview, describe(pills[target])] if operation != 0 else preview
		message.tooltip_text = message.text
	elif phase < 2:
		var candidates: Array[String] = []
		if operation == 0 or operation == 2:
			var weights := candidate_weights()
			for id in weights:
				candidates.append("%s:%d" % [SKILLS[id].name, weights[id]])
		if phase == 1:
			message.text = "再次确认后立即扣料，放弃成品也不会返还。"
		elif not reason.is_empty():
			message.text = reason
		elif candidates.is_empty():
			message.text = "确认后起炼，出炉时可比较并选择保留原丹。"
		else:
			message.text = "本体候选：%s" % "、".join(candidates)
		var details := message.text
		if support >= 0 and support_count > 0:
			var weights := trait_weights()
			details += "\n定向词条：%s" % TRAITS[support] if convert_trait else "\n词条权重（火/露/魔）：%d / %d / %d" % [weights[0], weights[1], weights[2]]
		message.tooltip_text = details

func confirm_brew() -> void:
	if phase == 3:
		settle(true)
		return
	if phase >= 2 or not validate_recipe().is_empty():
		return
	if phase == 0:
		phase = 1
		refresh()
		return
	var cost := costs()
	for kind in cost:
		field.inventory[kind] -= cost[kind]
	origin = field.player.position
	progress = 0.0
	duration = 1.2 if stationary else 2.5
	phase = 2
	refresh()
	progress_label.text = "坩埚起炼 · 留在原地" if stationary else "随身试剂起炼 · 可边移动边炼制"
	sparks.emitting = true
	sound.stream = preload("res://audio/S_BrewStart.wav")
	sound.play()

func _physics_process(delta: float) -> void:
	if phase != 2:
		return
	if stationary and origin.distance_to(field.player.position) > STATIONARY_RADIUS:
		progress_label.text = "驻留炼制暂停 · 回到起炼位置"
		return
	progress += delta
	progress_label.text = "%s · %.1f 秒" % ["驻留坩埚" if stationary else "随身试剂", maxf(0.0, duration - progress)]
	if progress >= duration:
		complete_brew()

func complete_brew() -> void:
	if phase != 2:
		return
	pending = pills[target].duplicate() if operation != 0 else {"level": 1, "quality": 0, "trait": -1}
	if operation == 0 or operation == 2:
		pending.skill = roll_weighted(candidate_weights())
		pending.main = main
	if operation == 1:
		pending.level += 1
	if operation == 0 or operation == 3:
		pending.trait = -1 if support_count == 0 else support if convert_trait else roll_weighted(trait_weights())
	if operation == 0 or operation == 1:
		pending.quality = maxi(pending.quality, int(stationary))
		if rng.randf() < 0.25:
			pending.quality = mini(2, pending.quality + 1)
	sparks.emitting = false
	sound.stream = preload("res://audio/S_BrewDone.wav")
	sound.play()
	phase = 3
	refresh()
	cauldron.modulate = Color(1.3, 0.75, 1.3)
	message.modulate.a = 0.0
	var reveal := create_tween().set_parallel()
	reveal.tween_property(cauldron, "modulate", Color.WHITE, 0.4)
	reveal.tween_property(message, "modulate:a", 1.0, 0.35)

func settle(accept: bool) -> void:
	if phase != 3:
		return
	var result := pending
	if accept:
		var new_skill: int = result.skill
		match operation:
			0:
				if equipped.size() < EQUIPPED_LIMIT - 1:
					equipped.append(new_skill)
				else:
					bag.append(new_skill)
			2:
				var list := equipped if equipped.has(target) else bag
				list[list.find(target)] = new_skill
				cooldowns[new_skill] = cooldowns.get(target, 0.0)
				cooldowns.erase(target)
				pills.erase(target)
		pills[new_skill] = result
	pending = {}
	reset()
	toggle()
	brew_settled.emit(accept, result)

func skill_stats(pill: Dictionary) -> Dictionary:
	var stats: Dictionary = SKILLS[pill.skill].duplicate()
	stats.damage = roundf(stats.damage * (1.0 + 0.15 * (pill.level - 1))
		* (1.1 if pill.trait == 0 else 1.0) * (1.0 + 0.05 * pill.quality))
	if pill.trait == 1:
		stats.range *= 1.15
		stats.radius *= 1.15
	if pill.trait == 2:
		stats.cd *= 0.9
	return stats

func describe(pill: Dictionary) -> String:
	var stats := skill_stats(pill)
	return "%s Lv.%d · %s · %s\n伤害 %d   冷却 %.2f 秒   范围 %d" % [
		stats.name, pill.level, QUALITY[pill.quality], TRAITS[pill.trait] if pill.trait >= 0 else "无附加词条",
		int(stats.damage), stats.cd, roundi(stats.range * WORLD_SCALE)]

func cast_equipped(delta: float, at: Vector2, enemies: Array, apply_hit: Callable) -> void:
	update_bolts(delta, enemies, apply_hit)
	for skill in equipped:
		cooldowns[skill] = float(cooldowns.get(skill, 0.0)) - delta
		if cooldowns[skill] > 0:
			continue
		var stats := skill_stats(pills[skill])
		var enemy := nearest_enemy(at, stats.range * WORLD_SCALE, enemies, [])
		if enemy.is_empty():
			continue
		cooldowns[skill] = stats.cd
		match stats.cast:
			"SelfArea", "TargetArea":
				var center: Vector2 = at if stats.cast == "SelfArea" else enemy.body.position
				if stats.cast == "SelfArea" and skill == 2:
					# 寒霜环：自身范围释放，播水面涟漪序列帧。
					FX.frost_ring(field.effects, center, stats.radius * WORLD_SCALE * 2.0)
				for entry in enemies.duplicate():
					if living(entry) and entry.body.position.distance_to(center) <= stats.radius * WORLD_SCALE:
						apply_skill_hit(entry, stats, apply_hit)
			"Bounce":
				var used := []
				for hit in int(stats.targets):
					var center: Vector2 = enemy.body.position
					used.append(enemy)
					apply_skill_hit(enemy, stats, apply_hit)
					enemy = nearest_enemy(center, stats.range * WORLD_SCALE, enemies, used)
					if enemy.is_empty():
						break
			"Bolt":
				fire_bolt(at, enemy.body.position, stats)
			_:
				apply_skill_hit(enemy, stats, apply_hit)

func living(enemy: Dictionary) -> bool:
	return enemy.hp > 0.0 and is_instance_valid(enemy.body) and not enemy.body.is_queued_for_deletion()

func nearest_enemy(at: Vector2, reach: float, enemies: Array, excluded: Array) -> Dictionary:
	var closest := {}
	var nearest := reach * reach
	for enemy in enemies:
		if not living(enemy) or excluded.has(enemy):
			continue
		var distance := at.distance_squared_to(enemy.body.position)
		if distance < nearest:
			nearest = distance
			closest = enemy
	return closest

func apply_skill_hit(enemy: Dictionary, stats: Dictionary, apply_hit: Callable) -> void:
	apply_hit.call(enemy, stats.damage / 18.0, stats.slow, stats.factor, stats.color)

func fire_bolt(at: Vector2, goal: Vector2, stats: Dictionary) -> void:
	var bolt := Polygon2D.new()
	bolt.polygon = PackedVector2Array([Vector2(8, 0), Vector2(-4, 4), Vector2(-8, 0), Vector2(-4, -4)])
	bolt.color = stats.color
	bolt.position = at
	bolt.rotation = at.angle_to_point(goal)
	var trail: CPUParticles2D = TRAIL.instantiate()
	trail.color = stats.color
	trail.emitting = true
	bolt.add_child(trail)
	field.add_child(bolt)
	bolts.append({"body": bolt, "direction": Vector2.RIGHT.rotated(bolt.rotation),
		"remaining": float(stats.range) * WORLD_SCALE, "stats": stats})

func update_bolts(delta: float, enemies: Array, apply_hit: Callable) -> void:
	for shot in bolts.duplicate():
		var bolt: Polygon2D = shot.body
		if bolt.is_queued_for_deletion():
			continue
		var distance := minf(shot.remaining, shot.stats.speed * WORLD_SCALE * delta)
		var from := bolt.global_position
		var to: Vector2 = from + shot.direction * distance
		var walls := PhysicsRayQueryParameters2D.create(from, to, 1)
		var wall := field.get_world_2d().direct_space_state.intersect_ray(walls) as Dictionary
		if not wall.is_empty():
			to = wall.position
		var hit := {}
		var closest := INF
		for enemy in enemies:
			if not living(enemy):
				continue
			var center: Vector2 = enemy.body.global_position
			var along := Geometry2D.get_closest_point_to_segment(center, from, to)
			var travel := from.distance_squared_to(along)
			if center.distance_squared_to(along) <= 121.0 and travel < closest:
				closest = travel
				hit = enemy
		bolt.global_position = to
		shot.remaining -= distance
		if not hit.is_empty() or not wall.is_empty() or shot.remaining <= 0.0:
			bolts.erase(shot)
			bolt.queue_free()
			if not hit.is_empty():
				apply_skill_hit(hit, shot.stats, apply_hit)

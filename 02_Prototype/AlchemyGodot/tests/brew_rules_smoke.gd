extends SceneTree

const BREW := preload("res://scenes/brew.tscn")

class TestPlayer extends Node2D:
	var locked := false

class TestField extends Node2D:
	var player := TestPlayer.new()
	var inventory := [7, 7, 7, 0, 2, 0]

var brew
var field: TestField

func _initialize() -> void:
	run.call_deferred()

func require(ok: bool, description: String) -> bool:
	if not ok:
		push_error(description)
		quit(1)
	return ok

func finish_brew(accept: bool) -> Dictionary:
	brew.confirm_brew()
	brew.confirm_brew()
	brew._physics_process(3.0)
	var result: Dictionary = brew.pending.duplicate()
	brew.settle(accept)
	return result

func run() -> void:
	field = TestField.new()
	root.add_child(field)
	field.add_child(field.player)
	brew = BREW.instantiate()
	field.add_child(brew)
	brew.attach(field)
	brew.rng.seed = 77
	brew.toggle()
	if not require(brew.SKILLS.size() == 25, "stable skill IDs read from Unreal CSV"): return
	var source: Button = brew.get_node("Panel/MainBag/Ingredient0")
	var slot: Button = brew.get_node("Panel/MainSlot")
	var payload := {"material": source.get("material_id"), "is_support": source.get("is_support")}
	if not require(slot.call("_can_drop_data", Vector2.ZERO, payload) and
		not brew.get_node("Panel/SupportSlot").call("_can_drop_data", Vector2.ZERO, payload), "native drop role check"): return
	slot.call("_drop_data", Vector2.ZERO, payload)
	brew.confirm_brew()
	if not require(field.inventory[0] == 7 and brew.phase == 1, "first confirmation does not consume"): return
	brew.select_material(0, true)
	if not require(brew.phase == 0, "changing support clears confirmation"): return
	brew.change_count(false, 1)
	brew.change_count(false, 1)
	if not require(brew.candidate_weights()[12] == 10, "3 main materials alter body weights"): return
	brew.change_conversion(true)
	brew.change_mode(1)
	brew.confirm_brew()
	brew.confirm_brew()
	if not require(field.inventory[0] == 3 and field.inventory[4] == 1 and brew.phase == 2 and not brew.blocks_world(), "combined costs and world keeps moving"): return
	field.player.position.x += 60
	brew._physics_process(3.0)
	if not require(brew.phase == 2 and brew.progress == 0.0, "stationary brewing pauses outside origin"): return
	field.player.position = Vector2.ZERO
	brew._physics_process(1.25)
	if not require(brew.phase == 3 and brew.pending.trait == 0 and brew.pending.quality >= 1, "stationary quality and directed trait"): return
	var first: int = brew.pending.skill
	brew.settle(true)
	if not require(brew.equipped.has(first) and brew.pills[first].level == 1, "new result equips skill"): return
	brew.toggle()
	brew.change_operation(1)
	var growth := finish_brew(true)
	if not require(growth.skill == first and growth.level == 2 and growth.trait == 0 and field.inventory[0] == 2, "same-form strengthening"): return
	brew.toggle()
	brew.change_operation(2)
	brew.select_material(1, false)
	brew.cooldowns[first] = 0.7
	var new_body := finish_brew(true)
	var second: int = new_body.skill
	if not require(second != first and new_body.main == 1 and new_body.trait == 0 and new_body.level == 2 and
		brew.cooldowns[second] == 0.7 and not brew.pills.has(first), "changing main material preserves growth, trait and cooldown"): return
	brew.toggle()
	brew.change_operation(3)
	brew.select_material(2, true)
	brew.change_conversion(true)
	var rejected := finish_brew(false)
	if not require(rejected.trait == 2 and brew.pills[second].trait == 0 and field.inventory[4] == 0, "reject preserves old pill and committed materials stay spent"): return
	brew.toggle()
	brew.change_operation(3)
	brew.select_material(2, true)
	var updated := finish_brew(true)
	if not require(updated.skill == second and updated.main == 1 and updated.level == 2 and brew.pills[second].trait >= 0, "changing support preserves body and level"): return
	var target := Node2D.new()
	target.position = Vector2(12, 0)
	field.add_child(target)
	var hits := []
	brew.cast_equipped(2.0, Vector2.ZERO, [{"body": target, "hp": 20}], func(_enemy: Dictionary, amount: float, _slow: float, _factor: float, _color: Color) -> void: hits.append(amount))
	await create_timer(0.25).timeout
	if not require(hits.size() == 1 and hits[0] > 0, "accepted pill performs a combat hit"): return
	target.position = Vector2(60, 0)
	brew.fire_bolt(Vector2.ZERO, target.position, brew.SKILLS[1])
	target.position.x -= 12
	brew.update_bolts(0.3, [{"body": target, "hp": 20}], func(_enemy: Dictionary, amount: float, _slow: float, _factor: float, _color: Color) -> void: hits.append(amount))
	if not require(hits.size() == 2 and brew.bolts.is_empty(), "bolt intersects live target on its path"): return
	brew.sound.stop()
	await create_timer(0.15).timeout
	field.queue_free()
	await process_frame
	print("ALCHEMY_GODOT_BREW_PASS skill data drag confirmation combined costs stationary pause conversion quality new strengthen reforge trait rejection equipped cast bolt")
	quit()

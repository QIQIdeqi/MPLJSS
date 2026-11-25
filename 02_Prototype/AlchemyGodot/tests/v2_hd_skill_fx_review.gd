extends SceneTree

const HD_BATTLE := preload("res://scripts/hd_battle_view.gd")
const SKILLS := preload("res://data/skills/skill_data.gd")
const STEP := 1.0 / 60.0
const OUTPUT := "res://.godot/v2_hd_fx_review"
const TESTS := [
	{"id": "sk_blast_flask", "events": ["cast", "impact"], "capture": ["cast", "impact"]},
	{"id": "sk_clay_homunculus", "events": ["summon_start", "summon_strike"], "capture": ["summon_start", "summon_strike"]},
	{"id": "sk_mithril_drop", "events": ["flight", "impact", "hop"], "capture": ["flight", "hop"]},
	{"id": "sk_gravity_stone", "events": ["flight", "impact", "zone_start"], "capture": ["impact", "zone_start"]},
	{"id": "sk_corrosive_flask", "events": ["flight", "impact", "zone_start", "zone_tick"], "capture": ["flight", "zone_tick"]},
	{"id": "sk_mist_flask", "events": ["flight", "impact", "zone_start", "zone_tick"], "capture": ["flight", "zone_tick"]},
	{"id": "sk_crystal_growth", "events": ["impact"], "capture": ["impact"]},
	{"id": "sk_obsidian_blade", "events": ["flight", "impact", "hop"], "capture": ["flight", "hop"]},
	{"id": "sk_spirit_gel", "events": ["flight", "impact"], "capture": ["flight", "impact"]},
	{"id": "sk_soul_needle", "events": ["flight", "impact"], "capture": ["flight", "impact"]},
	{"id": "link_blast_homunculus", "events": ["summon_start", "summon_strike", "summon_end"], "capture": ["summon_strike", "summon_end"]},
	{"id": "link_mithril_orbit", "events": ["zone_start", "zone_tick"], "capture": ["zone_start", "zone_tick"]},
	{"id": "link_corrosive_mist", "events": ["zone_start", "zone_tick"], "capture": ["zone_start", "zone_tick"]},
	{"id": "link_crystal_shatter_blade", "events": ["impact"], "capture": ["impact"]},
	{"id": "link_soulbound_needle", "events": ["flight", "impact"], "capture": ["flight", "impact"]},
]
const TARGET_OFFSETS := [Vector2(109, 5), Vector2(156, -34), Vector2(172, 39), Vector2(214, 2)]

var capture := false
var capture_night := false
var capture_dir := OUTPUT
var battle: Node2D
var world: Node3D
var attack_effects: Node3D
var skill_manager: SkillManager
var hits := 0

func _initialize() -> void:
	call_deferred("_review")

func _review() -> void:
	var arguments := OS.get_cmdline_user_args()
	if not arguments.has("--migration-test"):
		_fail("Pass --migration-test to use an isolated battle save")
		return
	capture = arguments.has("--capture")
	capture_night = arguments.has("--night")
	if capture_night:
		capture_dir = OUTPUT + "_night"
	if capture and DisplayServer.get_name() == "headless":
		_fail("--capture requires a graphics renderer")
		return
	if capture:
		var result := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(capture_dir))
		if result != OK:
			_fail("Cannot create capture folder: %s" % error_string(result))
			return

	var packed: PackedScene = load("res://scenes/battle.tscn")
	battle = packed.instantiate()
	battle.field_seed = 22147
	root.add_child(battle)
	battle.set_physics_process(false)
	if not is_instance_valid(battle.hd_view):
		battle.hd_view = HD_BATTLE.new()
		battle.add_child(battle.hd_view)
		battle.hd_view.attach(battle)
	world = battle.hd_view.world_view
	attack_effects = world.attack_effects
	skill_manager = battle.alchemy_system.skills
	_place_targets()
	await process_frame

	for test: Dictionary in TESTS:
		var passed := await _review_skill(test)
		if not passed:
			return
	var needle_target_loss := await _check_target_loss(&"sk_soul_needle", "impact", false)
	if not needle_target_loss:
		return
	var flask_target_loss := await _check_target_loss(&"sk_corrosive_flask", "zone_start", true)
	if not flask_target_loss:
		return
	if capture and not await _capture_overlap():
		return

	skill_manager.clear()
	skill_manager.add_skill(&"sk_blast_flask")
	skill_manager.cast_equipped(STEP, battle.player.position, battle.enemies, _record_hit)
	var exiting_effects := attack_effects.get_children()
	if exiting_effects.is_empty():
		_fail("The scene exit test needs a live flight effect")
		return
	battle.queue_free()
	await process_frame
	await process_frame
	for effect in exiting_effects:
		if is_instance_valid(effect):
			_fail("Visual node outlived the battle scene")
			return
	print("V2_HD_SKILL_FX_REVIEW_PASS: %d skills, range gate, target loss, effect cleanup and scene exit" % TESTS.size())
	quit()

func _review_skill(test: Dictionary) -> bool:
	var id: String = test.id
	var from: Vector2 = battle.player.position
	skill_manager.clear()
	if capture:
		world.cycle_time = 38.0 if capture_night else 0.0
		world.update_time_of_day(0.0)
	var required: Dictionary = {}
	var instances: Dictionary = {}
	for event: String in test.events:
		required[event] = false
	var capture_schedule: Dictionary = {}
	hits = 0
	for base_id: String in _equipped_ids(id):
		battle.apply_upgrade({"type":"new_skill", "skill_id":base_id})
		if not skill_manager.has_skill(StringName(base_id)):
			return _fail("%s cannot equip %s" % [id, base_id])
	if id.begins_with("link_"):
		if skill_manager.runtimes.size() != 2 or skill_manager.has_skill(StringName(id)):
			return _fail("%s consumed a skill slot" % id)
		var active_combos := skill_manager.unlocked_chains()
		if active_combos.size() != 1 or active_combos[0].id != id:
			return _fail("%s was not activated by its two parent rewards" % id)

	var targets: Array = battle.enemies
	var empty_targets: Array = []
	skill_manager.cast_equipped(STEP, from, empty_targets, _record_hit)
	if not skill_manager.active.is_empty() or attack_effects.get_child_count() > 0 or hits > 0:
		return _fail("%s activated with no target" % id)
	_reset_targets(from + Vector2(1000.0, 0.0))
	skill_manager.cast_equipped(STEP, from, targets, _record_hit)
	if not skill_manager.active.is_empty() or attack_effects.get_child_count() > 0 or hits > 0:
		return _fail("%s activated outside skill range" % id)

	_reset_targets(from)
	skill_manager.cast_equipped(STEP, from, targets, _record_hit)
	# Release once and advance the same live states without automatically rearming other skills.
	for frame in 450:
		skill_manager._update_active(STEP, from, targets, _record_hit)
		for node in attack_effects.get_children():
			if String(node.get_meta("skill_id", "")) != id:
				continue
			var event := String(node.get_meta("event", ""))
			if required.has(event):
				required[event] = true
				if not instances.has(event):
					instances[event] = {}
				instances[event][node.get_instance_id()] = true
			if capture and event in test.capture and not capture_schedule.has(event):
				var delay := 3 if event in ["flight", "cast", "hop"] else 7
				capture_schedule[event] = frame + delay
		if capture:
			for event in capture_schedule:
				if capture_schedule[event] == frame:
					var saved := await _save_frame(id, event, from + Vector2(112.0, 0.0))
					if not saved:
						return false
			if capture_schedule.size() < test.capture.size() or capture_schedule.values().max() > frame:
				await process_frame
		if skill_manager.active.is_empty() and (not capture or (capture_schedule.size() == test.capture.size() and capture_schedule.values().max() <= frame)):
			break

	if not skill_manager.active.is_empty():
		return _fail("%s retained an active gameplay state after 7.5s" % id)
	for event in required:
		if not required[event]:
			return _fail("%s did not create a node for %s" % [id, event])
	if id == "link_soulbound_needle" and (instances.flight.size() != 3 or instances.impact.size() != 1):
		return _fail("Soulbound should release three needles and mark the target only once per volley")
	if id == "link_crystal_shatter_blade" and instances.impact.size() != 1:
		return _fail("Crystal shatter should show one break per combo")
	if hits == 0:
		return _fail("%s caused no hit in a stationary enemy group" % id)
	# Physics tracked effects may have a brief finish fade after their state is gone.
	await create_timer(0.8).timeout
	for node in attack_effects.get_children():
		var event := String(node.get_meta("event", ""))
		if event in ["cast", "flight", "zone_start", "summon_start"]:
			return _fail("%s retained %s/%s after its state ended" % [id, node.get_meta("skill_id", ""), event])
	world.rebuild()
	await process_frame
	await process_frame
	if attack_effects.get_child_count() > 0:
		return _fail("%s retained an effect after battlefield rebuild" % id)
	print("V2_HD_FX_CASE_PASS %s: %s, %d damage callbacks" % [id, ", ".join(required.keys()), hits])
	return true

func _capture_overlap() -> bool:
	var from: Vector2 = battle.player.position
	skill_manager.clear()
	_reset_targets(from)
	world.cycle_time = 38.0 if capture_night else 0.0
	world.update_time_of_day(0.0)
	for id in [&"sk_corrosive_flask", &"sk_mist_flask", &"sk_gravity_stone",
			&"sk_mithril_drop", &"sk_crystal_growth", &"sk_obsidian_blade"]:
		skill_manager.add_skill(id)
	skill_manager.cast_equipped(STEP, from, battle.enemies, _record_hit)
	for frame in 58:
		skill_manager._update_active(STEP, from, battle.enemies, _record_hit)
		if frame == 37 or frame == 55:
			if not await _save_frame("overlap", str(frame), from + Vector2(112.0, 0.0)):
				return false
		await process_frame
	skill_manager.clear()
	world.rebuild()
	await process_frame
	await process_frame
	print("V2_HD_FX_OVERLAP_CAPTURED: six equipped skills and three linked pairs")
	return true

func _check_target_loss(id: StringName, outcome_event: String, expects_ground_effect: bool) -> bool:
	var from: Vector2 = battle.player.position
	_reset_targets(from)
	skill_manager.clear()
	skill_manager.add_skill(id)
	hits = 0
	var enemy: Dictionary = battle.enemies[0].duplicate()
	var targets := [enemy]
	skill_manager.cast_equipped(STEP, from, targets, _record_hit)
	for frame in 4:
		skill_manager._update_active(STEP, from, targets, _record_hit)
	var flight_nodes: Array[Node] = []
	for node in attack_effects.get_children():
		if node.get_meta("event", "") == "flight":
			flight_nodes.append(node)
	if flight_nodes.is_empty() or hits > 0:
		return _fail("%s target-loss probe needs a projectile in flight" % id)

	enemy.hp = 0.0
	for frame in 80:
		skill_manager._update_active(STEP, from, targets, _record_hit)
	var created_outcome := false
	for node in attack_effects.get_children():
		if node.get_meta("event", "") == outcome_event:
			created_outcome = true
	if created_outcome != expects_ground_effect or hits > 0:
		return _fail("%s produced the wrong outcome after its target disappeared" % id)
	await create_timer(0.6).timeout
	for node in flight_nodes:
		if is_instance_valid(node):
			return _fail("%s left a flight visual after the enemy died" % id)
	skill_manager.clear()
	world.rebuild()
	await process_frame
	await process_frame
	print("V2_HD_FX_TARGET_LOSS_PASS %s" % id)
	return true

func _equipped_ids(id: String) -> Array:
	for chain: Dictionary in SKILLS.CHAINS:
		if chain.id == id:
			return chain.parents
	return [id]

func _place_targets() -> void:
	var enemies: Array = battle.enemies
	while enemies.size() > TARGET_OFFSETS.size():
		var entry: Dictionary = enemies.pop_back()
		entry.body.queue_free()
	assert(enemies.size() >= 3, "The visual review requires at least three original battle monsters")

func _reset_targets(origin: Vector2) -> void:
	for i in battle.enemies.size():
		battle.enemies[i].body.position = origin + TARGET_OFFSETS[i]

func _record_hit(_enemy: Dictionary, _damage: float, _time: float, _strength: float, _tint: Color) -> void:
	hits += 1

func _save_frame(id: String, event: String, focus: Vector2) -> bool:
	await RenderingServer.frame_post_draw
	var image := world.get_viewport().get_texture().get_image()
	if image.is_empty():
		return _fail("Empty rendered frame for %s/%s" % [id, event])
	var center := Vector2i(world.screen_at(focus))
	var crop := Rect2i(center - Vector2i(230, 148), Vector2i(460, 280))
	var bounds := Rect2i(Vector2i.ZERO, image.get_size())
	var path := "%s/%s_%s.png" % [capture_dir, id, event]
	var error := image.get_region(crop.intersection(bounds)).save_png(path)
	if error != OK:
		return _fail("Cannot save %s: %s" % [path, error_string(error)])
	return true

func _fail(message: String) -> bool:
	push_error("V2_HD_FX_REVIEW_FAIL: " + message)
	quit(1)
	return false

extends SceneTree

const HD_BATTLE := preload("res://scripts/hd_battle_view.gd")
const ABILITIES := preload("res://data/alchemy_abilities/alchemy_ability_data.gd")
const STEP := 1.0 / 60.0
const OUTPUT := "res://.godot/skill_expansion_fx_review"
const CASES := {
	"sk_thunder_salt": "impact",
	"sk_fire_oil": "zone_start",
	"sk_mercury_ring": "zone_start",
	"sk_frost_powder": "impact",
	"sk_wind_flask": "impact",
	"sk_feather_draught": "buff_start",
	"sk_wind_boots": "dash",
	"sk_return_wind_powder": "dash",
	"sk_renewal_flask": "zone_start",
	"sk_dew_tonic": "heal",
}
const TARGETS := [Vector2(94, 12), Vector2(128, -54), Vector2(146, 50), Vector2(170, 0)]

var battle: Node2D
var world: Node3D
var skills: SkillManager
var capture: bool
var origin: Vector2

func _initialize() -> void:
	call_deferred("_review")

func _review() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.has("--migration-test"):
		_fail("Pass --migration-test to isolate the save")
		return
	capture = args.has("--capture")
	if capture and DisplayServer.get_name() == "headless":
		_fail("--capture requires a graphics renderer")
		return
	if capture and DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT)) != OK:
		_fail("Could not create capture directory")
		return
	var scene: PackedScene = load("res://scenes/battle.tscn")
	battle = scene.instantiate()
	battle.field_seed = 22147
	root.add_child(battle)
	battle.set_physics_process(false)
	battle.player.set_physics_process(false)
	if not is_instance_valid(battle.hd_view):
		battle.hd_view = HD_BATTLE.new()
		battle.add_child(battle.hd_view)
		battle.hd_view.attach(battle)
	world = battle.hd_view.world_view
	skills = battle.alchemy_system.skills
	origin = battle.player.position
	while battle.enemies.size() > TARGETS.size():
		var enemy: Dictionary = battle.enemies.pop_back()
		enemy.body.queue_free()
	if battle.enemies.size() < 2:
		_fail("Battle fixture needs two or more targets")
		return
	await process_frame
	if not _check_reward_cards():
		return

	for use_split in [false, true]:
		skills.ability_id = ABILITIES.ABILITY_SPLIT if use_split else ABILITIES.ABILITY_INITIAL
		for id: String in CASES:
			if not await _review_skill(id, use_split):
				return
	battle.queue_free()
	await process_frame
	print("SKILL_EXPANSION_FX_REVIEW_PASS: 10 new skills, base and split")
	quit()

func _check_reward_cards() -> bool:
	var new_ids := ["sk_thunder_salt", "sk_wind_boots", "sk_renewal_flask"]
	var pool: Array = battle.alchemy_system.upgrades._build_pool()
	var picks := pool.filter(func(pick: Dictionary) -> bool: return pick.skill_id in new_ids)
	if pool.size() != 20 or picks.size() != 3:
		return _fail("Expected 20 starting rewards and three present preview cards")
	battle.upgrade_ui.offer(picks)
	var buttons: Array = battle.upgrade_ui.buttons
	for i in picks.size():
		var label := "属性 %s · %s" % [picks[i].attribute, picks[i].category]
		if not buttons[i].text.contains(label):
			return _fail("Reward card is missing its attribute or role")
	buttons[1].pressed.emit()
	if paused or skills.runtimes.size() != 1 or not skills.has_skill(StringName(picks[1].skill_id)):
		return _fail("Reward card selection should equip the skill and resume battle")
	var upgrades: Array = battle.alchemy_system.upgrades._build_pool()
	var upgrade: Dictionary = upgrades.back()
	if upgrade.skill_id != "sk_wind_boots" or not upgrade.desc.contains("30→34%"):
		return _fail("The wind boots card should show 30→34%%, got %s %s" % [upgrade.skill_id, upgrade.desc])
	battle.upgrade_ui.offer([upgrade])
	var upgrade_button: Button = battle.upgrade_ui.buttons[0]
	if not upgrade_button.text.contains("属性 晶核 · 机动"):
		return _fail("Upgrade card is missing the Crystal Core attribute")
	upgrade_button.pressed.emit()
	if skills.runtime_for(&"sk_wind_boots").level != 2:
		return _fail("The selected skill should apply its next level")
	var hud := battle.get_node("Interface/CombatHUD")
	hud.update_slots()
	if hud.get_node("Bottom/Slot0").tooltip_text != "风纹靴 · 晶核":
		return _fail("Skill slot tooltip is missing its attribute")
	hud.toggle_bag()
	if hud.actions.get_child(0).text != "风纹靴  Lv.2  ·  晶核":
		return _fail("Equipped skill list is missing its attribute")
	hud.close_panel()
	return true

func _review_skill(id: String, use_split: bool) -> bool:
	skills.clear()
	battle.skill_mobility.clear()
	world.clear_skill_fx()
	battle.player.position = origin
	battle.hp = 40.0
	for i in battle.enemies.size():
		var enemy: Dictionary = battle.enemies[i]
		enemy.body.position = origin + TARGETS[i]
		enemy.hp = 1000.0
		enemy.freeze_left = 0.0
	await process_frame
	battle.apply_upgrade({"type": "new_skill", "skill_id": id})
	if not skills.has_skill(StringName(id)):
		return _fail("Unable to equip %s through an upgrade" % id)
	var expected_event: String = CASES[id]
	var frame_with_fx := -1
	var dash_distance := 0.0
	var return_direction := Vector2(-1.0, -1.0).normalized()
	for frame in 210:
		var moving := id in ["sk_fire_oil", "sk_feather_draught", "sk_dew_tonic"]
		if id == "sk_fire_oil":
			battle.player.position = origin + Vector2(-1.0, 0.55) * minf(136.0, float(frame) * 2.8)
		elif moving and frame_with_fx < 0:
			battle.player.position = origin + Vector2(-1.0, 0.55) * minf(58.0, float(frame) * 1.3)
		var at: Vector2 = battle.player.position
		var context: Dictionary = battle.skill_action_context()
		context.moving = moving
		context.facing = Vector2.RIGHT
		skills.cast_equipped(STEP, at, battle.enemies, _ignore_hit, context)
		battle.skill_mobility.tick(STEP, at, battle.enemies, context)
		if id == "sk_wind_boots" and frame == 0:
			dash_distance = 88.2 * battle.skill_mobility.choose_dodge(at, Vector2.RIGHT, true, 88.2)
		elif id == "sk_wind_boots":
			battle.player.position = origin + Vector2.RIGHT * dash_distance * minf(float(frame) / 11.0, 1.0)
		elif id == "sk_return_wind_powder":
			if frame == 0:
				battle.skill_mobility.choose_dodge(at, Vector2.RIGHT, true, 88.2)
			elif frame == 11:
				battle.player.position = origin + Vector2(88.2, 0.0)
				battle.skill_mobility.on_dodge_finished(battle.player.position, Vector2.RIGHT)
			elif frame == 13:
				battle.skill_mobility.choose_dodge(at, return_direction, false, 88.2)
			elif frame > 13:
				battle.player.position = origin + Vector2(88.2, 0.0) + return_direction * minf(float(frame - 13) * 8.0, 88.2)
		for effect in world.attack_effects.get_children():
			if effect.get_meta("skill_id", "") == id and effect.get_meta("event", "") == expected_event:
				if frame_with_fx < 0:
					frame_with_fx = frame
		if frame_with_fx >= 0:
			if not capture:
				break
			var frames_until_capture := 8
			var focus := origin + Vector2(52.0, 0.0)
			if id == "sk_mercury_ring":
				frames_until_capture = 12
			elif id == "sk_fire_oil":
				frames_until_capture = 36
				focus = origin + Vector2(-28.0, 16.0)
			elif id in ["sk_thunder_salt", "sk_wind_boots", "sk_return_wind_powder", "sk_dew_tonic"]:
				frames_until_capture = 5
			if frame - frame_with_fx >= frames_until_capture:
				return await _save_frame(id, use_split, focus)
		if capture and frame_with_fx >= 0:
			await process_frame
	if frame_with_fx < 0:
		return _fail("Missing %s for %s (split=%s)" % [expected_event, id, use_split])
	print("SKILL_EXPANSION_FX_EVENT %s/%s split=%s" % [id, expected_event, use_split])
	return true

func _save_frame(id: String, use_split: bool, focus: Vector2) -> bool:
	await RenderingServer.frame_post_draw
	var image := world.get_viewport().get_texture().get_image()
	if image.is_empty():
		return _fail("Could not capture %s" % id)
	var center := Vector2i(world.screen_at(focus))
	var crop := Rect2i(center - Vector2i(230, 148), Vector2i(460, 296))
	var path := "%s/%s_%s.png" % [OUTPUT, id, "split" if use_split else "base"]
	if image.get_region(crop.intersection(Rect2i(Vector2i.ZERO, image.get_size()))).save_png(path) != OK:
		return _fail("Could not save %s" % path)
	return true

func _ignore_hit(_enemy: Dictionary, _damage: float, _time: float, _strength: float, _tint: Color) -> void:
	pass

func _fail(message: String) -> bool:
	push_error("SKILL_EXPANSION_FX_REVIEW_FAIL: " + message)
	quit(1)
	return false

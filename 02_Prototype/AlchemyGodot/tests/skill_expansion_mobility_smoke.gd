extends SceneTree

const ABILITIES := preload("res://data/alchemy_abilities/alchemy_ability_data.gd")

var _battle
var _player
var _manager: SkillManager
var _checks := 0
var _failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if not OS.get_cmdline_user_args().has("--migration-test"):
		printerr("Skill mobility smoke requires --migration-test for an isolated save.")
		quit(1)
		return
	var scene := load("res://scenes/battle.tscn") as PackedScene
	if scene == null:
		printerr("Skill mobility smoke could not load the battle scene.")
		quit(1)
		return
	_battle = scene.instantiate()
	if _battle == null or _battle.get_script() == null:
		printerr("Skill mobility smoke could not instantiate the battle script.")
		if _battle != null:
			_battle.free()
		quit(1)
		return
	_battle.enemy_config = null
	_battle.field_seed = 20261127
	root.add_child(_battle)
	_battle.set_physics_process(false)
	_player = _battle.player
	_player.set_physics_process(false)
	_player.locked = false
	_player.collision_mask = 0
	_player.position = Vector2(600.0, 400.0)
	_manager = _battle.alchemy_system.skills
	for id in [&"sk_feather_draught", &"sk_wind_boots", &"sk_return_wind_powder", &"sk_dew_tonic"]:
		_check(_manager.add_skill(id), "equip %s through the normal manager" % id)
	if _failures == 0:
		await _test_dodges()
		await _test_movement()
		_test_healing()
	_battle.queue_free()
	await process_frame
	print("SKILL_MOBILITY_SMOKE checks=%d failures=%d" % [_checks, _failures])
	quit(1 if _failures else 0)

func _test_dodges() -> void:
	var boots := _manager.runtime_for(&"sk_wind_boots")
	var return_wind := _manager.runtime_for(&"sk_return_wind_powder")
	await _press_dodge("move_right")
	_check(_player.dodge > 0.0 and is_equal_approx(_player.velocity.x, 637.0), "boots boost the normal dodge speed by 30%")
	_check(boots.cooldown_left > 0.0 and return_wind.ready(), "first dodge spends boots and leaves return wind ready")
	await _finish_current_dodge()
	await _press_dodge("move_up")
	_check(_player.dodge > 0.0 and is_equal_approx(_player.velocity.y, -490.0), "second press reorients the actual dodge without applying boots")
	_check(is_equal_approx(_player.cooldown, 0.8) and return_wind.cooldown_left > 0.0, "second dodge spends return wind and restarts the normal cooldown")
	await _finish_current_dodge()
	await _press_dodge("move_left")
	_check(_player.dodge == 0.0, "bonus dodge cannot open a third dodge during native cooldown")
	return_wind.cooldown_left = 0.0
	_player.cooldown = 0.0
	await _press_dodge("move_right")
	await _finish_current_dodge()
	_battle.skill_mobility.tick(0.36, _player.position, [], _battle.skill_action_context())
	await _press_dodge("move_up")
	_check(_player.dodge == 0.0 and return_wind.ready(), "expired return window leaves the skill ready and grants no second dodge")

	_manager.ability_id = ABILITIES.ABILITY_SPLIT
	return_wind.cooldown_left = 0.0
	boots.cooldown_left = 0.0
	_player.cooldown = 0.0
	await _press_dodge("move_right")
	_check(is_equal_approx(_player.velocity.x, 666.4), "split boots combine two 60% bonuses into one dodge")
	await _finish_current_dodge()
	_battle.skill_mobility.tick(0.36, _player.position, [], _battle.skill_action_context())
	await _press_dodge("move_up")
	_check(_player.dodge > 0.0 and _player.velocity.y < -489.0, "split return window survives past its ordinary window")
	await _finish_current_dodge()

func _finish_current_dodge() -> void:
	await physics_frame
	_player._physics_process(0.19)

func _press_dodge(action: StringName) -> void:
	await physics_frame
	Input.action_press(action)
	Input.action_press(&"dodge")
	await physics_frame
	_player._physics_process(0.01)
	Input.action_release(&"dodge")
	Input.action_release(action)

func _test_movement() -> void:
	var mobility = _battle.skill_mobility
	var feather := _manager.runtime_for(&"sk_feather_draught")
	feather.cooldown_left = 0.0
	mobility.clear()
	_player.dodge = 0.0
	var old_bounds: Rect2 = _player.movement_bounds
	var old_clamp: bool = _player.clamp_to_battle_bounds
	_player.movement_bounds = Rect2(_player.position - Vector2(120.0, 120.0), Vector2(120.0, 240.0))
	_player.clamp_to_battle_bounds = true
	await _walk_one_tick(&"move_right")
	var stopped: Dictionary = _battle.skill_action_context()
	mobility.tick(1.05, _player.position, [], stopped)
	_check(not stopped.moving and feather.ready(), "holding into a clamped wall produces no movement charge")
	_player.movement_bounds = old_bounds
	_player.clamp_to_battle_bounds = old_clamp
	await _walk_one_tick(&"move_left")
	var moving: Dictionary = _battle.skill_action_context()
	_check(moving.moving, "live directional movement produces an actual movement sample")
	mobility.tick(1.01, _player.position, [], moving)
	_check(is_equal_approx(mobility.walk_speed_scale, 1.25) and not feather.ready(), "sustained actual motion starts feather boost")
	mobility.tick(1.21, _player.position, [], moving)
	_check(is_equal_approx(mobility.walk_speed_scale, 1.25), "split feather has a second pulse after the first 1.2 seconds")
	mobility.tick(1.21, _player.position, [], moving)
	_check(is_equal_approx(mobility.walk_speed_scale, 1.0), "split boost expires after about 2.4 seconds total")

func _walk_one_tick(action: StringName) -> void:
	await physics_frame
	Input.action_press(action)
	_player.set_physics_process(true)
	await physics_frame
	_player.set_physics_process(false)
	Input.action_release(action)

func _test_healing() -> void:
	var mobility = _battle.skill_mobility
	var dew := _manager.runtime_for(&"sk_dew_tonic")
	mobility.clear()
	dew.cooldown_left = 0.0
	_battle.hp = 100.0
	var target := Node2D.new()
	_battle.actors.add_child(target)
	target.position = _player.position + Vector2(80.0, 0.0)
	var foes := [{"body":target, "hp":10.0}]
	var moving: Dictionary = _battle.skill_action_context()
	moving.moving = true
	mobility.tick(1.25, _player.position, [], moving)
	_check(dew.ready() and is_equal_approx(_battle.hp, 100.0), "dew needs a living enemy in range")
	mobility.tick(1.25, _player.position, foes, moving)
	_player.dodge = 0.0
	_check(_battle.hurt(10.0), "a real hit is accepted by field")
	mobility.tick(1.0, _player.position, foes, moving)
	_check(dew.ready() and is_equal_approx(_battle.hp, 90.0), "receiving damage resets dew charge")
	mobility.tick(1.25, _player.position, foes, moving)
	mobility.tick(0.76, _player.position, foes, moving)
	_check(is_equal_approx(_battle.hp, 94.8) and not dew.ready(), "split first healing pulse restores 60%")
	mobility.tick(0.12, _player.position, foes, moving)
	_check(is_equal_approx(_battle.hp, 94.8), "second split pulse is not immediate")
	mobility.tick(0.13, _player.position, foes, moving)
	_check(is_equal_approx(_battle.hp, 99.6), "split second pulse restores another 60%")
	_battle.hp = 119.0
	_check(is_equal_approx(_battle.heal_player(8.0), 1.0) and is_equal_approx(_battle.hp, 120.0), "healing reports actual restored HP and respects cap")
	_battle.hp = 0.0
	_check(is_equal_approx(_battle.heal_player(8.0), 0.0), "healing cannot resurrect the player")
	target.queue_free()

func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		printerr("SKILL_MOBILITY_FAIL " + label)

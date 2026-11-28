extends SceneTree

const HD_BATTLE := preload("res://scripts/hd_battle_view.gd")
const SKILLS := preload("res://data/skills/skill_data.gd")
const FIELD_ENEMY := preload("res://scripts/field_enemy.gd")
const STEP := 1.0 / 60.0
const OUTPUT := "res://.godot/independent_combo_review"

var battle
var world
var skills: SkillManager
var origin: Vector2
var checks := 0
var failures := 0
var capture := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.has("--migration-test"):
		push_error("Use --migration-test to isolate progress.")
		quit(1)
		return
	capture = args.has("--capture") and DisplayServer.get_name() != "headless"
	if capture:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var scene := load("res://scenes/skill_test_stage.tscn") as PackedScene
	if scene == null:
		quit(1)
		return
	battle = scene.instantiate()
	if battle.get_script() == null:
		battle.free()
		quit(1)
		return
	root.add_child(battle)
	battle.set_physics_process(false)
	battle.player.set_physics_process(false)
	if not is_instance_valid(battle.hd_view):
		battle.hd_view = HD_BATTLE.new()
		battle.add_child(battle.hd_view)
		battle.hd_view.attach(battle)
	world = battle.hd_view.world_view
	skills = battle.test_skills()
	origin = battle.player.position
	await physics_frame
	for split: bool in [false, true]:
		await _furnace(split)
		await _coat(split)
		await _mirror(split)
		await _rewind(split)
		await _wall(split)
		await _cleanser(split)
		await _gate(split)
		await _counter(split)
		await _dew(split)
	battle.clear_combat_effects()
	_expect(world.combo_effects._fx._live.is_empty() and world.combo_effects._fx._clips.is_empty(),
		"Battle effect cleanup removes persistent state and short clips")
	battle.queue_free()
	await process_frame
	await _actual_kill()
	print("INDEPENDENT_COMBO_SCENE checks=%d failures=%d" % [checks, failures])
	quit(int(failures > 0))


func _equip(id: StringName, split: bool) -> void:
	battle.player.position = origin
	battle.player.direction = Vector2.RIGHT
	battle.player.dodge = 0.0
	battle.player.forced_motion = false
	if battle.player.hurt_time > 0.0:
		battle.player.art.modulate = battle.player._hurt_base_modulate
		battle.player.hurt_time = 0.0
		battle.player.hurt_expression_time = 0.0
		battle.player.update_pose(battle.player.pose, 0.0)
	_set_motion(origin, origin)
	battle.hp = 90.0
	battle.hurt_cooldown = 0.0
	battle.set_test_dummy_count(3)
	battle.set_test_split(split)
	if capture:
		battle._panel._tabs.current_tab = 1
		battle._panel._equip_combo(id)
	else:
		battle.equip_test_combo(id)
	_hold_parents()
	_expect(skills.unlocked_chains().size() == 1 and skills.combo_rules.ready(id),
		"The two equipped parents unlock %s while both are cooling down" % id)


func _hold_parents() -> void:
	for runtime in skills.runtimes:
		runtime.cooldown_left = 100.0


func _set_motion(from: Vector2, at: Vector2) -> void:
	battle.player.position = at
	battle.player.ordinary_from = from
	battle.player.ordinary_to = at
	battle.player.ordinary_motion = not from.is_equal_approx(at)
	battle.player.walked_this_frame = battle.player.ordinary_motion
	battle.player.walk_from = from


func _advance(frames: int) -> void:
	for _frame in frames:
		battle._physics_process(STEP)
		_set_motion(battle.player.position, battle.player.position)


func _visual_states(id: StringName, from: Array) -> Array:
	return from.filter(func(state: Dictionary) -> bool: return state.skill_id == id)


func _furnace(split: bool) -> void:
	const ID := &"combo_furnace"
	_equip(ID, split)
	_advance(70)
	_expect(_visual_states(ID, world.combo_effects._fx._live.values()).size() == 1, "Nearby dummies raise one furnace")
	_set_motion(origin + Vector2(71.0, 0.0), origin + Vector2(78.0, 0.0))
	_advance(14)
	_expect(not skills.combo_rules.ready(ID), "Actual walking out of the furnace releases its independent attack")
	_expect(world.combo_effects._fx._clips.any(
		func(clip: Dictionary) -> bool: return clip.skill_id == ID and clip.event == "combo_hit"),
		"Directed fire hits a dummy and reaches the HD renderer")
	await _capture("furnace", split)


func _coat(split: bool) -> void:
	const ID := &"combo_thunder_coat"
	_equip(ID, split)
	_advance(1)
	battle.player.dodge = 0.15
	_expect(not battle.hurt(20.0) and skills.combo_rules.ready(ID), "An avoided hit preserves the coat")
	battle.player.dodge = 0.0
	_expect(battle.hurt(20.0, Vector2.ZERO, battle.enemies[0].body), "A real enemy hit resolves")
	_expect(is_equal_approx(battle.hp, 76.8) and not skills.combo_rules.ready(ID),
		"The coat mitigates 6.8 out of 20 once")
	_expect(_visual_states(ID, world.combo_effects._fx._clips).size() == 2,
		"Absorption and counter launch each emit one visual")
	await _capture("coat", split)


func _mirror(split: bool) -> void:
	const ID := &"combo_tide_mirror"
	_equip(ID, split)
	var source: Node2D = battle.enemies[0].body
	battle.fire_web(battle.actors.to_global(origin + Vector2(154.0, 0.0)), Vector2.LEFT, 1, 1.0, source)
	for _frame in 35:
		_advance(1)
		if not _visual_states(ID, world.combo_effects._fx._live.values()).is_empty():
			break
	var active := _visual_states(ID, world.combo_effects._fx._live.values())
	_expect(active.size() == 1 and active[0].phase == "mirror" and skills.combo_rules.ready(ID),
		"Tide Mirror shows the fixed interception plane before spending cooldown")
	await _capture("mirror_ready", split)
	for _frame in 24:
		_advance(1)
		if not skills.combo_rules.ready(ID):
			break
	_advance(2)
	active = _visual_states(ID, world.combo_effects._fx._live.values())
	_expect(active.size() == 1 and active[0].phase == "return"
		and is_equal_approx(float(active[0].width), 0.44 * SKILLS.UNIT), "Reflected wave uses the actual width")
	await _capture("mirror", split)
	_advance(13)
	_expect(battle.web_shots.is_empty() and is_equal_approx(battle.hp, 90.0),
		"Mirror intercepts the actual enemy bullet before hurt")
	_expect(not skills.combo_rules.ready(ID), "Intercept, not creating the mirror, spends cooldown")
	var clips := _visual_states(ID, world.combo_effects._fx._clips)
	_expect(clips.filter(func(clip: Dictionary) -> bool: return clip.event == "combo_hit").size() == 1,
		"Only the reflected projectile hits a dummy")


func _wall(split: bool) -> void:
	const ID := &"combo_crystal_wall"
	_equip(ID, split)
	_advance(20)
	_expect(not skills.combo_rules.ready(ID), "Three dummies can preview the independent wall")
	_expect(_visual_states(ID, world.combo_effects._fx._live.values()).size() == 1, "One blocking wall reaches the renderer")
	await _capture("crystal_wall", split)

func _rewind(split: bool) -> void:
	const ID := &"combo_rewind_anchor"
	_equip(ID, split)
	var dummy_pos: Vector2 = battle.enemies[0].body.position
	battle.prepare_test_condition(ID)
	_hold_parents()
	_expect(battle._test_pursuers.size() == 2, "Test condition brings two temporary pursuers")
	if battle._test_pursuers.is_empty():
		return
	var first: Dictionary = battle._test_pursuers[0]
	for _frame in 65:
		_advance(1)
		var states := _visual_states(ID, world.combo_effects._fx._live.values())
		if states.any(func(state: Dictionary) -> bool: return state.phase == "rewind"):
			break
	var active := _visual_states(ID, world.combo_effects._fx._live.values())
	_expect(not skills.combo_rules.ready(ID) and active.size() == 1, "Two approaching targets activate one shared rewind")
	var before: Vector2 = first.body.position
	await _capture("rewind", split)
	_advance(17)
	_expect(first.body.position.x > before.x + 25.0 and first.hp == 100.0
		and battle.enemies[0].body.position == dummy_pos,
		"The pursuer returns toward its old position and the wooden dummy stays put")


func _cleanser(split: bool) -> void:
	const ID := &"combo_cleanser"
	_equip(ID, split)
	await physics_frame
	Input.action_press(&"move_right")
	Input.action_press(&"dodge")
	await physics_frame
	battle.player._physics_process(STEP)
	Input.action_release(&"dodge")
	Input.action_release(&"move_right")
	for _frame in 11:
		battle.player._physics_process(STEP)
		_advance(1)
	var landing: Vector2 = battle.player.position
	var cooldown := float(skills.chain_cooldowns.get(ID, 0.0))
	var states := _visual_states(ID, world.combo_effects._fx._live.values())
	var pools := states.filter(func(state: Dictionary) -> bool: return state.phase == "pool")
	_expect(cooldown > 9.8 and battle.spore_patches.is_empty() and landing.distance_to(origin) > 60.0,
		"Native Space dodge in the training scene activates with ordinary enemies and no hazard")
	_expect(pools.size() == 1 and pools[0].target.is_equal_approx(landing)
		and is_equal_approx(pools[0].radius, 1.45 * SKILLS.UNIT),
		"Only one pool is rendered at the real landing even with Split Alchemy")
	_expect(is_equal_approx(battle.player.walk_speed_scale, 1.30),
		"The production mobility controller grants 30 percent walking speed")
	if capture:
		await create_timer(0.15).timeout
	await _capture("cleanser", split)
	_advance(65)
	_expect(is_equal_approx(battle.player.walk_speed_scale, 1.30), "Standing on the pool keeps the mobility bonus")
	_set_motion(landing, landing + Vector2.DOWN * 110.0)
	_advance(37)
	_expect(is_equal_approx(battle.player.walk_speed_scale, 1.0), "Exiting the pool ends the speed bonus after its grace period")
	battle.player.position = origin
	battle.reset_test_cooldowns()
	_hold_parents()
	var center := origin + Vector2(104.0, 0.0)
	battle.fire_web(battle.actors.to_global(center), Vector2.ZERO, 5)
	_advance(22)
	var movement = battle.skill_mobility.independent
	var hazard := int(battle.spore_patches[0].id)
	movement.begin_ordinary_dodge(center - Vector2(35.0, 0.0))
	movement.observe_dodge_motion(center - Vector2(35.0, 0.0), center + Vector2(38.0, 0.0), false)
	movement.finish_ordinary_dodge(center + Vector2(38.0, 0.0))
	_expect(not skills.combo_rules.ready(ID) and movement.hazard_safe(hazard, center),
		"Ordinary dodge carves an authoritative source-specific gap from the real spore zone")
	_set_motion(center, center)
	_advance(45)
	_expect(is_equal_approx(battle.hp, 90.0), "Standing in that gap prevents the actual hazard hit")
	await _capture("cleanser_spores", split)

func _gate(split: bool) -> void:
	const ID := &"combo_crystal_gate"
	_equip(ID, split)
	for index in 30:
		var at := origin + Vector2.RIGHT * float(index + 1) * 3.1
		_set_motion(at - Vector2.RIGHT * 3.1, at)
		_advance(1)
	var active := _visual_states(ID, world.combo_effects._fx._live.values())
	_expect(skills.combo_rules.ready(ID) and active.size() == 1, "A sustained run offers one gate pair without spending it")
	await _capture("gate", split)
	var movement = battle.skill_mobility.independent
	var gate: Dictionary = movement._gate
	if not gate.is_empty():
		var result: Variant = battle.player.resolve_gate_dodge.call(gate.entry)
		_expect(result is Vector2 and not skills.combo_rules.ready(ID), "The player dodge resolver accepts the validated gate")

func _counter(split: bool) -> void:
	const ID := &"combo_opening_counter"
	_equip(ID, split)
	battle.prepare_test_condition(ID)
	_hold_parents()
	_advance(1)
	var active := _visual_states(ID, world.combo_effects._fx._live.values())
	_expect(skills.combo_rules.ready(ID) and active.size() == 1
		and active[0].target == origin and is_equal_approx(float(active[0].radius), 1.35 * SKILLS.UNIT),
		"A close enemy windup offers one stomp circle centered on the player")
	if active.size() != 1:
		return
	var at := origin + Vector2(42.0, 0.0)
	battle.enemies[1].body.position = at + Vector2(52.0, 0.0)
	_set_motion(origin, at)
	_advance(1)
	active = _visual_states(ID, world.combo_effects._fx._live.values())
	_expect(active.size() == 1 and active[0].target == at, "The stomp preview follows the player")
	await _capture("counter_ready", split)
	_advance(16)
	_expect(not skills.combo_rules.ready(ID), "The timed stomp spends cooldown if it hits")
	var clips := _visual_states(ID, world.combo_effects._fx._clips)
	_expect(clips.filter(func(clip: Dictionary) -> bool: return clip.event == "combo_launch").size() == 1
		and clips.filter(func(clip: Dictionary) -> bool: return clip.event == "combo_hit").size() == 2,
		"The stomp plays once and hits both targets inside the circle")
	await _capture("counter", split)

func _dew(split: bool) -> void:
	const ID := &"combo_dew_pickup"
	_equip(ID, split)
	battle.prepare_test_condition(ID)
	_hold_parents()
	var active := _visual_states(ID, world.combo_effects._fx._live.values())
	_expect(not skills.combo_rules.ready(ID) and active.size() == 1, "The test death event creates one dew drop")
	if active.size() != 1:
		return
	await _capture("dew", split)
	_set_motion(origin, active[0].target)
	_advance(1)
	_expect(is_equal_approx(float(battle.hp), 100.0), "Actual pickup adds exactly 10 life under either ability")


func _actual_kill() -> void:
	const ID := &"combo_dew_pickup"
	var scene := load("res://scenes/battle.tscn") as PackedScene
	if scene == null:
		_expect(false, "The production battle scene loads for the kill check")
		return
	var field = scene.instantiate()
	field.field_seed = 22147
	root.add_child(field)
	field.set_physics_process(false)
	field.player.set_physics_process(false)
	await physics_frame
	if not field.enemies.is_empty():
		var manager: SkillManager = field.alchemy_system.skills
		for parent: String in SKILLS.combo_by_id(ID).parents:
			manager.add_skill(StringName(parent))
		field.hp = 50.0
		var victim: Dictionary = field.enemies[0]
		victim.body.position = field.player.position + Vector2(35.0, 0.0)
		field.damage_enemy(victim, 5000.0)
		_expect(not manager.combo_rules.ready(ID), "The production death path drops the dew collectible")
		var dew: Dictionary = field.independent_field._dew
		if not dew.is_empty():
			var from: Vector2 = field.player.position
			var pickup: Vector2 = dew.point
			var context: Dictionary = field.skill_action_context()
			context.move_from = from
			context.ordinary_motion = true
			field.independent_field.tick(STEP, pickup, field.enemies, context)
		_expect(is_equal_approx(field.hp, 60.0), "Crossing that drop heals ten points through production heal_player")
	else:
		_expect(false, "Production battle provides a killable target")
	_check_production_cleanser(field)
	field.queue_free()
	await process_frame


func _check_production_cleanser(field) -> void:
	const ID := &"combo_cleanser"
	var manager: SkillManager = field.alchemy_system.skills
	for parent: String in SKILLS.combo_by_id(ID).parents:
		manager.add_skill(StringName(parent))
	for runtime in manager.runtimes:
		runtime.cooldown_left = 100.0
	var previous_count: int = field.enemies.size()
	field.spawn_enemy(FIELD_ENEMY.Kind.SLIME)
	if field.enemies.size() <= previous_count:
		_expect(false, "Production battle provides a chasing slime for the speed comparison")
		return
	var foe: Dictionary = field.enemies[-1]
	var slime: FIELD_ENEMY = foe.body
	var landing: Vector2 = field.player.position
	var foe_at := landing + Vector2.RIGHT * 72.0
	var start := landing - Vector2.RIGHT * 80.0
	field.player.position = start - Vector2.RIGHT * 30.0
	slime.position = foe_at
	field._physics_process(STEP)
	var normal_speed := slime.velocity.length()
	slime.position = foe_at
	var movement = field.skill_mobility.independent
	movement.begin_ordinary_dodge(start)
	movement.observe_dodge_motion(start, landing, false)
	movement.finish_ordinary_dodge(landing)
	field._physics_process(STEP)
	var pool_speed := slime.velocity.length()
	_expect(normal_speed > 1.0 and absf(pool_speed - normal_speed * 0.62) < 0.15,
		"A production slime chases at 62 percent speed inside the pool (normal %.3f, pool %.3f)" % [normal_speed, pool_speed])
	foe.slow_left = 1.0
	foe.slow_factor = 0.45
	slime.position = foe_at
	field._physics_process(STEP)
	var stacked_speed := slime.velocity.length()
	_expect(normal_speed > 1.0 and absf(stacked_speed - normal_speed * 0.45) < 0.15,
		"The pool respects stronger active slows in production (normal %.3f, stacked %.3f)" % [normal_speed, stacked_speed])


func _capture(name: String, split: bool) -> void:
	if not capture:
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	var path := "%s/%s_%s.png" % [OUTPUT, name, "split" if split else "base"]
	_expect(frame.save_png(path) == OK, "Captured " + path)


func _expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

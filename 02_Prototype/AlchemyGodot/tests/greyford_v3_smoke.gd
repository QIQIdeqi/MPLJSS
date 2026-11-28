
extends SceneTree

const DROP_TABLE := preload("res://data/materials/drop_table.gd")
const LAYOUT := preload("res://scripts/level_layout.gd")
const DELTA := 1.0 / 60.0
const EVIDENCE := "res://Evidence/GreyfordV3/"
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("GREYFORD_FAIL: ", message)

func make_field(seed: int, world: SubViewport = null) -> Node2D:
	var packed := load("res://scenes/levels/greyford_01.tscn") as PackedScene
	var field := packed.instantiate()
	field.field_seed = seed
	field.stage_active = false
	if world:
		world.add_child(field)
		field.player.set_physics_process(false)
		field.stage_active = true
		return field
	field.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(field)
	current_scene = field
	for enemy: Dictionary in field.enemies:
		enemy.body.queue_free()
	field.enemies.clear()
	field.until_spawn = 999.0
	field.stage_active = true
	return field

func fire_at_feet(field: Node2D, multiplier := 1.0) -> void:
	var feet: Vector2 = field.player.global_position
	field.fire_web(feet - Vector2(10, 0), Vector2.RIGHT, field.FIELD_ENEMY.Kind.SPIDER, multiplier)

func press_f(field: Node2D) -> void:
	var action := InputEventAction.new()
	action.action = &"interact"
	action.pressed = true
	field._unhandled_input(action)

func same_frame_damage() -> void:
	var field := make_field(1001)
	var runtime = field.field_events
	field.player.position = runtime.points[Vector2i.ZERO]
	field._physics_process(1.5 - DELTA)
	check(runtime.charging and runtime.progress_s < 1.5, "ready for the last frame")
	fire_at_feet(field)
	field._physics_process(DELTA)
	check(field.hp < field.MAX_HP and not runtime.charging and runtime.progress_s == 0.0, "last-frame projectile resets on real HP loss")
	check(runtime.damage_reset_strength == 1.0 and runtime.damage_reset_at == field.player.position and runtime.hp_loss_reset_count == 1,
		"HP reset starts the crimson ring at the branch center and counts once")
	runtime.damage_reset_tween.custom_step(0.11)
	check(is_equal_approx(runtime.damage_reset_strength, 0.5), "HP reset ring fades halfway at 0.11s")
	runtime.damage_reset_tween.custom_step(0.11)
	check(runtime.damage_reset_strength == 0.0, "HP reset ring ends at 0.22s")
	check(runtime.completed.is_empty() and field.pickups.is_empty() and field.material_drops.is_empty() and field.boss_gate_cuts == 0, "interruption grants no reward or cut")
	await physics_frame
	field.hurt_cooldown = 0.0
	field._physics_process(1.5 - DELTA)
	var hp: float = field.hp
	field.hurt(1.0)
	field.heal_player(1.0)
	field._physics_process(DELTA)
	check(field.hp == hp and runtime.progress_s == 0.0 and runtime.completed.is_empty(), "same-frame healing does not erase HP loss")
	await physics_frame
	field.hurt_cooldown = 0.0
	field._physics_process(1.5 - DELTA)
	field.player.dodge = 1.0
	fire_at_feet(field)
	field._physics_process(DELTA)
	check(field.hp == hp and runtime.completed.has(Vector2i.ZERO) and field.xp == 4, "dodged projectile allows one completion and four XP")
	check(runtime.hp_loss_reset_count == 2 and runtime.reset_count == 2, "same-frame heal counts as HP loss and dodge adds no reset")
	field.free()
	field = make_field(1002)
	runtime = field.field_events
	field.player.position = runtime.points[Vector2i.ZERO]
	field._physics_process(1.5 - DELTA)
	fire_at_feet(field, 100.0)
	field._physics_process(DELTA)
	check(field.ended and runtime.completed.is_empty() and field.pickups.is_empty() and field.boss_gate_cuts == 0, "lethal projectile wins the final frame")
	check(runtime.hp_loss_reset_count == 1 and runtime.damage_reset_strength == 1.0, "lethal HP loss also resets the branch")
	field.free()

func pause_and_revisit() -> void:
	var field := make_field(1002)
	var runtime = field.field_events
	var at: Vector2 = runtime.points[Vector2i.ZERO]
	field.player.position = at
	field._physics_process(0.75)
	check(runtime.origin_hint_left == 3.0, "first origin hint starts at three seconds")
	var held_time: float = field.run_time
	var held_charge: float = runtime.progress_s
	var candidates: Array = field.alchemy_system.roll_upgrades()
	field.upgrade_ui.offer(candidates)
	field.process_mode = Node.PROCESS_MODE_INHERIT
	await create_timer(2.0).timeout
	check(paused and field.run_time == held_time and runtime.progress_s == held_charge and runtime.origin_hint_left == 3.0, "actual upgrade screen freezes two seconds")
	field.process_mode = Node.PROCESS_MODE_DISABLED
	field.upgrade_ui._choose(candidates[0])
	field._physics_process(0.12)
	check(runtime.progress_s > held_charge, "charge resumes from saved progress")
	field.player.position = at + Vector2(81, 0)
	field._physics_process(DELTA)
	check(runtime.progress_s == 0.0 and runtime.completed.is_empty(), "81px cancels the charge")
	field.player.position = at
	field._physics_process(0.75)
	field.player.position = Vector2(5000, 3000)
	field.stream_field()
	check(not runtime.points.has(Vector2i.ZERO) and runtime.progress_s == 0.0, "stream unloading interrupts")
	await physics_frame
	field.player.position = at + Vector2(80, 0)
	field._physics_process(1.5)
	check(runtime.completed.has(Vector2i.ZERO) and field.pickups.size() == 4 and field.xp == 0 and field.level == 1, "circle edge produces four uncollected XP")
	for pickup: Dictionary in field.pickups:
		check(is_equal_approx(pickup.sprite.position.distance_to(at), 26.0), "origin XP uses 26px radius")
	field.player.position = Vector2(5000, 3000)
	field.stream_field()
	field.player.position = at + Vector2(80, 0)
	field._physics_process(1.5)
	check(runtime.points[Vector2i.ZERO] == at and runtime.completed.size() == 1 and field.pickups.size() == 4 and field.material_drops.size() == 2 and runtime.origin_hint_left == 0.0, "revisit keeps deterministic point and cannot duplicate drops or restart tutorial")
	field.player.position = at
	field._physics_process(DELTA)
	check(runtime.origin_xp_pickups == 4 and field.xp == 4, "restored origin XP remains tagged on pickup")
	field.free()

func check_generation(field: Node2D) -> void:
	var runtime = field.field_events
	check(runtime.first_neighbors.size() == 2 and runtime.first_neighbors[0].y == 0 and runtime.first_neighbors[1].x == 0, "seed picks one horizontal and one vertical chunk")
	for coord: Vector2i in [Vector2i.ZERO] + runtime.first_neighbors:
		check(runtime.points.has(coord), "mandatory point exists seed %d chunk %s" % [field.field_seed, coord])
		if not runtime.points.has(coord):
			continue
		var at: Vector2 = runtime.points[coord]
		var distance := at.distance_to(field.spawn_position)
		var on_origin := coord == Vector2i.ZERO
		check((distance >= 380.0 and distance <= 450.0 and at.y < field.spawn_position.y) if on_origin else (distance >= 650.0 and distance <= 1350.0), "correct spawn bands and origin above")
		var route := LAYOUT.route_distance(field.layout_preset, at)
		check(route >= 145.0 and route <= 180.0, "point clear of the main route")
		for prop: Dictionary in field.infinite_layout.active_chunks[coord].props:
			if prop.collision != Vector2.ZERO:
				var half: Vector2 = prop.collision * 0.5
				check(at.distance_to(at.clamp(prop.position - half, prop.position + half)) >= runtime.RADIUS, "circle clear of collider")
	var cardinal_count := 0
	for coord: Vector2i in runtime.points:
		if absi(coord.x) + absi(coord.y) == 1:
			cardinal_count += 1
	check(cardinal_count == 2, "exactly two cardinal neighbors offer a point")

func gate_thresholds(a: bool) -> void:
	var case_count := 1 if a else 3
	for cuts in case_count:
		var expected := 135.0 if a else 165.0 - 30.0 * cuts
		var field := make_field(1001)
		check_generation(field)
		for i in cuts:
			check(field.apply_boss_gate_cut(), "B accepts each cut before its limit")
		check(field.boss_gate_threshold() == expected and field.gate_cut_capped() == (cuts == 2), "gate threshold and cap match current group")
		field.run_time = expected - DELTA
		field._physics_process(0.0)
		check(not field.portal_ready, "gate locked on preceding frame")
		field.run_time = expected
		field._physics_process(0.0)
		check(field.portal_ready and not field.apply_boss_gate_cut(), "gate opens at exact threshold and cuts lock")
		field.free()
	if a:
		return
	var field := make_field(1002)
	var runtime = field.field_events
	field.player.position = runtime.points[Vector2i.ZERO]
	field._physics_process(1.5)
	field.player.position = runtime.points[runtime.first_neighbors[0]]
	field._physics_process(1.5 - DELTA)
	field.run_time = 106.0 - DELTA
	field.spawn_wave = field.enemy_config.wave_index(106.0)
	check(not field.portal_ready, "one cut leaves gate locked before 135s")
	field._physics_process(DELTA)
	check(field.portal_ready and field.gate_cut_capped() and is_equal_approx(field.boss_gate_opened_at, 106.0), "second completion opens the gate on the same tick")
	field.player.position = runtime.points[runtime.first_neighbors[1]]
	field._physics_process(1.5)
	check(runtime.completed.size() == 3 and field.boss_gate_cuts == 2 and field.run_manager.ledger.total() == 6, "third branch still grants both materials after the cap")
	field.free()

func gate_interaction() -> void:
	for seed in [1001, 1002]:
		var field := make_field(seed)
		check_generation(field)
		var cross := Vector2(1280, 430) if seed == 1001 else Vector2(-1, 430)
		field.player.position = cross
		field.run_time = field.boss_gate_threshold()
		field._physics_process(0.0)
		var gate: Vector2 = field.portal_position
		check(gate == (Vector2(1920, 360) if seed == 1001 else Vector2(-640, 360)) and field.portal.position == gate, "gate and world effect use the current chunk center")
		var chunk: Vector2i = field.chunk_at(gate)
		for prop: Dictionary in field.infinite_layout.active_chunks[chunk].props:
			if prop.collision != Vector2.ZERO:
				var half: Vector2 = prop.collision * 0.5
				check(gate.distance_to(gate.clamp(prop.position - half, prop.position + half)) >= 112.0, "gate retains 112px footprint clearance")
		check(LAYOUT.route_distance(field.layout_preset, gate) == 0.0, "gate center sits on the protected main route")
		await walk_to_gate(field, gate)
		field.player.position += Vector2(5000, 0)
		field._physics_process(0.0)
		var hud: Control = field.boss_gate_hud
		hud.update_gate(0.0, true, Vector2(1700, 1000), false, false)
		check(not field.infinite_layout.active_chunks.has(chunk) and field.portal_position == gate and field.portal.position == gate, "unloading does not move the open portal")
		check(hud.door_marker.x <= 1060.001 and hud.door_marker.y <= 624.001, "edge marker avoids right 220px and bottom 96px")
		check(hud.safe_rect().position == Vector2(26, 58), "edge marker safe area starts below the upper HUD")
		field.player.position = gate + Vector2(60, 0)
		field._physics_process(0.0)
		hud._process(0.0)
		press_f(field)
		check(not hud.prompt.visible and not field.portal_dialog.visible, "60px hides prompt and rejects F")
		field.player.position = gate + Vector2(59, 0)
		hud._process(0.0)
		var prompt_center: Vector2 = hud.prompt.position + hud.prompt.size * 0.5
		check(hud.prompt.visible and prompt_center.is_equal_approx(hud.project_point(gate) - Vector2(0, 72)), "59px displays F exactly 72px above the door")
		press_f(field)
		check(field.portal_dialog.visible, "59px opens confirmation")
		field.portal_dialog.hide()
		check(current_scene == field and not field.portal_dialog.visible, "cancel leaves field active")
		press_f(field)
		field.player.position = gate + Vector2(60, 0)
		field.enter_boss()
		check(current_scene == field, "confirmation revalidates distance")
		field.player.position = gate + Vector2(59, 0)
		field.enter_boss()
		check(current_scene != field and current_scene.stage_is_boss, "confirmation enters the Boss stage inside range")
		current_scene.free()
		await process_frame

func compare_live_waves() -> void:
	var uncut_world := SubViewport.new()
	var cut_world := SubViewport.new()
	for world in [uncut_world, cut_world]:
		world.world_2d = World2D.new()
		root.add_child(world)
	var uncut := make_field(1001, uncut_world)
	var cut := make_field(1001, cut_world)
	check(cut.apply_boss_gate_cut() and cut.apply_boss_gate_cut(), "B comparison applies two cuts through the gate API")
	for field in [uncut, cut]:
		# Hold the same player position and ignore combat damage during the scheduler comparison.
		field.player.dodge = INF
		field.until_attack = INF
	var waves := {}
	var scheduled_spawns := 0
	var spawned_enemies := 0
	var frames := 0
	var cut_open_frame := 0
	await physics_frame
	for frame in range(1, 165 * 60 + 1):
		var previous_timer: float = uncut.until_spawn
		var previous_count: int = uncut.enemies.size()
		await physics_frame
		frames = frame
		var wave: int = uncut.enemy_config.wave_index(uncut.run_time)
		waves[wave] = true
		var schedule_matches: bool = uncut.run_time == cut.run_time and uncut.spawn_wave == wave and cut.spawn_wave == wave \
			and uncut.until_spawn == cut.until_spawn and uncut.rng.state == cut.rng.state and uncut.enemies.size() == cut.enemies.size()
		if not schedule_matches:
			check(false, "wave or spawn schedule diverged at frame %d (%.6fs)" % [frame, uncut.run_time])
			break
		if cut.portal_ready and cut_open_frame == 0:
			cut_open_frame = frame
		if uncut.until_spawn > previous_timer - DELTA:
			scheduled_spawns += 1
		if uncut.enemies.size() > previous_count:
			spawned_enemies += 1
			if uncut.enemies.back().body.kind != cut.enemies.back().body.kind:
				check(false, "spawned enemy kind diverged at frame %d" % frame)
				break
		if frame % 60 == 0:
			# Retire enemies symmetrically so later waves continue exercising real spawning.
			for field in [uncut, cut]:
				if not field.enemies.is_empty():
					var retired: Dictionary = field.enemies.pop_front()
					retired.body.free()
		if uncut.portal_ready:
			break
	check(uncut.portal_ready and frames == 165 * 60 and absf(uncut.boss_gate_opened_at - 165.0) < 0.000001,
		"B cut=0 opens at 165s on frame 9900")
	check(cut_open_frame == 105 * 60 and absf(cut.boss_gate_opened_at - 105.0) < 0.000001,
		"B cut=2 opens at 105s on frame 6300")
	check(waves.size() > 1 and spawned_enemies > 0, "wave comparison exercised transitions and actual enemy spawns")
	print("GREYFORD_WAVE_COMPARE seed=1001 frames=%d waves=%s scheduled=%d spawned=%d cut0=%.6f cut2=%.6f cut2_frame=%d"
		% [frames, str(waves.keys()), scheduled_spawns, spawned_enemies, uncut.boss_gate_opened_at, cut.boss_gate_opened_at, cut_open_frame])
	cut_world.free()
	uncut_world.free()

func walk_to_gate(field: Node2D, gate: Vector2) -> void:
	field.set_physics_process(false)
	field.process_mode = Node.PROCESS_MODE_INHERIT
	field.player.locked = false
	field.player.position = gate - Vector2(0, 160)
	await physics_frame
	Input.action_press(&"move_down")
	for step in 120:
		await physics_frame
		if field.player.position.distance_to(gate) < 12.0:
			break
	Input.action_release(&"move_down")
	check(field.player.position.distance_to(gate) < 12.0, "real Lilita movement reaches gate from its protected road")
	field.set_physics_process(true)
	field.process_mode = Node.PROCESS_MODE_DISABLED

func workbench_gate() -> void:
	var village := (load("res://scenes/levels/village_greyford.tscn") as PackedScene).instantiate()
	root.add_child(village)
	var workbench = village.workbench_ui
	var profile: ProfileStore = village.profile_store
	for id in ["dew", "fire_powder", "wind_crystal"]:
		profile.material_inventory[id] = 2
	var feedback: Label = workbench.get_node("Panel/Margin/Scroll/VBox/Feedback")
	workbench.open()
	workbench._select_material("dew")
	workbench._select_material("fire_powder")
	workbench._submit_experiment()
	var success := feedback.text
	check(not success.is_empty() and profile.recipe_state("recipe_burst") == ProfileStore.RECIPE_STATE_FOUND
		and profile.material_count("dew") == 1 and profile.material_count("fire_powder") == 1, "G0 workbench succeeds, discovers recipe and consumes both materials")
	check_feedback_rebuild(workbench, feedback, success)
	workbench._select_material("wind_crystal")
	workbench._select_material("fire_powder")
	workbench._submit_experiment()
	check(not feedback.text.is_empty() and feedback.text != success and profile.material_count("wind_crystal") == 2
		and profile.material_count("fire_powder") == 1, "G0 failed workbench experiment preserves materials")
	check_feedback_rebuild(workbench, feedback, feedback.text)
	village.free()

func check_feedback_rebuild(workbench: CanvasLayer, feedback: Label, expected: String) -> void:
	workbench._select_material("dew")
	check(feedback.text == expected, "G0 feedback survives material selection")
	workbench._remove_material(0)
	check(feedback.text == expected, "G0 feedback survives material removal")
	workbench.close()
	workbench.open()
	check(feedback.text == expected, "G0 feedback survives reopening")

func boss_loot_gate() -> void:
	var field := (load("res://scenes/levels/greyford_01_boss.tscn") as PackedScene).instantiate()
	field.field_seed = 1001
	root.add_child(field)
	current_scene = field
	field.player.position = field.boss.body.position + Vector2(170, 0)
	field.profile_store.save_path = "res://project.godot/greyford_v3.cfg"
	field.damage_enemy(field.boss.entry, 999999.0)
	var death: Tween = field.boss_death
	check(death != null and field.run_manager.ledger.total() == 0, "G0 remote Boss kill waits for the death animation")
	if death == null:
		field.free()
		return
	await death.finished
	check(field.ended and not field.run_rewards_saved and field.profile_store.material_count("dew") == 0,
		"G0 failed save rolls back the persistent inventory")
	var save_path: String = "res://.godot/greyford_v3_" + field.run_manager.run_id + ".cfg"
	field.profile_store.save_path = save_path
	check(field.settle_run() and field.settle_run(), "G0 existing ledger saves on retry and repeated exits are idempotent")
	var saved := ConfigFile.new()
	check(ProfileStore.load_save(saved, save_path) == OK, "G0 Boss rewards persist to an isolated SSD save")
	var reloaded := ProfileStore.new()
	reloaded.setup(saved, save_path)
	for entry in DROP_TABLE.BOSS_DROPS:
		var amount := reloaded.material_count(entry.material_id)
		check(amount >= int(entry.min) and amount <= int(entry.max), "G0 reloaded material matches single Boss roll: " + entry.material_id)
	var replay := RunManager.new()
	replay.setup(reloaded)
	replay.start_run(field.run_manager.run_id)
	replay.collect_material("dew", 4)
	var before := reloaded.material_count("dew")
	check(replay.settle_run_materials("test") and reloaded.material_count("dew") == before, "G0 replay of the same run ID does not duplicate rewards")
	field.leave_run()
	check(current_scene != field and not current_scene.combat, "G0 settled Boss returns to village")
	current_scene.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	await process_frame

func run() -> void:
	check(OS.get_cmdline_user_args().has("--migration-test"), "isolated save mode")
	if failures:
		quit(1)
		return
	var capture_g1 := OS.get_cmdline_user_args().has("--capture-g1")
	if capture_g1 or OS.get_cmdline_user_args().has("--capture"):
		await capture_states(capture_g1)
	else:
		if not OS.get_cmdline_user_args().has("--greyford-gate-a"):
			workbench_gate()
			await boss_loot_gate()
			await compare_live_waves()
		await same_frame_damage()
		await pause_and_revisit()
		gate_thresholds(OS.get_cmdline_user_args().has("--greyford-gate-a"))
		await gate_interaction()
		check(checks >= 30, "all test groups ran")
	print("GREYFORD_SMOKE_%s checks=%d failures=%d" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(1 if failures else 0)

func capture_states(g1_only: bool) -> void:
	if DisplayServer.get_name() == "headless":
		check(false, "capture requires a renderer")
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EVIDENCE))
	var field := make_field(1001)
	field.activate_stage()
	field.process_mode = Node.PROCESS_MODE_DISABLED
	var view = field.hd_view
	var world = view.world_view
	for night in ([true] if g1_only else [false, true]):
		field.portal_ready = false
		if is_instance_valid(field.portal):
			field.portal.free()
		field.run_time = 0.0
		field.boss_gate_cuts = 0
		field.field_events.completed.clear()
		field.player.position = field.spawn_position
		field.stream_field()
		field.field_events.reset_charge("capture_reset")
		field.field_events.origin_hint_shown = false
		field.field_events.origin_hint_left = 0.0
		if not g1_only:
			await capture_state(field, world, "S1_spawn", night)
		var origin: Vector2 = field.field_events.points[Vector2i.ZERO]
		field.player.position = origin
		field.field_events.tick_charge(0.75, false)
		if not g1_only:
			await capture_state(field, world, "S2_charge", night)
		field.spawn_enemy(field.FIELD_ENEMY.Kind.BAT)
		var bat: CharacterBody2D = field.enemies.back().body
		bat.position = origin - Vector2(120, 0)
		bat.state = field.FIELD_ENEMY.State.WINDUP
		bat.remaining = 0.3
		bat.aim = Vector2.RIGHT
		bat.queue_redraw()
		field.fire_web(origin + Vector2(45, 35), Vector2.LEFT)
		await capture_state(field, world, "S2_warning", night)
		field.enemies.clear()
		bat.queue_free()
		field.clear_webs()
		field.field_events.reset_charge("capture_step")
		field.field_events.origin_hint_left = 0.0
		field.player.position = Vector2(1920, 365)
		field.stream_field()
		field.run_time = 105.0
		field.boss_gate_cuts = 2
		field.update_boss_gate()
		field.player.position = Vector2(400, 430)
		field.stream_field()
		if not g1_only:
			await capture_state(field, world, "S3_offscreen", night)
		field.player.position = field.portal_position + Vector2(45, 0)
		field.stream_field()
		await capture_state(field, world, "S4_prompt", night)
		check(is_instance_valid(world.portal_beam) and world.portal_beam.visible
			and is_equal_approx(world.portal_beam.modulate.a, 0.35), "S4 renders the portal beam at 0.35 peak alpha")
	field.free()
	if g1_only:
		return
	var boss_field := (load("res://scenes/levels/greyford_01_boss.tscn") as PackedScene).instantiate()
	boss_field.field_seed = 1001
	root.add_child(boss_field)
	current_scene = boss_field
	boss_field.process_mode = Node.PROCESS_MODE_DISABLED
	var boss_world = boss_field.hd_view.world_view
	await capture_state(boss_field, boss_world, "boss_surface", false)
	await capture_state(boss_field, boss_world, "boss_surface", true)
	boss_field.free()

func capture_state(field: Node2D, world: Node3D, name: String, night: bool) -> void:
	world.cycle_time = 40.0 if night else 1.0
	field.update_camera(0.0)
	field.hd_view._process(0.0)
	field.boss_gate_hud._process(0.0)
	field.get_node("Interface/CombatHUD")._process(0.0)
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var filename := EVIDENCE + name + ("_night.png" if night else "_day.png")
	check(image.save_png(ProjectSettings.globalize_path(filename)) == OK, filename)

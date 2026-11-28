extends SceneTree
## Run with --migration-test: no player save or inventory is written.

var checks: Array[Dictionary] = []
var failures := 0
const OUTPUT := "res://Evidence/FiveRegions_20261124/"

func _initialize() -> void:
	run_checks.call_deferred()

func check(ok: bool, message: String) -> void:
	checks.append({"passed": ok, "check": message})
	if not ok:
		failures += 1
		printerr("FIVE_REGION_FLOW_FAIL: " + message)

func run_checks() -> void:
	check(OS.get_cmdline_user_args().has("--migration-test"), "isolated save mode is required")
	var catalog = load("res://levels/catalog.tres")
	check(catalog.validation_errors().is_empty(), "five region catalog validates")
	check(catalog.entries.size() == 11 and catalog.selectable_levels().size() == 5, "village exposes five normal scenes and five linked Boss scenes")
	for definition in catalog.selectable_levels():
		for seed_value in [1,77,2026,99173]:
			var stream = load("res://scripts/infinite_field_layout.gd").new()
			stream.setup(definition.layout, seed_value, definition.level_id, definition.spawn_position)
			for coord: Vector2i in [Vector2i.ZERO,Vector2i(2,-3),Vector2i(-4,2),Vector2i(-5,-5)]:
				var generated: Dictionary = stream.build_chunk(coord)
				check(generated.error.is_empty(), "%s production palette seed %s chunk %s generates without dropping required counts" % [definition.level_id,seed_value,coord])
		var packed = load(definition.scene_path)
		var field = packed.instantiate()
		field.field_seed = 77
		field.stage_active = false
		field.process_mode = Node.PROCESS_MODE_DISABLED
		root.add_child(field)
		current_scene = field
		await physics_frame
		await physics_frame
		var label := String(definition.level_id)
		check(field.startup_complete and field.startup_error.is_empty(), label + " starts with real gameplay and HUD")
		if not field.startup_complete:
			field.free()
			continue
		check(field.is_infinite_field() and not field.player.clamp_to_battle_bounds, label + " has no fixed world boundary")
		check(field.chunk_nodes.size() == 9, label + " starts with nine active chunks")
		var first: Dictionary = field.infinite_layout.active_chunks[Vector2i.ZERO].duplicate(true)
		var at: Vector2 = field.player.position
		field.add_pickup(at + Vector2(70, 0), 0)
		field.add_pickup(at + Vector2(80, 0), 1)
		field.spawn_material_drop(at + Vector2(90, 0), "dew", 2, false)
		var coins_before: int = field.coins
		var xp_before: int = field.xp
		field.player.position = Vector2(6400, 3600)
		check(field.stream_field() and field.chunk_nodes.size() == 9, label + " travels beyond the old arena and unloads distant chunks")
		check(field.pickups.is_empty() and field.material_drops.is_empty() and field.dormant_drops[Vector2i.ZERO].size() == 3, label + " stores far loot as data")
		check(field.coins == coins_before and field.xp == xp_before and field.run_manager.ledger.materials.is_empty(), label + " does not auto-collect distant loot")
		field.player.position = at
		check(field.stream_field() and field.infinite_layout.active_chunks[Vector2i.ZERO] == first, label + " revisits the identical layout")
		check(field.dormant_drops.is_empty() and field.pickups.size() == 2 and field.material_drops.size() == 1, label + " restores uncollected loot once")
		check(field.pickups[0].sprite.position.distance_to(at) >= 70.0 and field.material_drops[0].sprite.position == at + Vector2(90,0), label + " retains drop world positions")
		field.player.position = Vector2(6400,3600)
		field.stream_field()
		field.player.position = at
		field.stream_field()
		check(field.pickups.size() == 2 and field.material_drops.size() == 1, label + " does not duplicate loot on a second revisit")
		field.field_events.points = {Vector2i.ZERO: at}
		tick_branch(field.field_events)
		var reward_count: int = field.pickups.size() + field.material_drops.size()
		tick_branch(field.field_events)
		check(field.field_events.completed.has(Vector2i.ZERO) and reward_count == field.pickups.size()+field.material_drops.size(), label + " optional encounter triggers only once per chunk")
		field.player.position = Vector2(-2560, -1440)
		check(field.stream_field() and field.chunk_at(field.player.position) == Vector2i(-2,-2), label + " supports negative world coordinates")
		field.spawn_enemy()
		await physics_frame
		check(not field.enemies.is_empty(), label + " spawns its configured enemy")
		for enemy in field.enemies:
			check(enemy.hp >= 8.0, label + " uses configured health rather than shared two HP")
			# This fixture disables the scene's physics bodies; movement is exercised by the live MCP run.
			enemy.body.queue_free()
		field.enemies.clear()
		field.until_spawn = 1.0
		field.stage_active = true
		var gate_at: float = field.boss_gate_threshold()
		field.run_time = gate_at - 1.0
		field._physics_process(0.0)
		check(not field.portal_ready, label + " keeps Boss closed before its configured threshold")
		field.run_time = gate_at
		field._physics_process(0.0)
		check(field.portal_ready and is_instance_valid(field.portal), label + " opens voluntary Boss gate at its configured threshold")
		var portal_at: Vector2 = field.portal_position
		field.player.position += Vector2(2600, 0)
		field.stream_field()
		check(field.portal_position == portal_at, label + " keeps the opened portal in world space")
		field.hp = 87.0
		field.coins = 13
		var handoff: Dictionary = field.capture_run()
		var next = field.prepare_stage(definition.boss_level_id, handoff)
		check(next != null and next.stage_is_boss and not next.is_infinite_field(), label + " initializes its independent finite Boss")
		if next != null:
			var boss_definition = catalog.find_level(definition.boss_level_id)
			check(next.hp == 87.0 and next.coins == 13 and next.run_manager.run_id == field.run_manager.run_id, label + " carries health rewards and run identity to Boss")
			check(next.boss.display_name == boss_definition.boss_name and next.boss.max_hp > 0.0, label + " selects corresponding Boss profile")
			next.free()
		field.free()
		await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var report := FileAccess.open(OUTPUT + "flow.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failures": failures}, "\t"))
	report.close()
	print("FIVE_REGION_FLOW_%s checks=%d failures=%d" % ["PASS" if failures == 0 else "FAIL", checks.size(), failures])
	quit(0 if failures == 0 else 1)

func tick_branch(runtime: RefCounted) -> void:
	if runtime.timed:
		runtime.tick_charge(runtime.CHARGE_SECONDS, false)
	else:
		runtime.tick()

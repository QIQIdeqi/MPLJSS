extends SceneTree
## Run without --migration-test. Both cases use their own SSD save under .godot.

const MATERIALS := preload("res://data/materials/material_data.gd")
const PANEL := "Interface/RunSettlement/Panel"
const START_COINS := 23
const RUN_COINS := 13

var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		printerr("GREYFORD_SETTLEMENT_FAIL: ", message)
	return ok

func run() -> void:
	if check(not OS.get_cmdline_user_args().has("--migration-test"), "real fixture persistence enabled"):
		for scenario: String in ["normal", "retry"]:
			var save_path := "res://.godot/greyford_settlement_%d_%s.cfg" % [OS.get_process_id(), scenario]
			var before := failures
			check(await test_return(save_path, scenario == "retry"), scenario + " case completed")
			if is_instance_valid(current_scene):
				current_scene.free()
			var absolute_path := ProjectSettings.globalize_path(save_path)
			for suffix: String in ["", ".bak", ".tmp"]:
				DirAccess.remove_absolute(absolute_path + suffix)
			if failures == before:
				print("GREYFORD_SETTLEMENT_CASE_PASS: ", scenario)
	print("GREYFORD_SETTLEMENT_%s checks=%d failures=%d" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(1 if failures else 0)

func test_return(save_path: String, fail_first_write: bool) -> bool:
	var fixture := ConfigFile.new()
	fixture.set_value("tutorial", "brew_introduced", true)
	fixture.set_value("village", "coins", START_COINS)
	fixture.set_value("material_inventory", "dew", 4)
	fixture.set_value("material_inventory", "fire_powder", 2)
	if not check(ProfileStore.write_save(fixture, save_path) == OK, "isolated baseline saved"):
		return false
	var disk_before := FileAccess.get_file_as_string(save_path)
	var blocked_path := ProjectSettings.globalize_path(save_path + ".tmp")
	if fail_first_write and not check(DirAccess.make_dir_absolute(blocked_path) == OK, "temporary save path blocked"):
		return false

	var packed := load("res://scenes/levels/greyford_01_boss.tscn") as PackedScene
	var boss = packed.instantiate()
	boss.save_path = save_path
	boss.field_seed = 1001
	root.add_child(boss)
	current_scene = boss
	boss.set_physics_process(false)
	if not check(boss.startup_complete and boss.stage_is_boss, "Boss scene initialized"):
		return false
	var panel := boss.get_node_or_null(PANEL) as PanelContainer
	if not check(panel != null and not panel.is_visible_in_tree(), "settlement panel starts hidden"):
		return false
	var profile: ProfileStore = boss.profile_store
	var profile_before := profile.snapshot()
	var manager: RunManager = boss.run_manager
	var run_id := manager.run_id
	var ledger := manager.ledger
	boss.coins = RUN_COINS
	manager.collect_material("dew", 2)
	boss.damage_enemy(boss.boss.entry, 999999.0)
	for frame in 240:
		if boss.ended:
			break
		await process_frame
	if not check(boss.ended and boss.player.locked, "Boss death completes and locks player"):
		return false

	var rewards := ledger.summary()
	check(rewards.size() == MATERIALS.ids().size() and ledger.count("dew") > 2, "settlement includes earlier loot and Boss drops")
	var materials := panel.get_node_or_null("Summary/Materials") as Label
	var status := panel.get_node_or_null("Summary/Status") as Label
	if not check(panel.is_visible_in_tree() and materials != null and materials.is_visible_in_tree()
			and status != null and status.is_visible_in_tree(), "settlement panel and reward labels are visible"):
		return false
	var displayed := materials.text.split("\n")
	var expected_total := 0
	var expected_inventory: Dictionary = profile_before.materials.duplicate()
	for id: String in rewards:
		var count := int(rewards[id])
		expected_total += count
		expected_inventory[id] = int(expected_inventory.get(id, 0)) + count
		check(displayed.has("%s ×%d" % [MATERIALS.name_of(id), count]), "visible quantity matches ledger for " + id)
	check(displayed.size() == rewards.size() + 1 and displayed[0] == "素材 +%d" % expected_total,
		"visible material total and row count match ledger")

	if fail_first_write:
		check(profile.last_error != OK and not boss.run_rewards_saved, "first settlement encounters a real write error")
		check(status.text == "保存失败，本局收益已保留。", "visible status explains the failed save")
		check(manager.is_run_active() and profile.snapshot() == profile_before,
			"first failure restores the active run and pre-settlement profile")
		check(FileAccess.get_file_as_string(save_path) == disk_before, "first failure leaves the disk save intact")
		press_f()
		await process_frame
		if not check(current_scene == boss and boss.player.is_inside_tree(), "F with blocked writes keeps the player in the Boss arena"):
			return false
		check(manager.ledger == ledger and manager.is_run_active() and ledger.summary() == rewards and boss.coins == RUN_COINS,
			"failed return retains the same active ledger and coins")
		check(profile.snapshot() == profile_before, "failed writes roll back in-memory inventory, coins and marker")
		check(FileAccess.get_file_as_string(save_path) == disk_before and not FileAccess.file_exists(save_path + ".bak"),
			"failed writes leave the original disk save intact")
		if not check(DirAccess.remove_absolute(blocked_path) == OK, "temporary save path restored"):
			return false
	else:
		check(boss.run_rewards_saved and status.text == "已结算 %d 金币" % RUN_COINS, "visible status reports successful settlement")

	press_f()
	await process_frame
	var village = current_scene
	if not check(is_instance_valid(village) and village.level_id == &"village_greyford" and village.startup_complete,
			"F returns to the initialized village"):
		return false
	check(village.save_path == save_path, "village inherits the isolated save path")
	check(village.profile_store.material_inventory == expected_inventory, "village inventory deltas match all displayed materials")
	check(village.save.get_value("village", "coins", 0) == START_COINS + RUN_COINS, "village credits coins once")
	var saved := ConfigFile.new()
	if not check(ProfileStore.load_save(saved, save_path) == OK, "isolated save reloads from disk"):
		return false
	var reloaded := ProfileStore.new()
	reloaded.setup(saved, save_path)
	check(reloaded.material_inventory == expected_inventory, "disk inventory credits each material once")
	check(saved.get_value("village", "coins", 0) == START_COINS + RUN_COINS, "disk credits coins once")
	check(reloaded.settled_runs == [run_id], "disk contains exactly one settlement marker for this run")
	return true

func press_f() -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = KEY_F
		event.keycode = KEY_F
		event.pressed = pressed
		Input.parse_input_event(event)

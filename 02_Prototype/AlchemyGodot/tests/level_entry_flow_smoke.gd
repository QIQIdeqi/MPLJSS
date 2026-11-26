extends SceneTree
## Production scene/object calls, not a mouse-event or visual acceptance test.
## Run without --migration-test: every real write targets this isolated SSD fixture.
const PROFILE := preload("res://scripts/run/profile_store.gd")
const OUTPUT := "res://Evidence/LevelEntry_20261124/flow_test"
const SAVE_PATH := OUTPUT + "/progress.cfg"
var checks: Array[Dictionary] = []
var failures := 0
var active: Node
var config: Node
var fixture_before: Dictionary = {}

func _initialize() -> void:
	run_checks.call_deferred()

func check(ok: bool, message: String) -> bool:
	checks.append({"passed": ok, "check": message})
	if not ok:
		failures += 1
		printerr("LEVEL_ENTRY_FLOW_FAIL: " + message)
	return ok

func read_disk() -> ConfigFile:
	var data := ConfigFile.new()
	check(PROFILE.load_save(data, SAVE_PATH) == OK, "isolated fixture reloads")
	return data

func stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		node.stop()
	for child in node.get_children():
		stop_audio(child)

func run_checks() -> void:
	if not check(not OS.get_cmdline_user_args().has("--migration-test"), "real fixture persistence enabled"):
		await finish_checks()
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	# Remove only the empty directory used by this fixture's forced write failure.
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(SAVE_PATH + ".tmp")):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH + ".tmp"))
	var fixture := ConfigFile.new()
	fixture.set_value("village", "coins", 10)
	fixture.set_value("material_inventory", "dew", 4)
	fixture.set_value("material_inventory", "fire_powder", 5)
	fixture.set_value("ability_inventory", "split", 2)
	check(PROFILE.write_save(fixture, SAVE_PATH) == OK, "fixture starts with two split abilities")
	config = root.get_node("RunConfig")
	config.reset()
	var scene := load("res://scenes/levels/village_greyford.tscn") as PackedScene
	if not check(scene != null, "real registered village scene loads"):
		await finish_checks()
		return
	active = scene.instantiate()
	active.save_path = SAVE_PATH
	root.add_child(active)
	current_scene = active
	active.process_mode = Node.PROCESS_MODE_DISABLED
	if not check(active.startup_complete and active.startup_error.is_empty(), "village finishes initialization"):
		await finish_checks()
		return
	active.entry_select_ui.open()
	active._physics_process(0.0)
	check(active.player.locked, "preparation locks village movement")
	var action := InputEventAction.new()
	action.action = "alchemy"
	action.pressed = true
	active._unhandled_input(action)
	check(not active.workbench_ui.visible, "workbench cannot overlap preparation")
	check(active.profile_store.ability_count("split") == 2, "opening preparation does not consume stock")
	active.on_entry_confirmed(&"unknown_level", &"split")
	check(current_scene == active and active.entry_select_ui.visible, "unknown destination keeps village preparation open")
	check(int(read_disk().get_value("ability_inventory", "split", 0)) == 2, "invalid destination does not debit disk")
	var real_catalog = active.level_catalog
	var invalid_catalog = real_catalog.duplicate(true)
	var invalid_scene := Node2D.new()
	var packed := PackedScene.new()
	check(packed.pack(invalid_scene) == OK, "fixture packs an invalid gameplay root")
	invalid_scene.free()
	check(ResourceSaver.save(packed, OUTPUT + "/invalid_stage.tscn") == OK, "invalid destination fixture saved separately")
	invalid_catalog.find_level(&"greyford_01").scene_path = OUTPUT + "/invalid_stage.tscn"
	active.level_catalog = invalid_catalog
	active.on_entry_confirmed(&"greyford_01", &"split")
	check(current_scene == active and not active.entry_busy and active.entry_select_ui.visible, "uninitializable gameplay scene rolls back to preparation")
	check(not config.entry_confirmed and active.profile_store.ability_count("split") == 2, "failed scene never confirms or consumes ability")
	active.level_catalog = real_catalog
	# A directory where the temporary save file must be created forces a real I/O failure.
	check(DirAccess.make_dir_absolute(ProjectSettings.globalize_path(SAVE_PATH + ".tmp")) == OK, "fixture forces a temporary-file write failure")
	active.on_entry_confirmed(&"greyford_01", &"split")
	check(current_scene == active and not active.entry_busy and active.entry_select_ui.visible, "arrival save failure keeps original village")
	check(not config.entry_confirmed and active.profile_store.ability_count("split") == 2, "arrival save failure restores confirmation and stock")
	check(int(read_disk().get_value("ability_inventory", "split", 0)) == 2, "arrival save failure leaves disk stock intact")
	check(DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH + ".tmp")) == OK, "fixture removes forced failure directory")
	var village := active
	active.entry_select_ui.level_buttons[&"greyford_01"].pressed.emit()
	active.entry_select_ui.ability_buttons[&"split"].pressed.emit()
	check(active.entry_select_ui.selected_ability == &"split", "the split ability card is selected through its button")
	active.entry_select_ui.confirm_button.pressed.emit()
	active = current_scene
	if not check(active != village and active != null and active.combat and not active.stage_is_boss, "final confirm publishes independent normal scene immediately"):
		await finish_checks()
		return
	active.process_mode = Node.PROCESS_MODE_DISABLED
	check(active.startup_complete and active.stage_active and config.entry_confirmed, "published battle is initialized and confirmed")
	check(active.scene_file_path == "res://scenes/levels/greyford_01.tscn" and active.level_id == &"greyford_01", "normal stable ID maps to its own scene")
	check(active.save_path == SAVE_PATH and active.profile_store.save_path == SAVE_PATH, "battle inherits isolated profile path")
	check(active.alchemy_system.ability_id == "split" and active.profile_store.ability_count("split") == 1, "selected ability active and consumed exactly once")
	check_split_in_battle()
	check(int(read_disk().get_value("ability_inventory", "split", 0)) == 1, "successful debit is durable")
	# Calling the production transaction twice with the same receipt must not charge again.
	check(active.profile_store.commit_entry_ability("split", "greyford_01", config.entry_id) and active.profile_store.ability_count("split") == 1, "repeated arrival receipt is idempotent")
	active.hp = 87.0
	active.xp = 7
	active.level = 4
	active.coins = 13
	active.kills = 29
	active.run_time = 301.0
	active.until_attack = 0.31
	active.hurt_cooldown = 0.72
	active.inventory = [3, 2, 1, 0, 0, 0]
	active.player.cooldown = 0.41
	active.alchemy_system.apply_upgrade({"type": "new_skill", "skill_id": &"sk_blast_flask"})
	active.alchemy_system.apply_upgrade({"type": "skill_upgrade", "skill_id": &"sk_blast_flask"})
	active.alchemy_system.apply_upgrade({"type": "skill_upgrade", "skill_id": &"sk_blast_flask"})
	active.alchemy_system.apply_upgrade({"type": "new_skill", "skill_id": &"sk_brittle_mark"})
	var runtime = active.alchemy_system.skills.runtime_for(&"sk_blast_flask")
	runtime.reset_cooldown()
	var cast_duration: float = runtime.cooldown_total
	runtime.cooldown_left = 1.23
	runtime.config["stage_test_marker"] = "preserved"
	active.alchemy_system.skills.chain_cooldowns = {&"link_blast_mark": 2.5}
	active.alchemy_system.synergies.cooldowns = {&"test_synergy": 1.4}
	active.run_manager.collect_material("dew", 3)
	active.run_manager.collect_material("fire_powder", 2)
	active.brew.pills = {1: {"main":0,"support":1,"level":2,"quality":1,"trait":0}}
	active.brew.equipped.append(1)
	active.brew.bag.append(2)
	active.brew.cooldowns = {1: 0.67}
	var normal_seed: int = active.rng.seed
	var run_id: String = active.run_manager.run_id
	var normal_path: String = active.scene_file_path
	var expected_seed: int = int((str(normal_seed) + ":greyford_01_boss").hash()) + 1
	active.portal_ready = true
	active.player.position = active.portal_position
	var boss_failure_catalog = real_catalog.duplicate(true)
	boss_failure_catalog.find_level(&"greyford_01_boss").scene_path = OUTPUT + "/invalid_stage.tscn"
	active.level_catalog = boss_failure_catalog
	active.enter_boss()
	check(current_scene == active and active.portal_ready and active.hp == 87.0 and active.run_manager.ledger.materials == {"dew":3,"fire_powder":2}, "failed Boss scene preserves current battle and ledger")
	check(int(read_disk().get_value("ability_inventory", "split", 0)) == 1, "failed Boss scene does not charge entry again")
	active.level_catalog = real_catalog
	var normal := active
	active.enter_boss()
	active = current_scene
	if not check(active != normal and active != null and active.stage_is_boss, "voluntary portal publishes an independent Boss scene"):
		await finish_checks()
		return
	active.process_mode = Node.PROCESS_MODE_DISABLED
	check(active.scene_file_path != normal_path and active.level_id == &"greyford_01_boss", "Boss stable ID has separate scene")
	check(active.startup_complete and active.boss != null, "Boss controller starts inside its own stage")
	check(active.alchemy_system.skills.ability_id == &"split", "Boss continues using the selected split alchemy")
	check(active.run_manager.run_id == run_id and config.entry_confirmed, "Boss is the same confirmed run")
	check(active.hp == 87.0 and active.xp == 7 and active.level == 4 and active.coins == 13 and active.kills == 29, "Boss preserves health XP level coins kills")
	check(active.run_time == 301.0 and is_equal_approx(active.until_attack, 0.31) and is_equal_approx(active.hurt_cooldown, 0.72), "Boss preserves elapsed time and combat cooldowns")
	check(active.inventory == [3,2,1,0,0,0] and is_equal_approx(active.player.cooldown, 0.41), "Boss preserves inventory and player cooldown")
	runtime = active.alchemy_system.skills.runtime_for(&"sk_blast_flask")
	check(runtime != null and runtime.level == 3 and is_equal_approx(runtime.cooldown_left, 1.23) and runtime.config.get("stage_test_marker") == "preserved", "Boss preserves skill level cooldown and configuration")
	check(runtime != null and is_equal_approx(runtime.cooldown_total, cast_duration), "Boss preserves the cooldown HUD progress denominator")
	var unlocked: Array = active.alchemy_system.skills.unlocked_chains()
	check(active.alchemy_system.skills.runtimes.size() == 2 and unlocked.size() == 1 and unlocked[0].id == "link_blast_mark", "Boss preserves the combo derived from two occupied slots")
	check(active.alchemy_system.skills.chain_cooldowns.get(&"link_blast_mark") == 2.5 and active.alchemy_system.synergies.cooldowns.get(&"test_synergy") == 1.4, "Boss preserves chain and synergy cooldowns")
	check(active.run_manager.ledger.materials == {"dew":3,"fire_powder":2} and active.run_manager.is_run_active(), "Boss preserves unsettled material ledger")
	check(active.brew.pills.has(1) and active.brew.equipped == [1] and active.brew.bag == [2] and active.brew.cooldowns.get(1) == 0.67, "Boss preserves current drag-brew pills equipment bag and cooldowns")
	check(active.field_seed == expected_seed and active.field_seed != normal_seed and active.layout_preset.boss, "Boss layout has derived independent stage seed and preset")
	check(active.rng.seed == normal_seed, "combat RNG identity continues across independent layout generation")
	check(int(read_disk().get_value("ability_inventory", "split", 0)) == 1, "Boss entry never consumes another ability")
	active.finish(true)
	var disk := read_disk()
	check(active.ended and active.run_rewards_saved, "finish settles complete run")
	check(int(disk.get_value("village", "coins", 0)) == 23, "final coins written once")
	check(int(disk.get_value("material_inventory", "dew", 0)) == 7 and int(disk.get_value("material_inventory", "fire_powder", 0)) == 7, "material ledger written once")
	check(disk.get_value("settled_runs", "ids", []).has(run_id), "settled run ID is durable")
	active.finish(true)
	check(active.settle_run(), "repeat finish and settlement succeed idempotently")
	disk = read_disk()
	check(int(disk.get_value("village", "coins", 0)) == 23 and int(disk.get_value("material_inventory", "dew", 0)) == 7, "repeat finish never duplicates rewards")
	# The production exit must transfer this custom profile path to the menu.
	active.leave_run(true)
	await process_frame
	active = current_scene
	if check(active != null and active.scene_file_path == "res://scenes/menu.tscn", "unified exit reaches menu"):
		check(active.save_path == SAVE_PATH and not active.get_node("Actions/Continue").disabled, "menu continues the same isolated profile")
	check(not config.entry_confirmed and config.pending_run.is_empty(), "exit clears transient entry and stage handoff")
	disk = read_disk()
	check(int(disk.get_value("ability_inventory", "split", 0)) == 1 and int(disk.get_value("village", "coins", 0)) == 23, "exit does not double-charge or double-settle")
	active.enter_village()
	active = current_scene
	if check(active != null and active.level_id == &"village_greyford", "menu Continue returns to catalog village"):
		active.process_mode = Node.PROCESS_MODE_DISABLED
		check(active.save_path == SAVE_PATH and active.startup_complete, "Continue transfers isolated profile before village initialization")
		check(active.profile_store.ability_count("split") == 1 and int(active.save.get_value("village", "coins", 0)) == 23, "Continue reloads final ability and coin balances")
	await finish_checks()

func check_split_in_battle() -> void:
	var skills: SkillManager = active.alchemy_system.skills
	var hud := active.get_node("Interface/CombatHUD")
	check(skills.ability_id == &"split" and skills.runtimes.is_empty(), "split is armed before the first skill reward")
	hud._process(0.0)
	check(hud.phase_caption.text.contains("分裂炼金（等待首个技能）"), "HUD explains why no equipped skill has split yet")
	var targets: Array[Dictionary] = []
	for offset in [Vector2(130, -20), Vector2(144, 25)]:
		var body := Node2D.new()
		body.position = active.player.position + offset
		active.actors.add_child(body)
		targets.append({"body":body, "hp":100.0})
	active.enemies.append(targets[0])
	active.launch_basic_projectile(targets[0])
	check(active.basic_projectiles.size() == 1, "the starting magic bolt remains a single basic attack")
	active.enemies.erase(targets[0])
	active.apply_upgrade({"type":"new_skill", "skill_id":&"sk_brittle_mark"})
	hud._process(0.0)
	check(hud.phase_caption.text.ends_with("分裂炼金"), "HUD confirms split alchemy once a skill is equipped")
	active.alchemy_system.tick(0.0, active.player.position, targets, active.damage_brew_enemy)
	var sides: Array[int] = []
	for mark: Dictionary in skills.brittle_marks.values():
		sides.append(int(mark.split_side))
	check(sides.size() == 2 and -1 in sides and 1 in sides, "the first equipped mark skill splits onto two live targets")
	active.clear_combat_effects()
	skills.clear()
	for entry in targets:
		entry.body.queue_free()

func finish_checks() -> void:
	for child in root.get_children():
		stop_audio(child)
	for child in root.get_children():
		if child != config:
			child.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.3).timeout
	var report := {"checks": checks, "count": checks.size(), "failures": failures, "save_path": SAVE_PATH, "player_save_touched": false, "method": "production object calls, not mouse/visual acceptance"}
	var output := FileAccess.open(OUTPUT + "/verification.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
	print("LEVEL_ENTRY_FLOW_SMOKE_%s %d checks" % ["PASS" if failures == 0 else "FAIL", checks.size()])
	quit(0 if failures == 0 else 1)

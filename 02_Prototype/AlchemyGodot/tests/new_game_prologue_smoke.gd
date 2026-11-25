extends SceneTree
## Production menu/overlay objects with isolated SSD saves. Do not run with --migration-test.

const MENU_PATH := "res://scenes/menu.tscn"
const PROFILE := preload("res://scripts/run/profile_store.gd")
const STORY_PATH := "res://stories/prologue.tres"
const FIXTURES := "res://Evidence/NewGamePrologue_20261125/fixtures"

var checks := 0
var failures := 0
var fixture_dir := ""
var menu_scene: PackedScene
var stub_script: GDScript

func _initialize() -> void:
	run_checks.call_deferred()

func check(condition: bool, message: String) -> bool:
	checks += 1
	if not condition:
		failures += 1
		push_error("NEW_GAME_PROLOGUE: " + message)
	return condition

func stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		node.stop()
	for child in node.get_children():
		stop_audio(child)

func make_menu(path: String, stub := true, override_script: GDScript = null) -> Control:
	var menu := menu_scene.instantiate() as Control
	if override_script != null:
		menu.set_script(override_script)
	elif stub:
		menu.set_script(stub_script)
	menu.save_path = path
	menu.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(menu)
	current_scene = menu
	stop_audio(menu)
	return menu

func dispose(node: Node) -> void:
	if is_instance_valid(node):
		if current_scene == node:
			current_scene = null
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		node.queue_free()
	await process_frame

func read_save(path: String) -> ConfigFile:
	var data := ConfigFile.new()
	check(PROFILE.load_save(data, path) == OK, "isolated real save reloads: " + path.get_file())
	return data

func seed_save(path: String, completed: Variant = null) -> void:
	var data := ConfigFile.new()
	data.set_value("village", "coins", 73)
	data.set_value("material_inventory", "dew", 7)
	data.set_value("material_inventory", "fire_powder", 5)
	data.set_value("ability_inventory", "burst", 3)
	if completed != null:
		data.set_value("story", "prologue_completed", bool(completed))
	check(PROFILE.write_save(data, path) == OK, "isolated known inventory is saved")

func has_overlay(menu: Control) -> bool:
	return is_instance_valid(menu.prologue) and menu.prologue.visible

func has_error(menu: Control) -> bool:
	if is_instance_valid(menu.message) and menu.message.visible and not menu.message.text.is_empty():
		return true
	var overlay_error: Label = menu.prologue.get_node_or_null("Error") if has_overlay(menu) else null
	return overlay_error != null and overlay_error.visible and not overlay_error.text.is_empty()

func block_write(path: String) -> void:
	check(DirAccess.make_dir_absolute(ProjectSettings.globalize_path(path + ".tmp")) == OK, "temporary-file directory forces a real save failure")

func unblock_write(path: String) -> void:
	check(DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".tmp")) == OK, "only this test's empty write-failure directory is removed")

func run_checks() -> void:
	if not check(not OS.get_cmdline_user_args().has("--migration-test"), "production file persistence is enabled for isolated fixtures"):
		quit(1)
		return
	# Parse Menu only after the SceneTree has initialized configured autoloads.
	# A static inner class extends Menu too early under --script, before RunConfig is registered.
	await process_frame
	if root.get_node_or_null("RunConfig") == null:
		var config: Node = load("res://scripts/run/run_config.gd").new()
		config.name = "RunConfig"
		root.add_child(config)
	menu_scene = load(MENU_PATH) as PackedScene
	stub_script = GDScript.new()
	stub_script.source_code = "extends \"res://scripts/menu.gd\"\nvar village_entries := 0\nfunc enter_village() -> bool:\n\tvillage_entries += 1\n\treturn true\n"
	if not check(stub_script.reload() == OK and menu_scene != null, "runtime menu stub compiles after autoload initialization"):
		quit(1)
		return
	fixture_dir = FIXTURES + "/run_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(fixture_dir)) == OK, "unique fixture directory exists on project SSD")
	var source_hash := FileAccess.get_sha256(STORY_PATH)
	var book_hash := FileAccess.get_sha256("res://picture_books/prologue/prologue.tres")
	var pending_path := fixture_dir + "/pending.cfg"
	var menu := make_menu(pending_path)
	check(menu.get_node("Actions/Continue").disabled, "first launch has no continue action")
	menu.get_node("Actions/Start").pressed.emit()
	if not check(has_overlay(menu), "new-game button opens the actual prologue overlay"):
		await dispose(menu)
		quit(1)
		return
	check(menu.village_entries == 0 and menu.prologue.player.index == 0, "first launch shows the first illustration before entering village")
	var data := read_save(pending_path)
	check(int(data.get_value("village", "coins", -1)) == 0 and not bool(data.get_value("story", "prologue_completed", true)), "new real save records zero coins and an unfinished prologue")
	menu.prologue.next_page()
	check(menu.prologue.player.index == 0 and not menu.prologue.player.is_transitioning, "first next-page action completes the initial entry only")
	menu.prologue.next_page()
	check(menu.prologue.player.index == 1, "second next-page action advances the shared player")
	menu.prologue.previous_page()
	check(menu.prologue.player.index == 0, "previous-page action returns the shared player to the first illustration")
	menu.prologue.next_page()
	menu.prologue.next_page()
	var overlay_id: int = menu.prologue.get_instance_id()
	var pending_hash := FileAccess.get_sha256(pending_path)
	menu.start_new()
	check(has_overlay(menu) and menu.prologue.get_instance_id() == overlay_id and menu.prologue.player.index == 1, "duplicate new-game request cannot reset the running prologue")
	check(FileAccess.get_sha256(pending_path) == pending_hash, "duplicate start does not rewrite or reset the pending save")
	menu.prologue.return_to_menu()
	check(not has_overlay(menu) and menu.village_entries == 0, "return-to-menu closes prologue without entering village")
	check(not bool(read_save(pending_path).get_value("story", "prologue_completed", true)), "cancelling keeps the on-disk prologue unfinished")
	await dispose(menu)
	menu = make_menu(pending_path)
	check(not menu.get_node("Actions/Continue").disabled, "a pending save is available after menu recreation")
	menu.get_node("Actions/Continue").pressed.emit()
	check(has_overlay(menu) and menu.prologue.player.index == 0 and menu.village_entries == 0, "continue after restart replays the unfinished prologue from the first illustration")
	if has_overlay(menu):
		var player: Control = menu.prologue.player
		for i in 8:
			player._process(100.0)
	check(menu.village_entries == 1, "natural final-page completion enters village once")
	check(bool(read_save(pending_path).get_value("story", "prologue_completed", false)), "natural completion persists the finished flag before village entry")
	await dispose(menu)
	var skip_path := fixture_dir + "/skip.cfg"
	menu = make_menu(skip_path)
	menu.start_new()
	if check(has_overlay(menu), "skip case starts a real prologue"):
		menu.prologue.finish_prologue()
	check(menu.village_entries == 1 and bool(read_save(skip_path).get_value("story", "prologue_completed", false)), "explicit skip uses the same successful saved completion path")
	await dispose(menu)
	var old_path := fixture_dir + "/old.cfg"
	seed_save(old_path)
	var old_hash := FileAccess.get_sha256(old_path)
	menu = make_menu(old_path)
	menu.continue_game()
	check(menu.village_entries == 1 and not has_overlay(menu), "legacy saves without a story flag go straight to village")
	data = read_save(old_path)
	check(int(data.get_value("village", "coins", 0)) == 73 and int(data.get_value("material_inventory", "dew", 0)) == 7 and int(data.get_value("ability_inventory", "burst", 0)) == 3, "legacy continue keeps coins, materials and abilities")
	check(FileAccess.get_sha256(old_path) == old_hash, "legacy continue does not replace the old save with a fresh game")
	menu.start_new()
	check(has_overlay(menu) and FileAccess.get_sha256(old_path + ".before_new_game") == old_hash, "new game keeps an exact separate copy of the previous profile")
	if has_overlay(menu):
		menu.prologue.return_to_menu()
	var first_pending_hash := FileAccess.get_sha256(old_path)
	menu.start_new()
	check(has_overlay(menu) and FileAccess.get_sha256(old_path + ".before_new_game") == old_hash, "starting again after cancelling cannot overwrite original profile A")
	check(FileAccess.file_exists(old_path + ".before_new_game.2") and FileAccess.get_sha256(old_path + ".before_new_game.2") == first_pending_hash, "second new game keeps its prior pending profile as a separate numbered snapshot")
	if has_overlay(menu):
		menu.prologue.return_to_menu()
	var second_pending_hash := FileAccess.get_sha256(old_path)
	block_write(old_path)
	menu.start_new()
	check(not has_overlay(menu) and has_error(menu) and FileAccess.get_sha256(old_path) == second_pending_hash, "a later failed new-game write keeps the active pending profile intact")
	check(FileAccess.get_sha256(old_path + ".before_new_game") == old_hash and FileAccess.get_sha256(old_path + ".before_new_game.2") == first_pending_hash, "failed later start preserves both original and numbered backups")
	unblock_write(old_path)
	menu.start_new()
	if has_overlay(menu):
		menu.prologue.finish_prologue()
	check(FileAccess.get_sha256(old_path + ".before_new_game") == old_hash, "prologue completion cannot replace the previous-game backup")
	await dispose(menu)
	var memory_stub := GDScript.new()
	memory_stub.source_code = stub_script.source_code + "func profile_path() -> String:\n\treturn \"\"\n"
	if check(memory_stub.reload() == OK, "in-memory profile-mode menu stub compiles"):
		var completed_hash := FileAccess.get_sha256(old_path)
		menu = make_menu(old_path, true, memory_stub)
		menu.continue_game()
		check(menu.village_entries == 0 and not has_overlay(menu) and has_error(menu), "empty profile path without a pending in-memory save cannot continue a disk profile")
		check(FileAccess.get_sha256(old_path) == completed_hash, "in-memory continue leaves the isolated disk profile untouched")
		await dispose(menu)
	var failure_path := fixture_dir + "/failure.cfg"
	menu = make_menu(failure_path)
	menu.start_new()
	var before_failure := FileAccess.get_sha256(failure_path)
	block_write(failure_path)
	if check(has_overlay(menu), "write-failure case keeps the actual overlay"):
		menu.prologue.finish_prologue()
	check(menu.village_entries == 0 and has_overlay(menu) and has_error(menu), "failed completion displays an error and keeps prologue available for retry")
	check(FileAccess.get_sha256(failure_path) == before_failure and not bool(read_save(failure_path).get_value("story", "prologue_completed", true)), "failed completion preserves the exact unfinished disk save")
	unblock_write(failure_path)
	menu.complete_prologue()
	check(menu.village_entries == 1 and bool(read_save(failure_path).get_value("story", "prologue_completed", false)), "retry saves completion successfully before entering village")
	await dispose(menu)
	var bad_path := fixture_dir + "/bad_story_save.cfg"
	seed_save(bad_path, true)
	var bad_hash := FileAccess.get_sha256(bad_path)
	menu = make_menu(bad_path)
	var invalid: Resource = ResourceLoader.load(STORY_PATH, "", ResourceLoader.CACHE_MODE_IGNORE).duplicate(true)
	invalid.find_node("story_p00_prologue").before_book_path = "res://picture_books/prologue/not_a_real_book.tres"
	var invalid_path := fixture_dir + "/invalid_story.tres"
	check(ResourceSaver.save(invalid, invalid_path) == OK, "invalid reference fixture is saved outside production resources")
	menu.prologue_story_path = invalid_path
	menu.start_new()
	check(menu.village_entries == 0 and not has_overlay(menu) and has_error(menu), "invalid bound book is rejected before starting a new game")
	check(FileAccess.get_sha256(bad_path) == bad_hash, "bad story cannot overwrite the existing inventory save")
	menu.prologue_story_path = "res://stories/no_such_story.tres"
	menu.start_new()
	check(FileAccess.get_sha256(bad_path) == bad_hash and not has_overlay(menu), "missing story is also rejected without resetting old progress")
	menu.prologue_story_path = STORY_PATH
	block_write(bad_path)
	menu.start_new()
	check(menu.village_entries == 0 and not has_overlay(menu) and FileAccess.get_sha256(bad_path) == bad_hash, "failed new-save write never replaces old progress or opens prologue")
	unblock_write(bad_path)
	await dispose(menu)
	# This final case uses the original menu method and the real registered village, not the stub.
	var village_path := fixture_dir + "/actual_village.cfg"
	seed_save(village_path, true)
	menu = make_menu(village_path, false)
	menu.continue_game()
	var village := current_scene
	if check(village != menu and village != null and village.scene_file_path == "res://scenes/levels/village_greyford.tscn", "finished save enters the actual registered village scene"):
		village.process_mode = Node.PROCESS_MODE_DISABLED
		stop_audio(village)
		check(village.save_path == village_path and village.startup_complete, "real village initializes with the isolated save path")
		check(int(village.save.get_value("village", "coins", 0)) == 73 and village.profile_store.material_count("dew") == 7 and village.profile_store.ability_count("burst") == 3, "real village loads existing coins and inventory")
		check(village.profile_store.save_profile(), "real village profile saves through the production writer")
		data = read_save(village_path)
		check(bool(data.get_value("story", "prologue_completed", false)) and int(data.get_value("village", "coins", 0)) == 73 and int(data.get_value("ability_inventory", "burst", 0)) == 3, "village profile saving retains completed story flag and inventory")
		var saved_hash := FileAccess.get_sha256(village_path)
		var cancel := InputEventAction.new()
		cancel.action = "ui_cancel"
		cancel.pressed = true
		village._unhandled_input(cancel)
		var returned := current_scene as Control
		if check(returned != village and returned != null and returned.scene_file_path == MENU_PATH, "real village ui_cancel input returns to the production menu"):
			returned.process_mode = Node.PROCESS_MODE_DISABLED
			stop_audio(returned)
			check(returned.save_path == village_path, "village return passes the fixture profile path before menu initialization")
			check(not returned.get_node("Actions/Continue").disabled and not has_overlay(returned), "returned menu offers continue without starting prologue")
			check(FileAccess.get_sha256(village_path) == saved_hash, "village return performs no combat settlement or profile reset")
			returned.continue_game()
			var resumed := current_scene
			if check(resumed != returned and resumed != null and resumed.scene_file_path == "res://scenes/levels/village_greyford.tscn", "continue after village return re-enters village without replaying prologue"):
				resumed.process_mode = Node.PROCESS_MODE_DISABLED
				stop_audio(resumed)
				check(resumed.save_path == village_path and resumed.startup_complete, "continued village still uses the fixture path")
				check(bool(resumed.save.get_value("story", "prologue_completed", false)) and int(resumed.save.get_value("village", "coins", 0)) == 73 and resumed.profile_store.material_count("dew") == 7 and resumed.profile_store.ability_count("burst") == 3, "ui_cancel and continue preserve story completion, coins and all stock")
				check(FileAccess.get_sha256(village_path) == saved_hash, "full village-menu-village round trip leaves the saved profile unchanged")
				await dispose(resumed)
			else:
				await dispose(returned)
		else:
			await dispose(village)
	else:
		await dispose(menu)
	# Exercise final-page input with the original menu, so the finished signal really detaches the player.
	for route: String in ["enter", "space", "root_click"]:
		var input_path := fixture_dir + "/last_page_" + route + ".cfg"
		menu = make_menu(input_path, false)
		menu.start_new()
		if not check(has_overlay(menu), "last-page %s case opens production prologue" % route):
			await dispose(menu)
			continue
		var overlay: Control = menu.prologue
		var player: Control = overlay.player
		player.play(overlay.book, 7)
		player.advance()
		check(player.index == 7 and not player.is_transitioning, "last-page %s input starts from the fully visible final picture" % route)
		if route == "root_click":
			var click := InputEventMouseButton.new()
			click.pressed = true
			click.button_index = MOUSE_BUTTON_LEFT
			click.position = Vector2(800, 350)
			overlay._gui_input(click)
		else:
			var confirm := InputEventKey.new()
			confirm.pressed = true
			confirm.keycode = KEY_ENTER if route == "enter" else KEY_SPACE
			player._unhandled_input(confirm)
		var destination := current_scene
		if check(destination != menu and destination != null and destination.scene_file_path == "res://scenes/levels/village_greyford.tscn", "last-page %s input finishes into the actual village" % route):
			destination.process_mode = Node.PROCESS_MODE_DISABLED
			stop_audio(destination)
			check(destination.save_path == input_path and destination.startup_complete, "last-page %s input preserves the fixture path through synchronous scene removal" % route)
			check(bool(read_save(input_path).get_value("story", "prologue_completed", false)), "last-page %s input persists completion before village entry" % route)
			await dispose(destination)
		else:
			await dispose(menu)
	check(FileAccess.get_sha256(STORY_PATH) == source_hash and FileAccess.get_sha256("res://picture_books/prologue/prologue.tres") == book_hash, "all scenarios leave production story and book files unchanged")
	if failures == 0:
		print("NEW_GAME_PROLOGUE_PASS checks=%d first_start pending_restart manual natural skip legacy real_village write_retry invalid_story fixture=%s" % [checks, fixture_dir])
	quit(0 if failures == 0 else 1)

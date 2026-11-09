extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func require(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok

func capture(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"):
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var filename := ProjectSettings.globalize_path("res://Evidence/migration-" + name + ".png")
	get_root().get_texture().get_image().save_png(filename)

func action(name: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = true
	return event

func run() -> void:
	change_scene_to_file("res://scenes/menu.tscn")
	await scene_changed
	if not require(current_scene.name == &"MainMenu", "menu entry"): return
	await capture("menu")
	current_scene.enter_village()
	await scene_changed
	var village := current_scene
	var before: Vector2 = village.camera.position
	Input.action_press(&"move_right")
	await create_timer(0.4).timeout
	Input.action_release(&"move_right")
	if not require(village.camera.position.x > before.x and village.camera.zoom.x > 1, "camera follows movement"): return
	await capture("village")
	Input.action_press(&"move_up")
	await create_timer(0.39).timeout
	Input.action_release(&"move_up")
	Input.action_press(&"move_right")
	await create_timer(2.45).timeout
	Input.action_release(&"move_right")
	if not require(village.player.position.distance_to(village.GATE) < 92, "walkable route to village gate"): return
	village._unhandled_input(action(&"interact"))
	await scene_changed
	var battle := current_scene
	if not require(battle.tiles.size() > 0 and battle.enemies.size() == 8 and battle.first_brew and battle.inventory == [1, 1, 1, 0, 0, 0], "generated battle and live teaching starter"): return
	await capture("battle")
	battle._unhandled_input(action(&"alchemy"))
	var brew = battle.brew
	await capture("brew-input")
	var main_slot: Control = brew.get_node("Panel/MainSlot")
	var support_slot: Control = brew.get_node("Panel/SupportSlot")
	var main := {"material": 0, "is_support": false}
	var support := {"material": 1, "is_support": true}
	if not require(brew.visible and main_slot._can_drop_data(Vector2.ZERO, main) and not support_slot._can_drop_data(Vector2.ZERO, main), "drag role validation"): return
	main_slot._drop_data(Vector2.ZERO, main)
	support_slot._drop_data(Vector2.ZERO, support)
	var confirm: Button = brew.get_node("Panel/Confirm")
	confirm.pressed.emit()
	if not require(battle.inventory[0] == 1 and brew.phase == 1, "first confirm does not spend materials"): return
	brew.select_material(2, true)
	if not require(brew.phase == 0, "recipe change invalidates confirmation"): return
	support_slot._drop_data(Vector2.ZERO, support)
	confirm.pressed.emit()
	confirm.pressed.emit()
	if not require(battle.inventory[0] == 0 and battle.inventory[1] == 0 and brew.phase == 2 and brew.sparks.emitting and not brew.blocks_world(), "second confirm spends both ingredients and runs mobile particles"): return
	await capture("brew")
	await create_timer(2.65).timeout
	if not require(brew.phase == 3 and not brew.sparks.emitting and brew.blocks_world(), "brew result modal"): return
	confirm.pressed.emit()
	if not require(brew.pills.size() == 1 and brew.equipped.size() == 1 and not brew.visible and not battle.first_brew, "result acceptance equips pill"): return
	battle.add_pickup(battle.player.position, 0)
	battle.add_pickup(battle.player.position, 1)
	await physics_frame
	await physics_frame
	if not require(battle.coins == 1 and battle.xp == 1, "separate reward pickups"): return
	battle.first_brew = true
	battle.run_time = battle.portal_open_seconds - 1
	await physics_frame
	await physics_frame
	if not require(not battle.portal_ready, "portal before opening time"): return
	battle.run_time = battle.portal_open_seconds
	battle.player.position = battle.PORTAL
	await physics_frame
	await physics_frame
	if not require(battle.portal_ready, "portal opens without tutorial completion"): return
	battle._unhandled_input(action(&"interact"))
	if not require(battle.portal_dialog.visible, "confirm Boss entry"): return
	battle.portal_dialog.hide()
	if not require(not is_instance_valid(battle.boss) and battle.portal_ready, "cancel returns to field"): return
	battle._unhandled_input(action(&"interact"))
	var before_hp: float = battle.hp
	battle.portal_dialog.get_ok_button().pressed.emit()
	if not require(is_instance_valid(battle.boss) and battle.enemies.size() == 1 and battle.hp == before_hp and brew.equipped.size() == 1 and battle.boss.preparation > 0, "Boss preserves run state"): return
	battle._unhandled_input(action(&"alchemy"))
	var preparation: float = battle.boss.preparation
	await create_timer(0.2).timeout
	if not require(battle.boss.preparation == preparation, "Boss preparation pauses for alchemy"): return
	brew.toggle()
	battle.boss.preparation = 0.0
	battle.boss.next_dash = false
	battle.boss.start_attack()
	battle.boss.elapsed = 1.24
	await physics_frame
	await physics_frame
	if not require(battle.boss.shots.size() == 5, "first five-shot wave"): return
	battle.boss.elapsed = 0.79
	await physics_frame
	await physics_frame
	if not require(battle.boss.wave == 2 and battle.boss.shots.size() == 10, "second five-shot wave"): return
	battle.boss.next_dash = true
	battle.boss.start_attack()
	await capture("boss")
	battle.boss.elapsed = 0.61
	await physics_frame
	await physics_frame
	if not require(battle.boss.locked, "dash aim locks"): return
	battle.boss.elapsed = 0.99
	await physics_frame
	await physics_frame
	if not require(battle.boss.phase == battle.boss.Phase.DASH, "dash starts"): return
	battle.damage_enemy(battle.boss.entry, battle.boss.MAX_HP)
	if not require(battle.ended and battle.save.get_value("village", "coins") == 1, "Boss victory settles coins"): return
	battle._unhandled_input(action(&"interact"))
	await scene_changed
	if not require(current_scene.name == &"Village", "return to village"): return
	change_scene_to_file("res://scenes/battle.tscn")
	await scene_changed
	var skipped := current_scene
	skipped.run_time = skipped.portal_open_seconds
	skipped.player.position = skipped.PORTAL
	await physics_frame
	await physics_frame
	skipped._unhandled_input(action(&"interact"))
	skipped.portal_dialog.get_ok_button().pressed.emit()
	if not require(skipped.first_brew and skipped.brew.equipped.is_empty() and is_instance_valid(skipped.boss), "can enter Boss on a fresh run without brewing"): return
	print("ALCHEMY_GODOT_MIGRATION_PASS menu camera battle intro drag brew particles coins xp free_boss confirm cancel prep fan dash settlement")
	current_scene.music.stop()
	await create_timer(0.15).timeout
	quit()

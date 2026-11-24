extends SceneTree

const ENEMY := preload("res://scripts/field_enemy.gd")
const BOSS := preload("res://scripts/boss_arena.gd")
const WORLD := preload("res://scripts/hd_battle_world.gd")
const KINDS := ["skeleton", "bat", "spider", "wolf", "slime", "mushroom", "water_spirit"]
const PREFIX := "res://Evidence/HitFeedback_20261124/monster_flash_smoke"

var checks: Array[Dictionary] = []
var failures := 0
var actors := Node2D.new()
var world

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, detail: String) -> void:
	checks.append({"passed":ok, "check":detail})
	if not ok:
		failures += 1
		printerr("MONSTER_FLASH_FAIL: " + detail)

func red(color: Color) -> bool:
	return color.r > color.g and color.r > color.b and color.a > .99

func sync(source: Sprite2D, position: Vector2) -> Color:
	var live: Dictionary[int, bool] = {}
	world.update_enemy_card(source, position, live)
	return world.actor_cards[source.get_instance_id()].modulate

func check_material(source: Sprite2D, position: Vector2, label: String, flashing: bool) -> void:
	sync(source, position)
	var card: Sprite3D = world.actor_cards[source.get_instance_id()]
	check(source.material is ShaderMaterial, label + ": Canvas flash material remains attached")
	if source.material is ShaderMaterial:
		check(is_equal_approx(float(source.material.get_shader_parameter("flash")), 1.0 if flashing else 0.0),
			label + ": Canvas flash uniform follows actual flash phase")
	check((card.material_override is ShaderMaterial) == flashing,
		label + ": HD material active only during flash")
	if flashing and card.material_override is ShaderMaterial:
		check(card.material_override.get_shader_parameter("sprite_texture") == source.texture,
			label + ": HD flash samples current reaction atlas")
		check(is_equal_approx(float(card.material_override.get_shader_parameter("opacity")), source.modulate.a),
			label + ": HD flash preserves source opacity")
	check(card.texture == source.texture and card.frame_coords == source.frame_coords
		and card.hframes == source.hframes and card.vframes == source.vframes,
		label + ": HD frame coordinates match current artwork")

func run() -> void:
	if DirAccess.make_dir_recursive_absolute("res://Evidence/HitFeedback_20261124") != OK:
		push_error("Cannot create monster flash test output directory")
		quit(1)
		return
	root.add_child(actors)
	world = WORLD.new()
	root.add_child(world)
	world.add_child(world.attack_effects)
	for kind in KINDS.size():
		test_enemy(kind)
	test_boss()
	await test_damage_entry()
	world.free()
	actors.free()
	await process_frame
	await process_frame
	var file := FileAccess.open(PREFIX + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failures == 0, "failures":failures,
		"checks":checks, "scope":"Seven real monster sprites, Boss, reaction frame preservation, repeat hits, restoration, death alpha and HD card color copying; pixel appearance requires a graphical check."}, "\t"))
	print("MONSTER_FLASH_%s: %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks.size(), failures])
	quit(0 if failures == 0 else 1)

func test_enemy(kind: int) -> void:
	var name: String = KINDS[kind]
	var enemy := ENEMY.new()
	enemy.setup(kind, Rect2(0, 0, 1280, 720), load("res://art/enemies/" + name + ".png"))
	actors.add_child(enemy)
	enemy.position = Vector2(500, 400)
	enemy.state = enemy.State.RECOVER
	enemy.remaining = 10.0
	enemy.show_hurt()
	check(red(enemy.art.modulate), name + ": hit turns red immediately")
	check(enemy.art.texture == enemy.REACTIONS[kind] and enemy.art.frame_coords.y == 0,
		name + ": generated hurt frames stay active")
	check(sync(enemy.art, enemy.position) == enemy.art.modulate, name + ": HD card receives red modulation")
	check_material(enemy.art, enemy.position, name + " hit", true)
	enemy.advance(.04, enemy.position, reject_hurt, ignore_web)
	check(red(enemy.art.modulate), name + ": red remains during first 40ms")
	enemy.show_hurt()
	enemy.advance(.08, enemy.position, reject_hurt, ignore_web)
	check(red(enemy.art.modulate), name + ": repeated hit refreshes short flash")
	enemy.advance(.03, enemy.position, reject_hurt, ignore_web)
	check(enemy.art.modulate == Color.WHITE, name + ": flash restores after 100ms from last hit")
	check(enemy.hurt_left > 0 and enemy.art.texture == enemy.REACTIONS[kind] and enemy.art.frame_coords.x % 2 == 1,
		name + ": second hurt frame continues after flash ends")
	check(sync(enemy.art, enemy.position) == Color.WHITE, name + ": HD card also restores")
	check_material(enemy.art, enemy.position, name + " restored", false)
	enemy.state = enemy.State.WINDUP
	enemy.remaining = 1.0
	enemy.show_hurt()
	enemy.advance(.11, enemy.position, reject_hurt, ignore_web)
	check(enemy.art.modulate == Color(1.19, 1.08, .89), name + ": windup warning color restores after flash")
	enemy.show_hurt()
	var death := enemy.play_death()
	check(red(enemy.art.modulate) and enemy.art.frame_coords.y == 1,
		name + ": final hit flashes on generated death frame")
	check_material(enemy.art, enemy.position, name + " fatal hit", true)
	enemy.show_hurt()
	death.custom_step(.11)
	check(enemy.art.modulate == Color.WHITE, name + ": death flash restores after 100ms")
	check_material(enemy.art, enemy.position, name + " death restored", false)
	enemy.show_hurt()
	check(enemy.art.modulate == Color.WHITE, name + ": dying monster ignores later hurt flash")
	death.custom_step(.8)
	check(enemy.art.modulate.a < .01 and is_equal_approx(enemy.art.modulate.r, 1.0),
		name + ": death alpha fade remains intact")
	enemy.free()

func test_boss() -> void:
	var boss := BOSS.new()
	actors.add_child(boss)
	boss.setup(actors, true)
	var player := CharacterBody2D.new()
	actors.add_child(player)
	player.position = Vector2(650, 450)
	boss.preparation = 2.0
	boss.show_hurt()
	check(red(boss.art.modulate), "Boss: hit turns red immediately")
	check(boss.art.texture == boss.REACTION and boss.art.frame_coords.y == 0,
		"Boss: generated hurt frames remain active")
	check(sync(boss.art, boss.body.position) == boss.art.modulate, "Boss: HD card receives red modulation")
	check_material(boss.art, boss.body.position, "Boss hit", true)
	boss.advance(.04, player, reject_hurt, ignore_burst)
	boss.art_motion.custom_step(.04)
	check(red(boss.art.modulate), "Boss: red remains during preparation")
	boss.show_hurt()
	boss.advance(.08, player, reject_hurt, ignore_burst)
	boss.art_motion.custom_step(.08)
	check(red(boss.art.modulate), "Boss: repeated hit refreshes flash")
	boss.advance(.03, player, reject_hurt, ignore_burst)
	boss.art_motion.custom_step(.03)
	check(boss.preparation > 0 and boss.art.modulate == Color.WHITE,
		"Boss: red restores after 100ms even during preparation")
	check_material(boss.art, boss.body.position, "Boss restored", false)
	check(boss.art.texture == boss.REACTION and boss.art.frame_coords.x > 0,
		"Boss: hurt frame sequence advances independently of flash")
	boss.art_motion.custom_step(.2)
	check(boss.art.texture == boss.ART and boss.art.modulate == Color.WHITE,
		"Boss: normal artwork restores after reaction")
	boss.show_hurt()
	var death := boss.play_death()
	check(red(boss.art.modulate) and boss.art.frame_coords.y == 1,
		"Boss: final hit flashes on generated death frame")
	check_material(boss.art, boss.body.position, "Boss fatal hit", true)
	boss.show_hurt()
	death.custom_step(.11)
	check(boss.art.modulate == Color.WHITE, "Boss: death flash restores after 100ms")
	check_material(boss.art, boss.body.position, "Boss death restored", false)
	boss.show_hurt()
	check(boss.art.modulate == Color.WHITE, "Boss: dying boss ignores later hurt flash")
	death.custom_step(.8)
	check(boss.art.modulate.a < .01 and is_equal_approx(boss.art.modulate.r, 1.0),
		"Boss: death alpha fade remains intact")
	var body := boss.body
	boss.free()
	body.free()
	player.free()

func test_damage_entry() -> void:
	if not OS.get_cmdline_user_args().has("--migration-test"):
		check(false, "real damage fixture requires isolated save flag")
		return
	var battle = load("res://scenes/battle.tscn").instantiate()
	battle.enemy_config = null
	battle.field_seed = 20261124
	root.add_child(battle)
	battle.set_physics_process(false)
	battle.player.set_physics_process(false)
	var enemy := ENEMY.new()
	enemy.setup(0, battle.player.movement_bounds, load("res://art/enemies/skeleton.png"))
	battle.actors.add_child(enemy)
	enemy.state = enemy.State.RECOVER
	enemy.remaining = 10.0
	var entry := {"body":enemy, "hp":10.0, "boss":false, "elite":false}
	battle.enemies.append(entry)
	battle.damage_enemy(entry, 0.0)
	check(enemy.art.modulate == Color.WHITE, "field.damage_enemy: zero damage does not flash")
	battle.damage_enemy(entry, 1.0)
	check(red(enemy.art.modulate) and is_equal_approx(entry.hp, 9.0),
		"field.damage_enemy: real nonfatal monster damage flashes")
	enemy.advance(.11, enemy.position, reject_hurt, ignore_web)
	check(enemy.art.modulate == Color.WHITE, "field.damage_enemy: nonfatal flash restores")
	battle.damage_enemy(entry, 20.0)
	check(enemy.dying and red(enemy.art.modulate),
		"field.damage_enemy: fatal monster damage flashes on death pose")
	enemy.death_tween.custom_step(.11)
	check(enemy.art.modulate == Color.WHITE, "field.damage_enemy: fatal monster flash restores")
	battle.portal_ready = true
	battle.portal_position = battle.player.position
	battle.enter_boss()
	if check_boss(battle):
		battle.boss.entry.hp = 10.0
		battle.damage_enemy(battle.boss.entry, 1.0)
		check(red(battle.boss.art.modulate),
			"field.damage_enemy: real nonfatal Boss damage flashes")
		battle.boss.art_motion.custom_step(.11)
		check(battle.boss.art.modulate == Color.WHITE,
			"field.damage_enemy: real Boss flash restores")
		battle.damage_enemy(battle.boss.entry, 20.0)
		check(battle.boss.dying and red(battle.boss.art.modulate),
			"field.damage_enemy: fatal Boss damage flashes on death pose")
		battle.boss.art_motion.custom_step(.11)
		check(battle.boss.art.modulate == Color.WHITE,
			"field.damage_enemy: fatal Boss flash restores")
	for sound in battle.find_children("*", "AudioStreamPlayer", true, false):
		sound.stop()
	battle.queue_free()
	await process_frame
	await process_frame
	# Give the audio mix thread time to release stopped hit/death playback.
	await create_timer(.25).timeout

func check_boss(battle: Node) -> bool:
	var exists := is_instance_valid(battle.boss)
	check(exists, "real battle entered Boss fixture")
	return exists

func reject_hurt(_amount: float, _direction := Vector2.ZERO) -> bool:
	return false

func ignore_web(_point: Vector2, _direction: Vector2, _kind: int = 0) -> void:
	pass

func ignore_burst(_point: Vector2, _color: Color) -> void:
	pass

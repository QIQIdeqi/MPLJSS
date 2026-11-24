extends SceneTree

# Run with -- --migration-test. Exercises production logic; never loads or writes a real save.
const MANAGER := preload("res://scripts/skills/skill_manager.gd")
const WORLD := preload("res://scripts/hd_battle_world.gd")
const ENEMY := preload("res://scripts/field_enemy.gd")
const SKELETON := preload("res://art/enemies/skeleton.png")
var checks: Array[Dictionary] = []
var failures := 0
var battle
var completed: Array[String] = []

class EffectSink:
	extends RefCounted
	var events: Array[Dictionary] = []
	var hits := 0
	var world
	func play_skill_fx(info: Dictionary) -> void:
		events.append(info)
		world.show_skill_fx(info)
	func apply_hit(entry: Dictionary, damage: float, _slow_seconds: float, _slow: float, _color: Color) -> void:
		hits += 1
		entry.hp -= damage

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> bool:
	checks.append({"passed":ok, "check":message})
	if not ok:
		failures += 1
		printerr("HIT_FEEDBACK_FAIL: " + message)
	return ok

func _run() -> void:
	if DirAccess.make_dir_recursive_absolute("res://Evidence/HitFeedback_20261124") != OK:
		push_error("Cannot create hit feedback test output directory")
		quit(1)
		return
	if not check(OS.get_cmdline_user_args().has("--migration-test"), "isolated save flag required"):
		_finish()
		return
	var scene := load("res://scenes/battle.tscn") as PackedScene
	if not check(scene != null, "production battle scene loads"):
		_finish()
		return
	battle = scene.instantiate()
	var world_script: Script = load("res://scripts/hd_battle_world.gd")
	if not check(battle.get_script() != null and world_script.can_instantiate(), "production field and HD scripts compiled"):
		battle.free()
		_finish()
		return
	battle.enemy_config = null
	battle.field_seed = 20261124
	root.add_child(battle)
	battle.set_physics_process(false)
	battle.player.set_physics_process(false)
	battle.player.collision_mask = 0
	battle.player.position = Vector2(600, 400)
	if not check(battle.alchemy_system != null, "production battle systems ready"):
		_finish()
		return
	_test_basic()
	_test_zones()
	_test_fallback_zone()
	await _test_player()
	_finish()

func _test_basic() -> void:
	var foe := ENEMY.new()
	foe.setup(0, battle.player.movement_bounds, SKELETON)
	battle.actors.add_child(foe)
	foe.position = battle.player.position + Vector2(140, 0)
	var entry := {"body":foe, "hp":50.0, "boss":false, "elite":false}
	battle.enemies.append(entry)
	battle.launch_basic_projectile(entry)
	check(battle.basic_projectiles.size() == 1 and is_equal_approx(entry.hp, 50), "basic launch creates flight without immediate damage")
	if battle.basic_projectiles.is_empty(): return
	var state: Dictionary = battle.basic_projectiles[0]
	var origin: Vector2 = state.pos
	battle.advance_basic_projectiles(.05)
	check(is_equal_approx(entry.hp, 50) and (state.pos as Vector2).distance_to(origin) > 0, "in-flight basic projectile has not damaged target")
	foe.position.y += 44
	battle.advance_basic_projectiles(.05)
	check((state.pos as Vector2).y > origin.y and is_equal_approx(entry.hp, 50), "basic flight follows moving target rather than old cast point")
	for step in 100:
		battle.advance_basic_projectiles(.01)
	check(is_equal_approx(entry.hp, 49) and battle.basic_projectiles.is_empty() and state.finished, "arrival applies exactly one basic hit and finishes shared visual state")
	battle.advance_basic_projectiles(1.0)
	check(is_equal_approx(entry.hp, 49), "finished projectile cannot apply a second hit")
	battle.launch_basic_projectile(entry)
	var canceled: Dictionary = battle.basic_projectiles[0]
	entry.hp = 0.0
	battle.advance_basic_projectiles(.01)
	check(canceled.finished and battle.basic_projectiles.is_empty() and is_equal_approx(entry.hp, 0), "target dying before arrival cancels basic hit")
	entry.hp = 49.0
	battle.launch_basic_projectile(entry)
	canceled = battle.basic_projectiles[0]
	battle.enemies.erase(entry)
	battle.advance_basic_projectiles(.01)
	check(canceled.finished and battle.basic_projectiles.is_empty() and is_equal_approx(entry.hp, 49), "target removed from battle cancels flight without damage")
	battle.enemies.append(entry)
	battle.launch_basic_projectile(entry)
	canceled = battle.basic_projectiles[0]
	battle.clear_combat_effects()
	check(canceled.finished and battle.basic_projectiles.is_empty(), "battle transition marks outstanding projectile finished")
	battle.ended = true
	battle.launch_basic_projectile(entry)
	battle.advance_basic_projectiles(1.0)
	check(is_equal_approx(entry.hp, 49) and battle.basic_projectiles.is_empty(), "ended battle cannot launch or resolve a new hit")
	battle.ended = false
	battle.enemies.erase(entry)
	foe.queue_free()
	completed.append("basic")

func _test_zones() -> void:
	for skill_level in [1, 4]:
		var world := WORLD.new()
		root.add_child(world)
		world.add_child(world.attack_effects)
		var sink := EffectSink.new()
		sink.world = world
		var manager := MANAGER.new()
		manager.setup(&"initial", sink)
		var runtime := SkillRuntime.new()
		runtime.setup(&"sk_mist_flask")
		runtime.level = skill_level
		var body := Node2D.new()
		root.add_child(body)
		body.position = Vector2(140, 0)
		var entry := {"body":body, "hp":1000.0}
		var enemies: Array = [entry]
		manager._cast(runtime, Vector2.ZERO, entry)
		check(sink.hits == 0 and _skill_nodes(world, "flight") == 1, "mist Lv%d starts visible projectile without impact damage" % skill_level)
		for step in 120:
			manager._update_active(.01, Vector2.ZERO, enemies, sink.apply_hit)
			_advance_skill_nodes(world, .01)
			if manager.active.size() > 0 and manager.active[0].kind == "zone": break
		if not check(manager.active.size() == 1 and manager.active[0].kind == "zone", "mist Lv%d creates real zone only after arrival" % skill_level):
			body.free()
			world.free()
			continue
		var zone: Dictionary = manager.active[0]
		var duration := float(runtime.value("duration"))
		check(is_equal_approx(float(zone.left), duration) and _skill_nodes(world, "zone_start") == 1 and _skill_nodes(world, "flight") == 0, "mist Lv%d shares actual %.1fs zone lifetime with HD view" % [skill_level, duration])
		for step in 90:
			manager._update_active(.01, Vector2.ZERO, enemies, sink.apply_hit)
			_advance_skill_nodes(world, .01)
		check(not zone.finished and zone.left > 0 and sink.hits > 0 and _skill_nodes(world, "zone_start") == 1, "mist Lv%d still damages and remains visible after initial 0.8s sheet" % skill_level)
		for step in int((duration - .9 - .1) * 100):
			manager._update_active(.01, Vector2.ZERO, enemies, sink.apply_hit)
			_advance_skill_nodes(world, .01)
		check(not zone.finished and _skill_nodes(world, "zone_start") == 1, "mist Lv%d is visible near end of complete duration" % skill_level)
		for step in 22:
			manager._update_active(.01, Vector2.ZERO, enemies, sink.apply_hit)
			_advance_skill_nodes(world, .01)
		var end_hits := sink.hits
		check(zone.finished and manager.active.is_empty() and _skill_nodes(world, "zone_start") == 1, "mist Lv%d ends gameplay then begins visual fade" % skill_level)
		_advance_skill_nodes(world, .5)
		manager._update_active(.5, Vector2.ZERO, enemies, sink.apply_hit)
		check(_skill_nodes(world, "zone_start") == 0 and sink.hits == end_hits, "mist Lv%d releases after fade and applies no post-expiry damage" % skill_level)
		manager._cast(runtime, Vector2.ZERO, entry)
		var flight: Dictionary = manager.active[0]
		manager.clear_active()
		_advance_skill_nodes(world, .01)
		check(flight.finished and manager.active.is_empty() and _skill_nodes(world, "flight") == 0, "V2 clear marks live projectile finished for scene transition")
		manager._cast(runtime, Vector2.ZERO, entry)
		world.show_skill_fx({"skill_id":"sk_mist_flask", "event":"zone_start", "target":zone.pos,
			"radius":zone.radius, "color":Color("#b797c8"), "state":zone})
		world.show_damage_feedback(body.position, 1.0)
		var view = battle.HD_BATTLE.new()
		view.world_view = world
		root.add_child(view)
		view.set_process(false)
		battle.hd_view = view
		battle.clear_combat_effects()
		check(_skill_nodes(world, "flight") == 0 and _skill_nodes(world, "zone_start") == 0 and world.damage_numbers.is_empty(), "battle clear immediately releases HD projectile, zone and damage number visuals")
		battle.hd_view = null
		manager.clear_active()
		manager.field = null
		sink.events.clear()
		sink.world = null
		view.free()
		body.free()
		world.free()
		completed.append("zone%d" % skill_level)

func _skill_nodes(world: Node3D, event: String) -> int:
	var count := 0
	for effect in world.attack_effects.get_children():
		if not effect.is_queued_for_deletion() and effect.get_meta("event", "") == event:
			count += 1
	return count

func _advance_skill_nodes(world: Node3D, delta: float) -> void:
	for effect in world.attack_effects.get_children():
		if not effect.is_queued_for_deletion() and effect.get_meta("skill_id", "") == "sk_mist_flask":
			effect._process(delta)

func _test_fallback_zone() -> void:
	battle.clear_combat_effects()
	var zone := {"kind":"zone", "pos":battle.player.position, "left":4.0, "radius":140.0, "finished":false}
	battle.play_skill_fx({"skill_id":"sk_mist_flask", "event":"zone_start", "target":zone.pos,
		"radius":140.0, "color":Color("#b797c8"), "state":zone})
	if not check(battle.fallback_skill_visuals.size() == 1, "2D fallback registers persistent mist zone"):
		return
	var cloud: Node2D = battle.fallback_skill_visuals[0].node
	cloud._process(1.0)
	battle.advance_fallback_skill_visuals(1.0)
	check(is_instance_valid(cloud) and not cloud.is_queued_for_deletion() and battle.fallback_skill_visuals.size() == 1, "2D fallback mist survives initial sheet beyond 0.8s")
	zone.finished = true
	battle.advance_fallback_skill_visuals(.01)
	check(battle.fallback_skill_visuals.size() == 1, "2D fallback mist begins fade at actual end")
	battle.advance_fallback_skill_visuals(.5)
	check(battle.fallback_skill_visuals.is_empty(), "2D fallback mist releases after end fade")
	completed.append("fallback")

func _test_player() -> void:
	var player = battle.player
	player.locked = false
	player.dead = false
	player.dodge = 0
	battle.hurt_cooldown = 0
	battle.hp = 120.0
	var base: Color = player.art.modulate
	var original_scale: Vector2 = player.art.scale
	check(not battle.hurt(0) and is_equal_approx(battle.hp, 120) and player.art.modulate == base and is_zero_approx(player.hurt_time), "zero damage does not flash, play hurt feedback, or consume invulnerability")
	check(battle.hurt(9), "first player hit succeeds")
	check(is_equal_approx(battle.hp, 111) and player.art.modulate != base and player.hurt_time > 0, "successful hit applies 9HP and immediate local flash")
	var flash: Color = player.art.modulate
	check(not battle.hurt(9) and is_equal_approx(battle.hp, 111) and player.art.modulate == flash, "existing 0.55s invulnerability rejects duplicate hurt")
	var from: Vector2 = player.position
	Input.action_press(&"move_right")
	await physics_frame
	player._physics_process(.04)
	check(player.position.x > from.x and player.pose == player.Pose.WALK, "hurt feedback preserves movement and directional walk pose")
	player._physics_process(.08)
	Input.action_release(&"move_right")
	check(is_zero_approx(player.hurt_time) and player.art.modulate == base and player.art.scale == original_scale, "flash ends after 0.1s and restores color without resizing")
	player.show_hurt()
	player.locked = true
	player._physics_process(.12)
	check(player.art.modulate == base, "locked player cannot retain expired red flash")
	player.locked = false
	player.show_hurt()
	player.show_death()
	check(player.art.modulate == base, "death resets short hurt flash")
	player.dead = false
	player.dodge = .1
	battle.hurt_cooldown = 0
	check(not battle.hurt(9) and is_equal_approx(battle.hp, 111), "existing dodge invulnerability still rejects hit")
	player.dodge = 0
	check(player.hurt_sound.stream != null and player.hurt_sound.stream.get_length() > 0, "player hurt feedback has playable dedicated audio stream")
	battle.hp = 5.0
	check(battle.hurt(9) and player.dead and player.hurt_sound.playing and player.art.modulate == base, "lethal damage plays hurt sound then preserves clean death pose")
	completed.append("player")

func _finish() -> void:
	Input.action_release(&"move_right")
	check(completed == ["basic", "zone1", "zone4", "fallback", "player"], "every regression section reached its final check")
	if is_instance_valid(battle):
		for sound in battle.find_children("*", "AudioStreamPlayer", true, false):
			sound.stop()
		battle.queue_free()
	await process_frame
	await process_frame
	# AudioStreamPlayer queues playback release to the mix thread after stop/free.
	await create_timer(.25).timeout
	var report := {"passed":failures == 0, "checks":checks, "failures":failures, "headless":DisplayServer.get_name() == "headless", "scope":"Production battle/projectile/zone/hero states; visual look and human listening require graphical acceptance."}
	var file := FileAccess.open("res://Evidence/HitFeedback_20261124/verification.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("HIT_FEEDBACK_%s: %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks.size(), failures])
	quit(0 if failures == 0 else 1)

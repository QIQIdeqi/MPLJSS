extends SceneTree

const BATTLE_WORLD := preload("res://scripts/hd_battle_world.gd")
const SKILL_MANAGER := preload("res://scripts/skills/skill_manager.gd")

class BattleFx:
	extends RefCounted
	var world: Node3D
	var events: Array[Dictionary] = []

	func play_skill_fx(info: Dictionary) -> void:
		events.append(info)
		world.show_skill_fx(info)

func _initialize() -> void:
	var world := BATTLE_WORLD.new()
	root.add_child(world)
	world.add_child(world.attack_effects)
	world.show_skill_fx({"skill_id":"sk_blast_flask", "event":"impact", "target":Vector2(200.0, 200.0), "radius":96.0, "color":Color("e65b37")})
	world.show_skill_fx({"skill_id":"sk_corrosive_flask", "event":"impact", "target":Vector2(200.0, 200.0), "radius":100.0, "color":Color("4f9d47")})
	assert(world.attack_effects.get_child_count() == 2, "Both base impact effects should start")
	_check_needle_flight(world)
	await _check_blast_flask(world)
	print("v2_projectile_fx_smoke: basic needle volley and blast flask launch, landing and cleanup passed")
	quit()

func _check_needle_flight(world: Node3D) -> void:
	var effects := BattleFx.new()
	effects.world = world
	var manager := SKILL_MANAGER.new()
	manager.setup(&"initial", effects)
	var runtime := SkillRuntime.new()
	runtime.setup(&"sk_soul_needle")
	var target := Node2D.new()
	root.add_child(target)
	target.position = Vector2(420, 0)
	var enemy := {"body":target, "hp":1000.0}
	var hits: Array[float] = []
	var apply_hit := func(_entry, amount, _slow, _factor, _color): hits.append(amount)
	manager._spawn_needles(runtime, enemy)
	assert(manager.active.size() == 3)
	for index in 3:
		assert(is_equal_approx(float(manager.active[index].left), .12 * index))
	for step in 31:
		manager._update_active(.01, Vector2.ZERO, [enemy], apply_hit)
	assert(effects.events.size() == 3 and hits.is_empty(),
		"Three basic needles must launch before damage occurs")
	for event in effects.events:
		assert(event.skill_id == "sk_soul_needle" and event.event == "flight")
	for step in 100:
		manager._update_active(.01, Vector2.ZERO, [enemy], apply_hit)
	assert(manager.active.is_empty() and hits.size() == 3 and effects.events.size() == 6,
		"Each basic needle deals one hit and shows one impact")
	assert(effects.events.back().event == "impact")
	target.queue_free()

func _check_blast_flask(world: Node3D) -> void:
	var effects := BattleFx.new()
	effects.world = world
	var manager := SKILL_MANAGER.new()
	manager.setup(&"initial", effects)
	assert(manager.add_skill(&"sk_blast_flask"))
	var runtime := manager.runtime_for(&"sk_blast_flask")
	var target := Node2D.new()
	var bystander := Node2D.new()
	root.add_child(target)
	root.add_child(bystander)
	var enemies: Array = [{"body":target, "hp":10.0}, {"body":bystander, "hp":10.0}]
	var hits: Array[Node2D] = []
	var apply_hit := func(enemy, _amount, _slow, _factor, _color): hits.append(enemy.body)
	var landing := Vector2(runtime.range_px(), 0.0)
	target.position = landing + Vector2.RIGHT
	bystander.position = landing + Vector2.RIGHT * 30.0

	manager.cast_equipped(0.1, Vector2.ZERO, enemies, apply_hit)
	assert(runtime.ready() and effects.events.is_empty() and manager.active.is_empty() and hits.is_empty(),
		"Enemies outside the skill range must not trigger a throw, impact or cooldown")

	target.position = landing
	enemies[0].hp = 0.0
	manager.cast_equipped(0.1, Vector2.ZERO, enemies, apply_hit)
	assert(effects.events.is_empty() and manager.active.is_empty(), "A dead enemy in range cannot trigger a throw")
	enemies[0].hp = 10.0
	manager.cast_equipped(0.0, Vector2.ZERO, enemies, apply_hit)
	assert(effects.events.size() == 1 and effects.events[0].event == "cast" and hits.is_empty(),
		"An enemy entering range must start a throw without dealing damage early")
	var bottle: Node3D = world.attack_effects.get_child(-1)
	assert(bottle.get_script() == BATTLE_WORLD.BLAST_FLASK_FLIGHT)

	manager.cast_equipped(0.12, Vector2.ZERO, enemies, apply_hit)
	var previous_position: Vector2 = manager.active[0].pos
	target.free()
	enemies.remove_at(0)
	manager.cast_equipped(0.12, Vector2.ZERO, enemies, apply_hit)
	assert((manager.active[0].pos as Vector2).distance_to(landing) < previous_position.distance_to(landing),
		"The bottle must keep moving after its original target is removed")
	assert(hits.is_empty())
	for step in 90:
		manager.cast_equipped(1.0 / 60.0, Vector2.ZERO, enemies, apply_hit)
	assert(manager.active.is_empty() and effects.events.size() == 2 and effects.events[1].event == "impact")
	assert(effects.events[1].target == landing and hits == [bystander], "Splash is resolved once at the locked landing point")
	await process_frame
	await process_frame
	assert(not is_instance_valid(bottle), "The flight sprite should be freed after landing")
	bystander.queue_free()

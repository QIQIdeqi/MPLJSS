extends SceneTree

const BATTLE_WORLD := preload("res://scripts/hd_battle_world.gd")
const SKILL_MANAGER := preload("res://scripts/skills/skill_manager.gd")
var failed := false

class HitSink:
	extends RefCounted
	var world
	var hits := 0
	var impacts := 0
	func play_skill_fx(info: Dictionary) -> void:
		if info.event == "impact": impacts += 1
		world.show_skill_fx(info)
	func apply_hit(entry: Dictionary, damage: float, _seconds: float, _slow: float, _color: Color) -> void:
		hits += 1
		entry.hp -= damage

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		printerr("v2_combo_fx_smoke FAIL: " + message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var world := BATTLE_WORLD.new()
	root.add_child(world)
	world.add_child(world.attack_effects)
	world.show_skill_fx({"skill_id":"sk_obsidian_blade", "event":"link_crystal_shatter_blade", "target":Vector2(200.0, 200.0)})
	check(world.attack_effects.get_child_count() == 1, "Crystal combo should create one dedicated effect")
	world.show_skill_fx({"skill_id":"sk_soul_needle", "event":"link_soulbound_needle", "target":Vector2(200.0, 200.0)})
	check(world.attack_effects.get_child_count() == 1, "Soulbound link announcement should not duplicate real projectile bodies")
	var manager := SKILL_MANAGER.new()
	var sink := HitSink.new()
	sink.world = world
	manager.setup(&"initial", sink)
	var runtime := SkillRuntime.new()
	runtime.setup(&"sk_soul_needle")
	var target := Node2D.new()
	root.add_child(target)
	target.position = Vector2(420, 0)
	var enemy := {"body":target, "hp":1000.0}
	var enemies: Array = [enemy]
	manager._spawn_needles(runtime, Vector2.ZERO, enemy, true)
	check(manager.active.size() == 3, "Soulbound combo should schedule exactly three needles")
	for index in 3:
		check(is_equal_approx(float(manager.active[index].left), .06 + .12 * index), "Soulbound launch timing mismatch")
	for step in 31:
		manager._update_active(.01, Vector2.ZERO, enemies, sink.apply_hit)
		world._update_tracked_fx(.01)
	check(world.tracked_projectiles.size() == 3 and sink.hits == 0 and sink.impacts == 0,
		"Three real combo needles must be in flight before any damage or impact mark")
	for step in 100:
		manager._update_active(.01, Vector2.ZERO, enemies, sink.apply_hit)
		world._update_tracked_fx(.01)
	check(manager.active.is_empty() and world.tracked_projectiles.is_empty() and sink.hits == 3 and sink.impacts == 3,
		"Each real needle should create exactly one hit and one impact at arrival")
	var marks := 0
	for effect in world.attack_effects.get_children():
		if effect is AnimatedSprite3D and effect.frame == 4: marks += 1
	check(marks == 3, "Soulbound dedicated impact begins at frame four after each real arrival")
	manager.clear_active()
	manager.field = null
	sink.world = null
	target.queue_free()
	world.queue_free()
	await process_frame
	await process_frame
	print("v2_combo_fx_smoke: real combo flight, arrival feedback, and three scheduled needles %s" % ("FAILED" if failed else "passed"))
	quit(1 if failed else 0)

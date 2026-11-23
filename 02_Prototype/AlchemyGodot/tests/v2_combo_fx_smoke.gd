extends SceneTree

const BATTLE_WORLD := preload("res://scripts/hd_battle_world.gd")
const SKILL_MANAGER := preload("res://scripts/skills/skill_manager.gd")

func _initialize() -> void:
	var world := BATTLE_WORLD.new()
	root.add_child(world)
	world.add_child(world.attack_effects)
	world.show_skill_fx({"skill_id":"sk_obsidian_blade", "event":"link_crystal_shatter_blade", "target":Vector2(200.0, 200.0)})
	assert(world.attack_effects.get_child_count() == 1, "Crystal combo should create one dedicated effect")
	world.show_skill_fx({"skill_id":"sk_soul_needle", "event":"link_soulbound_needle", "target":Vector2(200.0, 200.0)})
	assert(world.attack_effects.get_child_count() == 4, "Soulbound combo should start with three needles")
	await create_timer(0.25).timeout
	assert(world.attack_effects.get_child_count() == 2, "Soulbound combo should retain only one impact mark")
	var manager := SKILL_MANAGER.new()
	var runtime := SkillRuntime.new()
	runtime.setup(&"sk_soul_needle")
	manager._spawn_needles(runtime, Vector2.ZERO, {}, true)
	assert(manager.active.size() == 3, "Soulbound combo should schedule exactly three needles")
	for index in 3:
		assert(is_equal_approx(float(manager.active[index].left), .06 + .12 * index), "Soulbound launch timing mismatch")
	print("v2_combo_fx_smoke: two combo effects and three scheduled needles passed")
	quit()

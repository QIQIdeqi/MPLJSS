extends SceneTree

const SKILLS := preload("res://data/skills/skill_data.gd")
const ABILITIES := preload("res://data/alchemy_abilities/alchemy_ability_data.gd")
const MENU_PATH := "res://scenes/menu.tscn"
const STAGE_PATH := "res://scenes/skill_test_stage.tscn"
const STEP := 1.0 / 60.0

var _stage
var _skills: SkillManager
var _checks := 0
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if not OS.get_cmdline_user_args().has("--migration-test"):
		push_error("Skill test stage smoke requires --migration-test.")
		quit(1)
		return
	var run_config := root.get_node("RunConfig")
	var campaign_ability: StringName = run_config.selected_ability
	var campaign_level: StringName = run_config.selected_level_id
	var load_error := change_scene_to_file(MENU_PATH)
	if not _check(load_error == OK and await _wait_for_scene(MENU_PATH), "Main menu loads through the project entry point"):
		_finish()
		return
	var entry := current_scene.get_node_or_null("Actions/SkillTest") as Button
	if not _check(entry != null and entry.is_visible_in_tree() and not entry.disabled, "Skill test button is accessible from the main menu"):
		_finish()
		return
	entry.pressed.emit()
	if not _check(await _wait_for_scene(STAGE_PATH), "Menu button opens the dedicated skill test stage"):
		_finish()
		return
	_stage = current_scene
	if not _check(_stage.has_method("test_skills"), "Dedicated stage initializes its testing controller"):
		_finish()
		return
	_stage.set_physics_process(false)
	_stage.player.set_physics_process(false)
	_skills = _stage.test_skills()
	if not _check(_skills != null, "The range uses a live production SkillManager"):
		_finish()
		return
	_check(_stage.profile_path().is_empty() and _stage.profile_store == null and _stage.run_manager == null,
		"The test stage has no campaign profile writer or run ledger")
	_check(not _stage.test_basic_attack, "Basic attack starts disabled for isolated skill tests")
	_test_panel()
	_test_catalog()
	_test_layouts()
	if not _stage.enemies.is_empty():
		_test_dummy_hits()
		_test_health_and_controls()
	_stage.return_to_menu()
	_check(await _wait_for_scene(MENU_PATH), "The test stage returns directly to the main menu")
	_check(run_config.selected_ability == campaign_ability and run_config.selected_level_id == campaign_level,
		"Changing test alchemy and gear preserves campaign selections")
	_finish()


func _wait_for_scene(path: String) -> bool:
	for _frame in range(12):
		if is_instance_valid(current_scene) and current_scene.scene_file_path == path:
			return true
		await process_frame
	return false


func _test_panel() -> void:
	var controls := _stage.find_child("SkillTestControls", true, false) as Control
	if not _check(controls != null and controls.is_visible_in_tree(), "The skill test panel is visible on entry"):
		return
	var panel: Variant = controls.get_parent()
	var equip: Button = panel._skill_toggles.get(&"sk_blast_flask")
	var combo: Button = panel._combo_buttons.get(&"combo_furnace")
	if not _check(equip != null and combo != null and panel._levels.size() == 5,
		"Panel wires real equip, level and combination controls"):
		return
	_stage.clear_test_skills()
	equip.pressed.emit()
	var flask := _skills.runtime_for(&"sk_blast_flask")
	if _check(flask != null, "Clicking the equipment control equips its skill"):
		var level_five: Button = panel._levels[4]
		level_five.pressed.emit()
		_check(_skills.runtime_for(&"sk_blast_flask").level == 5, "Clicking a rank button updates the selected skill")
	panel._tabs.current_tab = 1
	_check(combo.is_visible_in_tree(), "The combinations tab exposes its presets")
	combo.pressed.emit()
	_check(_skills.runtimes.size() == 2 and _skills.combo_rules.ready(&"combo_furnace"),
		"Clicking a combo preset equips both parents and unlocks the real combo")
	panel.toggle_panel()
	_check(not panel._body.is_visible_in_tree(), "Folding the panel leaves an unobstructed battle view")
	panel.toggle_panel()
	_check(panel._body.is_visible_in_tree(), "The panel reopens in the same session")
	_stage.clear_test_skills()


func _test_catalog() -> void:
	_stage.clear_test_skills()
	for row: Dictionary in SKILLS.ROWS:
		var id := StringName(row.id)
		_stage.toggle_test_skill(id)
		var runtime := _skills.runtime_for(id)
		if _check(runtime != null, "Can equip %s directly" % row.name):
			_stage.set_test_skill_level(id, 5)
			_check(_skills.runtime_for(id).level == 5, "Can raise %s to level five" % row.name)
	_check(_skills.runtimes.size() == SKILLS.ROWS.size() and _skills.runtimes.size() > 6,
		"All basic skills can be equipped at once in the range")
	_check(_skills.unlocked_chains().size() == SKILLS.CHAINS.size(), "All fixed recipes unlock with their actual parent skills")
	var last_id := StringName(SKILLS.ROWS.back().id)
	_stage.set_test_skill_level(last_id, 2)
	var last_runtime := _skills.runtime_for(last_id)
	_check(last_runtime != null and last_runtime.level == 2, "The stage supports lowering a skill level directly")
	_stage.toggle_test_skill(last_id)
	_check(not _skills.has_skill(last_id) and _skills.runtimes.size() == SKILLS.ROWS.size() - 1, "Equipped skills can be removed")
	for chain: Dictionary in SKILLS.CHAINS:
		var combo_id := StringName(chain.id)
		_stage.equip_test_combo(combo_id)
		var unlocked := _skills.unlocked_chains()
		var has_parents: bool = chain.parents.all(func(parent_id: String) -> bool:
			return _skills.has_skill(StringName(parent_id)))
		_check(_skills.runtimes.size() == chain.parents.size() and has_parents and unlocked.size() == 1
			and unlocked[0].id == combo_id, "Preset isolates the real parent skills for %s" % chain.name)
	_stage.clear_test_skills()
	_check(_skills.runtimes.is_empty() and _skills.unlocked_chains().is_empty(), "Clear removes equipped skills and their combinations")


func _test_layouts() -> void:
	for count in [1, 5, 3]:
		_stage.set_test_dummy_count(count)
		_check(_stage.test_dummy_count == count and _stage.enemies.size() == count, "The range supports %d dummies" % count)
		var positions := _dummy_positions()
		_check(positions.size() == count, "All %d dummies occupy separate target positions" % count)


func _test_dummy_hits() -> void:
	var positions := _dummy_positions()
	_move_into_range()
	var initial_health := float(_stage.hp)
	_advance(120)
	_expect_live_dummies(positions, "during idle simulation")
	_check(is_equal_approx(float(_stage.hp), initial_health), "Nearby dummies never attack the test player")
	for entry: Dictionary in _stage.enemies:
		_stage.damage_enemy(entry, 1.0e9)
	_expect_live_dummies(positions, "after lethal damage")
	_check(_stage.kills == 0 and _stage.pickups.is_empty() and _stage.material_drops.is_empty(),
		"Dummy hits do not count kills or create rewards")
	for split in [false, true]:
		_stage.set_test_split(split)
		var ability := ABILITIES.ABILITY_SPLIT if split else ABILITIES.ABILITY_INITIAL
		_check(_skills.ability_id == ability, "Mode reaches SkillManager: %s" % ability)
		_stage.equip_test_combo(&"combo_tide_mirror")
		_move_into_range()
		_advance(8)
		_check(not _skills.runtime_for(&"sk_wind_flask").ready(), "%s wind flask actually casts on a dummy" % ability)
		_check(_skills.combo_rules.ready(&"combo_tide_mirror"),
			"Wind Flask alone does not trigger Tide Mirror in %s" % ability)
		_expect_live_dummies(positions, "after %s wind pressure" % ability)
		_stage.equip_test_combo(&"combo_rewind_anchor")
		_move_into_range()
		_advance(100)
		_check(_skills.combo_rules.ready(&"combo_rewind_anchor"),
			"Stationary dummies and the two parent casts do not trigger Rewind Anchor in %s" % ability)
		_expect_live_dummies(positions, "after %s gravity pull and ring" % ability)
		_stage.clear_test_skills()
		_stage.toggle_test_skill(&"sk_frost_powder")
		_move_into_range()
		_advance(18)
		_check(_stage.enemies.any(func(entry: Dictionary) -> bool: return float(entry.get("freeze_left", 0.0)) > 0.0),
			"Dummies can receive ordinary-enemy frost status in %s" % ability)
		_expect_live_dummies(positions, "after %s freeze" % ability)
	_stage.clear_test_skills()


func _test_health_and_controls() -> void:
	_stage.set_test_split(false)
	_move_into_range()
	_stage.set_test_basic_attack(true)
	_check(_stage.test_basic_attack, "Basic attack can be enabled for comparison")
	var fired := false
	for _frame in 35:
		_advance(1)
		if not _stage.basic_projectiles.is_empty():
			fired = true
			break
	_check(fired, "The toggle enables a real basic projectile")
	_stage.set_test_basic_attack(false)
	_check(not _stage.test_basic_attack, "Basic attack can be disabled again")
	_stage.set_test_half_health(true)
	var half := float(_stage.MAX_HP) * 0.5
	_check(is_equal_approx(float(_stage.hp), half), "Half-health control creates a missing-health target")
	_stage.toggle_test_skill(&"sk_renewal_flask")
	_advance(43)
	_check(float(_stage.hp) > half and float(_stage.hp) < float(_stage.MAX_HP), "A real recovery pool heals the player")
	var recovery := _skills.runtime_for(&"sk_renewal_flask")
	_check(not recovery.ready(), "Recovery actually runs its base cooldown")
	_stage.reset_test_cooldowns()
	_check(_skills.runtime_for(&"sk_renewal_flask").ready(), "Cooldown reset readies base skills")
	_stage.equip_test_combo(&"combo_tide_mirror")
	_move_into_range()
	_stage.prepare_test_condition(&"combo_tide_mirror")
	_advance(40)
	_check(not _skills.combo_rules.ready(&"combo_tide_mirror"), "A real test bullet activates the mirror")
	_stage.reset_test_cooldowns()
	_check(_skills.combo_rules.ready(&"combo_tide_mirror"), "Cooldown reset also readies combinations")
	_stage.set_test_half_health(false)
	_check(is_equal_approx(float(_stage.hp), float(_stage.MAX_HP)), "Full-health control restores the test player")


func _move_into_range() -> void:
	var first: Vector2 = _stage.enemies[0].body.position
	var bounds: Rect2 = _stage.player.movement_bounds
	_stage.player.position = (first - Vector2(72.0, 0.0)).clamp(bounds.position, bounds.end)
	_stage.player.direction = Vector2.RIGHT


func _advance(frames: int) -> void:
	for _frame in frames:
		_stage._physics_process(STEP)


func _dummy_positions() -> Dictionary:
	var positions := {}
	for entry: Dictionary in _stage.enemies:
		positions[entry.body.position] = entry.body
	return positions


func _expect_live_dummies(positions: Dictionary, context: String) -> void:
	var intact: bool = positions == _dummy_positions() and _stage.enemies.all(func(entry: Dictionary) -> bool:
		return is_instance_valid(entry.body) and float(entry.hp) > 0.0)
	_check(intact, "All dummy instances stay still and alive %s" % context)


func _check(ok: bool, label: String) -> bool:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("SKILL_TEST_STAGE: " + label)
	return ok


func _finish() -> void:
	print("SKILL_TEST_STAGE checks=%d failures=%d" % [_checks, _failures])
	quit(int(_failures > 0))

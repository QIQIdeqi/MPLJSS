extends "res://scripts/field.gd"

const PANEL := preload("res://scripts/skill_test_panel.gd")
const DUMMY := preload("res://scripts/skill_test_dummy.gd")
const ABILITIES := preload("res://data/alchemy_abilities/alchemy_ability_data.gd")
const PURSUER_ART := preload("res://art/enemies/slime.png")
const TEST_SPAWN := Vector2(540.0, 410.0)
const DUMMY_OFFSETS := [
	Vector2(114.0, -6.0), Vector2(176.0, -51.0), Vector2(158.0, 53.0),
	Vector2(236.0, -12.0), Vector2(236.0, 62.0),
]

var test_dummy_count := 3
var test_basic_attack := false
var _panel: PANEL
var _test_pursuers: Array[Dictionary] = []
var _pursuit_left := 0.0


func _ready() -> void:
	player.position = TEST_SPAWN
	setup_combat_canvas()
	layout_preset = NORMAL_LAYOUT.duplicate()
	layout_preset.object_density = 0.0
	if not generate_field(false, 120):
		startup_error = "技能测试场地图加载失败。"
		stage_active = false
		$Interface/Hint.text = startup_error
		$Interface/Hint.show()
		return
	setup_combat_skills(ABILITIES.ABILITY_INITIAL)
	setup_enemy_hazards()
	test_skills().max_skill_slots = SKILLS.ROWS.size()
	set_test_dummy_count(test_dummy_count)
	if DisplayServer.get_name() != "headless":
		hd_view = HD_BATTLE.new()
		add_child(hd_view)
		hd_view.attach(self)
	queue_redraw()
	_panel = PANEL.new()
	_panel.name = "SkillTestPanel"
	$Interface.add_child(_panel)
	_panel.setup(self)
	startup_complete = true


func profile_path() -> String:
	return ""


func _physics_process(delta: float) -> void:
	if not startup_complete:
		return
	update_camera(delta)
	hurt_cooldown = maxf(0.0, hurt_cooldown - delta)
	var context := skill_action_context()
	context.frame_delta = delta
	independent_field.pre_actor_tick(player.position, enemies, context)
	advance_basic_projectiles(delta)
	advance_fallback_skill_visuals(delta)
	advance_webs(delta)
	_advance_test_pursuit(delta)
	for dummy in enemies:
		dummy.freeze_left = maxf(0.0, float(dummy.get("freeze_left", 0.0)) - delta)
		dummy.slow_left = maxf(0.0, float(dummy.get("slow_left", 0.0)) - delta)
		var pending: Dictionary = dummy.get("windup", {})
		if not pending.is_empty():
			pending.remaining = float(pending.remaining) - delta
			if float(pending.remaining) <= 0.0:
				dummy.windup = {}
	advance_combat_skills(delta, test_basic_attack)


func _input(event: InputEvent) -> void:
	if is_instance_valid(_panel) and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		_panel.toggle_panel()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		return_to_menu()


func damage_enemy(entry: Dictionary, damage: float) -> void:
	if damage > 0.0 and enemies.has(entry):
		show_enemy_hit_feedback(entry, damage_with_vulnerability(entry, damage))


func test_skills() -> SkillManager:
	return alchemy_system.skills


func toggle_test_skill(id: StringName) -> void:
	var skills := test_skills()
	var runtime := skills.runtime_for(id)
	if runtime != null:
		skills.runtimes.erase(runtime)
	elif not skills.add_skill(id):
		return
	reset_test_cooldowns()


func set_test_skill_level(id: StringName, rank: int) -> void:
	var runtime := test_skills().runtime_for(id)
	if runtime != null:
		runtime.level = clampi(rank, 1, 5)
		reset_test_cooldowns()


func equip_test_combo(id: StringName) -> void:
	var recipe := SKILLS.combo_by_id(id)
	if recipe.is_empty():
		return
	var skills := test_skills()
	var levels := {}
	for runtime in skills.runtimes:
		levels[runtime.skill_id] = runtime.level
	skills.runtimes.clear()
	for id_value: String in recipe.parents:
		var parent_id := StringName(id_value)
		if skills.add_skill(parent_id):
			skills.runtime_for(parent_id).level = int(levels.get(parent_id, 1))
	reset_test_cooldowns()


func clear_test_skills() -> void:
	test_skills().runtimes.clear()
	reset_test_cooldowns()


func reset_test_cooldowns() -> void:
	clear_combat_effects()
	clear_webs()
	_clear_test_pursuit()
	var skills := test_skills()
	for runtime in skills.runtimes:
		runtime.cooldown_left = 0.0
		runtime.cooldown_total = 0.0
	skills.chain_cooldowns.clear()
	player.cooldown = 0.0
	until_attack = 0.0
	for dummy in enemies:
		dummy.freeze_left = 0.0
		dummy.slow_left = 0.0
		dummy.slow_factor = 1.0
		dummy.windup = {}


func set_test_split(enabled: bool) -> void:
	var ability_id := StringName(ABILITIES.ABILITY_SPLIT if enabled else ABILITIES.ABILITY_INITIAL)
	test_skills().ability_id = ability_id
	alchemy_system.ability_id = String(ability_id)
	reset_test_cooldowns()


func set_test_basic_attack(enabled: bool) -> void:
	test_basic_attack = enabled
	reset_test_cooldowns()


func set_test_dummy_count(count: int) -> void:
	if count not in [1, 3, 5]:
		return
	reset_test_cooldowns()
	for entry in enemies:
		entry.body.queue_free()
	enemies.clear()
	test_dummy_count = count
	for index in count:
		var dummy := DUMMY.new()
		dummy.name = "TrainingDummy%d" % (index + 1)
		dummy.position = TEST_SPAWN + DUMMY_OFFSETS[index]
		actors.add_child(dummy)
		enemies.append({"body": dummy, "hp": 100.0, "max_hp": 100.0, "boss": false, "anchored": true,
			"wall_practice": true})


func set_test_half_health(enabled: bool) -> void:
	hp = MAX_HP * 0.5 if enabled else MAX_HP
	reset_test_cooldowns()

func prepare_test_condition(id: StringName) -> void:
	if not SKILLS.combo_by_id(id).is_empty() and test_skills().unlocked_chains().any(
			func(recipe: Dictionary) -> bool: return recipe.id == id):
		reset_test_cooldowns()
		var target: Dictionary = test_skills().nearest_enemy(player.position, 3.2 * SKILLS.UNIT, enemies)
		var at: Vector2 = player.position
		match id:
			&"combo_thunder_coat":
				if hp < 35.0:
					hp = 60.0
				hurt_cooldown = 0.0
				var source := target.get("body") as Node2D
				hurt(20.0, Vector2.ZERO, source)
			&"combo_tide_mirror":
				var origin := at + Vector2.RIGHT * 2.5 * SKILLS.UNIT
				fire_web(actors.to_global(origin), Vector2.LEFT)
			&"combo_rewind_anchor":
				_start_test_pursuit(at)
			&"combo_cleanser":
				var center: Vector2 = at + player.direction * SKILLS.UNIT
				fire_web(actors.to_global(center), Vector2.ZERO, FIELD_ENEMY.Kind.MUSHROOM)
			&"combo_opening_counter":
				if not target.is_empty() and at.distance_to(target.body.position) <= 1.80 * SKILLS.UNIT:
					var toward: Vector2 = (target.body.position as Vector2).direction_to(at)
					target.windup = {"token": 1, "aim": toward, "remaining": 1.05, "interruptible": false}
			&"combo_dew_pickup":
				if hp >= MAX_HP:
					hp = MAX_HP * 0.5
				var point: Vector2 = target.body.position if not target.is_empty() else at + Vector2.RIGHT * SKILLS.UNIT
				independent_field.notify_kill(point, skill_action_context())

func _start_test_pursuit(at: Vector2) -> void:
	for offset: Vector2 in [Vector2(190, -60), Vector2(-175, 45)]:
		var point := _clip_combo_walk(at, at + offset)
		if point.distance_to(at) < 70.0:
			continue
		var body := FIELD_ENEMY.new()
		body.setup(FIELD_ENEMY.Kind.SLIME, player.movement_bounds, PURSUER_ART)
		body.position = point
		actors.add_child(body)
		var entry := {"body":body, "hp":100.0, "max_hp":100.0, "boss":false, "anchored":false}
		enemies.append(entry)
		_test_pursuers.append(entry)
	_pursuit_left = 2.6

func _advance_test_pursuit(delta: float) -> void:
	if _test_pursuers.is_empty():
		return
	_pursuit_left -= delta
	if _pursuit_left <= 0.0:
		_clear_test_pursuit()
		return
	for entry in _test_pursuers:
		var body: FIELD_ENEMY = entry.body
		if not independent_field.is_rewinding(entry) and body.position.distance_squared_to(player.position) > 60.0 * 60.0:
			var target := body.position.move_toward(player.position, 96.0 * delta)
			body.facing = body.direction_row(body.position.direction_to(target))
			body.position = _clip_combo_walk(body.position, target)
			body.motion_time += delta
		body.hurt_left = maxf(0.0, body.hurt_left - delta)
		body.update_art()

func _clear_test_pursuit() -> void:
	for entry in _test_pursuers:
		enemies.erase(entry)
		entry.body.queue_free()
	_test_pursuers.clear()


func return_to_menu() -> void:
	var scene := load("res://scenes/menu.tscn") as PackedScene
	if scene == null:
		return
	var menu := scene.instantiate()
	menu.save_path = save_path
	if get_tree().change_scene_to_node(menu) != OK:
		menu.free()

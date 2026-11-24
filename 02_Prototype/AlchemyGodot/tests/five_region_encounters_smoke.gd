extends SceneTree

const TABLE := preload("res://levels/enemy_wave_table.gd")
const ROW := preload("res://levels/enemy_spawn_row.gd")
const BOSS := preload("res://scripts/boss_arena.gd")
const IDS := ["greyford_01", "trade_road_02", "manor_03", "pilgrimage_04", "capital_05"]
var checks := 0
var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error(label)

func run() -> void:
	var catalog = load("res://levels/catalog.tres")
	check(catalog != null, "catalog loads")
	if catalog == null:
		quit(1)
		return
	check(catalog.validation_errors().is_empty(), "eleven independent scene entries validate")
	check(catalog.selectable_levels().size() == 5, "five normal regions selectable from village")
	var seen_layouts := {}
	var seen_waves := {}
	for index in IDS.size():
		var definition = catalog.find_level(StringName(IDS[index]))
		var boss_definition = catalog.find_level(StringName(IDS[index] + "_boss"))
		check(definition != null and boss_definition != null, IDS[index] + " normal and Boss exist")
		if definition == null or boss_definition == null:
			continue
		check(definition.boss_level_id == boss_definition.level_id, IDS[index] + " links correct Boss")
		check(bool(definition.layout.infinite) and not bool(boss_definition.layout.infinite), IDS[index] + " unlimited normal / finite Boss")
		check(definition.layout.theme_id == StringName(IDS[index]) and boss_definition.layout.theme_id == StringName(IDS[index]), IDS[index] + " paired theme")
		check(boss_definition.boss_style == index, IDS[index] + " distinct Boss pattern")
		check(not seen_layouts.has(definition.layout.resource_path) and not seen_waves.has(definition.enemy_config.resource_path), IDS[index] + " independent edit resources")
		seen_layouts[definition.layout.resource_path] = true
		seen_waves[definition.enemy_config.resource_path] = true
		var waves: TABLE = definition.enemy_config
		check(waves.start_seconds.size() == 12 and waves.phase_names.size() == 12, IDS[index] + " twelve authored beats")
		check(waves.wave_index(299.9) == 8 and waves.wave_index(300.0) == 9, IDS[index] + " five-minute transition")
		check(waves.wave_index(390.0) == 9 and waves.wave_index(465.0) == 11 and waves.wave_index(480.0) == 9, IDS[index] + " post-gate loop repeats")
		check(waves.alive_cap(11) < waves.alive_cap(10) and waves.interval(11) > waves.interval(10), IDS[index] + " loop breathes after peak")
		var kinds := []
		for row in waves.rows:
			if waves.weight(row, 0) > 0.0:
				kinds.append(row.kind)
		check(kinds.size() == (2 if index == 0 else 1), IDS[index] + " opening avoids all-monster mixture")
		if index == 0:
			check(kinds.has(4) and kinds.has(0) and not kinds.has(6), "first wave uses slime and skeleton")
		var row: ROW = waves.rows[0]
		var early: Dictionary = waves.stats_for(row, 0.0)
		var late: Dictionary = waves.stats_for(row, 600.0)
		check(early.hp > 2.0 and late.hp > early.hp, IDS[index] + " health scales beyond old fixed two")
		check(late.damage_multiplier >= early.damage_multiplier and late.speed_multiplier <= 1.2, IDS[index] + " difficulty retains readable movement")
		var actors := Node2D.new()
		root.add_child(actors)
		var boss := BOSS.new()
		root.add_child(boss)
		boss.setup(actors, true, boss_definition.layout.playable_bounds(), index, boss_definition.boss_name)
		check(boss.display_name == boss_definition.boss_name and boss.entry.hp == boss.max_hp, IDS[index] + " configured Boss title and health")
		boss.target = Vector2(640, 430)
		boss.fire()
		check(not boss.shots.is_empty() if index in [0, 1] else (not boss.zones.is_empty() if index in [2, 4] else boss.phase == boss.Phase.AIM_DASH), IDS[index] + " expected attack family")
		if index == 1:
			check(boss.zones.size() == 1, "web Boss adds delayed landing web")
		if index == 2:
			check(boss.zones.size() == 5, "spore Boss leaves one of six positions open")
		if index == 4:
			check(boss.zones.size() == 2, "capital Boss leaves one of three sectors open")
		boss.sound.stop()
		boss.sound.stream = null
		boss.free()
		actors.free()
	# fire() starts a playback; stopped audio releases on the mix thread after the fixtures leave.
	await process_frame
	await process_frame
	await create_timer(0.25).timeout
	print(JSON.stringify({"suite":"five_region_encounters", "checks":checks, "failures":failures}))
	quit(0 if failures.is_empty() else 1)

extends SceneTree

const ABILITIES := preload("res://data/alchemy_abilities/alchemy_ability_data.gd")
const STEP := .01

var failures: Array[String] = []
var emitted: Array[Dictionary] = []
var hits: Array[Dictionary] = []
var bodies: Array[Node2D] = []
var missing_health := 20.0

func _init() -> void:
	_thunder_salt()
	_fire_oil()
	_mercury_ring()
	_frost_powder()
	_wind_flask()
	_renewal_flask()
	for body in bodies:
		body.free()
	if failures.is_empty():
		print("SKILL_EXPANSION_COMBAT_SMOKE_PASS")
	else:
		for failure in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)

func play_skill_fx(info: Dictionary) -> void:
	emitted.append(info)

func _record_hit(entry: Dictionary, damage: float, _slow: float, _factor: float, _color: Color) -> void:
	hits.append({"entry": entry, "damage": damage})

func _heal(amount: float) -> float:
	var recovered := minf(amount, missing_health)
	missing_health -= recovered
	return recovered

func _skill(id: StringName, split := false) -> SkillManager:
	emitted.clear()
	hits.clear()
	var manager := SkillManager.new()
	manager.setup(ABILITIES.ABILITY_SPLIT if split else ABILITIES.ABILITY_INITIAL, self)
	check(manager.add_skill(id), "unable to equip %s" % id)
	return manager

func _enemy(at: Vector2, elite := false, boss := false) -> Dictionary:
	var body := Node2D.new()
	body.position = at
	bodies.append(body)
	return {"body": body, "hp": 100.0, "elite": elite, "boss": boss}

func _run(manager: SkillManager, seconds: float, player: Vector2, enemies: Array, context: Dictionary = {}) -> void:
	for frame in roundi(seconds / STEP):
		manager.cast_equipped(STEP, player, enemies, _record_hit, context)

func _thunder_salt() -> void:
	var ordinary := _enemy(Vector2(24, 0))
	var elite := _enemy(Vector2(200, 0), true)
	var manager := _skill(&"sk_thunder_salt")
	manager.cast_equipped(0.0, Vector2.ZERO, [], _record_hit)
	check(emitted.is_empty() and manager.runtimes[0].ready(), "empty range starts no lightning or cooldown")
	_run(manager, .32, Vector2.ZERO, [ordinary, elite])
	check(hits.size() == 1 and hits[0].entry == elite and is_equal_approx(hits[0].damage, 42.0), "lightning first targets elite and hits once at .32 s")

	manager = _skill(&"sk_thunder_salt", true)
	_run(manager, .32, Vector2.ZERO, [ordinary, elite])
	check(hits.size() == 2 and hits[0].entry != hits[1].entry, "split lightning chooses different targets when possible")
	check(hits.size() == 2 and is_equal_approx(hits[0].damage + hits[1].damage, 50.4), "split lightning applies 60% per branch")
	check(_sides_for("cast") == [-1, 1] and _sides_for("impact") == [1, -1], "split toss emits a distinct launch and impact for each branch")

	manager = _skill(&"sk_thunder_salt")
	manager.cast_equipped(0.0, Vector2.ZERO, [ordinary], _record_hit)
	ordinary.hp = 0.0
	_run(manager, .40, Vector2.ZERO, [ordinary, elite])
	check(hits.is_empty() and manager.active.is_empty(), "lost lightning target fizzles instead of retargeting")

func _fire_oil() -> void:
	var enemy := _enemy(Vector2(42, 0))
	var manager := _skill(&"sk_fire_oil", true)
	manager.cast_equipped(0.0, Vector2.ZERO, [enemy], _record_hit)
	check(manager.runtimes[0].ready(), "standing still does not fire oil")
	manager.cast_equipped(0.0, Vector2.ZERO, [enemy], _record_hit, {"moving": true})
	manager.cast_equipped(STEP, Vector2(56, 0), [enemy], _record_hit, {"moving": true})
	var patches := manager.active.filter(func(state: Dictionary) -> bool: return state.kind == "oil_patch")
	check(patches.size() == 4, "real travel creates two oil lanes with two patches each")
	_run(manager, .45, Vector2(56, 0), [enemy])
	check(hits.size() == 2 and is_equal_approx(hits[0].damage + hits[1].damage, 9.6), "overlapping oil patches tick once per branch")
	_run(manager, .90, Vector2(56, 0), [enemy])
	check(hits.size() == 6, "each oil lane applies one tick per interval")

func _mercury_ring() -> void:
	var enemy := _enemy(Vector2(100, 0))
	var manager := _skill(&"sk_mercury_ring", true)
	_run(manager, .21, Vector2.ZERO, [enemy])
	check(hits.is_empty(), "mercury does not damage before the front reaches the target")
	_run(manager, .35, Vector2(20, 0), [enemy])
	check(hits.size() == 2 and is_equal_approx(hits[0].damage + hits[1].damage, 31.2), "fixed rings each deal one 60% hit after sweeping")
	check(_sides_for("zone_start") == [-1, 1], "delayed split front starts exactly once per genuine branch")
	check(manager.active.is_empty(), "mercury states finish at maximum radius")

func _frost_powder() -> void:
	var ordinary := _enemy(Vector2(60, 0))
	var elite := _enemy(Vector2(64, 0), true)
	var boss := _enemy(Vector2(70, 0), false, true)
	var manager := _skill(&"sk_frost_powder", true)
	manager.cast_equipped(0.0, Vector2.ZERO, [elite, boss], _record_hit)
	check(manager.runtimes[0].ready(), "ineligible targets do not consume frost cooldown")
	_run(manager, .20, Vector2.ZERO, [ordinary, elite, boss])
	check(is_equal_approx(ordinary.get("freeze_left", 0.0), .51), "overlapping frost uses longest freeze, with split duration")
	check(not elite.has("freeze_left") and not boss.has("freeze_left") and hits.is_empty(), "frost affects briefly only ordinary enemies and deals no damage")

func _wind_flask() -> void:
	var ordinary := _enemy(Vector2(48, 0))
	var boss := _enemy(Vector2(65, 0), false, true)
	var manager := _skill(&"sk_wind_flask", true)
	manager.cast_equipped(0.0, Vector2.ZERO, [boss], _record_hit)
	check(manager.runtimes[0].ready(), "boss-only encounter does not consume wind cooldown")
	manager.cast_equipped(0.0, Vector2.ZERO, [ordinary, boss], _record_hit)
	check(is_equal_approx(ordinary.body.position.x, 48.0 + 64.0 * .9 * .6), "overlapping cones push each body once")
	check(boss.body.position == Vector2(65, 0) and emitted.size() == 2 and hits.is_empty(), "wind ignores boss and displays both genuine cones")

func _renewal_flask() -> void:
	var manager := _skill(&"sk_renewal_flask", true)
	var context := {"missing_health": 0.0, "heal": _heal, "facing": Vector2.RIGHT, "bounds": Rect2(-5, -5, 200, 200)}
	manager.cast_equipped(0.0, Vector2.ZERO, [], _record_hit, context)
	check(manager.runtimes[0].ready(), "full health skips renewal cast")
	context.missing_health = 20.0
	missing_health = 20.0
	_run(manager, .50, Vector2.ZERO, [], context)
	check(is_equal_approx(missing_health, 17.6), "overlap can restore both 60% pulses at the fixed starting position")
	var centers: Array[Vector2] = []
	for item in emitted:
		if item.event == "zone_start":
			centers.append(item.target)
	check(_sides_for("zone_start") == [-1, 1] and centers.has(Vector2(0, -5)) and centers.has(Vector2(0, 20)),
		"both pool starts are labeled and centers honor finite battle bounds")
	_run(manager, .50, Vector2(160, 0), [], context)
	check(is_equal_approx(missing_health, 17.6), "moving out of the fixed pools skips healing")
	missing_health = .5
	_run(manager, .50, Vector2.ZERO, [], context)
	check(missing_health == 0.0, "combined heal is capped by missing health")

func _sides_for(event: String) -> Array[int]:
	var sides: Array[int] = []
	for item in emitted:
		if item.event == event:
			sides.append(int(item.split_side))
	return sides

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

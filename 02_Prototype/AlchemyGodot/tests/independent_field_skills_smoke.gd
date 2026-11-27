extends SceneTree

const FIELD_SKILLS := preload("res://scripts/skills/skill_independent_field.gd")
const STEP := 1.0 / 60.0
const FURNACE := &"combo_furnace"
const REWIND := &"combo_rewind_anchor"
const WALL := &"combo_crystal_wall"
const COUNTER := &"combo_opening_counter"
const DEW := &"combo_dew_pickup"


class Rules:
	extends RefCounted
	var equipped: StringName
	var casts := 0
	var effects: Array[Dictionary] = []

	func ready(id: StringName) -> bool:
		return id == equipped and casts == 0

	func commit(id: StringName) -> float:
		if not ready(id):
			return 0.0
		casts += 1
		return 1.0

	func emit(id: StringName, data: Dictionary) -> void:
		effects.append({"id": id, "data": data})

	func clip(context: Dictionary, from: Vector2, to: Vector2) -> Vector2:
		var clipping: Callable = context.get("clip_segment", Callable())
		return clipping.call(from, to) if clipping.is_valid() else to

	func clear_path(context: Dictionary, from: Vector2, to: Vector2) -> bool:
		return clip(context, from, to).distance_squared_to(to) < 0.04


var _rules := Rules.new()
var _field := FIELD_SKILLS.new()
var _targets: Array[Dictionary] = []
var _hits: Array[Dictionary] = []
var _interrupts := 0
var _heals: Array[float] = []
var _checks := 0
var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_field.setup(_rules)
	_test_furnace()
	_test_rewind()
	_test_wall()
	_test_counter()
	_test_dew()
	_fixture(&"", [])
	print("INDEPENDENT_FIELD_SKILLS checks=%d failures=%d" % [_checks, _failures])
	quit(int(_failures != 0))


func _fixture(id: StringName, positions: Array[Vector2]) -> void:
	_field.clear()
	for entry in _targets:
		entry.body.free()
	_targets.clear()
	_rules.equipped = id
	_rules.casts = 0
	_rules.effects.clear()
	_hits.clear()
	_heals.clear()
	_interrupts = 0
	for point in positions:
		var body := Node2D.new()
		root.add_child(body)
		body.position = point
		_targets.append({"body": body, "hp": 100.0, "boss": false})


func _context(from := Vector2.ZERO) -> Dictionary:
	return {"move_from": from, "ordinary_motion": true, "frame_delta": STEP, "walk_speed": 200.0,
		"combo_damage": _damage, "interrupt_attack": _interrupt, "heal": _heal, "missing_health": 3.0}


func _test_furnace() -> void:
	_fixture(FURNACE, [Vector2(90, 4), Vector2(135, 0), Vector2(-95, 0)])
	var context := _context()
	context.clip_segment = _clip_at_110
	_field.tick(STEP, Vector2.ZERO, _targets, context)
	_check(_last(FURNACE, "charge").get("target") == Vector2.ZERO and _rules.casts == 0, "valid crowd prepares one centered furnace")
	_field.tick(1.12, Vector2.ZERO, _targets, context)
	_field.tick(0.28, Vector2(80, 0), _targets, context)
	for frame in 30:
		_field.tick(STEP, Vector2(80.0 + frame, 0), _targets, context)
	_check(_rules.casts == 1, "exit commits once")
	_check(_hits.size() == 1 and _hits[0].entry == _targets[0] and is_equal_approx(_hits[0].amount, 42.0),
		"charged wave expands right, stops at the wall, and hits one time at hot damage")
	_fixture(FURNACE, [Vector2(90, 4)])
	_targets[0].boss = true
	_field.tick(STEP, Vector2.ZERO, _targets, _context())
	context = _context()
	context.forced_motion = true
	_field.tick(STEP, Vector2(90, 0), _targets, context)
	_check(_rules.casts == 0 and _field._furnace.is_empty(), "a boss qualifies but forced displacement cancels the circle")


func _test_rewind() -> void:
	_fixture(REWIND, [Vector2(-150, 0), Vector2(150, 0), Vector2(90, 0)])
	_targets[2].anchored = true
	var context := _context()
	for frame in 15:
		if frame > 0:
			_targets[0].body.position.x += 2.0
			_targets[1].body.position.x -= 2.0
		_field.tick(STEP, Vector2.ZERO, _targets, context)
	_check(_rules.casts == 1 and _field._rewind.sites.size() == 2, "only converging movable enemies form the anchor")
	var sites: Array = _field._rewind.sites
	var left_anchor: Vector2 = sites[0].point if sites[0].point.x < 0.0 else sites[1].point
	_targets[0].body.position.x = -60.0
	_targets[1].body.position.x = 60.0
	_field.tick(0.60, Vector2.ZERO, _targets, context)
	_check(_field.is_rewinding(_targets[0]) and _targets[0].body.position.x < -60, "anchor takes over live movement")
	_field.tick(0.24, Vector2.ZERO, _targets, context)
	_check(_targets[0].body.position.is_equal_approx(left_anchor) and not _field.is_rewinding(_targets[0]),
		"rewind restores old feet and clears movement ownership")
	_check(_targets[2].body.position == Vector2(90, 0) and _hits.is_empty(), "fixed dummy stays put and rewind deals no damage")
	_check(_last_event(REWIND, "combo_launch") and _last_event(REWIND, "combo_hit"),
		"rewind announces both the actual reversal and completed displacement")

	_fixture(REWIND, [Vector2(175, -8), Vector2(182, 11)])
	for frame in 13:
		if frame > 0:
			for entry in _targets:
				entry.body.position.x -= 0.35
		_field.tick(STEP, Vector2.ZERO, _targets, context)
	_check(_rules.casts == 1 and _field._rewind.sites.size() == 2,
		"slow enemies pursuing from the same side still trigger rewind")

	_fixture(REWIND, [Vector2(130, 0)])
	for frame in 13:
		if frame > 0:
			_targets[0].body.position.x -= 1.0
		_field.tick(STEP, Vector2.ZERO, _targets, context)
	_check(_rules.casts == 1 and _field._rewind.sites.size() == 1,
		"one nearby enemy triggers after longer continuing pursuit")
	if not _field._rewind.is_empty():
		_check(_field._rewind.sites[0].point == Vector2(130, 0),
			"anchor keeps the older foot position from the start of approach")


func _test_wall() -> void:
	_fixture(WALL, [Vector2(180, 0), Vector2(170, -27), Vector2(170, 28)])
	var context := _context()
	_field.tick(STEP, Vector2.ZERO, _targets, context)
	_check(_rules.casts == 0 and not _last(WALL, "preview").is_empty(), "wall shows a pre-placement preview before cooldown")
	_field.tick(0.23, Vector2.ZERO, _targets, context)
	var start := Vector2(150, 0)
	var finish := Vector2.ZERO
	var stop := _field.stop_enemy_motion(_targets[0], start, finish)
	_check(_rules.casts == 1 and stop.x > 73.0 and stop.x < 104.0, "wall blocks an ordinary enemy's actual travel")
	_check(_field.enemy_steering(_targets[0], finish) != finish, "enemy steering chooses a route around an end")
	_targets[0].flying = true
	_check(_field.stop_enemy_motion(_targets[0], start, finish) == finish, "flying enemies are unaffected")
	_field.boss_sweep(start, finish)
	_check(_field._wall.is_empty() and _last_event(WALL, "combo_hit"), "boss contact removes wall and emits one shatter")


func _test_counter() -> void:
	_fixture(COUNTER, [Vector2(70, 0), Vector2(30, 0), Vector2(135, 0), Vector2(-39, 0)])
	var context := _context()
	context.ordinary_motion = false
	context.clip_segment = _clip_at_110
	_targets[0].windup = {"token": 3, "aim": Vector2.LEFT, "remaining": 0.50, "interruptible": true}
	_field.tick(STEP, Vector2.ZERO, _targets, context)
	var marker := _last(COUNTER, "warn")
	_check(marker.get("target") == Vector2.ZERO and _rules.casts == 0,
		"live enemy windup begins a centered warning without immediately spending cooldown")
	context.frame_delta = 0.13
	_field.pre_actor_tick(Vector2(40, 0), _targets, context)
	_field.tick(0.13, Vector2(40, 0), _targets, context)
	_check(_last(COUNTER, "warn").get("target") == Vector2(40, 0) and _rules.casts == 0,
		"warning follows actual player feet and uses one countdown update per frame")
	_field.pre_actor_tick(Vector2(60, 0), _targets, context)
	_check(_rules.casts == 1 and _interrupts == 1 and _hits.size() == 2 and _hits[0].amount == 26.0 and _hits[1].amount == 26.0,
		"automatic stomp hits all visible enemies in range, then only interrupts the recorded source")

	_fixture(COUNTER, [Vector2(70, 0)])
	_targets[0].boss = true
	_targets[0].windup = {"token": 3, "aim": Vector2.LEFT, "remaining": 0.40, "interruptible": true}
	_field.tick(STEP, Vector2.ZERO, _targets, context)
	_field.tick(0.27, Vector2.ZERO, _targets, context)
	_check(_hits.size() == 1 and _interrupts == 0, "boss takes stomp damage while keeping its attack")

	_fixture(COUNTER, [Vector2(104, 0)])
	_targets[0].windup = {"token": 3, "aim": Vector2.LEFT, "remaining": 0.16, "interruptible": true}
	_field.tick(STEP, Vector2.ZERO, _targets, context)
	_field.tick(0.27, Vector2.ZERO, _targets, context)
	_check(_last_event(COUNTER, "combo_launch") and _rules.casts == 0 and _hits.is_empty(),
		"an empty stomp keeps its cooldown ready after a short retry")


func _test_dew() -> void:
	_fixture(DEW, [])
	var context := _context()
	context.valid_dew_ground = func(point: Vector2) -> bool: return point.x >= 70.0
	_field.notify_kill(Vector2(60, 0), context)
	_field.notify_kill(Vector2(100, 0), context)
	var effect := _last(DEW, "pickup")
	_check(_rules.casts == 1 and (effect.get("target", Vector2.ZERO) as Vector2).x >= 70.0,
		"only one kill pickup lands and finds nearby legal ground")
	context.missing_health = 0.0
	_field.tick(STEP, effect.get("target"), _targets, context)
	_check(not _field._dew.is_empty() and _heals.is_empty(), "full-health contact leaves the pickup")
	context.missing_health = 3.0
	_field.tick(STEP, effect.get("target"), _targets, context)
	_check(_heals == [3.0] and _field._dew.is_empty(), "pickup records real capped healing and is collected once")


func _damage(id: StringName, entry: Dictionary, amount: float) -> void:
	_hits.append({"id": id, "entry": entry, "amount": amount})


func _interrupt(entry: Dictionary, token: int, duration: float) -> bool:
	if token != int(entry.windup.token) or not is_equal_approx(duration, 0.24):
		return false
	_interrupts += 1
	entry.erase("windup")
	return true


func _heal(amount: float) -> float:
	var actual := minf(3.0, amount)
	_heals.append(actual)
	return actual


func _clip_at_110(from: Vector2, to: Vector2) -> Vector2:
	if from.x < 110.0 and to.x > 110.0:
		return from.lerp(to, (110.0 - from.x) / (to.x - from.x))
	return to


func _last(id: StringName, phase: String) -> Dictionary:
	for index in range(_rules.effects.size() - 1, -1, -1):
		var effect: Dictionary = _rules.effects[index]
		if effect.id == id and effect.data.get("phase", "") == phase:
			return effect.data
	return {}


func _last_event(id: StringName, event: String) -> bool:
	return _rules.effects.any(func(effect: Dictionary) -> bool: return effect.id == id and effect.data.event == event)


func _check(result: bool, note: String) -> void:
	_checks += 1
	if not result:
		_failures += 1
		push_error("INDEPENDENT_FIELD_SKILLS: " + note)

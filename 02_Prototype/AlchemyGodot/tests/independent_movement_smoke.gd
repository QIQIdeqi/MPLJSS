extends SceneTree

const MOVEMENT := preload("res://scripts/skills/skill_independent_movement.gd")
const LILITA := preload("res://scripts/lilita.gd")
const CLEANSER := &"combo_cleanser"
const GATE := &"combo_crystal_gate"

class Rules:
	extends RefCounted
	var commits: Dictionary
	var events: Array[Dictionary] = []

	func ready(id: StringName) -> bool:
		return not commits.has(id)

	func commit(id: StringName) -> float:
		if not ready(id):
			return 0.0
		commits[id] = true
		return 1.0

	func emit(id: StringName, info: Dictionary) -> void:
		var event := info.duplicate()
		event.skill_id = id
		events.append(event)

	func clip(context: Dictionary, _from: Vector2, target: Vector2) -> Vector2:
		return Vector2(target.x, minf(target.y, float(context.get("max_y", INF))))

	func clear_path(_context: Dictionary, _from: Vector2, _target: Vector2) -> bool:
		return true

var _rules: Rules
var _movement: MOVEMENT
var _checks := 0
var _failures := 0
var _exit_valid := true
var _enemy: Node2D
var _native_attempts := 0
var _ends := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_enemy = Node2D.new()
	_enemy.position = Vector2(150.0, 0.0)
	root.add_child(_enemy)
	_test_pool()
	_test_cut()
	_test_ineffective_cut()
	_test_gate()
	_test_retry_and_recheck()
	await _test_player_gate()
	_enemy.free()
	print("INDEPENDENT_MOVEMENT checks=%s failures=%s" % [_checks, _failures])
	quit(int(_failures > 0))


func _setup() -> void:
	_rules = Rules.new()
	_movement = MOVEMENT.new()
	_movement.setup(_rules)
	_exit_valid = true


func _test_pool() -> void:
	_setup()
	var landing := Vector2(-80, 0)
	var outside := landing + Vector2.UP * 93.0
	var foes := [{"body": _enemy, "hp": 100.0}]
	_movement.tick(0.0, Vector2.ZERO, foes, {})
	_movement.begin_ordinary_dodge(Vector2.ZERO)
	_movement.observe_dodge_motion(Vector2.ZERO, Vector2(-8, 0), false)
	_movement.finish_ordinary_dodge(Vector2(-8, 0))
	_check(_rules.ready(CLEANSER), "A blocked ordinary dodge with minimal travel does not spend the cooldown")
	_movement.begin_ordinary_dodge(Vector2.ZERO)
	_movement.observe_dodge_motion(Vector2.ZERO, landing, false)
	_movement.finish_ordinary_dodge(landing)
	_check(not _rules.ready(CLEANSER), "Dodging away from a nearby enemy activates with no hazard")
	_check(is_equal_approx(_movement.enemy_walk_scale(landing), 0.62)
		and is_equal_approx(_movement.enemy_walk_scale(outside), 1.0), "Slow is limited to the landing pool")
	_check(is_equal_approx(_movement.player_walk_scale(), 1.30), "Dodge landing immediately grants walking speed")
	_movement.tick(0.45, outside, foes, {})
	_check(is_equal_approx(_movement.player_walk_scale(), 1.30), "Speed persists briefly beyond the pool")
	_movement.tick(0.11, outside, foes, {})
	_check(is_equal_approx(_movement.player_walk_scale(), 1.0), "Speed expires after leaving the pool")
	_movement.tick(1.0, landing, foes, {})
	_check(is_equal_approx(_movement.player_walk_scale(), 1.30), "Reentering an active pool restores the boost")
	_movement.tick(1.25, outside, foes, {})
	_check(is_equal_approx(_movement.enemy_walk_scale(landing), 1.0), "The pool expires independently of cooldown")
	_movement.clear()
	_check(is_equal_approx(_movement.player_walk_scale(), 1.0), "Room cleanup clears the speed boost")


func _test_cut() -> void:
	_setup()
	var first := {"id": 7, "pos": Vector2(30, 0), "radius": 50.0, "remaining": 1.8}
	var second := {"id": 3, "pos": Vector2(78, 0), "radius": 50.0, "remaining": 2.5}
	var context := {"hazards": [second, first], "max_y": 28.0}
	_movement.tick(0.0, Vector2(-40, 18), [], context)
	_movement.begin_ordinary_dodge(Vector2(-40, 18))
	_movement.observe_dodge_motion(Vector2(-40, 18), Vector2(12, 18), false)
	_movement.observe_dodge_motion(Vector2(12, 18), Vector2(95, 18), false)
	_check(_rules.ready(CLEANSER), "movement has not spent cooldown mid-dodge")
	_movement.finish_ordinary_dodge(Vector2(95, 18))
	_check(not _rules.ready(CLEANSER), "an actual crossing spends cooldown")
	_check(_movement.hazard_safe(7, Vector2(45, 18)), "the first active hazard by contact owns the safe path")
	_check(not _movement.hazard_safe(3, Vector2(45, 18)), "overlapping second zone stays harmful")
	_check(not _movement.hazard_safe(7, Vector2(45, 35)), "terrain clips the lateral safety limit")
	var fill := _movement.hazard_fill(7)
	_check(not fill.is_empty(), "the original poison remains visible outside the strip")
	_check(not _inside_fill(Vector2(45, 18), fill) and _inside_fill(Vector2(45, 35), fill),
		"visible hazard fill exposes the ground only in the safe path")
	_movement.tick(0.3, Vector2(45, 18), [], {"hazards": [second]})
	_check(not _movement.hazard_safe(7, Vector2(45, 18)), "expired source ends the cut immediately")


func _test_ineffective_cut() -> void:
	_setup()
	var active := {"id": 6, "pos": Vector2.ZERO, "radius": 48.0, "remaining": 2.8}
	_movement.tick(0.0, Vector2(-55, 0), [], {"hazards": [active]})
	_movement.begin_ordinary_dodge(Vector2(-55, 0))
	_movement.observe_dodge_motion(Vector2(-55, 0), Vector2(-43, 0), false)
	_movement.observe_dodge_motion(Vector2(-43, 0), Vector2(8, 0), true)
	_movement.finish_ordinary_dodge(Vector2(8, 0))
	_check(_rules.ready(CLEANSER), "only reachable unforced motion contributes to the minimum cut length")
	_movement.begin_ordinary_dodge(Vector2(-55, 0))
	_movement.observe_dodge_motion(Vector2(-55, 0), Vector2(8, 0), false)
	_movement.tick(0.1, Vector2(8, 0), [], {"hazards": []})
	_movement.finish_ordinary_dodge(Vector2(8, 0))
	_check(_rules.ready(CLEANSER), "a zone must still be active when the ordinary dodge completes")
	_movement.tick(0.0, Vector2.ZERO, [{"body": _enemy, "hp": 100.0}], {})
	_movement.begin_ordinary_dodge(Vector2.ZERO)
	_movement.observe_dodge_motion(Vector2.ZERO, Vector2(50, 0), false)
	_movement.observe_dodge_motion(Vector2(50, 0), Vector2(80, 0), true)
	_movement.finish_ordinary_dodge(Vector2(80, 0))
	_check(_rules.ready(CLEANSER), "Knockback interrupts activation even with a nearby enemy")


func _test_gate() -> void:
	_setup()
	var preview := _run_until_gate()
	_check(not preview.is_empty(), "running at a valid heading shows one paired gate")
	if preview.is_empty():
		return
	_check(_rules.ready(GATE), "a gate preview does not spend cooldown")
	_check(_movement.use_gate(Vector2(-100, 0), true) == null, "feet must be inside the entrance")
	_check(_movement.use_gate(preview.from, false) == null, "native dodge must be ready")
	var destination: Variant = _movement.use_gate(preview.from, true)
	_check(destination == preview.target and not _rules.ready(GATE), "gate spends cooldown at the reviewed exit")
	_check(absf((destination as Vector2).y) > 0.0, "an invalid center exit uses a legal lateral stand point")
	_check(_movement.use_gate(preview.from, true) == null, "one preview cannot trigger twice")


func _test_retry_and_recheck() -> void:
	_setup()
	var preview := _run_until_gate()
	if preview.is_empty():
		_check(false, "gate preview fixture")
		return
	_exit_valid = false
	_check(_movement.use_gate(preview.from, true) == null and _rules.ready(GATE),
		"invalidated exit preserves cooldown and allows native dodge fallback")
	_exit_valid = true
	_movement.tick(0.2, preview.from, [], {})
	var previews := _rules.events.filter(func(event: Dictionary) -> bool: return event.event == "combo_update")
	_check(previews.size() == 1, "failed exits do not immediately regenerate the gate")

func _test_player_gate() -> void:
	_setup()
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down", &"dodge"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	var preview := _run_until_gate()
	if preview.is_empty():
		_check(false, "gate preview for player integration test")
		return
	var player := LILITA.new()
	var art := Sprite2D.new()
	art.name = "Art"
	player.add_child(art)
	root.add_child(player)
	player.set_physics_process(false)
	player.clamp_to_battle_bounds = false
	player.position = preview.from
	player.resolve_gate_dodge = func(at: Vector2) -> Variant: return _movement.use_gate(at, true)
	player.resolve_dodge = func(_at: Vector2, _heading: Vector2, _ready: bool, _distance: float) -> float:
		_native_attempts += 1
		return 1.0
	player.dodge_finished.connect(func(_at: Vector2, _heading: Vector2) -> void: _ends += 1)
	await _press_player_dodge(player)
	_check(player.position.is_equal_approx(preview.target as Vector2), "actual dodge input traverses the gate")
	_check(is_equal_approx(player.dodge, LILITA.DODGE_DURATION) and is_equal_approx(player.cooldown, LILITA.DODGE_COOLDOWN),
		"traversing uses the native dodge duration and cooldown")
	_check(player.forced_motion and not player.ordinary_motion and _native_attempts == 0,
		"traversal excludes voluntary path and the normal skill resolver")
	await physics_frame
	player._physics_process(0.19)
	_check(_ends == 0, "traversal does not trigger the return dodge finish event")
	player.cooldown = 0.0
	await _press_player_dodge(player)
	_check(_native_attempts == 1 and player.ordinary_motion and not player.forced_motion,
		"normal dodges still use the native resolver and produce motion")
	player.free()

func _press_player_dodge(player: LILITA) -> void:
	await physics_frame
	Input.action_press(&"move_right")
	Input.action_press(&"dodge")
	await physics_frame
	player._physics_process(0.01)
	Input.action_release(&"dodge")
	Input.action_release(&"move_right")


func _run_until_gate() -> Dictionary:
	var previous := Vector2.ZERO
	for index in range(1, 31):
		var at := Vector2(float(index) * 3.2, 0.0)
		var context := {"moving": true, "walk_from": previous, "gate_exit_valid": _allow_exit}
		_movement.tick(1.0 / 60.0, at, [{"body": _enemy, "hp": 100.0}], context)
		for event in _rules.events:
			if event.event == "combo_update" and event.skill_id == GATE:
				return event
		previous = at
	return {}


func _allow_exit(_entry: Vector2, exit: Vector2) -> bool:
	return _exit_valid and absf(exit.y) > 0.0


func _inside_fill(point: Vector2, fill: Array[PackedVector2Array]) -> bool:
	return fill.any(func(polygon: PackedVector2Array) -> bool: return Geometry2D.is_point_in_polygon(point, polygon))


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error(label)

extends RefCounted

const SKILLS := preload("res://data/skills/skill_data.gd")
const CLEANSER := &"combo_cleanser"
const GATE := &"combo_crystal_gate"
const U := SKILLS.UNIT
const CUT_WIDTH := 0.72 * U
const CUT_LENGTH := 1.50 * U
const CUT_MINIMUM := 0.30 * U
const CUT_LIFE := 2.80
const GATE_RADIUS := 0.38 * U
const GATE_LIFE := 2.20
const EPSILON := 0.00001

var _rules
var _context: Dictionary
var _hazards: Array
var _tracking := false
var _chosen_hazard := -1
var _traces: Array[PackedVector2Array] = []
var _trace_length := 0.0
var _cut: Dictionary
var _gate: Dictionary
var _gate_retry := 0.0
var _run_heading := Vector2.ZERO
var _run_time := 0.0
var _run_distance := 0.0


func setup(rules) -> void:
	_rules = rules


func clear() -> void:
	_end_cut()
	_end_gate()
	_reset_run()
	_gate_retry = 0.0
	_tracking = false
	_chosen_hazard = -1
	_traces.clear()
	_trace_length = 0.0
	_context = {}
	_hazards = []


func tick(delta: float, at: Vector2, enemies: Array, context: Dictionary) -> void:
	_context = context
	_hazards = context.get("hazards", [])
	if not _cut.is_empty():
		_cut.left = float(_cut.left) - delta
		var hazard := _hazard(int(_cut.id))
		if hazard.is_empty() or float(_cut.left) <= 0.0:
			_end_cut()
		else:
			_emit_cut("combo_update", minf(float(_cut.left), float(hazard.remaining)))
	_tick_gate(delta, at, enemies)


func begin_ordinary_dodge() -> void:
	_tracking = _rules.ready(CLEANSER) and _cut.is_empty()
	_chosen_hazard = -1
	_traces.clear()
	_trace_length = 0.0


func observe_dodge_motion(from: Vector2, at: Vector2, knocked_back: bool) -> void:
	if not _tracking or knocked_back or _trace_length >= CUT_LENGTH:
		return
	var delta := at - from
	var length := delta.length()
	if length <= EPSILON:
		return
	var interval := Vector2(-1.0, -1.0)
	if _chosen_hazard < 0:
		for candidate: Dictionary in _hazards:
			if float(candidate.remaining) <= 0.0:
				continue
			var intersection := _circle_interval(from, delta, candidate)
			if intersection.y <= intersection.x:
				continue
			var candidate_id := int(candidate.id)
			if interval.x < 0.0 or intersection.x < interval.x - EPSILON \
					or (is_equal_approx(intersection.x, interval.x) and candidate_id < _chosen_hazard):
				_chosen_hazard = candidate_id
				interval = intersection
	else:
		var hazard := _hazard(_chosen_hazard)
		if not hazard.is_empty():
			interval = _circle_interval(from, delta, hazard)
	if interval.x < 0.0 or interval.y <= interval.x:
		return
	var start := from + delta * interval.x
	var added := minf((interval.y - interval.x) * length, CUT_LENGTH - _trace_length)
	var end := start + delta / length * added
	if _traces.is_empty() or not _traces[-1][-1].is_equal_approx(start):
		_traces.append(PackedVector2Array([start, end]))
	else:
		var trace := _traces[-1]
		trace.append(end)
		_traces[-1] = trace
	_trace_length += added


func finish_ordinary_dodge() -> void:
	if not _tracking:
		return
	_tracking = false
	var hazard := _hazard(_chosen_hazard)
	if _trace_length < CUT_MINIMUM or hazard.is_empty() or not _rules.ready(CLEANSER):
		return
	var outline := _hazard_outline(hazard.pos, float(hazard.radius))
	var footprints: Array[PackedVector2Array] = []
	for trace: PackedVector2Array in _traces:
		for index in range(1, trace.size()):
			var from := trace[index - 1]
			var at := trace[index]
			var lateral := from.direction_to(at).orthogonal() * (CUT_WIDTH * 0.5)
			var footprint := PackedVector2Array([
				_rules.clip(_context, from, from + lateral),
				_rules.clip(_context, at, at + lateral),
				_rules.clip(_context, at, at - lateral),
				_rules.clip(_context, from, from - lateral),
			])
			for polygon in Geometry2D.intersect_polygons(footprint, outline):
				if polygon.size() >= 3:
					footprints.append(polygon)
	if footprints.is_empty() or _rules.commit(CLEANSER) <= 0.0:
		return
	var fill: Array[PackedVector2Array] = [outline]
	for footprint: PackedVector2Array in footprints:
		fill = _subtract_footprint(fill, footprint)
	_cut = {"id": _chosen_hazard, "left": CUT_LIFE, "path": _traces[0],
		"mask": _merge_footprints(footprints), "fill": fill}
	var duration := minf(CUT_LIFE, float(hazard.remaining))
	_emit_cut("combo_launch", duration)
	_emit_cut("combo_update", duration)


func hazard_safe(hazard_id: int, at: Vector2) -> bool:
	for polygon in hazard_mask(hazard_id):
		if Geometry2D.is_point_in_polygon(at, polygon):
			return true
	return false


func hazard_mask(hazard_id: int) -> Array[PackedVector2Array]:
	if not _cut.is_empty() and int(_cut.id) == hazard_id:
		return _cut.mask
	return []


func hazard_fill(hazard_id: int) -> Array[PackedVector2Array]:
	if not _cut.is_empty() and int(_cut.id) == hazard_id:
		return _cut.fill
	return []


func use_gate(at: Vector2, ordinary_ready: bool) -> Variant:
	if not ordinary_ready or _gate.is_empty() or not _rules.ready(GATE):
		return null
	var entry: Vector2 = _gate.entry
	if at.distance_squared_to(entry) > GATE_RADIUS * GATE_RADIUS:
		return null
	var destination: Vector2 = _gate.exit
	if not _can_exit(entry, destination):
		_end_gate()
		_gate_retry = 0.80
		return null
	if _rules.commit(GATE) <= 0.0:
		return null
	_end_gate()
	_reset_run()
	_tracking = false
	_rules.emit(GATE, {"event": "combo_launch", "phase": "jump", "effect_id": 1,
		"from": at, "target": destination, "radius": GATE_RADIUS, "duration": 0.22})
	return destination


func _tick_gate(delta: float, at: Vector2, enemies: Array) -> void:
	if not _gate.is_empty():
		_gate.left = float(_gate.left) - delta
		if float(_gate.left) <= 0.0 or not _rules.ready(GATE):
			_end_gate()
			_gate_retry = 0.80
		return
	_gate_retry = maxf(0.0, _gate_retry - delta)
	if not _rules.ready(GATE) or _gate_retry > 0.0 or not bool(_context.get("moving", false)) \
			or bool(_context.get("forced_motion", false)):
		_reset_run()
		return
	var from: Vector2 = _context.get("walk_from", at)
	var step := at - from
	if step.length_squared() <= EPSILON:
		_reset_run()
		return
	var direction := step.normalized()
	if _run_heading == Vector2.ZERO or _run_heading.dot(direction) < cos(deg_to_rad(25.0)):
		_reset_run()
		_run_heading = direction
	_run_time += delta
	_run_distance += step.length()
	if _run_time < 0.45 or _run_distance < 1.25 * U or not _enemy_near(at, enemies):
		return
	var entry := at + _run_heading * (0.60 * U)
	var exit := at + _run_heading * (3.20 * U)
	var lateral := _run_heading.orthogonal() * U
	_reset_run()
	var walk_clear: Callable = _context.get("gate_walk_clear", Callable())
	if walk_clear.is_valid():
		if not bool(walk_clear.call(at, entry)):
			return
	elif not _rules.clear_path(_context, at, entry):
		return
	for offset: float in [0.0, -0.35, 0.35, -0.70, 0.70]:
		var candidate := exit + lateral * offset
		if _can_exit(entry, candidate):
			_gate = {"entry": entry, "exit": candidate, "left": GATE_LIFE}
			_rules.emit(GATE, {"event": "combo_update", "phase": "gate", "effect_id": 1,
				"from": entry, "target": candidate, "radius": GATE_RADIUS, "duration": GATE_LIFE})
			return


func _can_exit(entry: Vector2, destination: Vector2) -> bool:
	var valid: Callable = _context.get("gate_exit_valid", Callable())
	if valid.is_valid():
		return bool(valid.call(entry, destination))
	return _rules.clear_path(_context, entry, destination)


func _enemy_near(at: Vector2, enemies: Array) -> bool:
	for enemy: Dictionary in enemies:
		var body := enemy.get("body") as Node2D
		if is_instance_valid(body) and not body.is_queued_for_deletion() \
				and float(enemy.get("hp", 0.0)) > 0.0 \
				and at.distance_squared_to(body.position) <= (3.6 * U) ** 2:
			return true
	return false


func _reset_run() -> void:
	_run_time = 0.0
	_run_distance = 0.0
	_run_heading = Vector2.ZERO


func _end_gate() -> void:
	if not _gate.is_empty():
		_rules.emit(GATE, {"event": "combo_end", "effect_id": 1})
		_gate = {}


func _end_cut() -> void:
	if not _cut.is_empty():
		_rules.emit(CLEANSER, {"event": "combo_end", "effect_id": 1})
		_cut = {}


func _emit_cut(event: String, duration: float) -> void:
	var path: PackedVector2Array = _cut.path
	var phase := "closing" if duration <= 0.35 else "channel"
	if event == "combo_launch":
		phase = "cut"
	_rules.emit(CLEANSER, {"event": event, "phase": phase, "effect_id": 1, "from": path[0],
		"target": path[-1], "points": path, "width": CUT_WIDTH, "patches": _cut.mask, "duration": duration})


func _hazard(id: int) -> Dictionary:
	for hazard: Dictionary in _hazards:
		if int(hazard.id) == id and float(hazard.remaining) > 0.0:
			return hazard
	return {}


func _circle_interval(from: Vector2, delta: Vector2, hazard: Dictionary) -> Vector2:
	var offset := from - (hazard.pos as Vector2)
	var quadratic := delta.length_squared()
	var linear := offset.dot(delta)
	var discriminant := linear * linear - quadratic * (offset.length_squared() - float(hazard.radius) ** 2)
	if discriminant <= 0.0:
		return Vector2(-1.0, -1.0)
	var root := sqrt(discriminant)
	return Vector2(maxf(0.0, (-linear - root) / quadratic), minf(1.0, (-linear + root) / quadratic))


func _hazard_outline(at: Vector2, radius: float) -> PackedVector2Array:
	var outline := PackedVector2Array()
	for index in 32:
		outline.append(at + Vector2.from_angle(TAU * float(index) / 32.0) * radius)
	return outline


func _merge_footprints(footprints: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var parts: Array[PackedVector2Array] = []
	for footprint in footprints:
		if not parts.is_empty():
			var merged := Geometry2D.merge_polygons(parts[-1], footprint)
			if merged.size() == 1:
				parts[-1] = merged[0]
				continue
		parts.append(footprint)
	return parts


func _subtract_footprint(fill: Array[PackedVector2Array], footprint: PackedVector2Array) -> Array[PackedVector2Array]:
	# Partition the visible area outside each convex edge, including fully enclosed holes.
	var result: Array[PackedVector2Array] = []
	var direction := -1.0 if Geometry2D.is_polygon_clockwise(footprint) else 1.0
	for polygon in fill:
		var remainder := polygon
		for index in footprint.size():
			var from := footprint[index]
			var edge := footprint[(index + 1) % footprint.size()] - from
			var rejected := _clip_half_plane(remainder, from, edge, -direction)
			if rejected.size() >= 3:
				result.append(rejected)
			remainder = _clip_half_plane(remainder, from, edge, direction)
			if remainder.size() < 3:
				break
	return result


func _clip_half_plane(polygon: PackedVector2Array, from: Vector2, edge: Vector2, sign_value: float) -> PackedVector2Array:
	var clipped := PackedVector2Array()
	if polygon.is_empty():
		return clipped
	var previous := polygon[-1]
	var previous_side := edge.cross(previous - from) * sign_value
	for point in polygon:
		var side := edge.cross(point - from) * sign_value
		if (side >= 0.0) != (previous_side >= 0.0):
			clipped.append(previous.lerp(point, previous_side / (previous_side - side)))
		if side >= 0.0:
			clipped.append(point)
		previous = point
		previous_side = side
	return clipped

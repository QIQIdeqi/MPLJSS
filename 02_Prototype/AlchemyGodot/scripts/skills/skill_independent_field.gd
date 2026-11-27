extends RefCounted

const U := preload("res://data/skills/skill_data.gd").UNIT
const FURNACE := &"combo_furnace"
const REWIND := &"combo_rewind_anchor"
const WALL := &"combo_crystal_wall"
const COUNTER := &"combo_opening_counter"
const DEW := &"combo_dew_pickup"
const FURNACE_RADIUS := 1.15 * U
const FURNACE_RANGE := 3.3 * U
const WALL_WIDTH := 0.26 * U
const COUNTER_RADIUS := 1.35 * U
const COUNTER_TELL := 0.26
const REWIND_WARN := 0.68
const REWIND_TRAVEL := 0.24
const REWIND_MIN_DRIFT := 0.12 * U
const DEW_RADIUS := 0.42 * U

var _rules
var _furnace: Dictionary = {}
var _rewind: Dictionary = {}
var _wall: Dictionary = {}
var _counter: Dictionary = {}
var _dew: Dictionary = {}
var _approach: Dictionary = {}
var _offered_windups: Dictionary = {}
var _furnace_retry := 0.0
var _counter_retry := 0.0
var _counter_advanced_before_actors := false
var _next_effect := 10000
var _generation := 0


func setup(rules) -> void:
	_rules = rules


func clear() -> void:
	_generation += 1
	for site: Dictionary in _rewind.get("sites", []):
		site.entry.erase("rewinding")
	_end(FURNACE, _furnace)
	_end(REWIND, _rewind)
	_end(WALL, _wall)
	_end(COUNTER, _counter)
	_end(DEW, _dew)
	_furnace = {}
	_rewind = {}
	_wall = {}
	_counter = {}
	_dew = {}
	_approach.clear()
	_offered_windups.clear()
	_furnace_retry = 0.0
	_counter_retry = 0.0
	_counter_advanced_before_actors = false


func pre_actor_tick(at: Vector2, enemies: Array, context: Dictionary) -> void:
	_counter_advanced_before_actors = true
	_advance_counter(float(context.get("frame_delta", 0.0)), at, enemies, context)


func tick(delta: float, at: Vector2, enemies: Array, context: Dictionary) -> void:
	var generation := _generation
	_furnace_retry = maxf(_furnace_retry - delta, 0.0)
	_tick_furnace(delta, at, enemies, context)
	if generation != _generation:
		return
	_tick_rewind(delta, at, enemies, context)
	_tick_wall(delta, at, enemies, context)
	if not _counter_advanced_before_actors:
		_advance_counter(delta, at, enemies, context)
	_counter_advanced_before_actors = false
	if generation != _generation:
		return
	_offer_counter(at, enemies, context)
	_tick_dew(delta, at, context)


func _tick_furnace(delta: float, at: Vector2, enemies: Array, context: Dictionary) -> void:
	if _furnace.is_empty():
		if _furnace_retry > 0.0 or not _rules.ready(FURNACE) or not _point_clear(at, context):
			return
		var count := 0
		for entry: Dictionary in enemies:
			if not _living(entry) or at.distance_squared_to(entry.body.position) > (3.4 * U) ** 2:
				continue
			count += 1
			if count >= 3 or bool(entry.get("boss", false)) or bool(entry.get("elite", false)):
				_furnace = {"id": _allocate(), "center": at, "age": 0.0, "phase": &"charge"}
				_show(FURNACE, _furnace, {"phase": "charge", "target": at, "radius": FURNACE_RADIUS, "heat": 0.0, "stage": 1})
				break
		return
	var center: Vector2 = _furnace.center
	if _furnace.phase == &"charge":
		var from: Vector2 = context.get("move_from", at)
		if bool(context.get("forced_motion", false)):
			_expire_furnace()
			return
		if at.distance_squared_to(center) > FURNACE_RADIUS ** 2:
			if not bool(context.get("ordinary_motion", false)) or from.distance_squared_to(center) > FURNACE_RADIUS ** 2 + 0.1:
				_expire_furnace()
				return
			var fraction := _circle_exit_fraction(from - center, at - from, FURNACE_RADIUS)
			var left_heat := float(_furnace.age) + delta * fraction
			if left_heat >= 2.4:
				_expire_furnace()
				return
			var scale: float = _rules.commit(FURNACE)
			if scale <= 0.0:
				_expire_furnace()
				return
			var stage := _heat_stage(left_heat)
			var direction := center.direction_to(from.lerp(at, fraction))
			_furnace.merge({"phase": &"wave", "direction": direction, "angle_degrees": [42.0, 68.0, 96.0][stage - 1],
				"damage": float([28.0, 35.0, 42.0][stage - 1]) * scale, "radius": 0.0, "hit": {}}, true)
			_flash(FURNACE, "combo_launch", {"target": center, "direction": direction, "stage": stage})
			_tick_furnace_wave(delta * (1.0 - fraction), enemies, context)
			return
		_furnace.age = float(_furnace.age) + delta
		if float(_furnace.age) >= 2.4:
			_expire_furnace()
			return
		_show(FURNACE, _furnace, {"phase": "charge", "target": center, "radius": FURNACE_RADIUS,
			"heat": clampf(float(_furnace.age) / 1.1, 0.0, 1.0), "stage": _heat_stage(float(_furnace.age))})
		return
	_tick_furnace_wave(delta, enemies, context)


func _tick_furnace_wave(delta: float, enemies: Array, context: Dictionary) -> void:
	var center: Vector2 = _furnace.center
	var direction: Vector2 = _furnace.direction
	var angle := float(_furnace.angle_degrees)
	var prior := float(_furnace.radius)
	var radius := minf(FURNACE_RANGE, prior + delta * 10.0 * U)
	var half_angle := deg_to_rad(angle * 0.5)
	var generation := _generation
	_furnace.radius = radius
	for entry: Dictionary in enemies.duplicate():
		if not _living(entry):
			continue
		var point: Vector2 = entry.body.position
		var offset := point - center
		var distance := offset.length()
		var key: int = entry.body.get_instance_id()
		if _furnace.hit.has(key) or distance < prior or distance > radius:
			continue
		if distance > 0.01 and direction.dot(offset / distance) < cos(half_angle):
			continue
		if not _rules.clear_path(context, center, point):
			continue
		_furnace.hit[key] = true
		_flash(FURNACE, "combo_hit", {"target": point, "direction": direction})
		_damage(FURNACE, entry, float(_furnace.damage), context)
		if generation != _generation:
			return
	_show(FURNACE, _furnace, {"phase": "wave", "target": center, "direction": direction,
		"angle_degrees": angle, "radius": radius, "arcs": _wave_arcs(center, direction, half_angle, radius, context)})
	if radius >= FURNACE_RANGE:
		_end(FURNACE, _furnace)
		_furnace = {}


func _wave_arcs(center: Vector2, direction: Vector2, half_angle: float, radius: float, context: Dictionary) -> Array[PackedVector2Array]:
	var arcs: Array[PackedVector2Array] = []
	var segment := PackedVector2Array()
	for index in range(25):
		var point := center + direction.rotated(lerpf(-half_angle, half_angle, index / 24.0)) * radius
		if _rules.clear_path(context, center, point):
			segment.append(point)
		else:
			if segment.size() >= 2:
				arcs.append(segment)
			segment = PackedVector2Array()
	if segment.size() >= 2:
		arcs.append(segment)
	return arcs


func _circle_exit_fraction(from: Vector2, offset: Vector2, radius: float) -> float:
	var magnitude := offset.length_squared()
	if magnitude <= 0.00001:
		return 1.0
	var dot := from.dot(offset)
	var discriminant := dot * dot - magnitude * (from.length_squared() - radius * radius)
	return clampf((-dot + sqrt(maxf(0.0, discriminant))) / magnitude, 0.0, 1.0)


func _heat_stage(age: float) -> int:
	if age >= 1.1:
		return 3
	return 2 if age >= 0.45 else 1


func _expire_furnace() -> void:
	_end(FURNACE, _furnace)
	_furnace = {}
	_furnace_retry = 1.0


func is_rewinding(entry: Dictionary) -> bool:
	return bool(entry.get("rewinding", false))


func _tick_rewind(delta: float, at: Vector2, enemies: Array, context: Dictionary) -> void:
	if _rewind.is_empty():
		_offer_rewind(delta, at, enemies)
		return
	_rewind.age = float(_rewind.age) + delta
	var elapsed := clampf(float(_rewind.age) - REWIND_WARN, 0.0, REWIND_TRAVEL)
	var rewind_now := float(_rewind.age) >= REWIND_WARN
	var points := PackedVector2Array()
	var positions := PackedVector2Array()
	var starting_origins := PackedVector2Array()
	var starting_positions := PackedVector2Array()
	var operating := false
	for site: Dictionary in _rewind.sites:
		var entry: Dictionary = site.entry
		if bool(site.get("done", false)) or not _rewind_eligible(entry) or not enemies.has(entry):
			entry.erase("rewinding")
			site.done = true
			continue
		var from: Vector2 = entry.body.position
		var target: Vector2 = site.point
		if rewind_now:
			if not site.has("start"):
				if from.distance_squared_to(target) < REWIND_MIN_DRIFT ** 2:
					site.done = true
					continue
				site.start = from
				site.destination = from.move_toward(target, 1.7 * U)
				starting_origins.append(target)
				starting_positions.append(from)
			entry.rewinding = true
			var start: Vector2 = site.start
			var desired := start.lerp(site.destination, elapsed / REWIND_TRAVEL)
			var clipped: Vector2 = _rules.clip(context, from, desired)
			clipped = stop_enemy_motion(entry, from, clipped)
			var body: Node2D = entry.body
			if body is CharacterBody2D and body.is_inside_tree():
				body.move_and_collide(clipped - from)
			else:
				body.position = clipped
			from = body.position
			if from.distance_squared_to(desired) > 0.25 or elapsed >= REWIND_TRAVEL:
				entry.erase("rewinding")
				site.done = true
				if from.distance_squared_to(start) > 0.25:
					_flash(REWIND, "combo_hit", {"target": from, "from": start})
		operating = operating or not bool(site.get("done", false))
		points.append(target)
		positions.append(from)
	if not starting_origins.is_empty():
		_flash(REWIND, "combo_launch", {"target": at, "points": starting_origins, "positions": starting_positions})
	if not points.is_empty():
		var progress := elapsed / REWIND_TRAVEL if rewind_now else float(_rewind.age) / REWIND_WARN
		_show(REWIND, _rewind, {"phase": "rewind" if rewind_now else "mark", "target": at,
			"points": points, "positions": positions, "progress": progress,
			"duration": maxf(REWIND_TRAVEL - elapsed if rewind_now else REWIND_WARN - float(_rewind.age), 0.01)})
	if not operating:
		_end(REWIND, _rewind)
		_rewind = {}


func _offer_rewind(delta: float, at: Vector2, enemies: Array) -> void:
	if not _rules.ready(REWIND):
		_approach.clear()
		return
	var samples := {}
	var candidates: Array[Dictionary] = []
	for entry: Dictionary in enemies:
		if not _rewind_eligible(entry):
			continue
		var point: Vector2 = entry.body.position
		var distance := at.distance_squared_to(point)
		if distance > (4.10 * U) ** 2:
			continue
		var id: int = entry.body.get_instance_id()
		var previous: Dictionary = _approach.get(id, {"latest": point, "origin": point, "duration": 0.0})
		var latest: Vector2 = previous.latest
		var motion := point - latest
		var toward := point.direction_to(at)
		var duration := 0.0
		var origin := point
		if delta > 0.0 and motion.dot(toward) >= 0.22 * U * delta:
			duration = float(previous.duration) + delta
			origin = previous.origin if float(previous.duration) > 0.0 else latest
		samples[id] = {"latest": point, "origin": origin, "duration": duration}
		if duration + 0.000001 >= 0.12 and not toward.is_zero_approx():
			candidates.append({"entry": entry, "point": origin, "current": point, "distance": distance, "duration": duration, "id": id})
	_approach = samples
	candidates.sort_custom(_nearer)
	if candidates.is_empty():
		return
	if candidates.size() == 1 and (float(candidates[0].duration) + 0.000001 < 0.16 or float(candidates[0].distance) > (2.25 * U) ** 2):
		return
	if _rules.commit(REWIND) <= 0.0:
		return
	candidates.resize(mini(4, candidates.size()))
	var points := PackedVector2Array()
	var positions := PackedVector2Array()
	for item: Dictionary in candidates:
		points.append(item.point)
		positions.append(item.current)
	_rewind = {"id": _allocate(), "age": 0.0, "sites": candidates}
	_show(REWIND, _rewind, {"phase": "mark", "target": at, "points": points, "positions": positions,
		"progress": 0.0, "duration": REWIND_WARN})


func _nearer(first: Dictionary, second: Dictionary) -> bool:
	if is_equal_approx(float(first.distance), float(second.distance)):
		return int(first.id) < int(second.id)
	return float(first.distance) < float(second.distance)


func _rewind_eligible(entry: Dictionary) -> bool:
	return _living(entry) and not bool(entry.get("boss", false)) \
		and not bool(entry.get("anchored", false)) and not bool(entry.get("displacement_immune", false))


func _tick_wall(delta: float, at: Vector2, enemies: Array, context: Dictionary) -> void:
	if _wall.is_empty():
		if _rules.ready(WALL):
			_offer_wall(at, enemies, context)
		return
	_wall.age = float(_wall.age) + delta
	if not bool(_wall.get("active", false)) and float(_wall.age) >= 0.22:
		if _rules.commit(WALL) <= 0.0:
			_end(WALL, _wall)
			_wall = {}
			return
		_wall.active = true
		_wall.context = context.duplicate()
		_show(WALL, _wall, {"phase": "wall", "points": _wall.points, "width": WALL_WIDTH, "target": _wall.center, "duration": 2.4})
		_flash(WALL, "combo_launch", {"target": _wall.center, "direction": _wall.normal})
	if float(_wall.age) >= 2.62:
		_end(WALL, _wall)
		_wall = {}


func _offer_wall(at: Vector2, enemies: Array, context: Dictionary) -> void:
	var targets: Array[Vector2] = []
	for entry: Dictionary in enemies:
		if _wall_eligible(entry, true):
			var offset: Vector2 = (entry.body.position as Vector2) - at
			if not offset.is_zero_approx() and offset.length_squared() <= (3.4 * U) ** 2:
				targets.append(offset)
	if targets.size() < 3:
		return
	var half_angle := deg_to_rad(35.0)
	var limit := cos(half_angle + 0.00001)
	var best_count := 2
	var best_distance := INF
	var best := Vector2.ZERO
	for target in targets:
		for offset: float in [-half_angle, 0.0, half_angle]:
			var heading := target.normalized().rotated(offset)
			var count := 0
			var distance := 0.0
			for candidate in targets:
				if heading.dot(candidate.normalized()) >= limit:
					count += 1
					distance += candidate.length()
			if count > best_count or (count == best_count and count >= 3 and distance < best_distance):
				best = heading
				best_count = count
				best_distance = distance
	if best.is_zero_approx():
		return
	var wall_at := at + best * (1.35 * U)
	var tangent := best.orthogonal()
	var points := _wall_floor_segment(wall_at, best, tangent, context)
	if points.size() < 2:
		return
	var center := (points[0] + points[1]) * 0.5
	_wall = {"id": _allocate(), "age": 0.0, "points": points, "center": center, "normal": best, "tangent": tangent,
		"half_length": points[0].distance_to(points[1]) * 0.5, "active": false}
	_show(WALL, _wall, {"phase": "preview", "points": points, "width": WALL_WIDTH, "target": center, "duration": 0.22})


func _wall_floor_segment(center: Vector2, normal: Vector2, tangent: Vector2, context: Dictionary) -> PackedVector2Array:
	const SAMPLES := 48
	var segment := Vector2i(-1, -1)
	var begin := -1
	var width := normal * WALL_WIDTH * 0.5
	for index in range(SAMPLES + 2):
		var point := center + tangent * lerpf(-1.2 * U, 1.2 * U, index / float(SAMPLES))
		var valid: bool = index <= SAMPLES and _point_clear(point, context) and _rules.clear_path(context, point - width, point + width)
		if valid:
			if begin < 0:
				begin = index
		elif begin >= 0:
			if index - 1 - begin > segment.y - segment.x:
				segment = Vector2i(begin, index - 1)
			begin = -1
	var a := center + tangent * lerpf(-1.2 * U, 1.2 * U, segment.x / float(SAMPLES))
	var b := center + tangent * lerpf(-1.2 * U, 1.2 * U, segment.y / float(SAMPLES))
	if a.distance_to(b) + 0.001 < 1.35 * U:
		return PackedVector2Array()
	return PackedVector2Array([a, b])


func enemy_steering(entry: Dictionary, player_at: Vector2) -> Vector2:
	if not _wall_active() or not _wall_eligible(entry, false):
		return player_at
	var at: Vector2 = entry.body.position
	if _wall_contact_fraction(at, player_at) < 0.0:
		return player_at
	var normal: Vector2 = _wall.normal
	var tangent: Vector2 = _wall.tangent
	var center: Vector2 = _wall.center
	var side := 1.0 if (at - center).dot(normal) >= 0.0 else -1.0
	var corners: Array[Vector2] = []
	for direction: float in [-1.0, 1.0]:
		var beyond := center + tangent * (direction * (float(_wall.half_length) + 14.0))
		var near := beyond + normal * (side * (WALL_WIDTH * 0.5 + 5.0))
		var turn := beyond - normal * (side * (WALL_WIDTH * 0.5 + 5.0))
		corners.append(turn if at.distance_squared_to(near) <= 5.0 ** 2 else near)
	corners.sort_custom(func(a: Vector2, b: Vector2) -> bool: return at.distance_squared_to(a) < at.distance_squared_to(b))
	for corner in corners:
		if _rules.clear_path(_wall.context, at, corner):
			return corner
	return player_at


func stop_enemy_motion(entry: Dictionary, from: Vector2, to: Vector2) -> Vector2:
	if not _wall_active() or not _wall_eligible(entry, false):
		return to
	var fraction := _wall_contact_fraction(from, to)
	if fraction < 0.0:
		return to
	var local_from := _wall_local(from)
	var local_to := _wall_local(to)
	if absf(local_from.x) <= float(_wall.half_length) and absf(local_from.y) <= WALL_WIDTH * 0.5:
		# Existing overlaps may leave toward the original side.
		if is_zero_approx(local_from.y) or (local_to.y - local_from.y) * local_from.y > 0.0:
			return to
	return from.lerp(to, fraction).move_toward(from, 0.35)


func boss_sweep(from: Vector2, to: Vector2, radius := 0.0) -> void:
	if not _wall_active():
		return
	var fraction := _wall_contact_fraction(from, to, radius)
	if fraction < 0.0:
		return
	var center: Vector2 = _wall.center
	var contact := Geometry2D.get_closest_point_to_segment(from.lerp(to, fraction), _wall.points[0], _wall.points[1])
	_flash(WALL, "combo_hit", {"target": contact, "center": center, "direction": from.direction_to(to)})
	_end(WALL, _wall)
	_wall = {}


func _wall_contact_fraction(from: Vector2, to: Vector2, radius := 0.0) -> float:
	var a := _wall_local(from)
	var displacement := _wall_local(to) - a
	var extents := Vector2(float(_wall.half_length), WALL_WIDTH * 0.5) + Vector2.ONE * radius
	var low := 0.0
	var high := 1.0
	for axis in 2:
		if is_zero_approx(displacement[axis]):
			if absf(a[axis]) > extents[axis]:
				return -1.0
			continue
		var t1 := (-extents[axis] - a[axis]) / displacement[axis]
		var t2 := (extents[axis] - a[axis]) / displacement[axis]
		low = maxf(low, minf(t1, t2))
		high = minf(high, maxf(t1, t2))
		if low > high:
			return -1.0
	return low


func _wall_local(point: Vector2) -> Vector2:
	var offset: Vector2 = point - (_wall.center as Vector2)
	return Vector2(offset.dot(_wall.tangent), offset.dot(_wall.normal))


func _wall_active() -> bool:
	return bool(_wall.get("active", false))


func _wall_eligible(entry: Dictionary, include_practice: bool) -> bool:
	return _living(entry) and not bool(entry.get("boss", false)) and not bool(entry.get("elite", false)) \
		and not bool(entry.get("flying", false)) \
		and (not bool(entry.get("anchored", false)) or (include_practice and bool(entry.get("wall_practice", false))))


func _advance_counter(delta: float, at: Vector2, enemies: Array, context: Dictionary) -> void:
	_counter_retry = maxf(_counter_retry - delta, 0.0)
	if _counter.is_empty():
		return
	var previous_left := float(_counter.left)
	_counter.left = previous_left - delta
	if float(_counter.left) > 0.000001:
		_show_counter(at)
	else:
		_stomp(at, previous_left, enemies, context)


func _offer_counter(at: Vector2, enemies: Array, context: Dictionary) -> void:
	if not _counter.is_empty() or _counter_retry > 0.0 or not _rules.ready(COUNTER):
		return
	var best := {}
	var nearest := INF
	var retained := {}
	for entry: Dictionary in enemies:
		if not _living(entry):
			continue
		var windup: Dictionary = entry.get("windup", {})
		if float(windup.get("remaining", 0.0)) < 0.12:
			continue
		var enemy_at: Vector2 = entry.body.position
		var token := int(windup.get("token", -1))
		var body_id: int = entry.body.get_instance_id()
		if int(_offered_windups.get(body_id, -2)) == token:
			retained[body_id] = token
			continue
		var distance := at.distance_squared_to(enemy_at)
		if token < 0 or distance >= nearest or distance > (1.80 * U) ** 2 or not _rules.clear_path(context, at, enemy_at):
			continue
		nearest = distance
		best = {"entry": entry, "body_id": body_id, "token": token, "left": COUNTER_TELL}
	_offered_windups = retained
	if best.is_empty():
		return
	best.id = _allocate()
	_offered_windups[best.body_id] = best.token
	_counter = best
	_show_counter(at)


func _show_counter(at: Vector2) -> void:
	var left := float(_counter.left)
	_show(COUNTER, _counter, {"phase": "warn", "target": at, "radius": COUNTER_RADIUS,
		"progress": 1.0 - left / COUNTER_TELL, "duration": left})


func _stomp(at: Vector2, until_impact: float, enemies: Array, context: Dictionary) -> void:
	var state := _counter
	_end(COUNTER, state)
	_counter = {}
	var targets: Array[Dictionary] = []
	for entry: Dictionary in enemies:
		if not _living(entry):
			continue
		var point: Vector2 = entry.body.position
		if point.distance_squared_to(at) <= COUNTER_RADIUS ** 2 and _rules.clear_path(context, at, point):
			targets.append(entry)
	var scale := 0.0
	if not targets.is_empty():
		scale = float(_rules.commit(COUNTER))
	_flash(COUNTER, "combo_launch", {"target": at, "radius": COUNTER_RADIUS, "did_hit": scale > 0.0})
	if scale <= 0.0:
		_counter_retry = 0.45
		return
	var generation := _generation
	for entry in targets:
		if not _living(entry) or not enemies.has(entry):
			continue
		var interrupted := _interrupt_counter_source(entry, state, until_impact, context)
		_flash(COUNTER, "combo_hit", {"target": entry.body.position, "from": at, "interrupted": interrupted})
		_damage(COUNTER, entry, 26.0 * scale, context)
		if generation != _generation:
			return


func _interrupt_counter_source(entry: Dictionary, state: Dictionary, until_impact: float, context: Dictionary) -> bool:
	if entry != state.entry or bool(entry.get("boss", false)) or bool(entry.get("elite", false)):
		return false
	var windup: Dictionary = entry.get("windup", {})
	if not bool(windup.get("interruptible", false)) or int(windup.get("token", -1)) != int(state.token) \
		or float(windup.get("remaining", 0.0)) <= until_impact:
		return false
	var callback: Callable = context.get("interrupt_attack", Callable())
	if not callback.is_valid():
		return false
	var result: Variant = callback.call(entry, state.token, 0.24)
	return bool(result) if result != null else true


func notify_kill(at: Vector2, context: Dictionary) -> void:
	if not _dew.is_empty() or float(context.get("missing_health", 0.0)) <= 0.0 or not _rules.ready(DEW):
		return
	var point: Variant = _dew_ground(at, context)
	if not point is Vector2:
		return
	var scale: float = _rules.commit(DEW)
	if scale <= 0.0:
		return
	_dew = {"id": _allocate(), "point": point, "left": 4.5, "heal": 10.0 * scale}
	_show_dew()


func _dew_ground(at: Vector2, context: Dictionary) -> Variant:
	if _valid_dew_ground(at, context):
		return at
	for ring in range(1, 8):
		for direction in 16:
			var test := at + Vector2.RIGHT.rotated(TAU * direction / 16.0) * (ring * 0.1 * U)
			if _valid_dew_ground(test, context):
				return test
	return null


func _valid_dew_ground(at: Vector2, context: Dictionary) -> bool:
	var callback: Callable = context.get("valid_dew_ground", Callable())
	return bool(callback.call(at)) if callback.is_valid() else _point_clear(at, context)


func _tick_dew(delta: float, at: Vector2, context: Dictionary) -> void:
	if _dew.is_empty():
		return
	_dew.left = float(_dew.left) - delta
	if float(_dew.left) <= 0.0:
		_end(DEW, _dew)
		_dew = {}
		return
	if float(context.get("missing_health", 0.0)) > 0.0 and _touches(at, _dew.point, DEW_RADIUS, context):
		var heal: Callable = context.get("heal", Callable())
		if heal.is_valid():
			var amount := float(heal.call(float(_dew.heal)))
			if amount > 0.0:
				_flash(DEW, "combo_heal", {"target": at, "from": _dew.point, "amount": amount})
				_end(DEW, _dew)
				_dew = {}
				return
	_show_dew()


func _show_dew() -> void:
	_show(DEW, _dew, {"phase": "pickup", "target": _dew.point, "radius": DEW_RADIUS,
		"duration": _dew.left, "opacity": clampf(float(_dew.left) / 0.8, 0.0, 1.0)})


func _touches(at: Vector2, point: Vector2, radius: float, context: Dictionary) -> bool:
	if bool(context.get("forced_motion", false)) or not bool(context.get("ordinary_motion", false)):
		return false
	var from: Vector2 = context.get("move_from", at)
	return from.distance_squared_to(at) > 0.00001 \
		and Geometry2D.get_closest_point_to_segment(point, from, at).distance_squared_to(point) <= radius * radius


func _point_clear(at: Vector2, context: Dictionary) -> bool:
	var callback: Callable = context.get("valid_combo_ground", Callable())
	if callback.is_valid():
		return bool(callback.call(at))
	var bounds: Rect2 = context.get("bounds", Rect2())
	return (not bounds.has_area() or bounds.has_point(at)) and _rules.clear_path(context, at - Vector2.RIGHT, at + Vector2.RIGHT)


func _living(entry: Dictionary) -> bool:
	var body: Variant = entry.get("body")
	return is_instance_valid(body) and not body.is_queued_for_deletion() and float(entry.get("hp", 0.0)) > 0.0


func _damage(id: StringName, entry: Dictionary, value: float, context: Dictionary) -> void:
	var apply: Callable = context.get("combo_damage", Callable())
	if apply.is_valid():
		apply.call(id, entry, value)


func _allocate() -> int:
	_next_effect += 1
	return _next_effect


func _show(id: StringName, state: Dictionary, data: Dictionary) -> void:
	data.event = "combo_update"
	data.effect_id = state.id
	_rules.emit(id, data)


func _flash(id: StringName, event: String, data: Dictionary) -> void:
	data.event = event
	_rules.emit(id, data)


func _end(id: StringName, state: Dictionary) -> void:
	if not state.is_empty():
		_rules.emit(id, {"event": "combo_end", "effect_id": state.id})

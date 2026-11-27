extends RefCounted

const SKILLS := preload("res://data/skills/skill_data.gd")
const COAT := &"combo_thunder_coat"
const MIRROR := &"combo_tide_mirror"
const U := SKILLS.UNIT
const COAT_FX := 1
const MIRROR_FX := 2
const RETURN_FX := 3
const MIRROR_WIDTH := 1.30 * U
const MIRROR_WINDOW := 0.32

var _rules
var _coat_visible := false
var _mirror := {}
var _return := {}
var _retry_left := 0.0


func setup(rules) -> void:
	_rules = rules


func clear() -> void:
	_coat_visible = false
	_mirror.clear()
	_return.clear()
	_retry_left = 0.0


func tick(delta: float, at: Vector2, enemies: Array, context: Dictionary) -> void:
	if _rules.ready(COAT):
		_coat_visible = true
		_show(COAT, "combo_update", COAT_FX, {"phase": "ready", "target": at})
	elif _coat_visible:
		_end_coat()
	_retry_left = maxf(0.0, _retry_left - delta)
	_advance_return(delta, enemies, context)


func mitigate(amount: float, at: Vector2) -> Dictionary:
	var reduction := minf(amount * 0.34, minf(18.0, maxf(0.0, amount - 1.0)))
	if reduction <= 0.0:
		return {}
	var power: float = _rules.commit(COAT)
	if power <= 0.0:
		return {}
	_end_coat()
	_show(COAT, "combo_hit", COAT_FX, {"phase": "absorb", "target": at})
	return {"amount": amount - reduction, "counter_damage": 24.0 * power}


func counter(at: Vector2, source: Node2D, enemies: Array, amount: float, context: Dictionary) -> void:
	if not is_instance_valid(source) or source.is_queued_for_deletion():
		return
	var target := source.position
	if at.distance_to(target) > 3.2 * U or not _rules.clear_path(context, at, target):
		return
	for entry: Dictionary in enemies:
		if entry.body != source or not _living(entry):
			continue
		_show(COAT, "combo_launch", COAT_FX, {"phase": "counter", "from": at, "target": target})
		var hit: Callable = context.get("combo_damage", Callable())
		if hit.is_valid():
			hit.call(COAT, entry, amount)
		return


func intercept(delta: float, at: Vector2, projectiles: Array[Dictionary], context: Dictionary) -> void:
	# Projectile records carry their owning array so a reflection removes the enemy bullet
	# before that bullet's usual collision and hurt callbacks are reached.
	if not _rules.ready(MIRROR):
		return
	if _mirror.is_empty() and _retry_left <= 0.0:
		_offer_mirror(at, projectiles, context)
	if _mirror.is_empty():
		return
	var center: Vector2 = _mirror.pos
	var normal: Vector2 = _mirror.normal
	var lateral := normal.orthogonal() * (MIRROR_WIDTH * 0.5)
	var first_time := INF
	var chosen := {}
	var contact := Vector2.ZERO
	for projectile: Dictionary in projectiles:
		var from: Vector2 = projectile.pos
		var direction: Vector2 = projectile.direction
		var speed := float(projectile.speed)
		var travel := speed * minf(delta, minf(float(projectile.left), float(_mirror.left)))
		if travel <= 0.0:
			continue
		var end := _projectile_end(projectile, from + direction * travel, context)
		var crossing: Variant = Geometry2D.segment_intersects_segment(from, end, center - lateral, center + lateral)
		if crossing == null or not _rules.clear_path(context, center, crossing):
			continue
		var player_offset := at - from
		var side := absf(player_offset.cross(direction))
		if side < 15.0:
			var player_contact := player_offset.dot(direction) - sqrt(225.0 - side * side)
			if player_offset.dot(direction) >= -15.0 and from.distance_to(crossing) > maxf(0.0, player_contact) + 0.001:
				continue
		var time := from.distance_to(crossing) / speed
		if time < first_time:
			first_time = time
			chosen = projectile
			contact = crossing
	if not chosen.is_empty():
		var power: float = _rules.commit(MIRROR)
		if power > 0.0:
			var container: Array = chosen.owner
			container.erase(chosen.shot)
			var direction: Vector2 = -(chosen.direction as Vector2)
			_end_mirror()
			_return = {"pos": contact, "direction": direction, "left": 7.0 * U, "damage": 24.0 * power}
			_show(MIRROR, "combo_launch", RETURN_FX, {"from": center, "target": contact, "direction": direction})
			_show_return(contact, contact)
			return
	_mirror.left = float(_mirror.left) - delta
	if float(_mirror.left) <= 0.0:
		_end_mirror()
		_retry_left = 0.65


func _offer_mirror(at: Vector2, projectiles: Array[Dictionary], context: Dictionary) -> void:
	var best_time := INF
	var best := {}
	for projectile: Dictionary in projectiles:
		var from: Vector2 = projectile.pos
		var direction: Vector2 = projectile.direction
		var speed := float(projectile.speed)
		var flight := maxf(0.0, minf(MIRROR_WINDOW, float(projectile.left)))
		var approach := (at - from).dot(direction)
		if approach <= 0.0 or speed <= 0.0 or flight == 0.0:
			continue
		var end := _projectile_end(projectile, from + direction * speed * flight, context)
		var closest := Geometry2D.get_closest_point_to_segment(at, from, end)
		if closest.distance_to(at) > 0.55 * U or not _rules.clear_path(context, closest, at):
			continue
		var time := from.distance_to(closest) / speed
		if time >= best_time:
			continue
		var distance := from.distance_to(at)
		var offset := minf(0.55 * U, distance * 0.5)
		var center := at + at.direction_to(from) * offset
		if not _rules.clear_path(context, at, center):
			continue
		best_time = time
		best = {"pos": center, "normal": direction, "left": MIRROR_WINDOW}
	if best.is_empty():
		return
	_mirror = best
	_show(MIRROR, "combo_update", MIRROR_FX, {"phase": "mirror", "target": best.pos,
		"direction": best.normal, "width": MIRROR_WIDTH, "duration": MIRROR_WINDOW})


func _projectile_end(projectile: Dictionary, destination: Vector2, context: Dictionary) -> Vector2:
	var clipper: Callable = projectile.get("clip", Callable())
	if clipper.is_valid():
		return clipper.call(projectile.pos, destination)
	return _rules.clip(context, projectile.pos, destination)


func _advance_return(delta: float, enemies: Array, context: Dictionary) -> void:
	if _return.is_empty():
		return
	var at: Vector2 = _return.pos
	var direction: Vector2 = _return.direction
	var travel := minf(12.0 * U * delta, float(_return.left))
	var goal := at + direction * travel
	var end: Vector2 = _rules.clip(context, at, goal)
	var reached := at.distance_to(end)
	var closest := INF
	var target := {}
	var hit_at := end
	const RADIUS := 0.16 * U
	for entry: Dictionary in enemies:
		if not _living(entry):
			continue
		var point: Vector2 = entry.body.position
		var offset := point - at
		var along := offset.dot(direction)
		var side := absf(offset.cross(direction))
		if side > RADIUS or along < -RADIUS:
			continue
		var chord := sqrt(maxf(0.0, RADIUS * RADIUS - side * side))
		var progress := maxf(0.0, along - chord)
		var impact := at + direction * progress
		if progress > reached or progress >= closest or not _rules.clear_path(context, impact, point):
			continue
		closest = progress
		target = entry
		hit_at = impact
	if not target.is_empty():
		var amount := float(_return.damage)
		_show(MIRROR, "combo_hit", RETURN_FX, {"target": target.body.position, "from": hit_at})
		_end_return()
		var hit: Callable = context.get("combo_damage", Callable())
		if hit.is_valid():
			hit.call(MIRROR, target, amount)
		return
	if reached + 0.05 < travel or float(_return.left) <= travel + 0.0001:
		_end_return()
		return
	_return.pos = end
	_return.left = float(_return.left) - travel
	_show_return(at, end)


func _show_return(from: Vector2, to: Vector2) -> void:
	_show(MIRROR, "combo_update", RETURN_FX, {"phase": "return", "from": from,
		"target": to, "direction": _return.direction, "width": 0.32 * U})


func _end_coat() -> void:
	_coat_visible = false
	_show(COAT, "combo_end", COAT_FX)


func _end_mirror() -> void:
	_mirror.clear()
	_show(MIRROR, "combo_end", MIRROR_FX)


func _end_return() -> void:
	_return.clear()
	_show(MIRROR, "combo_end", RETURN_FX)


func _show(id: StringName, event: String, effect_id: int, info: Dictionary = {}) -> void:
	info["event"] = event
	info["effect_id"] = effect_id
	_rules.emit(id, info)


func _living(entry: Dictionary) -> bool:
	return is_instance_valid(entry.get("body")) and not entry.body.is_queued_for_deletion() and float(entry.get("hp", 0.0)) > 0.0

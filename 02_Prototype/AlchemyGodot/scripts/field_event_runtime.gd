extends RefCounted
## Optional encounters. Only Greyford uses a timed interaction and Boss gate cuts.

const TITLES := {&"greyford_01": "林缘收集点", &"trade_road_02": "路障旁物资", &"manor_03": "孢子支路", &"pilgrimage_04": "路旁歇脚地", &"capital_05": "街口遭遇"}
const LAYOUT := preload("res://scripts/level_layout.gd")
const RADIUS := 80.0
const CHARGE_SECONDS := 1.5
const ROUTE_MIN := 48.0 + RADIUS + 17.0
const ROUTE_MAX := 48.0 + RADIUS + 52.0
const HINT_SECONDS := 3.0
const DAMAGE_RESET_SECONDS := 0.22
const DAMAGE_RESET_COLOR := Color("#FF3B30")

var field: Node2D
var completed: Dictionary = {}
var points: Dictionary = {}
var ink: Node2D
var timed := false
var first_neighbors: Array[Vector2i] = []
var active_id := Vector2i.ZERO
var charging := false
var progress_s := 0.0
var unloaded_frame := -1
var origin_hint_shown := false
var origin_hint_left := 0.0
var origin_xp_pickups := 0
var completion_flash := 0.0
var completion_at := Vector2.ZERO
var reset_count := 0
var hp_loss_reset_count := 0
var damage_reset_at := Vector2.ZERO
var damage_reset_strength := 0.0
var damage_reset_tween: Tween

func setup(source: Node2D) -> void:
	field = source
	timed = field.level_id == &"greyford_01"
	if timed:
		var seeded := RandomNumberGenerator.new()
		seeded.seed = field.infinite_layout.seed_value
		first_neighbors.assign([Vector2i(seeded.randi_range(0, 1) * 2 - 1, 0),
			Vector2i(0, seeded.randi_range(0, 1) * 2 - 1)])
	ink = Node2D.new()
	ink.name = "OptionalEncounterMarks"
	if timed:
		ink.z_index = -2
	field.actors.add_child(ink)
	ink.draw.connect(draw_marks)
	sync()

func sync() -> void:
	var previous := points
	points = {}
	for coord: Vector2i in field.infinite_layout.active_chunks:
		var layout: Dictionary = field.infinite_layout.active_chunks[coord]
		if timed:
			var cardinal := absi(coord.x) + absi(coord.y) == 1
			if coord != Vector2i.ZERO and not first_neighbors.has(coord):
				if cardinal or posmod(field.infinite_layout.chunk_seed(coord), 3) != 0:
					continue
			var point: Vector2 = previous[coord] if previous.has(coord) else find_point(coord, layout)
			if point.is_finite():
				points[coord] = point
			continue
		if coord != Vector2i.ZERO and posmod(field.infinite_layout.chunk_seed(coord), 3) != 0:
			continue
		for offset: Vector2 in [Vector2(0.234375,0.25),Vector2(0.765625,0.75),Vector2(0.234375,0.75),Vector2(0.765625,0.25)]:
			var at: Vector2 = layout.bounds.position + offset * layout.bounds.size
			var clear := true
			for prop in layout.props:
				if prop.collision != Vector2.ZERO and Rect2(prop.position-prop.collision*0.5,prop.collision).grow(72).has_point(at):
					clear = false
					break
			if clear:
				points[coord] = at
				break
	if charging and not points.has(active_id):
		reset_charge("unloaded")
		unloaded_frame = Engine.get_physics_frames()
	ink.queue_redraw()

func find_point(coord: Vector2i, layout: Dictionary) -> Vector2:
	var bounds: Rect2 = layout.bounds.grow(-RADIUS)
	var spawn: Vector2 = field.spawn_position
	var origin := coord == Vector2i.ZERO
	var inner := first_neighbors.has(coord)
	var candidates := PackedVector2Array()
	var upper_diagonal := PackedVector2Array()
	var footprints: Array[Rect2] = []
	for prop: Dictionary in layout.props:
		if prop.collision != Vector2.ZERO:
			footprints.append(Rect2(prop.position - prop.collision * 0.5, prop.collision))
	for y in range(ceili(bounds.position.y), floori(bounds.end.y) + 1, 12):
		for x in range(ceili(bounds.position.x), floori(bounds.end.x) + 1, 12):
			var at := Vector2(x, y)
			var distance := at.distance_to(spawn)
			if origin and (distance < 380.0 or distance > 450.0):
				continue
			if inner and (distance < 650.0 or distance > 1350.0):
				continue
			var route := LAYOUT.route_distance(field.layout_preset, at)
			if route < ROUTE_MIN or route > ROUTE_MAX:
				continue
			var clear := true
			for footprint in footprints:
				if at.distance_squared_to(at.clamp(footprint.position, footprint.end)) < RADIUS * RADIUS:
					clear = false
					break
			if not clear:
				continue
			candidates.append(at)
			if origin and at.y < spawn.y and absf(at.x - spawn.x) >= RADIUS:
				upper_diagonal.append(at)
	var choices := upper_diagonal if not upper_diagonal.is_empty() else candidates
	if choices.is_empty():
		return Vector2.INF
	var seeded := RandomNumberGenerator.new()
	seeded.seed = field.infinite_layout.chunk_seed(coord)
	return choices[seeded.randi_range(0, choices.size() - 1)]

func reset_charge(reason: String) -> void:
	if charging:
		reset_count += 1
		if reason == "hp_loss":
			hp_loss_reset_count += 1
			damage_reset_at = points[active_id]
			if damage_reset_tween and damage_reset_tween.is_valid():
				damage_reset_tween.kill()
			set_damage_reset_strength(1.0)
			damage_reset_tween = ink.create_tween()
			damage_reset_tween.tween_method(set_damage_reset_strength, 1.0, 0.0, DAMAGE_RESET_SECONDS)
		field.record_greyford("branch_reset", {"chunk": active_id, "reason": reason,
			"reset_count": reset_count, "hp_loss_count": hp_loss_reset_count,
			"hp_loss_share": float(hp_loss_reset_count) / reset_count})
	charging = false
	progress_s = 0.0
	ink.queue_redraw()

func set_damage_reset_strength(value: float) -> void:
	damage_reset_strength = value
	ink.queue_redraw()

func tick_charge(delta: float, hp_lost: bool) -> void:
	if completion_flash > 0.0:
		completion_flash = maxf(0.0, completion_flash - delta)
		ink.queue_redraw()
	origin_hint_left = maxf(0.0, origin_hint_left - delta)
	if Engine.get_physics_frames() == unloaded_frame:
		return
	if hp_lost:
		reset_charge("hp_loss")
		return
	if charging and field.player.position.distance_to(points[active_id]) > RADIUS:
		reset_charge("left_circle")
		return
	if not charging:
		var closest := RADIUS * RADIUS
		for coord: Vector2i in points:
			if completed.has(coord):
				continue
			var distance: float = field.player.position.distance_squared_to(points[coord])
			if distance < closest or (distance == closest and (not charging or coord < active_id)):
				active_id = coord
				closest = distance
				charging = true
		if not charging:
			return
		field.record_greyford("branch_begin", {"chunk": active_id})
		if active_id == Vector2i.ZERO and not origin_hint_shown:
			origin_hint_shown = true
			origin_hint_left = HINT_SECONDS
	progress_s += delta
	ink.queue_redraw()
	if progress_s + 0.000001 < CHARGE_SECONDS:
		return
	var coord := active_id
	var at: Vector2 = points[coord]
	completed[coord] = true
	completion_flash = 0.35
	completion_at = at
	charging = false
	progress_s = 0.0
	var cut_applied: bool = field.apply_boss_gate_cut()
	field.record_greyford("branch_complete", {"chunk": coord, "xp_before": field.xp,
		"level_before": field.level, "cut_applied": cut_applied, "cuts": field.boss_gate_cuts})
	field.spawn_material_drop(at + Vector2(-20, 0), "dew", 1, false)
	field.spawn_material_drop(at + Vector2(20, 0), "fire_powder", 1, false)
	if coord == Vector2i.ZERO:
		for i in 4:
			field.add_pickup(at + Vector2.from_angle(TAU * i / 4.0) * 26.0, 1, true)
		field.record_greyford("origin_xp_spawned", {"count": 4})

func tick() -> void:
	for coord: Vector2i in points:
		if completed.has(coord) or field.player.position.distance_to(points[coord]) > 64.0:
			continue
		completed[coord] = true
		var at: Vector2 = points[coord]
		match field.level_id:
			&"greyford_01", &"trade_road_02":
				field.spawn_material_drop(at+Vector2(-20,0), "dew", 1, false)
				field.spawn_material_drop(at+Vector2(20,0), "fire_powder", 1, false)
			&"manor_03":
				for angle in [0.0,2.1,4.2]:
					field.fire_web(at+Vector2.from_angle(angle)*72.0, Vector2.ZERO, field.FIELD_ENEMY.Kind.MUSHROOM)
				field.spawn_material_drop(at, "dew", 2, false)
			&"pilgrimage_04":
				# A short spawn breather, without healing or removing enemies already pursuing.
				field.until_spawn = maxf(field.until_spawn, 4.0)
				field.add_pickup(at, 1)
			&"capital_05":
				for i in mini(4, maxi(0, field.enemy_config.alive_cap(field.spawn_wave)-field.enemies.size())):
					field.spawn_enemy()
				field.spawn_material_drop(at, "fire_powder", 2, false)
		field.show_pickup_notice("发现%s · 可选遭遇" % TITLES.get(field.level_id, "支路"))
		ink.queue_redraw()

func draw_marks() -> void:
	if timed and completion_flash > 0.0:
		ink.draw_arc(completion_at, RADIUS, 0, TAU, 64, Color(1.0, 0.91, 0.63, completion_flash / 0.35), 4.0, true)
	if damage_reset_strength > 0.0:
		var tint := Color(DAMAGE_RESET_COLOR, damage_reset_strength * 0.48)
		var radius := RADIUS * lerpf(0.38, 1.0, damage_reset_strength)
		for i in 12:
			var angle := TAU * i / 12.0
			var arc := lerpf(0.05, 0.32, damage_reset_strength)
			ink.draw_arc(damage_reset_at, radius, angle, angle + arc, 5, tint, 2.0, true)
	var font := ThemeDB.fallback_font
	for coord: Vector2i in points:
		if completed.has(coord):
			continue
		var at: Vector2 = points[coord]
		if timed:
			draw_charge_ring(coord, at)
			continue
		ink.draw_circle(at, 42, Color(0.55,0.82,0.60,0.08))
		ink.draw_arc(at, 42, 0, TAU, 40, Color(0.65,0.86,0.66,0.6), 1.5, true)
		ink.draw_string(font, at+Vector2(-42,-48), "◇ 可选支路", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#c1dfbd"))

func draw_charge_ring(coord: Vector2i, at: Vector2) -> void:
	var active := charging and active_id == coord
	var gold := Color("#ffdc84")
	ink.draw_circle(at, RADIUS, Color(gold, 0.12 if active else 0.05))
	ink.draw_arc(at, RADIUS, 0, TAU, 64, Color("#422312"), 5.0, true)
	ink.draw_arc(at, RADIUS, 0, TAU, 64, Color(gold, 0.95 if active else 0.64), 2.0, true)
	if active and progress_s > 0.0:
		ink.draw_arc(at, RADIUS, -PI * 0.5, -PI * 0.5 + TAU * minf(1.0, progress_s / CHARGE_SECONDS),
			64, Color("#fff1ba"), 4.0, true)

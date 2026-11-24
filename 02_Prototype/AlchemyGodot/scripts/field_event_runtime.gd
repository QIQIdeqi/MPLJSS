extends RefCounted
## Optional local encounters. Their completion is never consulted by the Boss gate.

const TITLES := {&"greyford_01": "林缘收集点", &"trade_road_02": "路障旁物资", &"manor_03": "孢子支路", &"pilgrimage_04": "路旁歇脚地", &"capital_05": "街口遭遇"}
var field: Node2D
var completed: Dictionary = {}
var points: Dictionary = {}
var ink: Node2D

func setup(source: Node2D) -> void:
	field = source
	ink = Node2D.new()
	ink.name = "OptionalEncounterMarks"
	field.actors.add_child(ink)
	ink.draw.connect(draw_marks)
	sync()

func sync() -> void:
	points.clear()
	for coord: Vector2i in field.infinite_layout.active_chunks:
		if coord != Vector2i.ZERO and posmod(field.infinite_layout.chunk_seed(coord), 3) != 0:
			continue
		var layout: Dictionary = field.infinite_layout.active_chunks[coord]
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
	ink.queue_redraw()

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
	var font := ThemeDB.fallback_font
	for coord: Vector2i in points:
		if completed.has(coord):
			continue
		var at: Vector2 = points[coord]
		ink.draw_circle(at, 42, Color(0.55,0.82,0.60,0.08))
		ink.draw_arc(at, 42, 0, TAU, 40, Color(0.65,0.86,0.66,0.6), 1.5, true)
		ink.draw_string(font, at+Vector2(-42,-48), "◇ 可选支路", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#c1dfbd"))

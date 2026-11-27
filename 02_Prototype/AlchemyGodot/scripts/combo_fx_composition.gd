extends RefCounted

const SHEETS := {
	"combo_furnace": preload("res://art/vfx/fixed_combos/furnace.png"),
	"combo_thunder_coat": preload("res://art/vfx/fixed_combos/thunder_coat.png"),
	"combo_tide_mirror": preload("res://art/vfx/fixed_combos/tide_mirror.png"),
	"combo_rewind_anchor": preload("res://art/vfx/fixed_combos/rewind_anchor.png"),
	"combo_cleanser": preload("res://art/vfx/fixed_combos/cleanser.png"),
	"combo_crystal_gate": preload("res://art/vfx/fixed_combos/crystal_gate.png"),
	"combo_crystal_wall": preload("res://art/vfx/fixed_combos/crystal_wall.png"),
	"combo_opening_counter": preload("res://art/vfx/fixed_combos/opening_counter.png"),
	"combo_dew_pickup": preload("res://art/vfx/fixed_combos/dew_pickup.png"),
}
const COLORS := {
	"combo_furnace": Color("#ff9955"),
	"combo_thunder_coat": Color("#ffc679"),
	"combo_tide_mirror": Color("#8df8f0"),
	"combo_rewind_anchor": Color("#88bcf5"),
	"combo_cleanser": Color("#c3f1c5"),
	"combo_crystal_gate": Color("#b9a6ff"),
	"combo_crystal_wall": Color("#9adafb"),
	"combo_opening_counter": Color("#ffdc9a"),
	"combo_dew_pickup": Color("#ffe17e"),
}
const CELL := 96
const COLS := 8
const ROWS := 3
const FRAMES := COLS * ROWS
const GROUND := 5.9
const FLASH_HEIGHT := 17.0

var _live: Dictionary = {}
var _clips: Array[Dictionary] = []
var _time := 0.0
var _dirty := false

var shapes: Array[Dictionary] = []
var cards: Array[Dictionary] = []
var glows: Array[Dictionary] = []


static func supports(skill_id: String) -> bool:
	return SHEETS.has(skill_id)


func show_effect(info: Dictionary) -> void:
	var skill_id := String(info.get("skill_id", ""))
	if not supports(skill_id):
		return
	_dirty = true
	var key := "%s:%s" % [skill_id, str(info.get("effect_id", 0))]
	match String(info.get("event", "")):
		"combo_update":
			var previous: Dictionary = _live.get(key, {})
			var state := info.duplicate()
			var lifetime := float(info.get("duration", 0.0))
			state.expires = _time + (lifetime + 0.07 if lifetime > 0.0 else 2.5)
			state.started = previous.get("started", _time) if previous.get("phase") == state.get("phase") else _time
			_live[key] = state
		"combo_end":
			var ended: Dictionary = _live.get(key, {})
			_live.erase(key)
			if skill_id == "combo_furnace" and String(ended.get("phase", "")) == "wave":
				ended.event = "residue"
				ended.started = _time
				ended.lifetime = 0.25
				_clips.append(ended)
		"combo_launch", "combo_hit", "combo_heal":
			var clip := info.duplicate()
			clip.started = _time
			clip.lifetime = 0.46 if clip.event == "combo_heal" else 0.32
			_clips.append(clip)


func clear_effects() -> void:
	_live.clear()
	_clips.clear()
	shapes.clear()
	cards.clear()
	glows.clear()
	_dirty = true


func advance(delta: float) -> bool:
	_time += delta
	for key: String in _live.keys():
		if _time >= float(_live[key].expires):
			_live.erase(key)
			_dirty = true
	for index in range(_clips.size() - 1, -1, -1):
		var clip: Dictionary = _clips[index]
		if _time >= float(clip.started) + float(clip.lifetime):
			_clips.remove_at(index)
			_dirty = true
	if not _dirty and (_live.is_empty() and _clips.is_empty() or delta <= 0.0):
		return false
	_dirty = false
	shapes.clear()
	cards.clear()
	glows.clear()
	for state: Dictionary in _live.values():
		_draw_state(state)
	for clip: Dictionary in _clips:
		_draw_clip(clip)
	return true


func _draw_state(state: Dictionary) -> void:
	var skill_id := String(state.skill_id)
	var phase := String(state.get("phase", ""))
	var at: Vector2 = state.get("target", Vector2.ZERO)
	var from: Vector2 = state.get("from", at)
	var points: PackedVector2Array = state.get("points", PackedVector2Array())
	var width := float(state.get("width", 3.0))
	var radius := float(state.get("radius", 24.0))
	var remaining_fraction := clampf(float(state.get("progress", 1.0)), 0.0, 1.0)
	var color: Color = COLORS[skill_id]
	var pulse := 0.78 + sin(_time * 14.0) * 0.16
	match skill_id:
		"combo_furnace":
			_furnace(state, at, radius)
		"combo_thunder_coat":
			var shoulder := at + Vector2(10.0, 0.0)
			_gem(shoulder, 2.8, Color("#fff0b9"), 35.0)
			_glint(shoulder, 35.0, 21.0, color, 0.37 * pulse)
		"combo_tide_mirror":
			if phase in ["return", "flight"]:
				var heading: Vector2 = state.get("direction", from.direction_to(at))
				var trace := PackedVector2Array([at - heading.normalized() * 16.0, at])
				_ribbon(trace, 8.0, Color(color, 0.52), FLASH_HEIGHT)
				_ribbon(trace, 2.2, Color("#eaffff"), FLASH_HEIGHT + 0.28)
				_gem(at, 3.6, Color("#efffff"), FLASH_HEIGHT + 0.4)
				_glint(at, FLASH_HEIGHT + 0.4, 25.0, color, 0.36)
			else:
				if points.size() < 2:
					var normal: Vector2 = state.get("direction", Vector2.RIGHT)
					var along := normal.normalized().orthogonal() * width * 0.5
					points = PackedVector2Array([at - along, at + along])
				_mirror(points[0], points[-1], color)
		"combo_rewind_anchor":
			_draw_anchors(points, state.get("positions", PackedVector2Array()), color, phase == "rewind")
		"combo_cleanser":
			var closing := phase == "closing" or bool(state.get("closing", false))
			var rim := Color(color, 0.46 if closing else 0.84)
			var patches: Array = state.get("patches", [])
			if not patches.is_empty():
				_outlines(patches, rim)
			else:
				_parallel_edges(points, width * 0.5, rim)
			_ribbon(points, 1.4, Color(color, 0.42 if closing else 0.22), GROUND + 0.15)
		"combo_crystal_gate":
			_gate(from, radius, color, false, pulse)
			_gate(at, radius, color, true, pulse)
		"combo_crystal_wall":
			if points.size() < 2 and from != at:
				points = PackedVector2Array([from, at])
			if points.size() >= 2:
				_wall(points[0], points[-1], width, color, phase == "preview")
		"combo_opening_counter":
			var rim := Color(color, 0.66 + pulse * 0.26)
			_ribbon(PackedVector2Array([from, at]), 1.6, Color(color, 0.46), GROUND + 0.22)
			_rune(at, radius, 4, rim, PI / 4.0)
			_ring(at, maxf(3.0, radius * remaining_fraction), 1.6, Color(color, 0.56), GROUND + 0.28)
			_gem(at, 4.2, Color("#fff6d4"), GROUND + 0.45)
		"combo_dew_pickup":
			var remaining := float(state.expires) - _time
			var opacity := clampf(float(state.get("opacity", remaining / 0.80)), 0.0, 1.0)
			_ring(at, radius, 1.8, Color(color, 0.40 * opacity), GROUND + 0.15)
			_gem(at, 5.2, Color(color, 0.60 * opacity), GROUND + 0.25)
			var lift := 19.0 + sin(_time * 6.5) * 3.1
			_card(skill_id, at, 43.0, lift, posmod(floori(_time * 21.0), FRAMES), opacity)
			_glint(at, lift, 31.0, color, 0.43 * opacity)


func _furnace(state: Dictionary, center: Vector2, radius: float) -> void:
	if String(state.get("phase")) == "wave":
		var arcs: Array = state.get("arcs", [])
		if arcs.is_empty() and not state.has("arcs"):
			var direction: Vector2 = state.get("direction", Vector2.RIGHT)
			var angle := deg_to_rad(float(state.get("angle_degrees", 42.0)))
			var start := direction.angle() - angle * 0.5
			arcs.append(_arc(center, radius, start, angle, 19))
		for arc: PackedVector2Array in arcs:
			if arc.size() < 2:
				continue
			_ribbon(arc, 13.0, Color("#96331996"), GROUND)
			_ribbon(arc, 6.2, Color("#ff6638e6"), GROUND + 0.37)
			_ribbon(arc, 2.0, Color("#fff0aa"), GROUND + 0.72)
			var spacing := maxi(1, ceili(float(arc.size()) / 6.0))
			for index in range(0, arc.size(), spacing):
				var point := arc[index]
				_card("combo_furnace", point, 49.0, 10.5,
					posmod(floori(_time * 42.0) + index, FRAMES), 0.86)
		return
	var stage := clampi(int(state.get("stage", ceilf(float(state.get("heat", 0.0)) * 3.0))), 1, 3)
	var grades := [Color("#c95a40"), Color("#ff8f46"), Color("#ffd782")]
	var hue: Color = grades[stage - 1]
	_ring(center, radius, 9.0, Color(hue, 0.15 + 0.05 * stage))
	_ring(center, radius, 2.3, Color(hue, 0.78), GROUND + 0.12)
	_ring(center, radius - 7.0, 1.4, Color(hue, 0.37), GROUND + 0.24)
	for index in 8:
		var angle := TAU * index / 8.0
		var point := center + Vector2.from_angle(angle) * (radius - 2.0)
		_gem(point, 4.4, Color(hue, 0.78), GROUND + 0.32)
	_gem(center, 7.0, Color(hue, 0.82), GROUND + 0.35)
	_glint(center, GROUND + 3.0, 32.0, hue, 0.17 + 0.10 * stage)


func _mirror(a: Vector2, b: Vector2, color: Color) -> void:
	if a.is_equal_approx(b):
		return
	var top: float = FLASH_HEIGHT + 9.0
	_panel_face(a, b, FLASH_HEIGHT - 5.0, FLASH_HEIGHT - 5.0, top, top, Color(color, 0.25))
	var edge := PackedVector2Array([a, b])
	_ribbon(edge, 3.5, Color("#b9ffffed"), top)
	_ribbon(edge, 1.8, Color("#5cd3d9c7"), FLASH_HEIGHT - 5.0)
	_ribbon(edge, 1.6, Color(color, 0.46), GROUND)
	for at in edge:
		_gem(at, 3.2, Color("#ebffff"), top)
		_glint(at, top, 24.0, color, 0.26)
	for index in range(1, 7):
		var start := a.lerp(b, index / 7.0)
		var end := start.move_toward(b, 9.0)
		_panel_face(start, end, FLASH_HEIGHT - 4.5, FLASH_HEIGHT - 4.5,
			top - 1.0, top - 1.0, Color(color, 0.11))


func _draw_anchors(origins: PackedVector2Array, positions: PackedVector2Array, color: Color, returning: bool) -> void:
	for i in origins.size():
		var at := origins[i]
		_rune(at, 13.0, 4, Color(color, 0.65), PI / 4.0)
		_gem(at, 4.5, Color("#b9dff8"), GROUND + 0.15)
		_card("combo_rewind_anchor", at, 25.0, GROUND + 0.25,
			posmod(floori(_time * 17.0) + i * 3, FRAMES), 0.52, true)
		if returning and i < positions.size():
			var path := PackedVector2Array([positions[i], at])
			_ribbon(path, 12.0, Color(color, 0.25), GROUND + 0.3)
			_ribbon(path, 2.0, Color("#d6eeffdc"), GROUND + 0.5)
			_glint(positions[i], GROUND + 5.0, 22.0, color, 0.29)


func _gate(at: Vector2, radius: float, color: Color, exit_gate: bool, pulse: float) -> void:
	_rune(at, radius, 6, Color(color, 0.94 if exit_gate else 0.72), PI / 6.0)
	if exit_gate:
		_rune(at, radius + 6.0, 6, Color("#ded5ff83"), PI / 6.0)
	_gem(at, 9.0 if exit_gate else 6.5, Color(color, 0.80), GROUND + 0.32)
	_gem(at, 3.0 + 1.6 * pulse, Color("#fff0f7"), GROUND + 0.48)
	_glint(at, GROUND + 6.2, 32.0, color, 0.20 + 0.19 * pulse)


func _wall(a: Vector2, b: Vector2, width: float, color: Color, preview: bool) -> void:
	var span := a.distance_to(b)
	if span < 1.0:
		return
	var footprint := PackedVector2Array([a, b])
	_ribbon(footprint, width, Color(color, 0.22 if preview else 0.39), GROUND)
	_parallel_edges(footprint, width * 0.5, Color(color, 0.72))
	for at in footprint:
		_gem(at, 3.6, Color("#d5f4ff"), GROUND + 0.3)
	if preview:
		return
	var count := maxi(1, ceili(span / 22.0))
	for index in count:
		var left := a.lerp(b, index / float(count))
		var right := a.lerp(b, (index + 1.0) / float(count))
		var ridge := left.lerp(right, 0.57)
		var rim_height := 16.0 + float(posmod(index * 5, 4)) * 2.0
		var ridge_height := rim_height + 14.0 + float(posmod(index * 3, 4)) * 1.9
		_panel_face(left, ridge, GROUND, GROUND, rim_height, ridge_height, Color("#579bd9c8"))
		_panel_face(ridge, right, GROUND, GROUND, ridge_height, rim_height, Color("#a5def6b3"))
		_panel_face(left, ridge, rim_height - 2.3, ridge_height - 2.3, rim_height, ridge_height,
			Color("#daf7ffdf"))
		_panel_face(ridge, right, ridge_height - 2.3, rim_height - 2.3, ridge_height, rim_height,
			Color("#b9eaffdb"))


func _draw_clip(clip: Dictionary) -> void:
	var skill_id := String(clip.skill_id)
	var event := String(clip.event)
	var phase := String(clip.get("phase", ""))
	var at: Vector2 = clip.get("target", Vector2.ZERO)
	var from: Vector2 = clip.get("from", at)
	var color: Color = COLORS[skill_id]
	var progress := clampf((_time - float(clip.started)) / float(clip.lifetime), 0.0, 1.0)
	var fade := 1.0 - smoothstep(0.12, 1.0, progress)
	var frame := mini(floori(progress * FRAMES), FRAMES - 1)
	if event == "residue":
		_ring(at, 1.15 * 64.0, 5.0, Color(Color("#552d23"), 0.43 * fade), GROUND + 0.10)
		for arc: PackedVector2Array in clip.get("arcs", []):
			_ribbon(arc, 8.0, Color(Color("#462822"), 0.40 * fade), GROUND + 0.1)
		return
	var size := 51.0
	var height := FLASH_HEIGHT
	var opacity := 0.97 * (1.0 - smoothstep(0.66, 1.0, progress))
	var flat := false
	match skill_id:
		"combo_furnace":
			if event == "combo_launch":
				return
			size = 58.0
			height = 9.0
		"combo_thunder_coat":
			height = 28.0
			if event == "combo_launch" and not from.is_equal_approx(at):
				_lightning(from, at, fade)
		"combo_tide_mirror":
			size = 62.0 if event == "combo_launch" else 47.0
		"combo_rewind_anchor":
			size = 32.0
			flat = true
			height = GROUND + 0.3
		"combo_cleanser":
			if phase == "cut":
				var points: PackedVector2Array = clip.get("points", PackedVector2Array())
				for index in range(0, points.size(), maxi(1, ceili(points.size() / 5.0))):
					_card(skill_id, points[index], 41.0, GROUND + 0.30, frame, opacity, true)
				return
			size = 38.0
			height = GROUND + 0.3
			flat = true
		"combo_crystal_gate":
			_card(skill_id, from, 48.0, 13.0, frame, opacity)
			_glint(from, 14.0, 29.0, color, 0.36 * fade)
			size = 63.0
		"combo_crystal_wall":
			size = 67.0
			height = 18.0
		"combo_opening_counter":
			if event == "combo_hit":
				_ribbon(PackedVector2Array([from, at]), 7.0, Color(color, 0.43 * fade), 16.0)
				_ribbon(PackedVector2Array([from, at]), 2.4, Color(Color("#fff3cf"), fade), 16.2)
			size = 48.0
		"combo_dew_pickup":
			size = 55.0 if event == "combo_heal" else 37.0
			height = 20.0 + 16.0 * progress if event == "combo_heal" else 13.0
	_card(skill_id, at, size, height, frame, opacity, flat)
	_glint(at, height + 3.0, size * 0.72, color, 0.49 * fade)


func _lightning(a: Vector2, b: Vector2, fade: float) -> void:
	var path := PackedVector2Array([a])
	var lateral := a.direction_to(b).orthogonal()
	var spacing := minf(a.distance_to(b) * 0.15, 9.5)
	for index in range(1, 6):
		var zig := sin(float(index) * 5.37 + floorf(_time * 37.0))
		path.append(a.lerp(b, index / 6.0) + lateral * spacing * zig)
	path.append(b)
	_ribbon(path, 6.0, Color(Color("#f8ad728c"), fade * 0.62), 27.7)
	_ribbon(path, 2.4, Color(Color("#fff3be"), fade), 28.0)


func _outlines(patches: Array, color: Color) -> void:
	var segments: Dictionary = {}
	for patch: PackedVector2Array in patches:
		for i in patch.size():
			var a := patch[i]
			var b := patch[(i + 1) % patch.size()]
			var x := a.snapped(Vector2.ONE * 0.05)
			var y := b.snapped(Vector2.ONE * 0.05)
			var key := "%s %s" % [x, y] if x < y else "%s %s" % [y, x]
			if segments.has(key):
				segments.erase(key)
			else:
				segments[key] = PackedVector2Array([a, b])
	for segment: PackedVector2Array in segments.values():
		_ribbon(segment, 2.2, color, GROUND + 0.22)


func _card(id: String, at: Vector2, size: float, height: float, frame: int, opacity: float, flat := false) -> void:
	if size >= 1.0 and opacity > 0.01:
		cards.append({"texture": SHEETS[id], "at": at, "size": size, "height": height,
			"frame": frame, "opacity": opacity, "flat": flat})


func _glint(at: Vector2, height: float, size: float, color: Color, strength: float) -> void:
	if strength > 0.01 and size >= 1.0:
		glows.append({"at": at, "height": height, "size": size, "color": color, "strength": strength})


func _gem(at: Vector2, radius: float, color: Color, height: float) -> void:
	_polygon(PackedVector2Array([at + Vector2(0, -radius), at + Vector2(radius, 0),
		at + Vector2(0, radius), at + Vector2(-radius, 0)]), color, height)


func _polygon(points: PackedVector2Array, color: Color, height: float) -> void:
	shapes.append({"points": points, "color": color, "height": height})


func _panel_face(a: Vector2, b: Vector2, low_a: float, low_b: float, high_a: float, high_b: float, color: Color) -> void:
	shapes.append({"points": PackedVector2Array([a, b, b, a]), "color": color, "height": GROUND,
		"elevations": PackedFloat32Array([low_a, low_b, high_b, high_a])})


func _arc(at: Vector2, radius: float, start: float, extent: float, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(count + 1):
		points.append(at + Vector2.from_angle(start + extent * index / count) * radius)
	return points


func _rune(at: Vector2, radius: float, count: int, color: Color, angle: float) -> void:
	_ribbon(_arc(at, radius, angle, TAU, count), 2.1, color, GROUND + 0.20)


func _ring(at: Vector2, radius: float, width: float, color: Color, height := GROUND) -> void:
	if radius > 0.0:
		_ribbon(_arc(at, radius, 0.0, TAU, clampi(ceili(radius / 4.1), 12, 34)), width, color, height)


func _parallel_edges(points: PackedVector2Array, offset: float, color: Color) -> void:
	for index in range(1, points.size()):
		var a := points[index - 1]
		var b := points[index]
		var perpendicular := a.direction_to(b).orthogonal() * offset
		_ribbon(PackedVector2Array([a + perpendicular, b + perpendicular]), 1.9, color, GROUND + 0.21)
		_ribbon(PackedVector2Array([a - perpendicular, b - perpendicular]), 1.9, color, GROUND + 0.21)


func _ribbon(points: PackedVector2Array, width: float, color: Color, height := GROUND) -> void:
	for index in range(1, points.size()):
		var a := points[index - 1]
		var b := points[index]
		if a.distance_squared_to(b) < 0.01:
			continue
		var normal := a.direction_to(b).orthogonal() * width * 0.5
		_polygon(PackedVector2Array([a + normal, b + normal, b - normal, a - normal]), color, height)

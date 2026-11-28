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
const CLEANSER := "combo_cleanser"
const CLEANSER_FOAM_OFFSETS := [
	Vector2(-0.12, -0.08), Vector2(0.38, 0.17), Vector2(-0.49, 0.24),
	Vector2(0.24, -0.42), Vector2(-0.34, -0.53), Vector2(0.71, -0.34),
	Vector2(-0.75, -0.19), Vector2(-0.18, 0.70), Vector2(0.35, 0.64),
	Vector2(0.05, -0.82),
]

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
			if skill_id == CLEANSER and clip.get("phase") == "pool":
				clip.lifetime = 0.42
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
	var progress := clampf(float(state.get("progress", 0.0)), 0.0, 1.0)
	var color: Color = COLORS[skill_id]
	var pulse := 0.78 + sin(_time * 14.0) * 0.16
	match skill_id:
		"combo_furnace":
			_furnace(state, at, radius)
		"combo_thunder_coat":
			_thunder_shell(at, 1.0, 0.86, pulse)
		"combo_tide_mirror":
			if phase in ["return", "flight"]:
				var heading: Vector2 = state.get("direction", from.direction_to(at))
				_returning_wave(at, heading, width)
			else:
				if points.size() < 2:
					var normal: Vector2 = state.get("direction", Vector2.RIGHT)
					var along := normal.normalized().orthogonal() * width * 0.5
					points = PackedVector2Array([at - along, at + along])
				_mirror(points[0], points[-1], color)
		"combo_rewind_anchor":
			_draw_anchors(points, state.get("positions", PackedVector2Array()), color, phase == "rewind", progress)
		CLEANSER:
			match phase:
				"pool":
					_cleanser_foam(at, radius, progress, _time - float(state.started))
				"grip":
					var fade := clampf((float(state.expires) - _time - 0.07) / 0.18, 0.0, 1.0)
					var frame := 8 + posmod(floori(_time * 18.0), 10)
					_card(CLEANSER, at + Vector2(-8.0, 3.0), 19.0, GROUND + 0.38, frame, 0.64 * pulse * fade, true)
					_card(CLEANSER, at + Vector2(9.0, -4.0), 15.0, GROUND + 0.36, frame, 0.50 * pulse * fade, true)
				_:
					var closing := phase == "closing" or bool(state.get("closing", false))
					var stride := maxi(1, ceili(float(points.size()) / 7.0))
					for index in range(0, points.size(), stride):
						var rise := 2.0 + fmod(_time * 13.0 + index * 2.5, 8.0)
						_gem(points[index], 1.45, Color(color, (0.27 if closing else 0.49) * pulse), rise)
		"combo_crystal_gate":
			_gate(from, radius, color, false, pulse)
			_gate(at, radius, color, true, pulse)
		"combo_crystal_wall":
			if points.size() < 2 and from != at:
				points = PackedVector2Array([from, at])
			if points.size() >= 2:
				_wall(points[0], points[-1], width, color, phase == "preview")
		"combo_opening_counter":
			_stomp_warning(at, radius, progress)
		"combo_dew_pickup":
			var remaining := float(state.expires) - _time
			var opacity := clampf(float(state.get("opacity", remaining / 0.80)), 0.0, 1.0)
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
	for index in 18:
		var angle := index * 2.39996
		var spread := 0.43 + 0.50 * fmod(index * 0.618, 1.0)
		var point := center + Vector2.from_angle(angle) * radius * spread
		var flicker := 0.54 + 0.44 * sin(_time * (9.0 + stage) + index * 3.7)
		_gem(point, 1.6 + stage * 0.42, Color(hue, flicker * 0.89), 1.0 + flicker * stage * 2.0)
		if index % 4 == 0:
			_glint(point, 4.5, 13.5, hue, flicker * 0.41)
	_gem(center, 7.0, Color(hue, 0.82), GROUND + 0.35)
	_glint(center, GROUND + 3.0, 32.0, hue, 0.17 + 0.10 * stage)


func _thunder_shell(at: Vector2, scale: float, opacity: float, pulse: float) -> void:
	var shape := _arc(at, 29.0 * scale, PI / 8.0, TAU, 8)
	var feet := _arc(at, 24.0 * scale, 0.0, TAU, 24)
	_ribbon(feet, 6.4, Color(Color("#f1a648"), 0.33 * opacity))
	_ribbon(feet, 1.8, Color(Color("#fff2be"), 0.63 * opacity), GROUND + 0.3)
	for i in 8:
		var first := shape[i]
		var last := shape[i + 1]
		var low := 12.0 + 3.0 * scale
		var high := 27.0 + 9.0 * scale
		var gleam := 0.12 + 0.08 * pulse if i % 2 == 0 else 0.10
		_panel_face(first, last, low, low, high, high, Color(Color("#feb43f"), opacity * gleam))
		_panel_face(first, last, high - 2.8, high - 2.8, high, high, Color(Color("#f9be59"), opacity * 0.42))
		var side := first.lerp(last, 0.24 + 0.45 * fmod(_time * 3.2 + i * 0.22, 1.0))
		var toward := side.direction_to(at)
		var continuity := PackedVector2Array([side, side + toward * 4.5 + Vector2(-2, 1),
			side + toward * 9.0, side + toward * 12.0 + Vector2(1.8, -2.2)])
		_ribbon(continuity, 4.2, Color(Color("#ffa343"), opacity * 0.66), high + 0.28)
		_ribbon(continuity, 1.65, Color(Color("#fffbd8"), opacity), high + 0.50)
	for side in [-1, 1]:
		var shoulder := at + Vector2(23.0 * side * scale, 0)
		_gem(shoulder, 7.2 * scale, Color(Color("#ef991e"), opacity), 35.0)
		_gem(shoulder, 3.5 * scale, Color(Color("#fff5c9"), opacity), 35.4)
		_glint(shoulder, 35.4, 34.0, Color("#ffcd7d"), opacity * 0.63)


func _mirror(a: Vector2, b: Vector2, color: Color) -> void:
	if a.is_equal_approx(b):
		return
	var edge := PackedVector2Array([a, a.lerp(b, 0.18), a.lerp(b, 0.82), b])
	var high := [31.0, 52.0, 52.0, 31.0]
	var low := [17.0, 8.0, 8.0, 17.0]
	for i in 3:
		var left := edge[i]
		var right := edge[i + 1]
		_panel_face(left, right, low[i], low[i + 1], high[i], high[i + 1], Color("#237e9ccc"))
		_panel_face(left, right, low[i] + 3.2, low[i + 1] + 3.2, high[i] - 3.3, high[i + 1] - 3.3, Color("#52dfce84"))
		_panel_face(left, right, high[i] - 4.2, high[i + 1] - 4.2, high[i], high[i + 1], Color("#acfff5"))
		_panel_face(left, right, low[i], low[i + 1], low[i] + 2.5, low[i + 1] + 2.5, Color("#93fff1f1"))
	# A glass bevel gives the plane a readable silhouette when viewed edge-on.
	var center := a.lerp(b, 0.5)
	var depth := a.direction_to(b).orthogonal()
	var near_edge := center - depth * 12.0
	var far_edge := center + depth * 12.0
	_panel_face(near_edge, center, 16.0, 8.0, 39.0, 55.0, Color("#2ed0d7b0"))
	_panel_face(center, far_edge, 8.0, 16.0, 55.0, 39.0, Color("#48dbe5c0"))
	_panel_face(near_edge, center, 37.0, 52.0, 39.0, 55.0, Color("#adfff3"))
	_panel_face(center, far_edge, 52.0, 37.0, 55.0, 39.0, Color("#adfff3"))
	_gem(center, 6.0, Color("#effff8"), 33.0)
	_ribbon(PackedVector2Array([a, b]), 8.0, Color("#38bece71"), GROUND)
	_ribbon(PackedVector2Array([a, b]), 2.5, Color("#98fff1e4"), GROUND + 0.22)
	for i in 2:
		var offset := 0.23 + 0.27 * i + 0.13 * fmod(_time * 4.0, 1.0)
		var shine := a.lerp(b, offset)
		_panel_face(shine, shine.move_toward(b, 8.0), 11.0, 21.0, 29.0, 40.0, Color("#e7fff39c"))
	for at in [a, b]:
		_gem(at, 5.4, Color("#d5fffc"), 24.0)
		_glint(at, 24.0, 32.0, color, 0.59)


func _returning_wave(at: Vector2, heading: Vector2, width: float) -> void:
	if heading.is_zero_approx():
		return
	var forward := heading.normalized()
	var lateral := forward.orthogonal()
	var span := maxf(width * 0.5, 10.0)
	var crest := PackedVector2Array([at - forward * 10.0 + lateral * span, at - forward * 2.0 + lateral * span * 0.6,
		at + forward * 5.0, at - forward * 2.0 - lateral * span * 0.6, at - forward * 10.0 - lateral * span])
	var wake := PackedVector2Array([crest[0], crest[2], crest[-1], at - forward * 33.0])
	_polygon(wake, Color("#239db8a8"), 12.0)
	_ribbon(crest, 9.6, Color("#51edcbdc"), 13.5)
	_ribbon(crest, 3.4, Color("#e5fff8"), 14.0)
	for side in [-1, 1]:
		var end: Vector2 = at - forward * 27.0 + lateral * span * 0.86 * side
		var tip: Vector2 = at - forward * 8.5 + lateral * span * side
		_ribbon(PackedVector2Array([end, tip]), 5.0, Color("#61def2c4"), 12.3)
		_gem(tip, 3.4, Color("#e4fffa"), 15.0)
	_glint(at, 15.5, 37.0, Color("#63f0df"), 0.54)


func _draw_anchors(origins: PackedVector2Array, positions: PackedVector2Array, color: Color, returning: bool,
		progress: float) -> void:
	for i in origins.size():
		var at := origins[i]
		_ring(at, 23.0, 8.2, Color("#424d9b94"))
		_ring(at, 23.0, 2.9, Color("#99adf8ee"), GROUND + 0.13)
		_ring(at, 17.0, 1.55, Color("#789ef5de"), GROUND + 0.22)
		for tick in 8:
			var radial := Vector2.from_angle(TAU * tick / 8.0)
			_ribbon(PackedVector2Array([at + radial * 15.0, at + radial * 20.0]), 2.05, Color("#c8ebfb"), GROUND + 0.37)
		var hour := Vector2.from_angle(-PI * 0.5 - (1.0 if returning else progress) * TAU)
		var minute := hour.rotated(PI * 0.87)
		_ribbon(PackedVector2Array([at + minute * 8.0, at, at + hour * 14.0]), 2.4, Color("#eaf7ff"), GROUND + 0.5)
		_gem(at, 4.6, Color("#d2eeff"), GROUND + 0.54)
		_card("combo_rewind_anchor", at, 50.0, GROUND + 0.28,
			posmod(floori(_time * 23.0) + i * 3, FRAMES), 0.63, true)
		_glint(at, GROUND + 2.2, 40.0, color, 0.45)
		if i >= positions.size():
			continue
		var current := positions[i]
		var distance := current.distance_to(at)
		if distance < 9.0:
			continue
		_ring(current, 12.0, 2.4, Color("#a6caffb4"), GROUND + 0.26)
		if returning:
			var path := PackedVector2Array([current, at])
			_ribbon(path, 18.0, Color("#6877f68c"), GROUND + 0.3)
			_ribbon(path, 4.4, Color("#d2f3fff4"), GROUND + 0.5)
			_glint(current, GROUND + 6.0, 39.0, color, 0.65)
		var count := clampi(ceili(distance / 19.0), 1, 6)
		for j in count:
			var tip := current.lerp(at, (j + 0.62) / count)
			var direction := current.direction_to(at)
			var across := direction.orthogonal() * (5.0 if returning else 3.8)
			var tail := tip - direction * 6.2
			_ribbon(PackedVector2Array([tail + across, tip, tail - across]), 2.5 if returning else 1.8,
				Color(color, 0.95 if returning else 0.50), GROUND + 0.65)


func _stomp_warning(at: Vector2, radius: float, progress: float) -> void:
	var strength := 0.42 + 0.35 * progress
	for index in 16:
		var direction := Vector2.from_angle(index * 2.39996)
		var spread := (0.37 + 0.58 * fmod(index * 0.618, 1.0)) * lerpf(0.62, 1.0, progress)
		var point := at + direction * radius * spread
		var flicker := 0.63 + 0.35 * sin(_time * 19.0 + index * 2.9)
		_gem(point, 1.3 + progress * 1.4, Color(Color("#ffe7b4"), strength * flicker), 2.0 + flicker * 6.0)
		if index % 4 == 0:
			_glint(point, 6.0, 12.0, Color("#f5bd8d"), strength * flicker * 0.55)
	_gem(at, 5.5 + progress * 5.7, Color("#eab9e7"), GROUND + 0.41)
	_gem(at, 3.7 + progress * 3.0, Color("#fff6cd"), GROUND + 0.47)
	_glint(at, 12.2, 29.0 + progress * 10.0, Color("#f4beff"), strength * 0.69)


func _stomp_wave(at: Vector2, radius: float, progress: float, fade: float, did_hit: bool) -> void:
	var wave := radius * lerpf(0.17, 1.0, ease(clampf(progress / 0.67, 0.0, 1.0), 0.55))
	var amplitude := fade if did_hit else fade * 0.84
	for index in 20:
		var direction := Vector2.from_angle(index * 2.39996)
		var spread := 0.57 + 0.43 * fmod(index * 0.618, 1.0)
		var point := at + direction * wave * spread
		var inner := point - direction * minf(wave * 0.26, 12.0 - progress * 5.0)
		var height := 4.0 + sin(progress * PI) * (4.0 + (index % 5) * 2.0)
		_ribbon(PackedVector2Array([inner, point]), 2.8, Color(Color("#e9ae8b"), amplitude), height)
		_gem(point, 3.4 - progress * 2.0, Color(Color("#fff6dd"), amplitude), height + 1.8)


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
				_ring(at, 8.0 + 22.0 * progress, 3.5, Color(Color("#fff1a4"), fade), GROUND + 0.05)
				size = 67.0
			else:
				_thunder_shell(at, 1.02 + 0.68 * progress, fade, 1.0)
				_glint(at, 23.0, 70.0, Color("#ffbc5a"), 0.82 * fade)
				_ring(at, 26.0 + 18.0 * progress, 4.5, Color(Color("#ffffd5"), fade), GROUND + 0.18)
				size = 68.0
		"combo_tide_mirror":
			var direction: Vector2 = clip.get("direction", from.direction_to(at))
			_water_splash(at, direction, progress, fade, event == "combo_launch")
			size = 79.0 if event == "combo_launch" else 65.0
		"combo_rewind_anchor":
			if event == "combo_launch":
				for point: Vector2 in clip.get("points", PackedVector2Array()):
					_ring(point, 18.0 + progress * 10.0, 3.0, Color(Color("#b2ddff"), fade), GROUND + 0.45)
				return
			if from.distance_squared_to(at) > 16.0:
				var trail := PackedVector2Array([from, at])
				_ribbon(trail, 13.0, Color(Color("#6d7cea"), 0.32 * fade), GROUND + 0.32)
				_ribbon(trail, 2.4, Color(Color("#c7ebff"), 0.71 * fade), GROUND + 0.47)
			_ring(at, 11.0 + progress * 21.0, 2.5, Color(Color("#b1d7ff"), fade), GROUND + 0.40)
			size = 47.0
			flat = true
			height = GROUND + 0.3
		CLEANSER:
			if phase == "pool":
				_cleanser_splash(at, float(clip.get("radius", 24.0)), progress, fade, frame)
				return
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
			if event == "combo_launch":
				var radius := float(clip.get("radius", 86.4))
				_stomp_wave(at, radius, progress, fade, bool(clip.get("did_hit", true)))
				_card(skill_id, at, radius * 0.72, GROUND + 0.28, frame, opacity, true)
				_glint(at, FLASH_HEIGHT, 58.0, Color("#e7abff"), fade * 0.53)
				return
			var interrupt := bool(clip.get("interrupted", false))
			_ring(at, 8.0 + progress * 13.0, 2.2, Color(Color("#f8dd9a"), fade * 0.61), GROUND + 0.32)
			size = 47.0 if interrupt else 38.0
		"combo_dew_pickup":
			size = 55.0 if event == "combo_heal" else 37.0
			height = 20.0 + 16.0 * progress if event == "combo_heal" else 13.0
	_card(skill_id, at, size, height, frame, opacity, flat)
	_glint(at, height + 3.0, size * 0.72, color, 0.49 * fade)


func _cleanser_foam(at: Vector2, radius: float, progress: float, age: float) -> void:
	var spread := lerpf(0.42, 1.0, ease(clampf(age / 0.28, 0.0, 1.0), 0.50))
	var life_fade := smoothstep(0.0, 0.15, age) * (1.0 - smoothstep(0.76, 1.0, progress))
	for index in CLEANSER_FOAM_OFFSETS.size():
		var offset: Vector2 = CLEANSER_FOAM_OFFSETS[index]
		var ripple := 0.5 + 0.5 * sin(age * 5.5 + float(index) * 2.4)
		var patch_size := radius * lerpf(1.06, 0.52, offset.length()) * (0.90 + 0.10 * ripple)
		var frame := 8 + roundi(ripple * 10.0)
		var opacity := lerpf(0.40, 0.73, ripple) * life_fade
		_card(CLEANSER, at + offset * radius * spread, patch_size, GROUND + 0.26, frame, opacity, true)


func _cleanser_splash(at: Vector2, radius: float, progress: float, fade: float, frame: int) -> void:
	var spread := lerpf(0.20, 1.0, ease(progress, 0.38))
	for index in range(1, CLEANSER_FOAM_OFFSETS.size(), 2):
		var offset: Vector2 = CLEANSER_FOAM_OFFSETS[index]
		var spray_at := at + offset * radius * spread
		var rise := sin(progress * PI) * (8.0 + float(index) * 0.88)
		_card(CLEANSER, spray_at, radius * (0.32 + float(index % 3) * 0.08), GROUND + rise,
			mini(frame + index, FRAMES - 1), fade)
	_card(CLEANSER, at, radius * 1.04, GROUND + 0.34, frame, 0.78 * fade, true)
	_glint(at, GROUND + 7.0, radius * 0.72, Color("#c5f9ee"), 0.38 * fade)


func _lightning(a: Vector2, b: Vector2, fade: float) -> void:
	var path := PackedVector2Array([a])
	var lateral := a.direction_to(b).orthogonal()
	var spacing := minf(a.distance_to(b) * 0.15, 9.5)
	for index in range(1, 6):
		var zig := sin(float(index) * 5.37 + floorf(_time * 37.0))
		path.append(a.lerp(b, index / 6.0) + lateral * spacing * zig)
	path.append(b)
	_ribbon(path, 12.0, Color(Color("#ffad47"), fade * 0.52), 27.7)
	_ribbon(path, 6.4, Color(Color("#fff396"), fade * 0.87), 27.9)
	_ribbon(path, 2.8, Color(Color("#fffde2"), fade), 28.3)
	for j in [2, 4]:
		var base := path[j]
		var side := -1.0 if j == 2 else 1.0
		var arc := PackedVector2Array([base, base + lateral * (9.0 * side), base.lerp(b, 0.27) + lateral * (16.0 * side)])
		_ribbon(arc, 2.7, Color(Color("#ffe18e"), fade * 0.72), 28.5)


func _water_splash(at: Vector2, heading: Vector2, progress: float, fade: float, reflect: bool) -> void:
	var forward := Vector2.RIGHT if heading.is_zero_approx() else heading.normalized()
	var normal := forward.orthogonal()
	var shell := _arc(at, 10.0 + 25.0 * progress, forward.angle() - 1.18, 2.36, 11)
	_ribbon(shell, 9.4, Color(Color("#25c1d2"), 0.54 * fade), 12.5)
	_ribbon(shell, 3.4, Color(Color("#dafff5"), fade), 13.0)
	var width := 44.0 if reflect else 33.0
	for i in range(-2, 3):
		var push := progress * progress * width
		var spray := at + forward * (9.0 + push * (1.0 - absf(i) * 0.16)) + normal * (i * (5.4 + push * 0.40))
		_gem(spray, 4.5 - progress * 2.7, Color(Color("#a5fff6"), fade), 18.5 + progress * 4.1)


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

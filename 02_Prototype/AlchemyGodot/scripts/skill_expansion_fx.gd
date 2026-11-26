extends Node3D

const FOOTPRINT_SHADER := preload("res://art/vfx/skill_expansion/footprint.gdshader")
const SKILL_LIGHT := preload("res://scripts/v2_skill_light.gd")
const SPLIT_FX := preload("res://scripts/split_alchemy_fx.gd")
const SCALE := 0.01
const FLOOR := 0.064
const COLUMNS := 8
const ROWS := 3
const FRAMES := COLUMNS * ROWS
const SHEETS := {
	"sk_thunder_salt": preload("res://art/vfx/skill_expansion/thunder_salt.png"),
	"sk_fire_oil": preload("res://art/vfx/skill_expansion/fire_oil.png"),
	"sk_mercury_ring": preload("res://art/vfx/skill_expansion/mercury_ring.png"),
	"sk_frost_powder": preload("res://art/vfx/skill_expansion/frost_powder.png"),
	"sk_wind_flask": preload("res://art/vfx/skill_expansion/wind_flask.png"),
	"sk_feather_draught": preload("res://art/vfx/skill_expansion/feather_draught.png"),
	"sk_wind_boots": preload("res://art/vfx/skill_expansion/wind_boots.png"),
	"sk_return_wind_powder": preload("res://art/vfx/skill_expansion/return_wind.png"),
	"sk_renewal_flask": preload("res://art/vfx/skill_expansion/renewal_flask.png"),
	"sk_dew_tonic": preload("res://art/vfx/skill_expansion/dew_tonic.png"),
}

static var _floor_quad := QuadMesh.new()
static var _stroke_mesh := BoxMesh.new()
static var _frost_mesh := PrismMesh.new()
static var _parcels: Dictionary = {}

var _info: Dictionary
var _state: Dictionary
var _style: Dictionary
var _card: Sprite3D
var _floor_material: ShaderMaterial
var _floor_mesh: MeshInstance3D
var _tint: Color
var _accent: Color
var _card_tint: Color
var _feature_materials: Array[StandardMaterial3D] = []
var _heal_mark: Node3D
var _heal_origin: Vector3
var _age := 0.0
var _lifetime := 0.0


static func supports(skill_id: String) -> bool:
	return SHEETS.has(skill_id)


func start(info: Dictionary) -> void:
	_info = info
	_state = info.get("state", {})
	_style = _profile(info)
	if _style.is_empty():
		set_process(false)
		queue_free()
		return
	var skill_id := String(info.skill_id)
	var kind: String = _style.kind
	_lifetime = _duration(info, _state, _style)
	var side := int(info.get("split_side", _state.get("split_side", 0)))
	_tint = info.get("color", Color.WHITE)
	_accent = _tint.lightened(0.55) if side == 0 else SPLIT_FX.branch_color(side)
	_card_tint = Color.WHITE if side == 0 else Color.WHITE.lerp(_accent, 0.34)
	if side != 0:
		set_meta("split_side", side)
	var point := Motion.anchor(_info, _state, kind, 0.0)
	position = _world(point)
	var texture: Texture2D = _parcel_texture(skill_id) if kind == "arc" else SHEETS[skill_id]
	_card = Sprite3D.new()
	_card.texture = texture
	_card.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_card.shaded = false
	_card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_card.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_card.pixel_size = float(_style.get("size", 0.8)) / _width(texture, kind)
	_card.position.y = float(_style.get("height", FLOOR))
	_card.modulate = _card_tint
	_card.visible = kind != "freeze"
	if kind != "arc":
		_card.hframes = COLUMNS
		_card.vframes = ROWS
	add_child(_card)
	if kind == "dash":
		_card.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		_card.rotation.x = -PI * 0.5
		_card.rotation.y = -_heading(info, _state).angle()
	elif _style.get("flat", false):
		_card.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		_card.rotation.x = -PI * 0.5
	elif kind == "cone":
		var camera := get_viewport().get_camera_3d()
		_card.flip_h = is_instance_valid(camera) and camera.global_basis.x.dot(_world(_heading(info, _state))) < 0.0
	if _style.has("shape"):
		_add_footprint()
	_add_readability_layers(skill_id, kind, side)
	if _style.has("light"):
		SKILL_LIGHT.add(self, Vector3.UP * maxf(_card.position.y, 0.13), float(_style.light),
			Color(_accent, 0.58), minf(_lifetime, 0.32), 0.53)
	_process(0.0)


func _process(delta: float) -> void:
	_age += delta
	var time := _lifetime
	var kind: String = _style.kind
	if (_age >= time and not (kind == "freeze" and _state.has("freeze_target"))) or Motion.finished(_state, kind):
		queue_free()
		return
	var phase := clampf(_age / time, 0.0, 1.0)
	position = _world(Motion.anchor(_info, _state, kind, phase))
	var fade := Motion.fade(_age, time, kind)
	_card.modulate = Color(_card_tint, fade * float(_style.get("opacity", 0.88)))
	if kind == "arc":
		_card.position.y = Motion.arc_height(_state, phase)
	else:
		_card.frame = mini(floori(phase * FRAMES), FRAMES - 1)
	var radius := Motion.radius(_info, _state)
	if kind == "ring":
		var current := Motion.ring_radius(_state, _info, _age)
		_card.scale = Vector3.ONE * maxf(current / radius, 0.02)
		_card.modulate.a *= 0.42
	elif kind == "cone":
		_card.position += _world(_heading(_info, _state)) * radius * SCALE * 0.55 - _card.position.slide(Vector3.UP)
	elif kind == "dash":
		var glide := clampf(_age / 0.18, 0.0, 1.0)
		var origin: Vector2 = _info.get("from", Vector2.ZERO)
		var target: Vector2 = _info.get("target", origin)
		_card.position = _world((target - origin) * glide * 0.8)
		_card.position.y = 0.13 + phase * 0.08
	elif kind == "heal":
		_card.position.y = float(_style.height) + phase * 0.25
		if _heal_mark:
			_heal_mark.position = _heal_origin + Vector3.UP * phase * 0.31
	for material in _feature_materials:
		var tint := material.albedo_color
		tint.a = fade
		material.albedo_color = tint
	if _floor_material:
		_floor_material.set_shader_parameter("age", _age)
		_floor_material.set_shader_parameter("strength", fade * float(_style.get("ground", 0.8)))
		_floor_material.set_shader_parameter("wave", Motion.ring_radius(_state, _info, _age) / radius if kind == "ring" else phase)


func _add_footprint() -> void:
	_floor_mesh = MeshInstance3D.new()
	_floor_mesh.mesh = _floor_quad
	_floor_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_floor_mesh.rotation.x = -PI * 0.5
	_floor_mesh.position.y = FLOOR
	var radius := float(_style.get("footprint_radius", Motion.radius(_info, _state)))
	_floor_mesh.scale = Vector3.ONE * (radius * 2.0 * SCALE)
	_floor_material = ShaderMaterial.new()
	_floor_material.shader = FOOTPRINT_SHADER
	_floor_material.set_shader_parameter("tint", _tint)
	_floor_material.set_shader_parameter("accent", _accent)
	_floor_material.set_shader_parameter("shape", int(_style.shape))
	_floor_material.set_shader_parameter("heading", _heading(_info, _state))
	_floor_material.set_shader_parameter("cone_cosine", cos(_half_angle(_info, _state)))
	_floor_mesh.material_override = _floor_material
	add_child(_floor_mesh)


func _add_readability_layers(skill_id: String, kind: String, side: int) -> void:
	if skill_id == "sk_thunder_salt" and kind == "burst":
		var white := _ink(Color("#fff0ff"))
		var halo := _ink(Color("#b59bea") if side == 0 else _accent)
		var zigzag := [Vector3(-0.14, 1.83, 0.02), Vector3(0.02, 1.38, 0.04),
			Vector3(-0.13, 1.19, 0.01), Vector3(0.07, 0.92, 0.02),
			Vector3(-0.06, 0.70, 0.00), Vector3(0.10, 0.48, -0.04), Vector3(0.0, 0.10, 0.0)]
		for i in range(1, zigzag.size()):
			_stroke(self, zigzag[i - 1], zigzag[i], 0.071, halo)
			_stroke(self, zigzag[i - 1], zigzag[i], 0.033, white)
	elif skill_id == "sk_frost_powder" and kind in ["burst", "freeze"]:
		var ice := _ink(Color("#a1e8ef") if side == 0 else _accent.lerp(Color.CYAN, 0.27))
		var snow := _ink(Color("#e8fcfa"))
		var count := 4 if kind == "freeze" else 6
		var rad := 0.20 if kind == "freeze" else Motion.radius(_info, _state) * SCALE * 0.63
		for i in count:
			var angle := float(i) * TAU / float(count) + 0.3
			var at := Vector3(cos(angle) * rad, 0.15, sin(angle) * rad)
			var crystal := MeshInstance3D.new()
			crystal.mesh = _frost_mesh
			crystal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			crystal.material_override = snow if i % 3 == 0 else ice
			crystal.position = at
			crystal.rotation = Vector3(cos(angle) * 0.24, angle, sin(angle) * 0.24)
			crystal.scale = Vector3(0.11, 0.28 + float(i % 3) * 0.07, 0.095)
			add_child(crystal)
	elif kind == "dash":
		_add_dash_trail(skill_id, side)
	elif kind == "heal" and skill_id == "sk_dew_tonic":
		_add_heal_mark(side)


func _add_dash_trail(skill_id: String, side: int) -> void:
	var fwd := _world(_heading(_info, _state)).normalized()
	var lateral := Vector3(-fwd.z, 0.0, fwd.x)
	var origin: Vector2 = _info.get("from", Vector2.ZERO)
	var target: Vector2 = _info.get("target", origin)
	var length := maxf(origin.distance_to(target) * SCALE, 0.38)
	var color := _accent if side != 0 else Color("#9ce0fa")
	if side == 0 and skill_id == "sk_return_wind_powder":
		color = Color("#dfb6ef")
	var mantle := _ink(color)
	var core := _ink(color.lightened(0.58))
	var offsets := [-0.095, 0.095] if side == 0 else [float(side) * 0.14]
	for offset: float in offsets:
		var at := lateral * offset + Vector3.UP * 0.115
		var elbow := at + fwd * length * 0.44 - lateral * offset * 0.31 + Vector3.UP * 0.055
		var tip := at + fwd * length * 0.92 - lateral * offset * 0.58 + Vector3.UP * 0.016
		if skill_id == "sk_return_wind_powder":
			_stroke(self, at + fwd * 0.06, elbow - fwd * 0.085, 0.048, mantle)
			_stroke(self, elbow, tip, 0.052, core)
		else:
			_stroke(self, at, elbow, 0.042, mantle)
			_stroke(self, elbow, tip, 0.054, core)
			_stroke(self, tip - fwd * 0.15 + lateral * signf(offset) * 0.10, tip, 0.037, mantle)


func _add_heal_mark(side: int) -> void:
	_heal_mark = Node3D.new()
	add_child(_heal_mark)
	var camera := get_viewport().get_camera_3d()
	var right := camera.global_basis.x.normalized() if is_instance_valid(camera) else Vector3.RIGHT
	var up := camera.global_basis.y.normalized() if is_instance_valid(camera) else Vector3.UP
	var toward_camera := camera.global_basis.z.slide(Vector3.UP).normalized() if is_instance_valid(camera) else Vector3.BACK
	var side_offset := -0.21 if side < 0 else 0.28
	_heal_origin = Vector3.UP * 0.76 + right * side_offset + toward_camera * 0.27
	_heal_mark.position = _heal_origin
	var gold := _ink(Color("#ffe192") if side == 0 else _accent.lightened(0.21))
	var core := _ink(Color("#fff6cb"))
	_stroke(_heal_mark, -right * 0.14, right * 0.14, 0.077, gold)
	_stroke(_heal_mark, -up * 0.14, up * 0.14, 0.077, gold)
	_stroke(_heal_mark, -right * 0.10, right * 0.10, 0.041, core)
	_stroke(_heal_mark, -up * 0.10, up * 0.10, 0.041, core)
	var droplet := right * 0.18 + up * 0.105
	_stroke(_heal_mark, droplet - up * 0.025, droplet + up * 0.026, 0.047, gold)


func _ink(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	_feature_materials.append(material)
	return material


func _stroke(parent: Node3D, from: Vector3, to: Vector3, width: float, material: StandardMaterial3D) -> void:
	var axis := from.direction_to(to)
	if axis.is_zero_approx():
		return
	var mesh := MeshInstance3D.new()
	mesh.mesh = _stroke_mesh
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.material_override = material
	var up := Vector3.UP if absf(axis.y) < 0.98 else Vector3.FORWARD
	mesh.transform = Transform3D(Basis.looking_at(axis, up).scaled_local(Vector3(width, width, from.distance_to(to))), from.lerp(to, 0.5))
	parent.add_child(mesh)


static func _profile(info: Dictionary) -> Dictionary:
	var event := String(info.get("event", ""))
	var state: Dictionary = info.get("state", {})
	var diameter := Motion.radius(info, state) * 2.0 * SCALE
	match String(info.skill_id):
		"sk_thunder_salt":
			if event in ["cast", "flight"]:
				return {"kind":"arc", "time":0.32, "size":0.30}
			if event == "impact":
				return {"kind":"burst", "time":0.43, "size":1.03, "height":0.49, "light":0.67,
					"shape":0, "ground":1.0, "footprint_radius":31.0}
		"sk_fire_oil":
			if event == "cast":
				return {"kind":"burst", "time":0.24, "size":0.62, "height":0.16, "light":0.33}
			if event == "zone_start":
				return {"kind":"zone", "time":1.8, "size":diameter * 1.02, "height":0.20, "shape":0, "ground":0.8}
		"sk_mercury_ring":
			if event in ["zone_start", "ring_start"]:
				return {"kind":"ring", "time":0.4, "size":diameter, "height":FLOOR + 0.007, "shape":1, "flat":true}
		"sk_frost_powder":
			if event in ["cast", "flight"]:
				return {"kind":"arc", "time":0.32, "size":0.36}
			if event == "impact":
				return {"kind":"burst", "time":0.58, "size":diameter * 0.70, "height":0.35, "shape":0, "ground":0.77, "light":0.50}
			if event == "freeze_start":
				return {"kind":"freeze", "time":0.8, "size":0.54, "height":0.10,
					"shape":0, "ground":0.72, "footprint_radius":27.0}
		"sk_wind_flask":
			if event == "impact":
				return {"kind":"cone", "time":0.28, "size":diameter * 0.45, "height":0.30, "shape":2, "light":0.42}
		"sk_feather_draught":
			if event in ["buff_start", "buff_pulse", "boost"]:
				return {"kind":"follow", "time":2.0, "size":0.90, "height":0.20, "opacity":0.78}
		"sk_wind_boots":
			if event in ["dash", "boost"]:
				return {"kind":"dash", "time":0.34, "size":0.88, "height":0.18, "light":0.38}
		"sk_return_wind_powder":
			if event == "ready":
				return {"kind":"follow", "time":0.42, "size":0.60, "height":0.24, "opacity":0.78}
			if event in ["dash", "boost"]:
				return {"kind":"dash", "time":0.34, "size":0.97, "height":0.23, "light":0.43}
		"sk_renewal_flask":
			if event == "zone_start":
				return {"kind":"zone", "time":3.0, "size":diameter, "height":0.57, "shape":0, "ground":0.83, "opacity":0.7}
			if event in ["heal", "zone_tick"]:
				return {"kind":"heal", "time":0.28, "size":0.58, "height":0.35, "light":0.37}
		"sk_dew_tonic":
			if event == "heal":
				return {"kind":"heal", "time":0.44, "size":0.77, "height":0.71, "light":0.48}
	return {}


static func _duration(info: Dictionary, state: Dictionary, style: Dictionary) -> float:
	# A heal event can carry its parent pool state. Only its own pulse lifetime applies.
	var base := float(style.time)
	if style.kind in ["arc", "ring", "zone", "freeze"]:
		base = float(state.get("duration", state.get("left", base)))
	var duration := float(info.get("duration", 0.0))
	return maxf(duration if duration > 0.0 else base, 0.03)


static func _heading(info: Dictionary, state: Dictionary) -> Vector2:
	var origin: Vector2 = info.get("from", Vector2.ZERO)
	var target: Vector2 = info.get("target", origin)
	var heading: Vector2 = state.get("direction", origin.direction_to(target))
	return Vector2.RIGHT if heading.is_zero_approx() else heading.normalized()


static func _half_angle(info: Dictionary, state: Dictionary) -> float:
	return float(state.get("half_angle", float(info.get("angle", deg_to_rad(70.0))) * 0.5))


static func _width(texture: Texture2D, kind: String) -> float:
	return float(texture.get_width()) / (1.0 if kind == "arc" else float(COLUMNS))


static func _world(point: Vector2) -> Vector3:
	return Vector3(point.x, 0.0, point.y) * SCALE


static func _parcel_texture(skill_id: String) -> Texture2D:
	if _parcels.has(skill_id):
		return _parcels[skill_id]
	var salt := skill_id == "sk_thunder_salt"
	var pattern := ["...#...", "..#B#..", ".#BWB#.", "#BWWHB#", ".#BHB#.", "..#B#..", "...#..."] if salt else \
		["..##...", ".#WW#..", "..#B#..", ".#BHB#.", "#HWHBB#", "#WHBBB#", ".#####."]
	var palette := {"#":Color("#4b385a") if salt else Color("#2c5260"),
		"B":Color("#9d7bc7") if salt else Color("#87abae"),
		"H":Color("#ceb8e9") if salt else Color("#c4e1dc"), "W":Color("#faf4e2")}
	var art := Image.create_empty(7, 7, false, Image.FORMAT_RGBA8)
	for y in pattern.size():
		for x in 7:
			var symbol: String = pattern[y][x]
			if palette.has(symbol):
				art.set_pixel(x, y, palette[symbol])
	var texture := ImageTexture.create_from_image(art)
	_parcels[skill_id] = texture
	return texture


static func start_fallback(parent: Node2D, info: Dictionary) -> void:
	var style := _profile(info)
	if style.is_empty():
		return
	var effect := FallbackEffect.new()
	effect.set_meta("skill_expansion_fx", true)
	var kind: String = style.kind
	var state: Dictionary = info.get("state", {})
	var skill_id := String(info.skill_id)
	var texture: Texture2D = _parcel_texture(skill_id) if kind == "arc" else SHEETS[skill_id]
	effect.style = style
	effect.info = info
	effect.state = state
	var side := int(info.get("split_side", state.get("split_side", 0)))
	if side != 0:
		effect.set_meta("split_side", side)
	var tint: Color = info.get("color", Color.WHITE)
	effect.accent = tint.lightened(0.5) if side == 0 else SPLIT_FX.branch_color(side)
	effect.card_tint = Color.WHITE if side == 0 else Color.WHITE.lerp(effect.accent, 0.34)
	effect.time = _duration(info, state, style)
	effect.radius = float(style.get("footprint_radius", Motion.radius(info, state)))
	effect.heading = _heading(info, state)
	effect.half_angle = _half_angle(info, state)
	effect.card = Sprite2D.new()
	effect.card.texture = texture
	effect.card.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if kind != "arc":
		effect.card.hframes = COLUMNS
		effect.card.vframes = ROWS
	effect.card_scale = float(style.get("size", 0.8)) / (SCALE * _width(texture, kind))
	effect.card.flip_h = kind == "cone" and effect.heading.x < 0.0
	if kind == "dash":
		effect.card.rotation = effect.heading.angle()
	effect.add_child(effect.card)
	parent.add_child(effect)
	effect._process(0.0)


class Motion:
	static func finished(state: Dictionary, kind: String) -> bool:
		if kind == "freeze" and state.has("freeze_target"):
			var enemy: Dictionary = state.freeze_target
			return not is_instance_valid(enemy.get("body")) or float(enemy.get("hp", 0.0)) <= 0.0 \
				or float(enemy.get("freeze_left", 0.0)) <= 0.0
		return kind in ["arc", "zone", "ring"] and state.get("finished", false)

	static func anchor(info: Dictionary, state: Dictionary, kind: String, phase: float) -> Vector2:
		var origin: Vector2 = info.get("from", Vector2.ZERO)
		var target: Vector2 = info.get("target", origin)
		if kind == "arc":
			return state.get("pos", origin.lerp(target, phase))
		if kind in ["ring", "zone"]:
			return state.get("pos", target)
		if kind in ["cone", "dash"]:
			return origin
		if kind == "freeze":
			var enemy: Dictionary = state.get("freeze_target", {})
			var body: Variant = enemy.get("body")
			return body.global_position if is_instance_valid(body) else target
		var follow: Variant = info.get("follow")
		if is_instance_valid(follow) and follow is Node2D:
			return follow.global_position
		return target

	static func radius(info: Dictionary, state: Dictionary) -> float:
		return maxf(float(state.get("radius", info.get("radius", 28.0))), 8.0)

	static func ring_radius(state: Dictionary, info: Dictionary, age: float) -> float:
		return clampf(float(state.get("current_radius", age * float(state.get("speed", 448.0)))),
			0.0, radius(info, state))

	static func arc_height(state: Dictionary, phase: float) -> float:
		return float(state.get("flight_height", (1.0 - phase) * 34.0 + sin(phase * PI) * 32.0)) * SCALE

	static func fade(age: float, duration: float, kind: String) -> float:
		var tail := minf(duration * 0.55, 0.27)
		if kind in ["arc", "ring", "freeze"]:
			return 1.0
		return 1.0 - smoothstep(duration - tail, duration, age)


class FallbackEffect extends Node2D:
	var info: Dictionary
	var state: Dictionary
	var style: Dictionary
	var card: Sprite2D
	var card_tint: Color
	var accent: Color
	var heading: Vector2
	var half_angle: float
	var time: float
	var radius: float
	var card_scale: float
	var age := 0.0

	func _process(delta: float) -> void:
		age += delta
		var kind: String = style.kind
		if (age >= time and not (kind == "freeze" and state.has("freeze_target"))) or Motion.finished(state, kind):
			queue_free()
			return
		var phase := clampf(age / time, 0.0, 1.0)
		global_position = Motion.anchor(info, state, kind, phase)
		card.scale = Vector2.ONE * card_scale
		card.position.y = -float(style.get("height", FLOOR)) / SCALE
		if kind == "arc":
			card.position.y = -Motion.arc_height(state, phase) / SCALE
		else:
			card.frame = mini(int(phase * FRAMES), FRAMES - 1)
		card.modulate = Color(card_tint, Motion.fade(age, time, kind) * float(style.get("opacity", 0.88)))
		if kind == "ring":
			card.scale *= Motion.ring_radius(state, info, age) / radius
			card.modulate.a *= 0.42
		elif kind == "cone":
			card.position = heading * radius * 0.55 + Vector2.UP * 16.0
		elif kind == "dash":
			var origin: Vector2 = info.get("from", Vector2.ZERO)
			var target: Vector2 = info.get("target", origin)
			card.position = (target - origin) * minf(age / 0.18, 1.0) * 0.8 + Vector2.UP * 14.0
		elif kind == "heal":
			card.position.y -= phase * 25.0
		if style.has("shape"):
			queue_redraw()

	func _draw() -> void:
		if not style.has("shape"):
			return
		var fade := Motion.fade(age, time, style.kind)
		match int(style.shape):
			0:
				draw_circle(Vector2.ZERO, radius, Color(accent, fade * 0.12))
				draw_arc(Vector2.ZERO, radius - 1.0, 0.0, TAU, 48, Color(accent, fade * 0.43), 2.0)
			1:
				draw_arc(Vector2.ZERO, Motion.ring_radius(state, info, age), 0.0, TAU, 48, Color(accent, fade * 0.86), 3.0)
			2:
				var phase := age / time
				var angle := heading.angle()
				draw_arc(Vector2.ZERO, radius * phase, angle - half_angle, angle + half_angle, 28, Color(accent, fade * 0.68), 5.0)

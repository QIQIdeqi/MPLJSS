extends Node3D

const GROUND_SHADER := preload("res://shaders/v2_skill_ground.gdshader")
const SKILL_LIGHT := preload("res://scripts/v2_skill_light.gd")
const VIAL := preload("res://scenes/fx/brew_result_vial.png")
const DUST := preload("res://art/vfx/v2/clay_homunculus_summon_24f.png")
const SMOKE := preload("res://art/vfx/v2/blast_flask_impact_24f.png")
const MIST := preload("res://art/vfx/v2/mist_flask_cloud_24f.png")
const MITHRIL := preload("res://art/vfx/v2/mithril_drop_impact_24f.png")
const GOLEM := preload("res://art/vfx/v2/link_blast_homunculus_24f.png")
const GEL_NEEDLE := preload("res://art/vfx/v2/link_soulbound_needle_24f.png")
const WORLD_SCALE := 0.01
const FLOOR_Y := 0.055

enum Ground { RIPPLE, POOL, VORTEX, ORBIT, MIST, ACID }

static var box_mesh := BoxMesh.new()
static var shard_mesh := PrismMesh.new()
static var surface_materials: Dictionary[String, StandardMaterial3D] = {}
static var atlas_crops: Dictionary[String, AtlasTexture] = {}
static var clay_texture: ImageTexture

var state: Dictionary = {}
var skill_id := ""
var event_name := ""
var age := 0.0
var lifetime := 0.0
var world_radius := 0.6
var launch_point := Vector2.ZERO
var heading := Vector2.RIGHT
var body: Node3D
var body_card: Sprite3D
var light: OmniLight3D
var light_power := 0.0
var floor_mat: ShaderMaterial
var orbiters: Array[MeshInstance3D] = []
var vapors: Array[Sprite3D] = []
var vapor_offsets: Array[Vector3] = []
var vapor_colors: Array[Color] = []

func start(info: Dictionary) -> void:
	skill_id = String(info.get("skill_id", ""))
	event_name = String(info.get("event", ""))
	launch_point = info.get("from", Vector2.ZERO)
	var target: Vector2 = info.get("target", launch_point)
	state = info.get("state", info.get("projectile", {}))
	heading = state.get("direction", launch_point.direction_to(target))
	if heading.is_zero_approx():
		heading = Vector2.RIGHT
	world_radius = maxf(float(state.get("radius", info.get("radius", 0.0))) * WORLD_SCALE, 0.42)
	position = _world_at(target)
	match event_name:
		"flight":
			if state.is_empty():
				queue_free()
				return
			lifetime = -1.0
			_make_flight()
			_move_flight()
		"zone_start":
			if state.is_empty():
				queue_free()
				return
			lifetime = -1.0
			position = _world_at(state.get("pos", target))
			_make_zone()
		"summon_start":
			if state.is_empty():
				queue_free()
				return
			lifetime = -1.0
			position = _world_at(state.get("pos", launch_point))
			_make_summon()
		"summon_strike":
			_summon_strike(target, launch_point)
		"summon_end":
			_summon_end()
		"impact":
			_impact()
		"zone_tick":
			_zone_tick()
		"hop":
			_hop(target, launch_point)
	if is_zero_approx(lifetime):
		queue_free()

func _process(delta: float) -> void:
	age += delta
	if (lifetime >= 0.0 and age >= lifetime) or (lifetime < 0.0 and bool(state.get("visual_finished", false))):
		queue_free()
		return
	match event_name:
		"flight":
			_move_flight()
		"zone_start":
			position = _world_at(state.get("pos", Vector2.ZERO))
			_update_zone()
		"summon_start":
			_update_summon()
	if light:
		light.light_energy = light_power * pow(maxf(0.0, 1.0 - age / 0.19), 2.0)
	if floor_mat and event_name != "zone_start":
		var progress := clampf(age / maxf(lifetime * 0.68, 0.06), 0.0, 1.0)
		floor_mat.set_shader_parameter("wave_radius", lerpf(0.13, 0.92, 1.0 - pow(1.0 - progress, 2.0)))
		floor_mat.set_shader_parameter("age", age)
		floor_mat.set_shader_parameter("strength", 1.0 - smoothstep(0.10, 1.0, progress))

func _make_flight() -> void:
	body = Node3D.new()
	add_child(body)
	match skill_id:
		"sk_mithril_drop":
			body_card = _card(_crop(MITHRIL, Rect2(560, 0, 32, 48)), body, 0.008, Color(0.88, 0.96, 1.0))
			SKILL_LIGHT.add(body, Vector3.ZERO, 0.54, Color(0.34, 0.64, 1.0, 0.53))
		"sk_gravity_stone":
			_piece(body, Vector3.ZERO, Vector3(0.21, 0.25, 0.22), Color("#231a35"), true)
			_piece(body, Vector3(0.03, 0.045, 0.025), Vector3(0.10, 0.10, 0.11), Color("#a76bd7"), true, true)
			SKILL_LIGHT.add(body, Vector3.ZERO, 0.62, Color(0.64, 0.34, 0.96, 0.52))
		"sk_corrosive_flask":
			body_card = _card(VIAL, body, 0.0045, Color(0.60, 1.0, 0.45), true)
			SKILL_LIGHT.add(body, Vector3.ZERO, 0.34, Color(0.67, 0.94, 0.31, 0.43))
		"sk_mist_flask":
			body_card = _card(_crop(MIST, Rect2(558, 441, 36, 48)), body, 0.0055, Color(0.86, 0.95, 1.0), true)
			SKILL_LIGHT.add(body, Vector3.ZERO, 0.36, Color(0.54, 0.68, 1.0, 0.40))
		"sk_obsidian_blade":
			var blade := _piece(body, Vector3(0.03, 0.0, 0.0), Vector3(0.15, 0.39, 0.08), Color("#1d182a"), true)
			blade.rotation.z = -PI * 0.5
			var edge := _piece(body, Vector3(0.0, 0.023, -0.027), Vector3(0.025, 0.35, 0.025), Color("#ba7ec5"), true, true)
			edge.rotation.z = -PI * 0.48
			_streak(body, Vector3(-0.47, 0.0, 0.0), Vector3(-0.06, 0.0, 0.0), 0.022, Color("#ac63d2"))
			SKILL_LIGHT.add(body, Vector3(-0.22, 0.0, 0.0), 0.38, Color(0.67, 0.30, 0.93, 0.48))
		"sk_spirit_gel":
			_piece(body, Vector3.ZERO, Vector3(0.20, 0.15, 0.16), Color("#b66519"), true)
			_piece(body, Vector3(-0.08, 0.04, 0.03), Vector3(0.15, 0.075, 0.09), Color("#ffba52"), true, true)
			_streak(body, Vector3(-0.21, 0.0, 0.0), Vector3(-0.04, 0.0, 0.0), 0.044, Color("#ad6d37"))
			SKILL_LIGHT.add(body, Vector3.ZERO, 0.39, Color(1.0, 0.60, 0.21, 0.54))
		"sk_soul_needle":
			_streak(body, Vector3(-0.37, 0.0, 0.0), Vector3(0.21, 0.0, 0.0), 0.025, Color("#a9f5e8"))
			_streak(body, Vector3(-0.52, -0.031, 0.0), Vector3(-0.20, -0.031, 0.0), 0.013, Color("#668ace"))
			SKILL_LIGHT.add(body, Vector3.RIGHT * 0.18, 0.28, Color(0.44, 1.0, 0.87, 0.59))
		"link_soulbound_needle":
			body_card = _card(_crop(GEL_NEEDLE, Rect2(34, 51, 62, 26)), body, 0.007, Color.WHITE)
			_streak(body, Vector3(-0.37, 0.0, 0.0), Vector3(-0.04, 0.0, 0.0), 0.031, Color("#f2b752"))
			SKILL_LIGHT.add(body, Vector3.RIGHT * 0.15, 0.34, Color(0.87, 0.83, 0.46, 0.62))

func _move_flight() -> void:
	var at: Vector2 = state.get("pos", launch_point)
	var direction: Vector2 = state.get("direction", heading)
	if not direction.is_zero_approx():
		heading = direction
	position = _world_at(at)
	body.rotation.y = -heading.angle()
	body.position.y = 0.31
	if skill_id == "sk_corrosive_flask" or skill_id == "sk_mist_flask":
		var end: Vector2 = state.get("landing", state.get("destination", at))
		var distance := launch_point.distance_to(end)
		var progress := clampf(launch_point.distance_to(at) / maxf(distance, 0.01), 0.0, 1.0)
		body.position.y = lerpf(0.32, 0.13, progress) + sin(progress * PI) * 0.25
		body.rotation.y = 0.0
		body_card.rotation.z = -age * (8.0 if skill_id == "sk_corrosive_flask" else 6.0)
	elif skill_id == "sk_gravity_stone":
		body.rotation.x = age * 9.0
	elif body_card:
		body_card.rotation.y = -body.rotation.y

func _make_zone() -> void:
	match skill_id:
		"sk_gravity_stone":
			_ground(world_radius, Ground.VORTEX, Color("#291d3e"), Color("#9e5ad1"))
			_piece(self, Vector3(0.0, 0.13, 0.0), Vector3(0.20, 0.21, 0.18), Color("#392541"), true)
			_make_orbiters(4, Color("#b180d7"), false)
		"sk_corrosive_flask":
			_ground(world_radius, Ground.ACID, Color("#252f13"), Color("#bbcf4b"))
			_make_orbiters(6, Color("#c4d36a"), true)
		"sk_mist_flask":
			_ground(world_radius, Ground.MIST, Color("#626478"), Color("#b7bfdf"))
			_make_vapor(5, Color(0.68, 0.73, 0.90, 0.39), world_radius * 0.54)
		"link_mithril_orbit":
			_ground(world_radius, Ground.ORBIT, Color("#67778f"), Color("#d2e9fa"))
			_make_orbiters(4, Color("#eaf4ff"), false)
		"link_corrosive_mist":
			_ground(world_radius, Ground.MIST, Color("#484559"), Color("#768b36"))
			_make_vapor(7, Color(0.69, 0.48, 0.77, 0.43), world_radius * 0.53)
			for i in range(1, vapor_colors.size(), 2):
				vapor_colors[i] = Color(0.70, 0.82, 0.43, 0.41)
			_make_orbiters(4, Color("#b2c359"), true)
	_update_zone()

func _update_zone() -> void:
	if not floor_mat:
		return
	var remaining := float(state.get("left", 1.0))
	var fade := smoothstep(0.0, 0.22, age) * clampf(remaining / 0.40, 0.0, 1.0)
	floor_mat.set_shader_parameter("age", age)
	floor_mat.set_shader_parameter("strength", fade * 0.79)
	for i in vapors.size():
		var drift := Vector3(sin(age * 0.87 + i), 0.0, cos(age * 0.71 + i)) * 0.14
		vapors[i].position = vapor_offsets[i] + drift
		var tint := vapor_colors[i]
		tint.a *= fade * (0.78 + sin(age * 1.5 + i) * 0.22)
		vapors[i].modulate = tint
	for i in orbiters.size():
		var drift := age * (2.1 if skill_id == "link_mithril_orbit" else 0.88)
		var angle := i * TAU / orbiters.size() + drift
		var orbit := 0.65 + sin(age * 1.4 + i) * 0.12
		var elevation := 0.13 + cos(age * 3.1 + i * 1.9) * 0.073
		if skill_id == "sk_gravity_stone":
			orbit = 0.76 - fposmod(age * 0.64 + float(i) * 0.19, 0.65)
		var radius := world_radius * orbit
		orbiters[i].position = Vector3(cos(angle) * radius, elevation, sin(angle) * radius)
		orbiters[i].rotation.y = -angle
		orbiters[i].scale = Vector3.ONE * (0.053 * maxf(fade, 0.01))

func _make_orbiters(count: int, tint: Color, bubble: bool) -> void:
	for i in count:
		var stone := _piece(self, Vector3.ZERO, Vector3.ONE * 0.01, tint, not bubble, true)
		orbiters.append(stone)

func _make_vapor(count: int, tint: Color, spread: float) -> void:
	for i in count:
		var angle := i * TAU / count
		var offset := Vector3(cos(angle) * spread, 0.13 + (i % 2) * 0.07, sin(angle) * spread)
		var puff := _card(_crop(SMOKE, Rect2(308, 298, 44, 51)), self, 0.020, Color(tint, 0.0))
		puff.scale.y = 0.50
		vapors.append(puff)
		vapor_offsets.append(offset)
		vapor_colors.append(tint)

func _make_summon() -> void:
	var explosive := skill_id == "link_blast_homunculus"
	if explosive:
		body_card = _card(_crop(GOLEM, Rect2(26, 18, 76, 60)), self, 0.0091, Color.WHITE, true)
		SKILL_LIGHT.add(self, Vector3(0.0, 0.32, 0.08), 0.51, Color(1.0, 0.42, 0.15, 0.39))
	else:
		body_card = _card(_clay_sprite(), self, 0.040, Color.WHITE, true)
	_ground(0.30 if explosive else 0.27, Ground.RIPPLE, Color("#3f3023"), Color("#b18a5e"))
	floor_mat.set_shader_parameter("wave_radius", 0.76)
	_dust(3, Color(0.62, 0.52, 0.41, 0.64), 0.36)
	_update_summon()

func _update_summon() -> void:
	position = _world_at(state.get("pos", launch_point))
	var facing: Vector2 = state.get("direction", Vector2.RIGHT)
	var remaining := float(state.get("left", 1.0))
	var explosive := skill_id == "link_blast_homunculus"
	var fade := smoothstep(0.0, 0.17, age) * (1.0 if explosive else clampf(remaining / 0.3, 0.0, 1.0))
	body_card.flip_h = facing.x < -0.05
	body_card.modulate.a = fade
	body_card.position.y = (0.26 if explosive else 0.31) + absf(sin(age * 9.8)) * 0.033 if not facing.is_zero_approx() else (0.26 if explosive else 0.31)
	floor_mat.set_shader_parameter("strength", fade * 0.39)

func _summon_strike(target: Vector2, from: Vector2) -> void:
	lifetime = 0.28
	var explosive := skill_id == "link_blast_homunculus"
	var tint := Color("#ef9857") if explosive else Color("#c3a681")
	var direction := _world_at(target) - _world_at(from)
	if direction.is_zero_approx():
		direction = Vector3.RIGHT
	direction = direction.normalized()
	var fist := _piece(self, -direction * 0.37 + Vector3.UP * 0.26, Vector3(0.15, 0.13, 0.15), tint, true)
	create_tween().tween_property(fist, "position", Vector3.UP * 0.25, 0.085)
	create_tween().tween_property(fist, "scale", Vector3.ZERO, 0.22).set_delay(0.060)
	_fragments(4, tint, 0.51, 0.18, 0.29)
	SKILL_LIGHT.add(self, Vector3(0.0, 0.26, 0.07), 0.47, Color(tint, 0.76), 0.16, 0.66 if explosive else 0.37)

func _summon_end() -> void:
	lifetime = 0.76
	_ground(clampf(world_radius, 0.68, 1.16), Ground.RIPPLE, Color("#d44925"), Color("#ffb351"))
	_flash(Color("#ffa058"), 1.6, 1.55)
	SKILL_LIGHT.add(self, Vector3(0.0, 0.28, 0.13), 0.95, Color(1.0, 0.44, 0.11, 1.25), 0.27, 0.75)
	_fragments(8, Color("#85513c"), 1.68, 0.62, 0.49, true)
	_fragments(7, Color("#ffa54f"), 2.1, 0.98, 0.38)
	_dust(4, Color(0.45, 0.29, 0.26, 0.56), 0.62)

func _impact() -> void:
	lifetime = 0.37
	match skill_id:
		"sk_mithril_drop":
			_ground(0.39, Ground.RIPPLE, Color("#637187"), Color("#d8f2ff"))
			_fragments(6, Color("#b7d8e7"), 1.23, 0.44, 0.36, true)
			SKILL_LIGHT.add(self, Vector3(0.0, 0.18, 0.08), 0.46, Color(0.54, 0.80, 1.0, 0.94), 0.18, 0.75)
		"sk_gravity_stone":
			_fragments(7, Color("#b17dc4"), 1.63, 0.39, 0.35, true)
			_flash(Color("#bd83ed"), 0.95, 1.05)
			SKILL_LIGHT.add(self, Vector3(0.0, 0.21, 0.08), 0.57, Color(0.72, 0.36, 1.0, 0.91), 0.19, 0.34)
		"sk_corrosive_flask":
			_fragments(6, Color("#b0d071"), 1.04, 0.50, 0.30)
			SKILL_LIGHT.add(self, Vector3(0.0, 0.10, 0.05), 0.46, Color(0.70, 0.92, 0.24, 0.72), 0.19)
		"sk_mist_flask":
			_dust(4, Color(0.79, 0.80, 0.96, 0.49), 0.36)
			SKILL_LIGHT.add(self, Vector3(0.0, 0.15, 0.05), 0.53, Color(0.57, 0.69, 1.0, 0.64), 0.22)
		"sk_crystal_growth":
			lifetime = 0.55
			_ground(0.36, Ground.RIPPLE, Color("#3986af"), Color("#9be0ed"))
			_crystal_spikes()
			_fragments(4, Color("#8ac6f0"), 0.73, 0.32, 0.34, true)
			SKILL_LIGHT.add(self, Vector3(0.0, 0.31, 0.08), 0.50, Color(0.39, 0.85, 1.0, 0.89), 0.24, 0.62)
		"sk_obsidian_blade":
			lifetime = 0.24
			var along := _world_at(heading)
			SKILL_LIGHT.add(self, Vector3(0.0, 0.24, 0.08), 0.48, Color(0.72, 0.40, 0.96, 0.92), 0.18, 0.50)
			var cut := _streak(self, Vector3.UP * 0.20 - along * 0.23, Vector3.UP * 0.37 + along * 0.23, 0.032, Color("#c087d6"))
			create_tween().tween_property(cut, "scale", Vector3.ZERO, 0.21)
			_fragments(4, Color("#ad72c3"), 0.95, 0.47, 0.23, true)
		"sk_spirit_gel":
			lifetime = 0.54
			_ground(0.43, Ground.POOL, Color("#7f541d"), Color("#e9b24f"))
			_fragments(5, Color("#e7a647"), 0.82, 0.35, 0.43)
			SKILL_LIGHT.add(self, Vector3(0.0, 0.15, 0.08), 0.45, Color(1.0, 0.60, 0.18, 0.80), 0.20)
		"sk_soul_needle":
			lifetime = 0.21
			_needle_glint(Color("#b5efe4"), 0.22, false)
		"link_crystal_shatter_blade":
			lifetime = 0.57
			_ground(0.61, Ground.RIPPLE, Color("#43799e"), Color("#b7e9fa"))
			_fragments(6, Color("#9bddf7"), 1.93, 0.52, 0.51, true, 0.118)
			_flash(Color("#aaddf7"), 1.10, 1.26)
			SKILL_LIGHT.add(self, Vector3(0.0, 0.27, 0.10), 0.72, Color(0.49, 0.83, 1.0, 1.22), 0.25, 1.0)
		"link_soulbound_needle":
			lifetime = 0.46
			_needle_glint(Color("#91eadf"), 0.30, true)
			_ground(0.28, Ground.RIPPLE, Color("#966321"), Color("#c8edb3"))

func _zone_tick() -> void:
	lifetime = 0.22
	var tint: Color
	match skill_id:
		"sk_gravity_stone":
			tint = Color("#9f7bc1")
		"sk_corrosive_flask":
			tint = Color("#a9c858")
		"sk_mist_flask":
			tint = Color("#9caebf")
		"link_mithril_orbit":
			tint = Color("#c1d9e6")
		"link_corrosive_mist":
			tint = Color("#b2b760")
		_:
			return
	_fragments(3, tint, minf(1.0, world_radius), 0.18, 0.19, skill_id == "link_mithril_orbit", 0.034)

func _hop(target: Vector2, from: Vector2) -> void:
	lifetime = 0.18
	var tint := Color("#c9e6f4") if skill_id == "sk_mithril_drop" else Color("#9969b0")
	var previous := _world_at(from - target) + Vector3.UP * 0.27
	var end := Vector3.UP * 0.27
	var sideways := Vector3.UP.cross(previous.direction_to(end))
	var joint := previous.lerp(end, 0.45) + sideways * 0.075
	for segment in [[previous, joint], [joint, end]]:
		var trace := _streak(self, segment[0], segment[1], 0.026, tint)
		create_tween().tween_property(trace, "scale", Vector3.ZERO, 0.16)
	SKILL_LIGHT.add(self, end + Vector3.BACK * 0.07, 0.43, Color(tint, 0.92), 0.16, 0.65)

func _crystal_spikes() -> void:
	for i in 3:
		var tint := Color("#a8e2ec") if i == 1 else Color("#4684ad")
		var size := Vector3(0.13, 0.47 if i == 1 else 0.32, 0.10)
		var offset := Vector3((i - 1) * 0.12, size.y * 0.45, 0.015 * i)
		var spike := _piece(self, offset * Vector3(1.0, 0.2, 1.0), size * Vector3(1.0, 0.12, 1.0), tint, true, i == 1)
		spike.rotation.z = (1 - i) * 0.32
		var tween := create_tween().set_parallel(true)
		tween.tween_property(spike, "scale", size, 0.085)
		tween.tween_property(spike, "position", offset, 0.085)
		tween.chain().tween_property(spike, "scale", Vector3.ZERO, 0.25).set_delay(0.15)

func _needle_glint(tint: Color, size: float, bound: bool) -> void:
	var at := Vector3.UP * 0.28
	SKILL_LIGHT.add(self, at + Vector3.BACK * 0.08, size * 1.85, Color(tint, 1.06 if bound else 0.80),
		0.22 if bound else 0.14, 0.88 if bound else 0.62)
	for axis in [Vector3.RIGHT, Vector3.UP]:
		var line := _streak(self, at - axis * size * 0.5, at + axis * size * 0.5, 0.022, tint)
		create_tween().tween_property(line, "scale", Vector3.ZERO, 0.18)
	if bound:
		var mark := _piece(self, at, Vector3(0.095, 0.076, 0.037), Color("#e9b14f"), true, true)
		create_tween().tween_property(mark, "scale", Vector3.ZERO, 0.29).set_delay(0.125)

func _ground(radius: float, kind: Ground, tint: Color, accent: Color) -> void:
	floor_mat = ShaderMaterial.new()
	floor_mat.shader = GROUND_SHADER
	floor_mat.set_shader_parameter("pattern", kind)
	floor_mat.set_shader_parameter("tint", tint)
	floor_mat.set_shader_parameter("accent", accent)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * radius * 2.0
	var disc := MeshInstance3D.new()
	disc.mesh = quad
	disc.material_override = floor_mat
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disc.position.y = FLOOR_Y
	disc.rotation_degrees.x = -90.0
	add_child(disc)

func _flash(tint: Color, power: float, radius: float) -> void:
	light = OmniLight3D.new()
	light.light_color = tint
	light.light_energy = power
	light.omni_range = radius
	light.omni_attenuation = 1.65
	light.position.y = 0.38
	light_power = power
	add_child(light)

func _fragments(count: int, tint: Color, speed: float, height: float, duration: float, pointed := false, size := 0.064) -> void:
	for i in count:
		var angle := float(i) * TAU / count + 0.31
		var out := Vector3(cos(angle), 0.0, sin(angle))
		var at := out * 0.07 + Vector3.UP * 0.13
		var apex := at + out * speed * duration * 0.51 + Vector3.UP * height * (0.30 + float(i % 3) * 0.12)
		var end := out * speed * duration + Vector3.UP * FLOOR_Y
		var shape := Vector3(size * 0.58, size * (1.32 if pointed else 0.96), size * 0.51)
		var speck := _piece(self, at, shape, tint, pointed, not pointed)
		speck.rotation = Vector3(i * 0.81, -angle, -0.43)
		var flight := create_tween()
		flight.tween_property(speck, "position", apex, duration * 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		flight.tween_property(speck, "position", end, duration * 0.55).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		var fade := create_tween()
		fade.tween_property(speck, "scale", Vector3.ZERO, duration * 0.46).set_delay(duration * 0.54)

func _dust(count: int, tint: Color, duration: float) -> void:
	for i in count:
		var angle := i * TAU / count
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var puff := _card(_crop(DUST, Rect2(46, 173, 36, 36)), self, 0.011, tint)
		puff.position = direction * 0.095 + Vector3.UP * 0.09
		puff.scale.y = 0.56
		var tween := create_tween().set_parallel(true)
		tween.tween_property(puff, "modulate:a", 0.0, duration)
		tween.tween_property(puff, "position", direction * 0.43 + Vector3.UP * 0.18, duration)
		tween.tween_property(puff, "scale", Vector3(1.35, 0.72, 1.0), duration)
		tween.chain().tween_callback(puff.queue_free)

func _streak(parent: Node3D, from: Vector3, to: Vector3, width: float, tint: Color) -> MeshInstance3D:
	var length := from.distance_to(to)
	var line := _piece(parent, from.lerp(to, 0.5), Vector3(width, width, maxf(length, 0.001)), tint, false, true)
	if length > 0.001:
		var direction := from.direction_to(to)
		var up := Vector3.RIGHT if absf(direction.y) > 0.96 else Vector3.UP
		line.transform = Transform3D(Basis.looking_at(direction, up).scaled_local(line.scale), line.position)
	return line

func _piece(parent: Node3D, at: Vector3, size: Vector3, tint: Color, pointed: bool, luminous := false) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.mesh = shard_mesh if pointed else box_mesh
	item.material_override = _surface(tint, luminous)
	item.position = at
	item.scale = size
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(item)
	return item

func _card(texture: Texture2D, parent: Node3D, pixel: float, tint: Color, shaded := false) -> Sprite3D:
	var card := Sprite3D.new()
	card.texture = texture
	card.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	card.modulate = tint
	card.shaded = shaded
	card.pixel_size = pixel
	card.rotation_degrees.x = -27.0
	card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(card)
	return card

static func _surface(tint: Color, luminous: bool) -> StandardMaterial3D:
	var key := tint.to_html() + str(luminous)
	if not surface_materials.has(key):
		var surface := StandardMaterial3D.new()
		surface.albedo_color = tint
		surface.roughness = 0.65
		if luminous:
			surface.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		else:
			surface.emission_enabled = true
			surface.emission = tint * 0.14
		surface_materials[key] = surface
	return surface_materials[key]

static func _crop(texture: Texture2D, region: Rect2) -> AtlasTexture:
	var key := texture.resource_path + str(region)
	if not atlas_crops.has(key):
		var crop := AtlasTexture.new()
		crop.atlas = texture
		crop.region = region
		crop.filter_clip = true
		atlas_crops[key] = crop
	return atlas_crops[key]

static func _clay_sprite() -> ImageTexture:
	if clay_texture:
		return clay_texture
	var colors := {"d": Color("#3a2923"), "m": Color("#8c6751"), "h": Color("#b48a68"), "g": Color("#e1ac68")}
	var rows := [
		"....dddd....",
		"...dhhhmd...",
		"...dhmmmd...",
		"...dgmgmd...",
		"..ddmmmmdd..",
		".dhhmmmhhd..",
		"dhmhmmhmmhmd",
		"dmdhmgmmddmd",
		"dd.dhmmmd.dd",
		"...dmmmmmd..",
		"...dmd.dmd..",
		"..dmmd.dmd..",
		"..dddd.ddd..",
	]
	var image := Image.create_empty(12, rows.size(), false, Image.FORMAT_RGBA8)
	for y in rows.size():
		for x in 12:
			var mark: String = rows[y][x]
			if colors.has(mark):
				image.set_pixel(x, y, colors[mark])
	clay_texture = ImageTexture.create_from_image(image)
	return clay_texture

static func _world_at(point: Vector2) -> Vector3:
	return Vector3(point.x, 0.0, point.y) * WORLD_SCALE

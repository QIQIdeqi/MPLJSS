extends Node3D

const GROUND_SHADER := preload("res://shaders/v2_skill_ground.gdshader")
const SKILL_LIGHT := preload("res://scripts/v2_skill_light.gd")
const SPLIT_ALCHEMY_FX := preload("res://scripts/split_alchemy_fx.gd")
const VIAL := preload("res://scenes/fx/brew_result_vial.png")
const MIST := preload("res://art/vfx/v2/mist_flask_cloud_24f.png")
const BRITTLE_SHATTER := preload("res://art/vfx/v2/pixelfx/brittle_mark_break.png")
const BLAST_MARK_CONTACT := preload("res://art/vfx/v2/pixelfx/blast_mark_contact.png")
const MITHRIL_FLIGHT := preload("res://art/vfx/v2/pixelfx/mithril_flight.png")
const MITHRIL_IMPACT := preload("res://art/vfx/v2/pixelfx/mithril_impact.png")
const GRAVITY_FLIGHT := preload("res://art/vfx/v2/pixelfx/gravity_flight.png")
const GRAVITY_ZONE := preload("res://art/vfx/v2/pixelfx/gravity_zone.png")
const ACID_IMPACT := preload("res://art/vfx/v2/pixelfx/acid_impact.png")
const ACID_ZONE := preload("res://art/vfx/v2/pixelfx/acid_zone.png")
const MIST_ZONE := preload("res://art/vfx/v2/pixelfx/mist_zone.png")
const CRYSTAL_IMPACT := preload("res://art/vfx/v2/pixelfx/crystal_impact.png")
const OBSIDIAN_IMPACT := preload("res://art/vfx/v2/pixelfx/obsidian_impact.png")
const NEEDLE_FLIGHT := preload("res://art/vfx/v2/pixelfx/needle_flight.png")
const MITHRIL_ORBIT := preload("res://art/vfx/v2/pixelfx/mithril_orbit.png")
const CORROSIVE_MIST := preload("res://art/vfx/v2/pixelfx/corrosive_mist.png")
const CRYSTAL_SHATTER := preload("res://art/vfx/v2/pixelfx/crystal_shatter.png")
const SOULBOUND_FLIGHT := preload("res://art/vfx/v2/pixelfx/soulbound_flight.png")
const SOULBOUND_IMPACT := preload("res://art/vfx/v2/pixelfx/soulbound_impact.png")
const SPIRIT_GEL_FLIGHT := preload("res://art/vfx/v2/spirit_gel/spirit_gel_flight_24f.png")
const SPIRIT_GEL_IMPACT := preload("res://art/vfx/v2/spirit_gel/spirit_gel_impact_24f.png")
const ATLAS_COLUMNS := 8
const ATLAS_ROWS := 3
const ATLAS_FRAMES := ATLAS_COLUMNS * ATLAS_ROWS
const SPIRIT_GEL_IMPACT_FPS := 45.0
const WORLD_SCALE := 0.01
const FLOOR_Y := 0.055
const ZONE_FADE_DURATION := 0.45
const BREAK_DURATION := 0.36
const SHARD_CONTACT_DURATION := 0.25
const MARK_COLOR := Color("#ffc171")

enum Ground { RIPPLE, POOL, VORTEX, ORBIT, MIST, ACID }

static var box_mesh := BoxMesh.new()
static var shard_mesh := PrismMesh.new()
static var surface_materials: Dictionary[String, StandardMaterial3D] = {}
static var atlas_crops: Dictionary[String, AtlasTexture] = {}
static var fallback_animations: Dictionary[Texture2D, SpriteFrames] = {}
static var mark_textures: Dictionary[int, ImageTexture] = {}
static var shard_texture: ImageTexture

var state: Dictionary = {}
var skill_id := ""
var event_name := ""
var split_side := 0
var age := 0.0
var zone_fade_left := ZONE_FADE_DURATION
var lifetime := 0.0
var world_radius := 0.6
var launch_point := Vector2.ZERO
var heading := Vector2.RIGHT
var body: Node3D
var body_card: Sprite3D
var impact_card: Sprite3D
var library_card: Sprite3D
var zone_duration := 0.0
var zone_card_foot := 0.0
var floor_mat: ShaderMaterial
var orbiters: Array[MeshInstance3D] = []

func start(info: Dictionary) -> void:
	skill_id = String(info.get("skill_id", ""))
	event_name = String(info.get("event", ""))
	launch_point = info.get("from", Vector2.ZERO)
	var target: Vector2 = info.get("target", launch_point)
	state = info.get("state", info.get("projectile", {}))
	split_side = int(info.get("split_side", state.get("split_side", 0)))
	if split_side != 0:
		set_meta("split_side", split_side)
	heading = state.get("direction", launch_point.direction_to(target))
	if heading.is_zero_approx():
		heading = Vector2.RIGHT
	world_radius = maxf(float(state.get("radius", info.get("radius", 0.0))) * WORLD_SCALE, 0.42)
	position = _world_at(target)
	match event_name:
		"flight", "shard_flight":
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
		"mark_start":
			if state.is_empty():
				queue_free()
				return
			lifetime = -1.0
			_make_mark()
		"mark_break":
			_mark_break()
		"shard_impact":
			_shard_impact()
		"impact":
			_impact()
		"zone_tick":
			_zone_tick()
		"hop":
			_hop(target, launch_point)
	if is_zero_approx(lifetime):
		queue_free()
	elif split_side != 0:
		_add_split_accent(split_side)
	elif event_name == "mark_break" and state.get("split_merged", false):
		_add_split_accent(-1)
		_add_split_accent(1)

func _add_split_accent(side: int) -> void:
	match event_name:
		"flight":
			var accent := SPLIT_ALCHEMY_FX.new()
			body.add_child(accent)
			var trailing := skill_id != "sk_corrosive_flask" and skill_id != "sk_mist_flask"
			accent.start_follow(side, false, trailing)
		"impact", "zone_start", "mark_break":
			var accent := SPLIT_ALCHEMY_FX.new()
			add_child(accent)
			var camera := _world_camera()
			if camera:
				accent.position = camera.global_basis.z.slide(Vector3.UP).normalized() * 0.14
			var height := 0.20 if event_name == "zone_start" else 0.37
			if event_name == "mark_break":
				height = _mark_height(state)
			accent.start_mark(side, heading, height, 0.42)

func _process(delta: float) -> void:
	age += delta
	if lifetime >= 0.0 and age >= lifetime:
		queue_free()
		return
	if lifetime < 0.0 and state.get("finished", false):
		if event_name != "zone_start":
			queue_free()
			return
		zone_fade_left = maxf(0.0, zone_fade_left - delta)
		if is_zero_approx(zone_fade_left):
			queue_free()
			return
	match event_name:
		"flight", "shard_flight":
			_move_flight()
		"zone_start":
			position = _world_at(state.get("pos", Vector2.ZERO))
			_update_zone()
		"mark_start":
			_move_mark()
	if impact_card:
		impact_card.frame = mini(floori(age * SPIRIT_GEL_IMPACT_FPS), ATLAS_FRAMES - 1)
		impact_card.modulate.a = 1.0 - smoothstep(0.34, lifetime, age)
	if library_card and lifetime > 0.0:
		library_card.frame = mini(floori(age / lifetime * ATLAS_FRAMES), ATLAS_FRAMES - 1)
		library_card.modulate.a = 1.0 - smoothstep(lifetime * 0.66, lifetime, age)
	if floor_mat and event_name != "zone_start":
		var progress := clampf(age / maxf(lifetime * 0.68, 0.06), 0.0, 1.0)
		floor_mat.set_shader_parameter("wave_radius", lerpf(0.13, 0.92, 1.0 - pow(1.0 - progress, 2.0)))
		floor_mat.set_shader_parameter("age", age)
		floor_mat.set_shader_parameter("strength", 1.0 - smoothstep(0.10, 1.0, progress))

func _make_flight() -> void:
	body = Node3D.new()
	add_child(body)
	match skill_id:
		"link_blast_mark":
			body_card = _card(_mark_shard_texture(), body, 0.018, Color.WHITE)
			_streak(body, Vector3(-0.32, 0.0, 0.0), Vector3(-0.06, 0.0, 0.0), 0.013, Color("#ff914b"))
			SKILL_LIGHT.add(body, Vector3(-0.048, 0.0, 0.0), 0.24, Color(MARK_COLOR, 0.40))
		"sk_mithril_drop":
			library_card = _library_sprite(MITHRIL_FLIGHT, body, 0.023)
		"sk_gravity_stone":
			library_card = _library_sprite(GRAVITY_FLIGHT, body, 0.0067)
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
			body_card = _card(SPIRIT_GEL_FLIGHT, body, 0.010, Color.WHITE)
			body_card.hframes = 8
			body_card.vframes = 3
			body_card.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		"sk_soul_needle":
			library_card = _library_sprite(NEEDLE_FLIGHT, body, 0.012)
		"link_soulbound_needle":
			library_card = _library_sprite(SOULBOUND_FLIGHT, body, 0.012)

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
	elif skill_id == "sk_spirit_gel":
		body_card.frame = floori(age * 36.0) % ATLAS_FRAMES
	elif skill_id == "link_blast_mark":
		var camera := _world_camera()
		if camera:
			var center := body_card.global_position
			var ahead := center + _world_at(heading * 36.0)
			var projected := camera.unproject_position(ahead) - camera.unproject_position(center)
			body_card.global_basis = camera.global_basis * Basis(Vector3.BACK, -projected.angle())
	elif body_card:
		body_card.rotation.y = -body.rotation.y
	if library_card:
		library_card.frame = floori(age * 32.0) % ATLAS_FRAMES
		if skill_id == "sk_soul_needle" or skill_id == "link_soulbound_needle":
			var camera := _world_camera()
			if camera:
				var center := library_card.global_position
				var ahead := center + _world_at(heading * 36.0)
				var projected := camera.unproject_position(ahead) - camera.unproject_position(center)
				library_card.billboard = BaseMaterial3D.BILLBOARD_DISABLED
				library_card.global_basis = camera.global_basis * Basis(Vector3.BACK, -projected.angle())

func _make_zone() -> void:
	zone_duration = maxf(float(state.get("left", 1.0)), 0.1)
	match skill_id:
		"sk_gravity_stone":
			_ground(world_radius, Ground.VORTEX, Color("#291d3e"), Color("#9e5ad1"))
			_make_library_zone(GRAVITY_ZONE, 1.66, true)
		"sk_corrosive_flask":
			_ground(world_radius, Ground.ACID, Color("#252f13"), Color("#bbcf4b"))
			_make_library_zone(ACID_ZONE, 2.0, false, 22.0)
		"sk_mist_flask":
			_ground(world_radius, Ground.MIST, Color("#626478"), Color("#b7bfdf"))
			_make_library_zone(MIST_ZONE, 2.12, true, 0.0)
		"link_mithril_orbit":
			_ground(world_radius, Ground.ORBIT, Color("#67778f"), Color("#d2e9fa"))
			_make_library_zone(MITHRIL_ORBIT, 1.80, true)
			_make_orbiters(4, Color("#eaf4ff"))
		"link_corrosive_mist":
			_ground(world_radius, Ground.MIST, Color("#484559"), Color("#768b36"))
			_make_library_zone(CORROSIVE_MIST, 2.0, true, 0.0)
	_update_zone()

func _is_mist_zone() -> bool:
	return skill_id == "sk_mist_flask" or skill_id == "link_corrosive_mist"

func _update_zone() -> void:
	if not floor_mat:
		return
	var fade := smoothstep(0.0, 0.22, age) * (zone_fade_left / ZONE_FADE_DURATION)
	floor_mat.set_shader_parameter("age", age)
	floor_mat.set_shader_parameter("strength", fade * 0.53)
	if library_card:
		var card_alpha := 0.86
		if skill_id == "sk_mist_flask":
			card_alpha = 0.40
		elif skill_id == "link_corrosive_mist":
			card_alpha = 0.45
		library_card.modulate.a = fade * card_alpha
		if zone_card_foot > 0.0:
			var camera := _world_camera()
			var upright := camera.global_basis.y.y if camera else 0.72
			library_card.position.y = FLOOR_Y + zone_card_foot * library_card.pixel_size * upright
		if skill_id == "sk_mist_flask":
			library_card.frame = mini(floori(age / zone_duration * ATLAS_FRAMES), ATLAS_FRAMES - 1)
		else:
			library_card.frame = floori(age * 15.0) % ATLAS_FRAMES
	for i in orbiters.size():
		var angle := i * TAU / orbiters.size() + age * 2.1
		var orbit := 0.65 + sin(age * 1.4 + i) * 0.10
		var elevation := 0.13 + cos(age * 3.1 + i * 1.9) * 0.04
		var radius := world_radius * orbit
		orbiters[i].position = Vector3(cos(angle) * radius, elevation, sin(angle) * radius)
		orbiters[i].rotation.y = -angle
		orbiters[i].scale = Vector3.ONE * (0.053 * maxf(fade, 0.01))

func _make_orbiters(count: int, tint: Color) -> void:
	for i in count:
		var stone := _piece(self, Vector3.ZERO, Vector3.ONE * 0.01, tint, true, true)
		orbiters.append(stone)

func _make_mark() -> void:
	body = Node3D.new()
	add_child(body)
	var merged: bool = state.get("split_merged", false)
	body_card = _card(_brittle_texture(split_side, merged), body, 0.028 if merged else 0.024, Color.WHITE)
	body_card.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	SKILL_LIGHT.add(body, Vector3.ZERO, 0.39, Color(MARK_COLOR, 0.62), 0.24, 0.30)
	_move_mark()

func _move_mark() -> void:
	position = _world_at(state.get("pos", launch_point))
	body.position = Vector3.UP * _mark_height(state)
	var camera := _world_camera()
	if camera:
		body.position += camera.global_basis.z.slide(Vector3.UP).normalized() * 0.27
	var remaining := float(state.get("left", 1.0))
	body_card.modulate.a = (0.86 + 0.14 * cos(age * TAU * 1.8)) * minf(remaining * 7.0, 1.0)

func _mark_break() -> void:
	_library_burst(BRITTLE_SHATTER, BREAK_DURATION, 0.0067, _mark_height(state))
	# 源图集的碎裂重心偏右，把炸开的中心对准敌人身上的刻印。
	library_card.offset.x = -27.0
	library_card.modulate = _mark_tint(split_side)
	SKILL_LIGHT.add(self, Vector3.UP * (_mark_height(state) + 0.035), 0.49, Color(MARK_COLOR, 0.67), 0.16, 0.42)

func _shard_impact() -> void:
	_library_burst(BLAST_MARK_CONTACT, SHARD_CONTACT_DURATION, 0.0058, 0.31, true)
	SKILL_LIGHT.add(self, Vector3.UP * 0.31, 0.34, Color("#ff9f55"), 0.12)

func _impact() -> void:
	lifetime = 0.37
	match skill_id:
		"sk_mithril_drop":
			_library_burst(MITHRIL_IMPACT, 0.34, 0.010, 0.25, true)
		"sk_gravity_stone":
			SKILL_LIGHT.add(self, Vector3(0.0, 0.16, 0.04), 0.40, Color("#ab72ca"), 0.17, 0.14)
		"sk_corrosive_flask":
			_library_burst(ACID_IMPACT, 0.49, 0.012, 0.18)
		"sk_mist_flask":
			SKILL_LIGHT.add(self, Vector3(0.0, 0.14, 0.04), 0.35, Color(0.57, 0.69, 1.0, 0.45), 0.19)
		"sk_crystal_growth":
			_library_burst(CRYSTAL_IMPACT, 0.54, 0.014, 0.27, true)
		"sk_obsidian_blade":
			_library_burst(OBSIDIAN_IMPACT, 0.32, 0.0085, 0.32, true)
		"sk_spirit_gel":
			_spirit_gel_impact()
		"sk_soul_needle":
			lifetime = 0.21
			_needle_glint(Color("#b5efe4"), 0.22)
		"link_crystal_shatter_blade":
			_library_burst(CRYSTAL_SHATTER, 0.60, 0.012, 0.25, true)
		"link_soulbound_needle":
			_library_burst(SOULBOUND_IMPACT, 0.40, 0.009, 0.28, true)

func _spirit_gel_impact() -> void:
	lifetime = ATLAS_FRAMES / SPIRIT_GEL_IMPACT_FPS
	impact_card = _card(SPIRIT_GEL_IMPACT, self, 0.010, Color.WHITE)
	impact_card.hframes = 8
	impact_card.vframes = 3
	impact_card.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	impact_card.position.y = 0.31
	var camera := _world_camera()
	if camera:
		var toward_camera := camera.global_basis.z.slide(Vector3.UP).normalized()
		impact_card.position += toward_camera * 0.13

func _library_sprite(texture: Texture2D, parent: Node3D, pixel: float) -> Sprite3D:
	var card := _card(texture, parent, pixel, Color.WHITE)
	card.hframes = ATLAS_COLUMNS
	card.vframes = ATLAS_ROWS
	card.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	return card

func _library_burst(texture: Texture2D, duration: float, pixel: float, height: float, directional := false) -> void:
	lifetime = duration
	library_card = _library_sprite(texture, self, pixel)
	library_card.position.y = height
	var camera := _world_camera()
	if camera:
		var toward_camera := camera.global_basis.z.slide(Vector3.UP).normalized()
		library_card.position += toward_camera * 0.13
		library_card.flip_h = directional and camera.global_basis.x.dot(_world_at(heading)) < 0.0

func _world_camera() -> Camera3D:
	var viewport := get_viewport()
	return viewport.get_camera_3d() if viewport else null

func _make_library_zone(texture: Texture2D, extent: float, flat: bool, foot := 0.0) -> void:
	var frame_width := float(texture.get_width()) / ATLAS_COLUMNS
	library_card = _library_sprite(texture, self, world_radius * extent / frame_width)
	library_card.position.y = 0.024 if _is_mist_zone() else FLOOR_Y + 0.008
	if split_side != 0:
		library_card.modulate = Color.WHITE.lerp(SPLIT_ALCHEMY_FX.branch_color(split_side), 0.24)
	# A tilted camera projects sprite pixels down toward the terrain. Keep the source
	# baseline above the ground so the fog retains its soft lower edge at every pitch.
	zone_card_foot = foot + 4.0 if not flat else 0.0
	if flat:
		library_card.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		library_card.rotation_degrees.x = -90.0
		if skill_id == "sk_gravity_stone":
			library_card.scale.y = 1.34

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
	var metallic := skill_id == "sk_mithril_drop"
	var tint := Color("#c9e6f4") if metallic else Color("#9969b0")
	if split_side != 0:
		tint = tint.lerp(SPLIT_ALCHEMY_FX.branch_color(split_side), 0.57)
	var previous := _world_at(from - target) + Vector3.UP * 0.27
	var end := Vector3.UP * 0.27
	var sideways := Vector3.UP.cross(previous.direction_to(end))
	var joint := previous.lerp(end, 0.45) + sideways * (0.075 if metallic else 0.0)
	for segment in [[previous, joint], [joint, end]]:
		var trace := _streak(self, segment[0], segment[1], 0.026, tint)
		create_tween().tween_property(trace, "scale", Vector3.ZERO, 0.16)
	SKILL_LIGHT.add(self, end + Vector3.BACK * 0.07, 0.43, Color(tint, 0.92), 0.16, 0.65)

func _needle_glint(tint: Color, size: float) -> void:
	var at := Vector3.UP * 0.28
	SKILL_LIGHT.add(self, at + Vector3.BACK * 0.08, size * 1.85, Color(tint, 0.8), 0.14, 0.62)
	for axis in [Vector3.RIGHT, Vector3.UP]:
		var line := _streak(self, at - axis * size * 0.5, at + axis * size * 0.5, 0.022, tint)
		create_tween().tween_property(line, "scale", Vector3.ZERO, 0.18)

func _ground(radius: float, kind: Ground, tint: Color, accent: Color) -> void:
	floor_mat = ShaderMaterial.new()
	floor_mat.shader = GROUND_SHADER
	floor_mat.set_shader_parameter("pattern", kind)
	floor_mat.set_shader_parameter("tint", tint)
	var edge := accent
	if split_side != 0:
		edge = edge.lerp(SPLIT_ALCHEMY_FX.branch_color(split_side), 0.52)
	floor_mat.set_shader_parameter("accent", edge)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * radius * 2.0
	var disc := MeshInstance3D.new()
	disc.mesh = quad
	disc.material_override = floor_mat
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disc.position.y = 0.018 if _is_mist_zone() else FLOOR_Y
	disc.rotation_degrees.x = -90.0
	add_child(disc)

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

static func _mark_tint(side: int) -> Color:
	if side == 0:
		return Color.WHITE
	return Color.WHITE.lerp(SPLIT_ALCHEMY_FX.branch_color(side), 0.55)

static func _mark_height(mark: Dictionary) -> float:
	var victim: Dictionary = mark.get("target", {})
	return 0.55 if victim.get("boss", false) else 0.43

static func _brittle_texture(side: int, merged: bool) -> ImageTexture:
	var palette := 2 if merged else side
	if not mark_textures.has(palette):
		mark_textures[palette] = _mark_pixel_texture([
		"...............",
		"..........a....",
		"....a....ag....",
		".....o..og.....",
		".....go.og.....",
		"......gog..a...",
		"..ao...cgao....",
		"...gogccgo.....",
		"....agcg.......",
		".....gogog.....",
		"....og..oggo...",
		"....ga....ao...",
		"...a...........",
		"...............",
		"...............",
		], palette)
	return mark_textures[palette]

static func _mark_shard_texture() -> ImageTexture:
	if not shard_texture:
		shard_texture = _mark_pixel_texture([
		".................",
		".............ao..",
		"...a......oogga..",
		"....agggogggcgo..",
		"aagggccgccccggga.",
		"....agggocgggga..",
		"......aa..oggo...",
		"............a....",
		".................",
		])
	return shard_texture

static func _mark_colors(side: int) -> Dictionary:
	if side == 0:
		return {"o": Color("#663121"), "a": Color("#a65b37"), "g": MARK_COLOR, "c": Color("#fff1c3")}
	var tint := SPLIT_ALCHEMY_FX.branch_color(side)
	return {"o": tint.darkened(.64), "a": tint.darkened(.34), "g": tint, "c": tint.lerp(Color.WHITE, .68)}

static func _mark_pixel_texture(rows: PackedStringArray, palette := 0) -> ImageTexture:
	var width := rows[0].length()
	var image := Image.create_empty(width, rows.size(), false, Image.FORMAT_RGBA8)
	var left_colors := _mark_colors(-1 if palette == 2 else palette)
	var right_colors := _mark_colors(1) if palette == 2 else left_colors
	for y in rows.size():
		for x in width:
			var pixel := rows[y][x]
			var colors := left_colors if x * 2 < width else right_colors
			if colors.has(pixel):
				image.set_pixel(x, y, colors[pixel])
	return ImageTexture.create_from_image(image)

## Shares the mark and shard art with the HD view. Returns only nodes bound to a live state.
static func start_fallback(parent: Node2D, info: Dictionary) -> Node2D:
	var event := String(info.get("event", ""))
	var live_state: Dictionary = info.get("state", {})
	var side := int(info.get("split_side", live_state.get("split_side", 0)))
	if event == "mark_start" or event == "shard_flight":
		if live_state.is_empty():
			return null
		var sprite := Sprite2D.new()
		var merged: bool = live_state.get("split_merged", false)
		sprite.texture = _brittle_texture(side, merged) if event == "mark_start" else _mark_shard_texture()
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.scale = Vector2.ONE * (1.85 if merged else (1.6 if event == "mark_start" else 1.35))
		parent.add_child(sprite)
		update_fallback(sprite, live_state)
		return sprite
	var burst := AnimatedSprite2D.new()
	burst.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	burst.modulate = _mark_tint(side)
	var target: Vector2 = info.get("target", Vector2.ZERO)
	if event == "mark_break":
		burst.sprite_frames = _fallback_frames(BRITTLE_SHATTER, BREAK_DURATION)
		burst.position = target + Vector2.UP * (_mark_height(live_state) / WORLD_SCALE)
		burst.offset.x = -27.0
		burst.scale = Vector2.ONE * 0.52
	else:
		burst.sprite_frames = _fallback_frames(BLAST_MARK_CONTACT, SHARD_CONTACT_DURATION)
		burst.position = target + Vector2.UP * 31.0
		burst.scale = Vector2.ONE * 0.53
		var direction: Vector2 = live_state.get("direction", Vector2.RIGHT)
		burst.rotation = direction.angle()
	parent.add_child(burst)
	burst.animation_finished.connect(burst.queue_free, CONNECT_ONE_SHOT)
	burst.play()
	return null

static func update_fallback(node: Node2D, live_state: Dictionary) -> void:
	var at: Vector2 = live_state.get("pos", Vector2.ZERO)
	if live_state.get("kind", "") == "brittle_mark":
		node.position = at + Vector2.UP * (_mark_height(live_state) / WORLD_SCALE)
		node.modulate.a = minf(float(live_state.get("left", 1.0)) * 7.0, 1.0)
	else:
		node.position = at + Vector2.UP * 31.0
		var direction: Vector2 = live_state.get("direction", Vector2.RIGHT)
		node.rotation = direction.angle()

static func _fallback_frames(texture: Texture2D, duration: float) -> SpriteFrames:
	if not fallback_animations.has(texture):
		var animation := SpriteFrames.new()
		animation.set_animation_speed(&"default", ATLAS_FRAMES / duration)
		animation.set_animation_loop(&"default", false)
		var cell := texture.get_size() / Vector2(ATLAS_COLUMNS, ATLAS_ROWS)
		for frame in ATLAS_FRAMES:
			var origin := Vector2(frame % ATLAS_COLUMNS, floori(float(frame) / ATLAS_COLUMNS)) * cell
			animation.add_frame(&"default", _crop(texture, Rect2(origin, cell)))
		fallback_animations[texture] = animation
	return fallback_animations[texture]

static func _world_at(point: Vector2) -> Vector3:
	return Vector3(point.x, 0.0, point.y) * WORLD_SCALE

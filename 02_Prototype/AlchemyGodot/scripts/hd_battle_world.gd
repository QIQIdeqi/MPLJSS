extends "res://scripts/hd_outdoor_rig.gd"

enum ViewAngle { LOW, MID, OVERHEAD }

const LANDSCAPE := preload("res://scripts/hd_battle_landscape.gd")
const COIN_SHADER := preload("res://shaders/hd_battle_coin.gdshader")
const PORTAL_LIGHT := preload("res://shaders/hd_battle_portal_light.gdshader")
const BOUNDARY_SHADER := preload("res://shaders/hd_battle_boundary.gdshader")
const GLOW := preload("res://scenes/fx/glow.tres")
const UNITS_PER_PIXEL := 0.01
const SOURCE_HIDDEN_LAYER := 4

var field
var landscape: LANDSCAPE
var actor_cards: Dictionary[int, Sprite3D] = {}
var raised_hits: Array[Node2D] = []
var attack_effects := Node3D.new()
var particle_mesh: QuadMesh
var battle_focus := Vector3.ZERO
var view_angle := ViewAngle.MID
var boundary: MeshInstance3D
var boundary_bounds := Rect2()

static func world_at(point: Vector2) -> Vector3:
	return Vector3(point.x, 0.0, point.y) * UNITS_PER_PIXEL

func setup(source: Node2D, canvas_texture: Texture2D) -> void:
	field = source
	environment_setup("BattleWeather")
	lens.dof_blur_amount = 0.115
	lens.dof_blur_near_transition = 1.1
	lens.dof_blur_far_transition = 1.65
	landscape = LANDSCAPE.new()
	add_child(landscape)
	add_child(attack_effects)
	rebuild()
	var overlay := MeshInstance3D.new()
	overlay.name = "GroundEffects"
	var quad := QuadMesh.new()
	quad.size = field.MAP.size * UNITS_PER_PIXEL
	var material := StandardMaterial3D.new()
	material.albedo_texture = canvas_texture
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.blend_mode = BaseMaterial3D.BLEND_MODE_PREMULT_ALPHA
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.disable_fog = true
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	quad.material = material
	overlay.mesh = quad
	overlay.rotation_degrees.x = -90.0
	overlay.position = world_at(field.MAP.get_center()) + Vector3.UP * 0.035
	overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(overlay)
	update_view(0.0)

func update_boundary(bounds: Rect2) -> void:
	if boundary and boundary_bounds == bounds:
		return
	if not boundary:
		boundary = MeshInstance3D.new()
		boundary.name = "BattleBoundary"
		boundary.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := ShaderMaterial.new()
		material.shader = BOUNDARY_SHADER
		boundary.material_override = material
		add_child(boundary)
	boundary_bounds = bounds
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var offsets := PackedFloat32Array([-3.2, -0.8, 0.8, 3.2])
	var opacity := PackedFloat32Array([0.0, 1.0, 1.0, 0.0])
	var perimeter := (bounds.size.x + bounds.size.y) * 2.0
	for band in offsets.size() - 1:
		var inner := boundary_corners(bounds.grow(offsets[band]))
		var outer := boundary_corners(bounds.grow(offsets[band + 1]))
		var distance := 0.0
		for side in 4:
			var next := (side + 1) % 4
			var side_length := bounds.size.x if side % 2 == 0 else bounds.size.y
			var vertices := [inner[side], outer[side], outer[next], inner[side], outer[next], inner[next]]
			for i in vertices.size():
				var alpha := opacity[band] if i == 0 or i == 3 or i == 5 else opacity[band + 1]
				var at_end := i == 2 or i == 4 or i == 5
				surface.set_color(Color(1.0, 1.0, 1.0, alpha))
				surface.set_uv(Vector2((distance + (side_length if at_end else 0.0)) / perimeter, 0.0))
				surface.add_vertex(world_at(vertices[i]) + Vector3.UP * 0.024)
			distance += side_length
	boundary.mesh = surface.commit()

func boundary_corners(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y),
		rect.end, Vector2(rect.position.x, rect.end.y)])

func rebuild() -> void:
	for effect in attack_effects.get_children():
		effect.queue_free()
	raised_hits.clear()
	for prop in field.props:
		prop.visibility_layer = SOURCE_HIDDEN_LAYER
	landscape.rebuild(field.tiles, field.props, field.MAP)
	update_boundary(field.player.movement_bounds)

func screen_at(point: Vector2) -> Vector2:
	return camera.unproject_position(world_at(point))

func cycle_view_angle() -> void:
	view_angle = ((int(view_angle) + 1) % ViewAngle.size()) as ViewAngle

func update_view(delta: float) -> void:
	var player_at := world_at(field.player.position)
	var player_focus := player_at + Vector3.UP * 0.39
	var boss_focus := player_focus
	var goal := player_focus
	var distance_scale := 1.0
	if is_instance_valid(field.boss) and is_instance_valid(field.boss.body) and not field.ended:
		var boss_at := world_at(field.boss.body.position)
		var spacing := player_at.distance_to(boss_at)
		if field.boss.preparation > 0.0 or spacing < 3.2:
			boss_focus = boss_at + Vector3.UP * 0.48
			goal = (player_at + boss_at) * 0.5 + Vector3.UP * 0.43
			distance_scale += clampf((spacing - 1.8) * 0.13, 0.0, 0.42)
	var weight := 1.0 if delta <= 0.0 else 1.0 - exp(-7.0 * delta)
	battle_focus = battle_focus.lerp(goal, weight)
	var angle_blend := float(view_angle) / float(ViewAngle.OVERHEAD)
	camera_offset = camera_offset.lerp(STREET_OFFSET.lerp(OVERVIEW_OFFSET, angle_blend) * distance_scale, weight)
	camera.position = battle_focus + camera_offset
	camera.fov = lerpf(camera.fov, lerpf(47.0, 43.0, angle_blend), weight)
	camera.look_at(battle_focus)
	var player_depth := -camera.to_local(player_focus).z
	var boss_depth := -camera.to_local(boss_focus).z
	lens.dof_blur_near_distance = maxf(camera.near, minf(player_depth, boss_depth) - 0.9)
	lens.dof_blur_far_distance = maxf(player_depth, boss_depth) + 1.2
	if not field.ended and not field.brew.blocks_world() and not field.portal_dialog.visible:
		weather.advance(delta, player_at)
		update_time_of_day(delta)
	landscape.set_snow_cover(weather.snow_cover)
	fade_foreground(landscape.foreground_cards, player_at, 0.64, delta)
	# The wider combat area and moving enemies need a higher floor for night lighting.
	atmosphere.ambient_light_energy = maxf(0.34, atmosphere.ambient_light_energy)
	sun.light_energy = maxf(0.19, sun.light_energy)
	update_actor_cards()

func update_actor_cards() -> void:
	var live: Dictionary[int, bool] = {}
	update_card(field.player.art, field.player.position, live)
	for entry in field.enemies:
		if not is_instance_valid(entry.body) or entry.body.is_queued_for_deletion():
			continue
		var source: Sprite2D = field.boss.art if entry.boss else entry.body.art
		update_enemy_card(source, entry.body.position, live)
	for body: Node2D in field.defeated_art:
		if not body.is_queued_for_deletion():
			update_enemy_card(field.defeated_art[body], body.position, live)
	for pickup in field.pickups:
		var source: Sprite2D = pickup.sprite
		if is_instance_valid(source) and not source.is_queued_for_deletion():
			var is_new := not actor_cards.has(source.get_instance_id())
			var card := update_card(source, source.position, live, true)
			var bob := -source.offset.y / source.texture.get_height() - 0.35
			card.offset.y = source.texture.get_height() * 0.5
			card.position.y = 0.07 + bob * 0.27
			if is_new and pickup.kind == 0:
				var sweep := ShaderMaterial.new()
				sweep.shader = COIN_SHADER
				sweep.set_shader_parameter("coin", source.texture)
				sweep.set_shader_parameter("offset_phase", fposmod(source.position.dot(Vector2(0.007, 0.011)), 1.0))
				card.material_override = sweep
			elif is_new and is_instance_valid(pickup.motes):
				var motes := add_particles(card, pickup.motes.color_ramp)
				motes.top_level = true
				motes.position = card.position + Vector3.UP * 0.1
				motes.amount = 9
				motes.lifetime = 0.68
				motes.direction = Vector3.UP
				motes.spread = 27.0
				motes.gravity = Vector3.UP * 0.18
				motes.initial_velocity_min = 0.2
				motes.initial_velocity_max = 0.45
				motes.emitting = true
				pickup.motes.visibility_layer = SOURCE_HIDDEN_LAYER
	for i in range(raised_hits.size() - 1, -1, -1):
		var hit: Node2D = raised_hits[i]
		if not is_instance_valid(hit) or hit.is_queued_for_deletion():
			raised_hits.remove_at(i)
			continue
		update_effect_cards(hit, live, 0.19)
	if is_instance_valid(field.portal):
		update_effect_cards(field.portal, live, 0.0)
	for id in actor_cards.keys():
		if not live.has(id):
			actor_cards[id].queue_free()
			actor_cards.erase(id)

func update_enemy_card(source: Sprite2D, at: Vector2, live: Dictionary[int, bool]) -> void:
	var card := update_card(source, at, live)
	if card:
		card.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS if source.modulate.a < 0.999 else SpriteBase3D.ALPHA_CUT_DISCARD

func update_effect_cards(effect: Node2D, live: Dictionary[int, bool], height: float) -> void:
	for i in effect.cards.size():
		var card := update_card(effect.cards[i], effect.global_position, live, true)
		if not card:
			continue
		card.position.y = height
		card.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		card.render_priority = i
		if not card.material_override and card.texture.resource_path.ends_with("Light.png"):
			var light := ShaderMaterial.new()
			light.shader = PORTAL_LIGHT
			light.set_shader_parameter("light_atlas", card.texture)
			light.render_priority = i
			card.material_override = light

func raise_attack(impact: Node2D, from: Vector2, at: Vector2, tint: Color) -> void:
	for source in impact.cards:
		source.visibility_layer = SOURCE_HIDDEN_LAYER
	raised_hits.append(impact)
	var fade := Gradient.new()
	fade.colors = PackedColorArray([tint, Color(tint, 0.0)])
	var trail := add_particles(attack_effects, fade)
	trail.position = world_at(from) + Vector3.UP * 0.34
	trail.amount = 14
	trail.lifetime = 0.25
	trail.spread = 180.0
	trail.initial_velocity_min = 0.06
	trail.initial_velocity_max = 0.26
	trail.emitting = true
	var travel := trail.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	travel.tween_property(trail, "position", world_at(at) + Vector3.UP * 0.24, 0.18)
	travel.tween_callback(trail.set_emitting.bind(false))
	travel.tween_interval(trail.lifetime)
	travel.tween_callback(trail.queue_free)

func add_particles(parent: Node3D, fade: Gradient) -> CPUParticles3D:
	if not particle_mesh:
		var glow := StandardMaterial3D.new()
		glow.albedo_texture = GLOW
		glow.vertex_color_use_as_albedo = true
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glow.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		glow.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		particle_mesh = QuadMesh.new()
		particle_mesh.size = Vector2(0.11, 0.11)
		particle_mesh.material = glow
	var particles := CPUParticles3D.new()
	particles.emitting = false
	particles.gravity = Vector3.ZERO
	particles.local_coords = false
	particles.lifetime_randomness = 0.26
	particles.scale_amount_min = 0.42
	particles.scale_amount_max = 0.82
	particles.color_ramp = fade
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.mesh = particle_mesh
	parent.add_child(particles)
	return particles

func update_card(source: Sprite2D, at: Vector2, live: Dictionary[int, bool], pickup := false) -> Sprite3D:
	if not is_instance_valid(source) or not source.texture:
		return null
	var id := source.get_instance_id()
	live[id] = true
	var card := actor_cards.get(id) as Sprite3D
	if not card:
		card = Sprite3D.new()
		card.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		card.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		card.alpha_scissor_threshold = 0.35
		card.shaded = not pickup
		card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if pickup else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(card)
		actor_cards[id] = card
		source.visibility_layer = SOURCE_HIDDEN_LAYER
	card.position = world_at(at)
	# Sprite2D's positive Y points down. Keep each source frame anchored at its gameplay feet.
	var unit := maxf(absf(source.global_scale.y), 0.0001)
	card.pixel_size = unit * UNITS_PER_PIXEL
	card.scale.x = absf(source.global_scale.x) / unit
	card.rotation_degrees.x = -27.0
	card.offset = Vector2(source.offset.x, -source.offset.y - (source.global_position.y - at.y) / unit)
	card.centered = source.centered
	card.texture = source.texture
	card.hframes = source.hframes
	card.vframes = source.vframes
	card.region_enabled = source.region_enabled
	if source.region_enabled:
		card.region_rect = source.region_rect
	else:
		card.frame_coords = source.frame_coords
	card.flip_h = source.flip_h
	card.flip_v = source.flip_v
	card.modulate = source.modulate
	return card

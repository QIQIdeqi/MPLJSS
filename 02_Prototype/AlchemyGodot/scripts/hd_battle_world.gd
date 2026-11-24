extends "res://scripts/hd_outdoor_rig.gd"

enum ViewAngle { LOW, MID, OVERHEAD }

const LANDSCAPE := preload("res://scripts/hd_battle_landscape.gd")
const COIN_SHADER := preload("res://shaders/hd_battle_coin.gdshader")
const PORTAL_LIGHT := preload("res://shaders/hd_battle_portal_light.gdshader")
const BOUNDARY_SHADER := preload("res://shaders/hd_battle_boundary.gdshader")
const GLOW := preload("res://scenes/fx/glow.tres")
const ZONE_SHADER := preload("res://shaders/hd_skill_zone.gdshader")
const MONSTER_FLASH_SHADER := preload("res://shaders/monster_hit_flash_3d.gdshader")
const FIRE_SHEET := preload("res://art/vfx/generated/fire_projectile_24f_concept.png")
const ICE_SHEET := preload("res://art/vfx/generated/ice_ring_24f_concept.png")
const EARTH_SHEET := preload("res://art/vfx/generated/earth_strike_24f_concept.png")
const THUNDER_SHEET := preload("res://art/vfx/generated/thunder_strike_24f.png")
const WIND_SHEET := preload("res://art/vfx/generated/wind_blade_24f.png")
const CYCLONE_SHEET := preload("res://art/vfx/generated/cyclone_24f.png")
const BEAM_SHEET := preload("res://art/vfx/generated/arcane_beam_24f.png")
const EARTH_SPIKE_SHEET := preload("res://art/vfx/generated/earth_spike_24f.png")
const V2_BLAST_FLASK_SHEET := preload("res://art/vfx/v2/blast_flask_impact_24f.png")
const V2_CLAY_HOMUNCULUS_SHEET := preload("res://art/vfx/v2/clay_homunculus_summon_24f.png")
const V2_MITHRIL_DROP_SHEET := preload("res://art/vfx/v2/mithril_drop_impact_24f.png")
const V2_CRYSTAL_GROWTH_SHEET := preload("res://art/vfx/v2/crystal_growth_24f.png")
const V2_GRAVITY_STONE_SHEET := preload("res://art/vfx/v2/gravity_stone_impact_24f.png")
const V2_CORROSIVE_FLASK_SHEET := preload("res://art/vfx/v2/corrosive_flask_pool_24f.png")
const V2_MIST_FLASK_SHEET := preload("res://art/vfx/v2/mist_flask_cloud_24f.png")
const V2_OBSIDIAN_BLADE_SHEET := preload("res://art/vfx/v2/obsidian_blade_slash_24f.png")
const V2_SPIRIT_GEL_SHEET := preload("res://art/vfx/v2/spirit_gel_wave_24f.png")
const V2_SOUL_NEEDLE_SHEET := preload("res://art/vfx/v2/soul_needle_pierce_24f.png")
const V2_LINK_BLAST_HOMUNCULUS_SHEET := preload("res://art/vfx/v2/link_blast_homunculus_24f.png")
const V2_LINK_MITHRIL_ORBIT_SHEET := preload("res://art/vfx/v2/link_mithril_orbit_24f.png")
const V2_LINK_CORROSIVE_MIST_SHEET := preload("res://art/vfx/v2/link_corrosive_mist_24f.png")
const V2_LINK_CRYSTAL_SHATTER_BLADE_SHEET := preload("res://art/vfx/v2/link_crystal_shatter_blade_24f.png")
const V2_LINK_SOULBOUND_NEEDLE_SHEET := preload("res://art/vfx/v2/link_soulbound_needle_24f.png")
const UNITS_PER_PIXEL := 0.01
const SOURCE_HIDDEN_LAYER := 4
const GENERATED_FRAME := 256
const GENERATED_COLS := 6
const GENERATED_COUNT := 24

var field
var landscape: LANDSCAPE
var actor_cards: Dictionary[int, Sprite3D] = {}
var raised_hits: Array[Node2D] = []
var attack_effects := Node3D.new()
var particle_mesh: QuadMesh
var generated_frames: Dictionary = {}
var battle_focus := Vector3.ZERO
var view_angle := ViewAngle.MID
var boundary: MeshInstance3D
var boundary_bounds := Rect2()
var tracked_projectiles: Array[Dictionary] = []
var tracked_zones: Array[Dictionary] = []
var damage_numbers: Array[Label3D] = []

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

func clear_skill_fx() -> void:
	if not is_instance_valid(attack_effects):
		return
	for effect in attack_effects.get_children():
		effect.queue_free()
	raised_hits.clear()
	tracked_projectiles.clear()
	tracked_zones.clear()
	damage_numbers.clear()

func rebuild() -> void:
	clear_skill_fx()
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
	var advancing: bool = not field.ended and not field.brew.blocks_world() and not field.portal_dialog.visible
	_update_tracked_fx(delta if advancing else 0.0)

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
		if source.modulate.r > 1.5:
			var flash_material: ShaderMaterial = card.get_meta("hit_flash_material") if card.has_meta("hit_flash_material") else null
			if not flash_material:
				flash_material = ShaderMaterial.new()
				flash_material.shader = MONSTER_FLASH_SHADER
				card.set_meta("hit_flash_material", flash_material)
			flash_material.set_shader_parameter("sprite_texture", source.texture)
			flash_material.set_shader_parameter("opacity", source.modulate.a)
			card.material_override = flash_material
		elif card.material_override is ShaderMaterial and card.material_override.shader == MONSTER_FLASH_SHADER:
			card.material_override = null

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

# 技能系统的视觉桥接。技能伤害仍在 2D 逻辑层结算；这里仅在 HD 战斗
# 视图中呈现同一次施法，避免效果被地面捕获画布压暗或遮挡。
func show_skill_fx(info: Dictionary) -> void:
	var skill_id := String(info.get("skill_id", ""))
	var event_name := String(info.get("event", "cast"))
	var from: Vector2 = info.get("from", Vector2.ZERO)
	var target: Vector2 = info.get("target", from)
	var tint: Color = info.get("color", Color.WHITE)
	var radius := maxf(float(info.get("radius", 0.0)), 18.0)
	var state: Dictionary = info.get("state", {})
	if event_name == "cast" and state.get("kind", "") == "projectile":
		_track_projectile(state, tint)
		return
	if event_name == "impact" and state.get("kind", "") == "zone":
		_track_zone(state, tint)
	if event_name == "impact" and skill_id == "sk_soul_needle" and bool(state.get("combo", false)):
		var mark := _skill_sheet_24_128(target, V2_LINK_SOULBOUND_NEEDLE_SHEET, 108.0, 24.0)
		mark.frame = 4
		return
	# 五种固定连锁拥有自己的组合节奏，绝不复用基础技能的整段表现。
	match event_name:
		"link_blast_homunculus":
			_skill_sheet_24_128(target, V2_LINK_BLAST_HOMUNCULUS_SHEET, 132.0)
			return
		"link_mithril_orbit":
			_skill_sheet_24_128(target, V2_LINK_MITHRIL_ORBIT_SHEET, 152.0, 10.0)
			return
		"link_corrosive_mist":
			_skill_sheet_24_128(target, V2_LINK_CORROSIVE_MIST_SHEET, 168.0, 6.0)
			return
		"link_crystal_shatter_blade":
			_skill_sheet_24_128(target, V2_LINK_CRYSTAL_SHATTER_BLADE_SHEET, 142.0, 24.0)
			return
		"link_soulbound_needle":
			# Its three real projectiles launch on schedule; the dedicated mark plays on impact.
			return
	match skill_id:
		"sk_blast_flask":
			if event_name == "cast": _skill_travel(from, target, tint, .34, 19, .64)
			elif event_name == "impact": _skill_sheet_24_128(target, V2_BLAST_FLASK_SHEET, maxf(108.0, radius * 1.45))
			return
		"sk_clay_homunculus":
			if event_name == "cast":
				_skill_sheet_24_128(from, V2_CLAY_HOMUNCULUS_SHEET, 94.0)
			return
		"sk_mithril_drop":
			if event_name == "cast": _skill_travel(from, target, tint, .20, 12, .40)
			if event_name == "impact": _skill_sheet_24_128(target, V2_MITHRIL_DROP_SHEET, maxf(72.0, radius * .92))
			return
		"sk_gravity_stone":
			if event_name == "cast": _skill_travel(from, target, tint, .28, 14, .58)
			elif event_name == "impact": _skill_sheet_24_128(target, V2_GRAVITY_STONE_SHEET, maxf(116.0, radius * 1.05))
			return
		"sk_corrosive_flask":
			if event_name == "cast": _skill_travel(from, target, tint, .31, 15, .48)
			elif event_name == "impact": _skill_sheet_24_128(target, V2_CORROSIVE_FLASK_SHEET, maxf(112.0, radius * 1.10))
			return
		"sk_mist_flask":
			if event_name == "cast": _skill_travel(from, target, tint, .30, 12, .43)
			elif event_name == "impact": _skill_sheet_24_128(target, V2_MIST_FLASK_SHEET, maxf(112.0, radius * 1.22))
			return
		"sk_crystal_growth":
			_skill_sheet_24_128(target, V2_CRYSTAL_GROWTH_SHEET, 116.0)
			return
		"sk_obsidian_blade":
			_skill_sheet_24_128(from.lerp(target, .55), V2_OBSIDIAN_BLADE_SHEET, 88.0)
			return
		"sk_spirit_gel":
			if event_name == "cast": _skill_travel(from, target, tint, .28, 16, .56)
			elif event_name == "impact": _skill_sheet_24_128(target, V2_SPIRIT_GEL_SHEET, maxf(100.0, radius * 1.10))
			return
		"sk_soul_needle":
			if event_name == "cast": _skill_travel(from, target, tint, .10, 10, .31)
			elif event_name == "impact": _skill_sheet_24_128(target, V2_SOUL_NEEDLE_SHEET, 76.0)
			return
		"magic_bolt":
			# The shared projectile owns flight; successful damage owns the hit flash.
			return
		"fireball":
			_skill_sheet(from.lerp(target, 0.58), FIRE_SHEET, maxf(104.0, radius * 2.0))
			_skill_travel(from, target, tint, 0.36, 24, 0.80)
			_skill_burst(target, tint, 28, clampf(radius / 34.0, 0.72, 1.30))
		"ice_spike":
			_skill_sheet(target, ICE_SHEET, 108.0)
			_skill_travel(from, target, tint, 0.18, 20, 0.62)
			_skill_burst(target, tint, 18, 0.64)
		"thunder":
			_skill_sheet(target, THUNDER_SHEET, 116.0)
			_skill_strike(target, tint, 32, 0.90)
		"wind_blade":
			_skill_sheet(from.lerp(target, 0.56), WIND_SHEET, 76.0)
			_skill_travel(from, target, tint, 0.17, 18, 0.56)
			_skill_travel(target, from, tint, 0.17, 12, 0.44, 0.19)
		"cyclone":
			_skill_sheet(from, CYCLONE_SHEET, maxf(110.0, radius * 2.4))
			_skill_burst(from, tint, 30, clampf(radius / 24.0, 0.76, 1.16), 0.52)
		"poison_fog":
			_skill_burst(target, tint, 36, clampf(radius / 24.0, 0.86, 1.30), 0.86)
		"rockfall":
			_skill_sheet(target, EARTH_SHEET, maxf(112.0, radius * 2.1))
			_skill_strike(target, tint, 28, clampf(radius / 28.0, 0.76, 1.20))
		"beam":
			_skill_sheet(from.lerp(target, 0.62), BEAM_SHEET, 92.0)
			_skill_travel(from, target, tint, 0.08, 42, 0.42)
			_skill_burst(target, tint, 16, 0.54)
		"earth_spike":
			_skill_sheet(target, EARTH_SPIKE_SHEET, 112.0)
			_skill_strike(target, tint, 20, 0.66)
		_:
			if event_name == "cast":
				_skill_travel(from, target, tint, 0.24, 14, 0.48)

func _track_projectile(state: Dictionary, tint: Color) -> void:
	var node := Node3D.new()
	node.name = "SkillProjectile"
	attack_effects.add_child(node)
	node.position = world_at(state.pos) + Vector3.UP * 0.34
	var core := Sprite3D.new()
	core.texture = GLOW
	core.pixel_size = 18.0 * UNITS_PER_PIXEL / GLOW.get_width()
	core.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	core.shaded = false
	core.no_depth_test = true
	core.modulate = tint
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(core)
	var trail := add_particles(node, _skill_fade(tint))
	trail.amount = 10
	trail.lifetime = 0.16
	trail.spread = 180.0
	trail.initial_velocity_min = 0.02
	trail.initial_velocity_max = 0.08
	trail.scale_amount_min = 0.36
	trail.scale_amount_max = 0.62
	trail.emitting = true
	tracked_projectiles.append({"state": state, "node": node, "core": core, "particles": trail})

func _track_zone(state: Dictionary, tint: Color) -> void:
	var node := Node3D.new()
	node.name = "PersistentSkillZone"
	attack_effects.add_child(node)
	node.position = world_at(state.pos) + Vector3.UP * 0.055
	var radius := float(state.radius) * UNITS_PER_PIXEL
	var plane := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2.ONE * radius * 2.0
	var material := ShaderMaterial.new()
	material.shader = ZONE_SHADER
	material.set_shader_parameter("tint", tint)
	material.set_shader_parameter("opacity", 0.0)
	plane.mesh = mesh
	plane.material_override = material
	plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(plane)
	var fog := Gradient.new()
	fog.colors = PackedColorArray([Color(tint, 0.0), Color(tint, 0.20), Color(tint, 0.0)])
	fog.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	var particles := add_particles(node, fog)
	particles.amount = 14
	particles.lifetime = 0.9
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(radius * 0.6, 0.015, radius * 0.6)
	particles.position.y = 0.10
	particles.direction = Vector3.UP
	particles.spread = 60.0
	particles.initial_velocity_min = 0.03
	particles.initial_velocity_max = 0.12
	particles.scale_amount_min = 2.2
	particles.scale_amount_max = 4.0
	particles.emitting = true
	tracked_zones.append({"state": state, "node": node, "material": material,
		"particles": particles, "age": 0.0, "fade": 0.45})

func _update_tracked_fx(delta: float) -> void:
	for i in range(tracked_projectiles.size() - 1, -1, -1):
		var entry := tracked_projectiles[i]
		var state: Dictionary = entry.state
		if bool(state.get("finished", false)):
			entry.core.hide()
			entry.particles.emitting = false
			var clear: Tween = entry.node.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
			clear.tween_interval(0.18)
			clear.tween_callback(entry.node.queue_free)
			tracked_projectiles.remove_at(i)
			continue
		entry.node.position = world_at(state.pos) + Vector3.UP * 0.34
		entry.particles.speed_scale = 1.0 if delta > 0.0 else 0.0
	for i in range(tracked_zones.size() - 1, -1, -1):
		var entry := tracked_zones[i]
		var state: Dictionary = entry.state
		entry.age += delta
		entry.particles.speed_scale = 1.0 if delta > 0.0 else 0.0
		if bool(state.get("finished", false)):
			entry.fade -= delta
			entry.particles.emitting = false
			if entry.fade <= 0.0:
				entry.node.queue_free()
				tracked_zones.remove_at(i)
				continue
		entry.node.position = world_at(state.pos) + Vector3.UP * 0.055
		entry.material.set_shader_parameter("opacity", minf(entry.age / 0.2, 1.0) * clampf(entry.fade / 0.45, 0.0, 1.0))

func show_damage_feedback(at: Vector2, amount: float) -> void:
	_skill_burst(at, Color("#e9e3c2"), 7, 0.48, 0.14)
	for i in range(damage_numbers.size() - 1, -1, -1):
		if not is_instance_valid(damage_numbers[i]):
			damage_numbers.remove_at(i)
	if damage_numbers.size() >= 24:
		damage_numbers.pop_front().queue_free()
	var number := Label3D.new()
	number.name = "HitDamage"
	number.text = "−%d" % ceili(amount)
	number.font_size = 28
	number.outline_size = 6
	number.pixel_size = 0.0075
	number.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	number.no_depth_test = true
	number.shaded = false
	number.modulate = Color("#f5ecd4")
	number.position = world_at(at) + Vector3.UP * 0.85
	number.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	attack_effects.add_child(number)
	damage_numbers.append(number)
	var rise := number.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	rise.tween_property(number, "position:y", number.position.y + 0.3, 0.46).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rise.parallel().tween_property(number, "modulate:a", 0.0, 0.21).set_delay(0.25)
	rise.tween_callback(number.queue_free)

func _skill_sheet(at: Vector2, atlas: Texture2D, diameter_px: float) -> void:
	var key := atlas.resource_path
	if not generated_frames.has(key):
		var frames := SpriteFrames.new()
		frames.set_animation_loop("default", false)
		frames.set_animation_speed("default", 30.0)
		for i in GENERATED_COUNT:
			var frame := AtlasTexture.new()
			frame.atlas = atlas
			frame.region = Rect2((i % GENERATED_COLS) * GENERATED_FRAME,
				floori(i / GENERATED_COLS) * GENERATED_FRAME, GENERATED_FRAME, GENERATED_FRAME)
			frame.filter_clip = true
			frames.add_frame("default", frame)
		generated_frames[key] = frames
	var effect := AnimatedSprite3D.new()
	effect.sprite_frames = generated_frames[key]
	effect.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	effect.pixel_size = UNITS_PER_PIXEL
	effect.scale = Vector3.ONE * (diameter_px / GENERATED_FRAME)
	effect.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	effect.shaded = false
	effect.no_depth_test = true
	effect.position = world_at(at) + Vector3.UP * 0.33
	effect.animation_finished.connect(effect.queue_free)
	attack_effects.add_child(effect)
	effect.play("default")

func _skill_sheet_24_128(at: Vector2, atlas: Texture2D, diameter_px: float, fps := 30.0) -> AnimatedSprite3D:
	# FrameRonin V2 特效固定导出 6×4、128 px、24 帧；与历史 256 px 图集分开缓存。
	var key := atlas.resource_path + "#v2_128_24_%.2f" % fps
	if not generated_frames.has(key):
		var frames := SpriteFrames.new()
		frames.set_animation_loop("default", false)
		frames.set_animation_speed("default", fps)
		for i in 24:
			var frame := AtlasTexture.new()
			frame.atlas = atlas
			frame.region = Rect2((i % 6) * 128, floori(i / 6) * 128, 128, 128)
			frame.filter_clip = true
			frames.add_frame("default", frame)
		generated_frames[key] = frames
	var effect := AnimatedSprite3D.new()
	effect.sprite_frames = generated_frames[key]
	effect.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	effect.pixel_size = UNITS_PER_PIXEL
	effect.scale = Vector3.ONE * (diameter_px / 128.0)
	effect.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	effect.shaded = false
	effect.no_depth_test = true
	effect.position = world_at(at) + Vector3.UP * 0.33
	effect.animation_finished.connect(effect.queue_free)
	attack_effects.add_child(effect)
	effect.play("default")
	return effect

func _skill_travel(from: Vector2, to: Vector2, tint: Color, duration: float, amount: int,
		scale: float, delay := 0.0) -> void:
	var trail := add_particles(attack_effects, _skill_fade(tint))
	trail.position = world_at(from) + Vector3.UP * 0.34
	trail.amount = amount
	trail.lifetime = maxf(duration, 0.08)
	trail.spread = 22.0
	trail.initial_velocity_min = 0.02
	trail.initial_velocity_max = 0.10
	trail.scale_amount_min = scale * 0.72
	trail.scale_amount_max = scale
	var travel := trail.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	if delay > 0.0:
		travel.tween_interval(delay)
	travel.tween_callback(trail.set_emitting.bind(true))
	travel.tween_property(trail, "position", world_at(to) + Vector3.UP * 0.30, maxf(duration, 0.08))
	travel.tween_callback(trail.set_emitting.bind(false))
	travel.tween_interval(trail.lifetime)
	travel.tween_callback(trail.queue_free)

func _skill_burst(at: Vector2, tint: Color, amount: int, scale: float, lifetime := 0.36) -> void:
	var burst := add_particles(attack_effects, _skill_fade(tint))
	burst.position = world_at(at) + Vector3.UP * 0.27
	burst.amount = amount
	burst.lifetime = lifetime
	burst.spread = 180.0
	burst.initial_velocity_min = 0.10
	burst.initial_velocity_max = 0.42
	burst.scale_amount_min = scale * 0.70
	burst.scale_amount_max = scale
	burst.emitting = true
	var clear := burst.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	clear.tween_interval(lifetime * 1.35)
	clear.tween_callback(burst.queue_free)

func _skill_strike(at: Vector2, tint: Color, amount: int, scale: float) -> void:
	var strike := add_particles(attack_effects, _skill_fade(tint))
	strike.position = world_at(at) + Vector3.UP * 1.08
	strike.amount = amount
	strike.lifetime = 0.30
	strike.direction = Vector3.DOWN
	strike.spread = 10.0
	strike.initial_velocity_min = 2.4
	strike.initial_velocity_max = 3.4
	strike.scale_amount_min = scale * 0.68
	strike.scale_amount_max = scale
	strike.emitting = true
	var clear := strike.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	clear.tween_interval(0.44)
	clear.tween_callback(strike.queue_free)
	_skill_burst(at, tint, maxi(10, amount / 2), scale * 0.78, 0.28)

func _skill_fade(tint: Color) -> Gradient:
	var fade := Gradient.new()
	fade.colors = PackedColorArray([Color(tint, 0.95), Color(tint, 0.0)])
	fade.offsets = PackedFloat32Array([0.0, 1.0])
	return fade

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

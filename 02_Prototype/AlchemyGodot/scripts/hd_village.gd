extends Node3D

const BUILDING := preload("res://scripts/hd_village_building.gd")
const TERRAIN := preload("res://scripts/hd_village_terrain.gd")
const ART_DIR := "res://art/village_hd/"
const OVERVIEW_OFFSET := Vector3(0, 6.65, 3.84)
const DAY_CYCLE_SECONDS := 60.0
const DUSK_AT_SECONDS := 22.0
const NIGHT_AT_SECONDS := 34.0
const DAWN_AT_SECONDS := 46.0
const WEATHER := preload("res://scripts/hd_village_weather.gd")
const STREET_OFFSET := Vector3(0, 2.90, 6.24)
const DISTRICTS := preload("res://scripts/hd_village_districts.gd")
const GARDENS := preload("res://scripts/hd_village_gardens.gd")

# ===== 局外角色尺寸（可视化可调，Inspector 实时预览）=====
# 角色在 3D 世界里的目标身高（米）。局内 2D 角色由 lilita.tscn 的 Art.scale 控制，
# 局外 3D 贴片由这里的 walker_height 控制；两者独立，需分别调成视觉一致。
@export var walker_height := 0.76
# 是否显示身高参考标尺（一根半透明立柱，高度 = walker_height，跟随角色，用于对比）。
@export var show_height_guide := false

var walker: CharacterBody2D
var walker_card: Sprite3D
var height_guide: MeshInstance3D
var camera: Camera3D
var sun: DirectionalLight3D
var atmosphere: Environment
var lens: CameraAttributesPractical
var local_lights: Array[OmniLight3D] = []
var cycle_time := 0.0
var dusk_amount := 0.0
var night_amount := 0.0
var weather: WEATHER
var terrain: TERRAIN
var snow_materials: Array[ShaderMaterial] = []
var snow_cover := 0.0
var street_view := true
var camera_offset := STREET_OFFSET
var bridge_framing := 0.0
var sky_material: ProceduralSkyMaterial
var clock := 0.0
var focus := Vector3.ZERO
var foreground_cards: Dictionary[Sprite3D, Image] = {}

func setup(source: CharacterBody2D, road: PackedVector2Array) -> void:
	walker = source
	terrain = TERRAIN.new()
	terrain.road_polygon = road
	add_child(terrain)
	environment_setup()
	weather = WEATHER.new()
	weather.name = "VillageWeather"
	add_child(weather)
	build_horizon()
	var objects := Node3D.new()
	objects.name = "VillageProps"
	add_child(objects)
	var masks: Dictionary[Texture2D, Image] = {}
	var zones := DISTRICTS.ZONES.duplicate()
	zones.merge(GARDENS.ZONES)
	for district_name: String in zones:
		var district := Node3D.new()
		district.name = district_name
		objects.add_child(district)
		if district_name == "WestBankGarden":
			GARDENS.build_terrace_edging(district)
			GARDENS.plant_terraces(district)
		for spec: Array in zones[district_name]:
			var path: String = ART_DIR + spec[0] + ".png"
			var generated_path: String = ART_DIR + "generated/" + spec[0] + ".png"
			if ResourceLoader.exists(generated_path):
				path = generated_path
			var texture := load(path) as Texture2D
			var prop := make_card(texture, spec[2])
			prop.name = spec[0]
			district.add_child(prop, true)
			prop.position = TERRAIN.world_at(spec[1])
			if spec[0] == "TerraceTrough":
				add_bank_support(prop, spec[1], Vector2(0.71, 0.38), preload("res://art/cobblestone.png"), Color("#92846b"))
			if spec.size() > 3:
				prop.rotate_y(deg_to_rad(spec[3]))
			if spec[0] == "House":
				prop.offset.y = 231.0
				if spec[1] == Vector2(505, 503):
					add_bank_support(prop, spec[1], Vector2(0.86, 0.57), preload("res://art/cobblestone.png"), Color("#8b806b"))
			elif spec[0] == "Waterwheel":
				prop.offset.y = 217.0
				add_bank_support(prop, spec[1], Vector2(0.53, 0.41), preload("res://art/village_hd/WoodGrain.png"), Color("#896244"))
			var kind: String = spec[0]
			var snow_kind := ["Oak", "Cottage", "Warehouse", "Workshop", "House", "", "Well"].find(kind)
			if snow_kind >= 0:
				var material := BUILDING.snow_material(texture, snow_kind)
				prop.material_override = material
				snow_materials.append(material)
			var roof := BUILDING.add_volume(prop, kind)
			if roof:
				snow_materials.append(roof)
			if spec[0] in ["Oak", "House", "Lantern"]:
				if not masks.has(texture):
					var image := texture.get_image()
					if image.is_compressed():
						image.decompress()
					masks[texture] = image
				foreground_cards[prop] = masks[texture]
	walker_card = make_card(null, walker_height)
	walker_card.name = "LilitaCard"
	walker_card.rotation_degrees.x = 0.0
	walker_card.scale.y = 1.8
	walker_card.region_enabled = true
	walker_card.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	walker_card.pixel_size = walker_height / 256.0
	walker_card.offset.y = 107.0
	add_child(walker_card)
	if show_height_guide:
		height_guide = make_height_guide(walker_height)
		add_child(height_guide)
	for at in [Vector2(344, 210), Vector2(704, 177), Vector2(775, 346), Vector2(956, 252), Vector2(1042, 287), Vector2(1112, 295)]:
		add_lamp(at)
	add_particles(Vector2(1170, 310), true)
	add_particles(Vector2(615, 411), false)
	add_particles(Vector2(363, 551), false)
	if "--village-snow-preview" in OS.get_cmdline_user_args():
		weather.upcoming.assign([WEATHER.Kind.SNOW, WEATHER.Kind.CLEAR])
		preview_next_weather()
	update_view(0.0)

func make_card(texture: Texture2D, height: float) -> Sprite3D:
	var card := Sprite3D.new()
	card.texture = texture
	card.rotation_degrees.x = -27.0
	card.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	card.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	card.alpha_scissor_threshold = 0.46
	card.shaded = true
	card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if texture:
		card.pixel_size = height / texture.get_height()
		card.offset.y = texture.get_height() * 0.5
	else:
		card.pixel_size = height / 512
	return card

# 身高参考标尺：一根半透明立柱，高度 = walker_height，用于局外直观对比角色大小。
func make_height_guide(height: float) -> MeshInstance3D:
	var guide := MeshInstance3D.new()
	guide.name = "HeightGuide"
	var box := BoxMesh.new()
	box.size = Vector3(0.08, height, 0.08)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.35, 0.2, 0.45)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	box.material = material
	guide.mesh = box
	guide.position = Vector3.ZERO
	guide.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return guide

func add_bank_support(card: Sprite3D, at: Vector2, size: Vector2, texture: Texture2D, tint: Color) -> void:
	var footing := MeshInstance3D.new()
	footing.name = "BankFooting"
	var top := card.position.y + 0.015
	var lowest := top
	for x in [-0.5, 0.5]:
		for z in [-1.0, 0.0]:
			var sample := at + Vector2(size.x * x, size.y * z) * TERRAIN.SCALE
			lowest = minf(lowest, TERRAIN.ground_height(sample, TERRAIN.river_distance(sample)))
	var bottom := lowest - 0.12
	var block := BoxMesh.new()
	block.size = Vector3(size.x, top - bottom, size.y)
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.albedo_color = tint
	material.roughness = 0.95
	block.material = material
	footing.mesh = block
	card.add_child(footing)
	footing.rotation.x = -card.rotation.x
	footing.position = card.basis.inverse() * Vector3(0, (top + bottom) * 0.5 - card.position.y, -size.y * 0.5)


func environment_setup() -> void:
	atmosphere = Environment.new()
	atmosphere.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	sky_material = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#7a9caf")
	sky_material.sky_horizon_color = Color("#b0c5c8")
	sky_material.ground_horizon_color = Color("#b0c5c8")
	sky_material.ground_bottom_color = Color("#7e8975")
	sky.sky_material = sky_material
	atmosphere.sky = sky
	atmosphere.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	atmosphere.ambient_light_color = Color("#cad8d5")
	atmosphere.ambient_light_energy = 0.45
	atmosphere.fog_enabled = true
	atmosphere.fog_light_color = Color("#809c96")
	atmosphere.fog_density = 0.007
	atmosphere.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world := WorldEnvironment.new()
	world.environment = atmosphere
	add_child(world)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-51, -33, 0)
	sun.light_color = Color("#fff0d0")
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 25
	add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 43.0
	camera.near = 0.1
	camera.far = 60
	camera.current = true
	lens = CameraAttributesPractical.new()
	lens.dof_blur_far_enabled = true
	lens.dof_blur_far_transition = 3.3
	lens.dof_blur_near_enabled = true
	lens.dof_blur_near_transition = 2.0
	lens.dof_blur_amount = 0.105
	camera.attributes = lens
	add_child(camera)

func build_horizon() -> void:
	for i in 3:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var material := StandardMaterial3D.new()
		material.albedo_color = [Color("#8396a3"), Color("#687f86"), Color("#516c6b")][i]
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.roughness = 1.0
		surface.set_material(material)
		var z := -26.0 + i * 4.0
		for j in range(-9, 9):
			var a := j * 3.0
			var b := (j + 1) * 3.0
			var left := Vector3(a, 1.95 + sin(a * 0.23 + i) * 0.85 + cos(a * 0.58) * 0.41, z)
			var right := Vector3(b, 1.95 + sin(b * 0.23 + i) * 0.85 + cos(b * 0.58) * 0.41, z)
			for vertex: Vector3 in [left, right, Vector3(b, -3.5, z), left, Vector3(b, -3.5, z), Vector3(a, -3.5, z)]:
				surface.add_vertex(vertex)
		surface.generate_normals()
		var ridge := MeshInstance3D.new()
		ridge.mesh = surface.commit()
		ridge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ridge)

func add_lamp(at: Vector2) -> void:
	var lamp := OmniLight3D.new()
	lamp.light_color = Color("#ffad5b")
	lamp.light_energy = 0.28
	lamp.omni_range = 2.35
	lamp.position = TERRAIN.world_at(at) + Vector3(0, 0.9, 0.22)
	add_child(lamp)
	local_lights.append(lamp)

func add_particles(at: Vector2, mist: bool) -> void:
	var particles := CPUParticles3D.new()
	particles.amount = 16 if mist else 12
	particles.lifetime = 3.0 if mist else 2.2
	particles.preprocess = particles.lifetime
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(0.42, 0.15, 0.33)
	particles.direction = Vector3(0.6, 1, 0.1)
	particles.spread = 37.0
	particles.gravity = Vector3.ZERO
	particles.initial_velocity_min = 0.08
	particles.initial_velocity_max = 0.29
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * (0.30 if mist else 0.038)
	var material := StandardMaterial3D.new()
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.75, 0.94, 0.86, 0.32) if mist else Color(1.0, 0.85, 0.40, 0.9), Color.TRANSPARENT])
	var radial := GradientTexture2D.new()
	radial.gradient = gradient
	radial.fill = GradientTexture2D.FILL_RADIAL
	radial.fill_from = Vector2(0.5, 0.5)
	radial.fill_to = Vector2(1.0, 0.5)
	material.albedo_texture = radial
	quad.material = material
	particles.mesh = quad
	particles.position = TERRAIN.world_at(at) + Vector3.UP * 0.12
	add_child(particles)

func update_view(delta: float) -> void:
	clock += delta
	var at := TERRAIN.world_at(walker.position)
	walker_card.position = at
	if height_guide:
		height_guide.position = at + Vector3(0.32, walker_height * 0.5, -0.06)
	var art: Sprite2D = walker.get_node("Art")
	if walker_card.texture != art.texture:
		walker_card.texture = art.texture
	if walker_card.region_rect != art.region_rect:
		walker_card.region_rect = art.region_rect
	walker_card.flip_h = art.flip_h
	var goal := Vector3(clampf(at.x, -4.6, 4.6), at.y + (0.65 if street_view else 0.42), clampf(at.z - 0.24, -2.1, 2.3))
	var on_bridge := Geometry2D.get_closest_point_to_segment(walker.position, TERRAIN.BRIDGE_START, TERRAIN.BRIDGE_END)
	bridge_framing = 1.0 - smoothstep(28.0, 135.0, walker.position.distance_to(on_bridge)) if street_view else 0.0
	var bridge_center := TERRAIN.world_at(TERRAIN.BRIDGE_START.lerp(TERRAIN.BRIDGE_END, 0.5))
	goal = goal.lerp(bridge_center + Vector3(0, 0.42, 0), 0.55 * bridge_framing)
	focus = goal if delta == 0.0 else focus.lerp(goal, 1.0 - exp(-7.0 * delta))
	var angle_blend := 1.0 if delta == 0.0 else 1.0 - exp(-7.0 * delta)
	var desired_offset := STREET_OFFSET + Vector3(0, 0.58, 0.30) * bridge_framing if street_view else OVERVIEW_OFFSET
	camera_offset = camera_offset.lerp(desired_offset, angle_blend)
	camera.position = focus + camera_offset
	camera.fov = lerpf(camera.fov, 47.0 if street_view else 43.0, angle_blend)
	walker_card.scale.y = lerpf(walker_card.scale.y, 1.04 if street_view else 1.8, angle_blend)
	camera.look_at(focus)
	update_foreground(delta)
	var depth := (camera.to_local(at + Vector3.UP * 0.4)).z * -1.0
	lens.dof_blur_far_distance = depth + 1.23
	lens.dof_blur_near_distance = maxf(0.1, depth - 1.12)
	weather.advance(delta, at)
	terrain.set_snow_cover(weather.snow_cover)
	if not is_equal_approx(snow_cover, weather.snow_cover):
		snow_cover = weather.snow_cover
		for material in snow_materials:
			material.set_shader_parameter("snow_cover", snow_cover)
	update_time_of_day(delta)

func preview_next_time() -> void:
	if cycle_time < DUSK_AT_SECONDS - 0.1 or cycle_time > 55.0:
		cycle_time = DUSK_AT_SECONDS
	elif cycle_time < NIGHT_AT_SECONDS - 0.1:
		cycle_time = NIGHT_AT_SECONDS
	else:
		cycle_time = 0.0
	update_time_of_day(0.0)

func preview_next_weather() -> void:
	weather.elapsed = 0.0
	weather.next_weather()

func update_time_of_day(delta: float) -> void:
	cycle_time = fposmod(cycle_time + delta, DAY_CYCLE_SECONDS)
	var twilight := smoothstep(7.0, DUSK_AT_SECONDS, cycle_time)
	var after_dusk := smoothstep(DUSK_AT_SECONDS, NIGHT_AT_SECONDS, cycle_time)
	var dawn := smoothstep(DAWN_AT_SECONDS, DAY_CYCLE_SECONDS, cycle_time)
	dusk_amount = twilight * (1.0 - after_dusk)
	night_amount = after_dusk * (1.0 - dawn)
	var clouds := weather.cloud_cover
	sun.light_energy = (0.95 - 0.56 * dusk_amount - 0.90 * night_amount) * (1.0 - clouds * 0.64) + weather.flash
	sun.light_color = Color("#fff0d0").lerp(Color("#ffa976"), dusk_amount).lerp(Color("#94b5ff"), maxf(night_amount, weather.flash))
	sun.rotation_degrees.x = -51.0 + 26.0 * dusk_amount + 14.0 * night_amount
	atmosphere.ambient_light_energy = (0.45 - 0.15 * dusk_amount - 0.25 * night_amount) * (1.0 - clouds * 0.26)
	atmosphere.ambient_light_color = Color("#cad8d5").lerp(Color("#809cc9"), dusk_amount).lerp(Color("#718dcd"), night_amount)
	sky_material.sky_top_color = Color("#7a9caf").lerp(Color("#253d6a"), dusk_amount).lerp(Color("#101e44"), night_amount).lerp(Color("#4c5e70"), clouds * 0.68)
	sky_material.sky_horizon_color = Color("#b0c5c8").lerp(Color("#657b9f"), dusk_amount).lerp(Color("#334a73"), night_amount).lerp(Color("#84909b"), clouds * 0.65)
	sky_material.ground_horizon_color = sky_material.sky_horizon_color
	atmosphere.fog_light_color = sky_material.sky_horizon_color
	atmosphere.fog_density = 0.007 + clouds * 0.018
	for i in local_lights.size():
		local_lights[i].light_energy = (0.28 + 0.92 * dusk_amount + 1.18 * night_amount) * (0.93 + 0.07 * sin(clock * (3.0 + i)))

func update_foreground(delta: float) -> void:
	var feet := walker_card.global_position
	var eye := camera.global_position
	var body_height := 0.73 * walker_card.scale.y
	var samples := [
		feet + Vector3(0, body_height * 0.84, 0),
		feet + Vector3(-0.12, body_height * 0.54, 0),
		feet + Vector3(0.12, body_height * 0.54, 0),
	]
	for card in foreground_cards:
		var occluding := false
		if card.global_position.distance_squared_to(feet) < 16.0:
			var inverse := card.global_transform.affine_inverse()
			var local_eye := inverse * eye
			for sample: Vector3 in samples:
				var local_sample := inverse * sample
				if local_eye.z * local_sample.z >= 0.0:
					continue
				var hit := local_eye.lerp(local_sample, local_eye.z / (local_eye.z - local_sample.z))
				var image: Image = foreground_cards[card]
				var u := hit.x / (image.get_width() * card.pixel_size) + 0.5
				var v := 0.5 + (card.offset.y - hit.y / card.pixel_size) / image.get_height()
				if u >= 0 and u < 1 and v >= 0 and v < 1 and image.get_pixel(int(u * image.get_width()), int(v * image.get_height())).a >= card.alpha_scissor_threshold:
					occluding = true
					break
		var opacity := move_toward(card.modulate.a, 0.12 if occluding else 1.0, delta * (8.0 if occluding else 4.5))
		if not is_equal_approx(card.modulate.a, opacity):
			card.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS if opacity < 1.0 else SpriteBase3D.ALPHA_CUT_DISCARD
			card.modulate.a = opacity
			if card.material_override is ShaderMaterial:
				card.set_instance_shader_parameter("card_opacity", opacity)
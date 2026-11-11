extends Node3D

const STREET_OFFSET := Vector3(0, 2.90, 6.24)
const OVERVIEW_OFFSET := Vector3(0, 6.65, 3.84)
const DAY_CYCLE_SECONDS := 60.0
const DUSK_AT_SECONDS := 22.0
const NIGHT_AT_SECONDS := 34.0
const DAWN_AT_SECONDS := 46.0
const WEATHER := preload("res://scripts/hd_village_weather.gd")

var camera: Camera3D
var sun: DirectionalLight3D
var atmosphere: Environment
var lens: CameraAttributesPractical
var local_lights: Array[OmniLight3D] = []
var cycle_time := 0.0
var dusk_amount := 0.0
var night_amount := 0.0
var weather: WEATHER
var street_view := true
var camera_offset := STREET_OFFSET
var sky_material: ProceduralSkyMaterial
var clock := 0.0

func environment_setup(weather_name: String = "OutdoorWeather") -> void:
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
	weather = WEATHER.new()
	weather.name = weather_name
	add_child(weather)

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
	clock += delta
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

func fade_foreground(foreground_cards: Dictionary[Sprite3D, Image], feet: Vector3, body_height: float, delta: float) -> void:
	var eye := camera.global_position
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

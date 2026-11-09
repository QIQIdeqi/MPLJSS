extends Node3D

enum Kind { CLEAR, RAIN, THUNDER, STORM, SNOW }

const NAMES := ["鏅村ぉ", "涓嬮洦", "鎵撻浄", "闆烽洦", "涓嬮洩"]
const WEATHER_SECONDS := 12.0
const THUNDER := preload("res://audio/S_VillageThunder.wav")

var current := Kind.CLEAR
var elapsed := 0.0
var flash := 0.0
var cloud_cover := 0.0
var snow_cover := 0.0
var flash_timer := 0.0
var upcoming: Array[int] = [Kind.RAIN, Kind.THUNDER, Kind.STORM, Kind.SNOW]
var rain: CPUParticles3D
var snow: CPUParticles3D
var thunder: AudioStreamPlayer
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	upcoming.shuffle()
	rain = make_precipitation(false)
	snow = make_precipitation(true)
	thunder = AudioStreamPlayer.new()
	thunder.stream = THUNDER
	thunder.volume_db = -14
	add_child(thunder)

func advance(delta: float, at: Vector3) -> void:
	position = at + Vector3.UP * 4.8
	elapsed += delta
	while elapsed >= WEATHER_SECONDS:
		elapsed -= WEATHER_SECONDS
		next_weather()
	var snowing := current == Kind.SNOW
	var melting_rate := 0.095 if current == Kind.RAIN or current == Kind.STORM else 0.038
	snow_cover = move_toward(snow_cover, 1.0 if snowing else 0.0, delta * (0.13 if snowing else melting_rate))
	var target_cloud := [0.0, 0.45, 0.56, 0.72, 0.37][current] as float
	cloud_cover = move_toward(cloud_cover, target_cloud, delta * 0.42)
	flash = move_toward(flash, 0.0, delta * 3.0)
	if current == Kind.THUNDER or current == Kind.STORM:
		flash_timer -= delta
		if flash_timer <= 0.0:
			flash_timer = rng.randf_range(3.5, 6.5)
			flash = 0.65
			thunder.play()

func next_weather() -> void:
	if upcoming.is_empty():
		upcoming.assign([Kind.CLEAR, Kind.RAIN, Kind.THUNDER, Kind.STORM, Kind.SNOW])
		upcoming.shuffle()
		if upcoming[0] == current:
			upcoming.push_back(upcoming.pop_front())
	current = upcoming.pop_front() as Kind
	rain.emitting = current == Kind.RAIN or current == Kind.STORM
	snow.emitting = current == Kind.SNOW
	flash_timer = rng.randf_range(0.7, 1.8)
	flash = 0.0

func make_precipitation(is_snow: bool) -> CPUParticles3D:
	var drops := CPUParticles3D.new()
	drops.amount = 500 if is_snow else 850
	drops.lifetime = 4.1 if is_snow else 0.78
	drops.emitting = false
	drops.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	drops.emission_box_extents = Vector3(7.2, 0.2, 5.4)
	drops.direction = Vector3(0.25, -1, 0)
	drops.spread = 13.0 if is_snow else 3.0
	drops.gravity = Vector3(0.1, -0.20 if is_snow else -4.4, 0)
	drops.initial_velocity_min = 0.7 if is_snow else 5.4
	drops.initial_velocity_max = 1.35 if is_snow else 7.0
	drops.scale_amount_min = 0.55
	drops.scale_amount_max = 1.2
	var quad := QuadMesh.new()
	quad.size = Vector2(0.05, 0.05) if is_snow else Vector2(0.007, 0.17)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.93, 0.97, 1.0, 0.85) if is_snow else Color(0.63, 0.79, 0.91, 0.44)
	if is_snow:
		var gradient := Gradient.new()
		gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
		var flake := GradientTexture2D.new()
		flake.gradient = gradient
		flake.fill = GradientTexture2D.FILL_RADIAL
		flake.fill_from = Vector2(0.5, 0.5)
		flake.fill_to = Vector2(1.0, 0.5)
		material.albedo_texture = flake
	quad.material = material
	drops.mesh = quad
	add_child(drops)
	return drops

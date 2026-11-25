extends Sprite3D

const BOTTLE := preload("res://scenes/fx/brew_result_vial.png")
const SKILL_LIGHT := preload("res://scripts/v2_skill_light.gd")
const WORLD_UNITS_PER_PIXEL := 0.01

var projectile: Dictionary
var launch_point: Vector2
var travel_distance: float

func start(state: Dictionary, from: Vector2, target: Vector2) -> void:
	projectile = state
	launch_point = from
	travel_distance = maxf(0.001, from.distance_to(target))
	texture = BOTTLE
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	pixel_size = 0.0045
	shaded = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	SKILL_LIGHT.add(self, Vector3(0.0, 0.0, 0.02), 0.28, Color(1.0, 0.48, 0.22, 0.40))
	_process(0.0)

func _process(_delta: float) -> void:
	if projectile.get("finished", false):
		queue_free()
		return
	var at: Vector2 = projectile.pos
	var progress := clampf(launch_point.distance_to(at) / travel_distance, 0.0, 1.0)
	var height := lerpf(0.39, 0.14, progress) + sin(progress * PI) * 0.30
	position = Vector3(at.x * WORLD_UNITS_PER_PIXEL, height, at.y * WORLD_UNITS_PER_PIXEL)
	rotation = Vector3(deg_to_rad(-27.0), 0.0, -0.38 - progress * TAU)

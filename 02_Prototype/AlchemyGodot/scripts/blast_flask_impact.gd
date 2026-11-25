extends Node3D

const GROUND_SHADER := preload("res://shaders/blast_flask_ground.gdshader")
const FLAME_SHADER := preload("res://shaders/blast_flask_flame.gdshader")
const SKILL_LIGHT := preload("res://scripts/v2_skill_light.gd")
const SOURCE_SHEET := preload("res://art/vfx/v2/blast_flask_impact_24f.png")
const LIFETIME := 0.85

class Fragment:
	var mesh: MeshInstance3D
	var velocity: Vector3
	var base_scale: Vector3
	var lifetime: float
	var spin: float

var age := 0.0
var ground_material: ShaderMaterial
var flame_material: ShaderMaterial
var flame: MeshInstance3D
var flash: OmniLight3D
var fragments: Array[Fragment] = []
var smoke: Array[Sprite3D] = []
var spread := 1.0

func start(radius: float) -> void:
	spread = clampf(radius, 0.55, 1.45)
	_make_ground()
	_make_flame()

	flash = OmniLight3D.new()
	flash.light_color = Color("#ff8b43")
	flash.light_energy = 1.5
	flash.omni_range = spread * 1.65
	flash.omni_attenuation = 1.7
	flash.position.y = 0.42
	add_child(flash)

	SKILL_LIGHT.add(self, Vector3(0.0, 0.24, 0.16), 0.70, Color(1.0, 0.43, 0.12, 1.16), 0.21, 0.54)

	_make_fragments()
	_make_smoke()

func _make_ground() -> void:
	ground_material = ShaderMaterial.new()
	ground_material.shader = GROUND_SHADER
	var ripple := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * spread * 2.0
	ripple.mesh = quad
	ripple.material_override = ground_material
	ripple.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ripple.rotation_degrees.x = -90.0
	ripple.position.y = 0.046
	add_child(ripple)

func _make_flame() -> void:
	flame_material = ShaderMaterial.new()
	flame_material.shader = FLAME_SHADER
	flame = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.02, 0.72) * sqrt(spread)
	flame.mesh = quad
	flame.material_override = flame_material
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame.rotation_degrees.x = -27.0
	flame.position = Vector3(0.0, 0.35, 0.19)
	add_child(flame)

func _make_fragments() -> void:
	var glass := PrismMesh.new()
	glass.size = Vector3(0.077, 0.092, 0.022)
	var glass_material := StandardMaterial3D.new()
	glass_material.albedo_color = Color("#8da0a1")
	glass_material.roughness = 0.42
	glass_material.emission_enabled = true
	glass_material.emission = Color("#6d3a28")
	glass.material = glass_material

	var ember := BoxMesh.new()
	ember.size = Vector3(0.027, 0.089, 0.022)
	var ember_material := StandardMaterial3D.new()
	ember_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ember_material.albedo_color = Color("#ffbf67")
	ember.material = ember_material

	for index in 19:
		var is_glass := index < 7
		var angle := index * 2.39996 + randf_range(-0.11, 0.11)
		var outward := Vector3(cos(angle), 0.0, sin(angle))
		var piece := Fragment.new()
		piece.mesh = MeshInstance3D.new()
		piece.mesh.mesh = glass if is_glass else ember
		piece.mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		piece.mesh.rotation.y = -angle
		piece.base_scale = Vector3.ONE * randf_range(0.64, 1.16)
		piece.mesh.scale = piece.base_scale
		piece.velocity = outward * randf_range(0.85, 1.75) * spread
		piece.velocity.y = randf_range(0.9, 2.1) if is_glass else randf_range(0.8, 2.8)
		piece.spin = randf_range(-6.0, 6.0) if is_glass else 0.0
		piece.lifetime = randf_range(0.36, 0.64) if is_glass else randf_range(0.18, 0.42)
		add_child(piece.mesh)
		fragments.append(piece)

func _make_smoke() -> void:
	# Reuse the isolated gray puff from the old sheet, without its flash or flying debris.
	var plume := AtlasTexture.new()
	plume.atlas = SOURCE_SHEET
	plume.region = Rect2(256 + 52, 256 + 42, 44, 51)
	plume.filter_clip = true
	for index in 3:
		var puff := _make_sprite(plume)
		puff.rotation_degrees.x = -27.0
		puff.pixel_size = 0.011
		puff.modulate = Color(0.72, 0.59, 0.47, 0.0)
		smoke.append(puff)

func _make_sprite(texture: Texture2D) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = texture
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sprite)
	return sprite

func _process(delta: float) -> void:
	age += delta
	if age >= LIFETIME:
		queue_free()
		return

	ground_material.set_shader_parameter("age", minf(age, 0.34))
	flame.visible = age < 0.19
	if flame.visible:
		flame_material.set_shader_parameter("age", age)
	flash.light_energy = 1.5 * pow(maxf(1.0 - age / 0.19, 0.0), 2.0)

	for piece in fragments:
		var progress := age / piece.lifetime
		piece.mesh.visible = progress < 1.0
		if not piece.mesh.visible:
			continue
		var flight := piece.velocity * age
		flight.y = maxf(0.045, 0.08 + flight.y - 3.6 * age * age)
		piece.mesh.position = flight
		piece.mesh.rotation.x = piece.spin * age
		piece.mesh.scale = piece.base_scale * (1.0 - smoothstep(0.5, 1.0, progress))

	for index in smoke.size():
		var progress := clampf((age - 0.065 - index * 0.028) / 0.70, 0.0, 1.0)
		var angle := 0.32 + index * TAU / 3.0
		var drift := Vector3(cos(angle), 0.0, sin(angle)) * progress * spread * 0.44
		smoke[index].position = drift + Vector3.UP * (0.12 + progress * 0.19)
		smoke[index].scale = Vector3.ONE * lerpf(0.72, 1.55, progress)
		smoke[index].modulate.a = 0.47 * smoothstep(0.0, 0.19, progress) * (1.0 - smoothstep(0.22, 1.0, progress))

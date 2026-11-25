extends Node3D

const GLINT_SHADER := preload("res://shaders/v2_skill_glint.gdshader")
const JADE := Color("#68dfd1")
const AMETHYST := Color("#d499fa")

static var stroke_mesh := BoxMesh.new()
static var glint_mesh := QuadMesh.new()
var stroke_materials: Array[StandardMaterial3D] = []
var glint_materials: Array[ShaderMaterial] = []
var age := 0.0
var lifetime := 0.0

static func branch_color(side: int) -> Color:
	return JADE if side < 0 else AMETHYST

func start_cast(direction: Vector2) -> void:
	lifetime = 0.30
	var forward := _flat(direction)
	var lateral := Vector3(-forward.z, 0.0, forward.x)
	var origin := Vector3.UP * 0.26 + forward * 0.06
	for side in [-1, 1]:
		var wing := lateral * float(side)
		var tint := branch_color(side)
		var pivot := origin + forward * 0.19 + wing * 0.16 + Vector3.UP * 0.045
		var tip := origin + forward * 0.43 + wing * 0.25 + Vector3.UP * 0.08
		var material := _stroke_material(tint)
		_stroke(origin + wing * 0.03, pivot, 0.035, material)
		_stroke(pivot, tip, 0.025, material)
		_glint(tip, 0.28, tint, 0.72)

func start_follow(side: int, summoned := false, trailing := true) -> void:
	var tint := branch_color(side)
	var spark := Vector3(0.03, 0.53, 0.0) if summoned else Vector3(-0.10, 0.05, 0.06 * side)
	_glint(spark, 0.26 if summoned else 0.29, tint, 0.82)
	if trailing and not summoned:
		var material := _stroke_material(tint)
		_stroke(spark - Vector3.RIGHT * 0.18, spark, 0.022, material)
		_stroke(spark - Vector3.RIGHT * 0.29, spark - Vector3.RIGHT * 0.22, 0.014, material)
	set_process(false)

func start_mark(side: int, direction: Vector2, height: float, duration: float) -> void:
	lifetime = duration
	var forward := _flat(direction)
	var wing := Vector3(-forward.z, 0.0, forward.x) * float(side)
	var center := Vector3.UP * height + wing * 0.11
	var tint := branch_color(side)
	var material := _stroke_material(tint)
	_stroke(center - forward * 0.12, center + wing * 0.09 + Vector3.UP * 0.07, 0.024, material)
	_stroke(center + wing * 0.09 + Vector3.UP * 0.07, center + forward * 0.12, 0.020, material)
	_glint(center + wing * 0.06 + Vector3.UP * 0.055, 0.31, tint, 0.83)

func _process(delta: float) -> void:
	age += delta
	if age >= lifetime:
		queue_free()
		return
	var phase := age / lifetime
	var fade := 1.0 - smoothstep(0.18, 1.0, phase)
	for material in stroke_materials:
		var tint := material.albedo_color
		tint.a = fade * 0.88
		material.albedo_color = tint
	for material in glint_materials:
		material.set_shader_parameter("strength", fade * 0.82)

func _stroke_material(tint: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(tint, 0.88)
	stroke_materials.append(material)
	return material

func _stroke(from: Vector3, to: Vector3, width: float, material: StandardMaterial3D) -> void:
	var mesh := MeshInstance3D.new()
	mesh.mesh = stroke_mesh
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.material_override = material
	var along := from.direction_to(to)
	var basis := Basis.looking_at(along, Vector3.UP)
	mesh.transform = Transform3D(basis.scaled_local(Vector3(width, width, from.distance_to(to))), from.lerp(to, 0.5))
	add_child(mesh)

func _glint(at: Vector3, size: float, tint: Color, strength: float) -> void:
	var mesh := MeshInstance3D.new()
	mesh.mesh = glint_mesh
	mesh.position = at
	mesh.scale = Vector3.ONE * size
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = GLINT_SHADER
	material.set_shader_parameter("tint", tint)
	material.set_shader_parameter("strength", strength)
	material.set_shader_parameter("rays", 0.53)
	mesh.material_override = material
	add_child(mesh)
	glint_materials.append(material)

static func _flat(direction: Vector2) -> Vector3:
	if direction.is_zero_approx():
		return Vector3.RIGHT
	return Vector3(direction.x, 0.0, direction.y).normalized()

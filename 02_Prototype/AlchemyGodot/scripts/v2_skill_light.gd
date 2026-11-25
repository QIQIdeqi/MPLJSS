extends RefCounted

const GLINT_SHADER := preload("res://shaders/v2_skill_glint.gdshader")
static var quad := QuadMesh.new()

static func add(parent: Node3D, at: Vector3, size: float, tint: Color,
		duration := 0.0, rays := 0.0) -> void:
	var glint := MeshInstance3D.new()
	glint.mesh = quad
	glint.position = at
	glint.scale = Vector3.ONE * size
	glint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = GLINT_SHADER
	material.set_shader_parameter("tint", tint)
	material.set_shader_parameter("strength", tint.a)
	material.set_shader_parameter("rays", rays)
	glint.material_override = material
	parent.add_child(glint)
	if duration > 0.0:
		var fade := glint.create_tween()
		fade.set_parallel(true)
		fade.tween_property(material, "shader_parameter/strength", 0.0, duration).set_trans(Tween.TRANS_SINE)
		fade.tween_property(glint, "scale", glint.scale * 1.24, duration).set_ease(Tween.EASE_OUT)
		fade.chain().tween_callback(glint.queue_free)

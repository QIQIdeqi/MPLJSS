extends Node3D

const FX := preload("res://scripts/combo_fx_composition.gd")
const GLINT := preload("res://shaders/v2_skill_glint.gdshader")
const WORLD_SCALE := 0.01
const MAX_GLINTS := 32

var _fx := FX.new()
var _mesh := ImmediateMesh.new()
var _material := StandardMaterial3D.new()
var _cards: Array[Sprite3D] = []
var _glows: Array[MeshInstance3D] = []
var _glow_quad := QuadMesh.new()


func _ready() -> void:
	var surface := MeshInstance3D.new()
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	surface.mesh = _mesh
	surface.extra_cull_margin = 0.08
	add_child(surface)
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.vertex_color_use_as_albedo = true
	_material.vertex_color_is_srgb = true
	_material.disable_fog = true
	_material.render_priority = 2


func show_effect(info: Dictionary) -> void:
	_fx.show_effect(info)


func clear_effects() -> void:
	_fx.clear_effects()
	_mesh.clear_surfaces()
	for card in _cards:
		card.hide()
	for glow in _glows:
		glow.hide()


func _process(delta: float) -> void:
	if not _fx.advance(delta):
		return
	_render_shapes()
	_render_cards()
	_render_glows()


func _render_shapes() -> void:
	_mesh.clear_surfaces()
	var started := false
	for shape in _fx.shapes:
		var points: PackedVector2Array = shape.points
		var elevations: PackedFloat32Array = shape.get("elevations", PackedFloat32Array())
		var indices := Geometry2D.triangulate_polygon(points) if elevations.is_empty() \
			else PackedInt32Array([0, 1, 2, 0, 2, 3])
		if indices.is_empty():
			continue
		if not started:
			_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _material)
			started = true
		var height := float(shape.height)
		for index in indices:
			_mesh.surface_set_color(shape.color)
			_mesh.surface_add_vertex(_world(points[index], height if elevations.is_empty() else elevations[index]))
	if started:
		_mesh.surface_end()


func _render_cards() -> void:
	var count := _fx.cards.size()
	while _cards.size() < count:
		var sprite := Sprite3D.new()
		sprite.shaded = false
		sprite.modulate = Color.WHITE
		sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.hframes = FX.COLS
		sprite.vframes = FX.ROWS
		add_child(sprite)
		_cards.append(sprite)
	for i in _cards.size():
		var sprite := _cards[i]
		sprite.visible = i < count
		if not sprite.visible:
			continue
		var card: Dictionary = _fx.cards[i]
		var flat := bool(card.flat)
		sprite.position = _world(card.at, float(card.height))
		sprite.texture = card.texture
		sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED if flat else BaseMaterial3D.BILLBOARD_ENABLED
		sprite.rotation.x = -PI * 0.5 if flat else 0.0
		sprite.pixel_size = float(card.size) * WORLD_SCALE / FX.CELL
		sprite.frame = int(card.frame)
		sprite.modulate = Color(1.0, 1.0, 1.0, float(card.opacity))


func _render_glows() -> void:
	var count := mini(_fx.glows.size(), MAX_GLINTS)
	while _glows.size() < count:
		var spot := MeshInstance3D.new()
		spot.mesh = _glow_quad
		spot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := ShaderMaterial.new()
		material.shader = GLINT
		material.set_shader_parameter("rays", 0.14)
		spot.material_override = material
		add_child(spot)
		_glows.append(spot)
	for index in _glows.size():
		var spot := _glows[index]
		spot.visible = index < count
		if not spot.visible:
			continue
		var info: Dictionary = _fx.glows[index]
		spot.position = _world(info.at, float(info.height))
		spot.scale = Vector3.ONE * float(info.size) * WORLD_SCALE
		var material := spot.material_override as ShaderMaterial
		material.set_shader_parameter("tint", info.color)
		material.set_shader_parameter("strength", info.strength)


static func _world(point: Vector2, height: float) -> Vector3:
	return Vector3(point.x, height, point.y) * WORLD_SCALE

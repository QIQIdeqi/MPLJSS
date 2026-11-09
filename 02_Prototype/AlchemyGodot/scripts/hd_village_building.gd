extends RefCounted

const WOOD := preload("res://art/village_hd/WoodGrain.png")
const SNOW_SHADER := preload("res://scripts/hd_village_prop_snow.gdshader")
const STONE := preload("res://art/cobblestone.png")

static func add_volume(facade: Sprite3D, kind: String) -> ShaderMaterial:
	if kind != "Cottage" and kind != "Workshop" and kind != "Warehouse":
		return null

	var cottage := kind == "Cottage"
	var warehouse := kind == "Warehouse"
	var volume := Node3D.new()
	volume.name = "BuildingVolume"
	facade.add_child(volume)
	# Keep the ground anchor but cancel the original illustration's presentation tilt.
	volume.basis = Basis(Vector3.RIGHT, -facade.rotation.x) * Basis(Vector3.UP, deg_to_rad(-15.0 if cottage else 19.0))

	if warehouse:
		# The painted hoist and cargo occupy the left and lower foreground.
		volume.position.x = 0.32
	elif not cottage:
		volume.position.x = 0.09

	var half_width := 0.67 if cottage else 0.58
	var rear := -1.03 if cottage else -0.89
	var eaves := 0.91 if cottage else 0.72
	var ridge := 1.37 if cottage else 1.11
	var front_base := -0.22
	if warehouse:
		half_width = 0.78
		rear = -1.51
		eaves = 1.04
		ridge = 1.51
		front_base = -0.30
	var shear := tan(absf(facade.rotation.x))
	var front_eaves := front_base - shear * eaves
	var roof_front := front_eaves - 0.06
	var roof_back := rear - 0.10
	var ridge_z := lerpf(roof_front, roof_back, 0.56)
	var roof_left := -half_width - 0.10
	var roof_right := half_width + 0.10

	var timber := material(Color("#775338"), WOOD)
	var frame := material(Color("#5b4028"), WOOD)
	var fill := material(Color("#c2a07d") if cottage else Color("#865d39"))
	var foundation := material(Color("#8c8276"), STONE)
	var roof := material(Color("#c4b3a5"), facade.texture)
	roof.uv1_scale = Vector3(0.27, 0.12, 1.0) if cottage else Vector3(0.26, 0.13, 1.0)
	roof.uv1_offset = Vector3(0.23, 0.14, 0.0) if cottage else Vector3(0.52, 0.29, 0.0)
	if warehouse:
		fill.albedo_color = Color("#bc9b72")
		roof.albedo_color = Color("#d3b992")
		roof.uv1_scale = Vector3(0.20, 0.24, 1.0)
		roof.uv1_offset = Vector3(0.60, 0.23, 0.0)

	for side in [-1.0, 1.0]:
		var x: float = half_width * side
		var normal := Vector3(side, 0, 0)
		var z_front_foundation := front_base - shear * 0.17
		quad(volume, "StoneFooting", foundation, normal,
			Vector3(x, -0.10, front_base), Vector3(x, -0.10, rear),
			Vector3(x, 0.17, rear), Vector3(x, 0.17, z_front_foundation))
		quad(volume, "SideWall", fill, normal,
			Vector3(x, 0.17, z_front_foundation), Vector3(x, 0.17, rear),
			Vector3(x, eaves, rear), Vector3(x, eaves, front_eaves))
		triangle(volume, "TimberGable", timber, normal,
			Vector3(x, eaves, front_eaves), Vector3(x, eaves, rear), Vector3(x, ridge - 0.04, ridge_z))
		var trim_x: float = x + side * 0.018
		beam(volume, "EavesBeam", frame, Vector3(trim_x, eaves, front_eaves), Vector3(trim_x, eaves, rear), 0.081)
		beam(volume, "SillBeam", frame, Vector3(trim_x, 0.18, z_front_foundation), Vector3(trim_x, 0.18, rear), 0.062)
		beam(volume, "CornerPost", frame, Vector3(trim_x, 0.12, rear), Vector3(trim_x, eaves, rear), 0.085)
		var center_z := lerpf(front_eaves, rear, 0.49)
		beam(volume, "WallStud", timber, Vector3(trim_x, 0.18, center_z), Vector3(trim_x, eaves, center_z), 0.06)
		beam(volume, "DiagonalBrace", timber,
			Vector3(trim_x, 0.51, rear + 0.035), Vector3(trim_x, eaves - 0.035, center_z), 0.052)
		beam(volume, "GableStud", frame,
			Vector3(trim_x, eaves, ridge_z), Vector3(trim_x, ridge - 0.05, ridge_z), 0.068)

	quad(volume, "RearWall", fill, Vector3.FORWARD,
		Vector3(-half_width, -0.10, rear), Vector3(half_width, -0.10, rear),
		Vector3(half_width, eaves, rear), Vector3(-half_width, eaves, rear))
	var left_ridge := Vector3(roof_left, ridge, ridge_z)
	var right_ridge := Vector3(roof_right, ridge, ridge_z)
	var left_front := Vector3(roof_left, eaves, roof_front)
	var right_front := Vector3(roof_right, eaves, roof_front)
	var left_back := Vector3(roof_left, eaves, roof_back)
	var right_back := Vector3(roof_right, eaves, roof_back)
	var snowy_roof := snow_material(facade.texture, 5)
	snowy_roof.set_shader_parameter("tint", roof.albedo_color)
	snowy_roof.set_shader_parameter("texture_scale", Vector2(roof.uv1_scale.x, roof.uv1_scale.y))
	snowy_roof.set_shader_parameter("texture_offset", Vector2(roof.uv1_offset.x, roof.uv1_offset.y))
	var roof_thickness := 0.12 if warehouse else 0.073
	roof_panel(volume, snowy_roof, timber, left_front, right_front, right_ridge, left_ridge, roof_thickness)
	roof_panel(volume, snowy_roof, timber, right_back, left_back, left_ridge, right_ridge, roof_thickness)
	beam(volume, "RidgeCap", timber, left_ridge, right_ridge, 0.065)
	return snowy_roof

static func snow_material(texture: Texture2D, kind: int) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = SNOW_SHADER
	result.set_shader_parameter("albedo_texture", texture)
	result.set_shader_parameter("surface_kind", kind)
	return result

static func material(color: Color, texture: Texture2D = null) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.albedo_texture = texture
	result.roughness = 0.94
	result.cull_mode = BaseMaterial3D.CULL_BACK
	result.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	return result

static func roof_panel(parent: Node3D, tile: Material, fascia: Material, a: Vector3, b: Vector3, c: Vector3, d: Vector3, depth: float) -> void:
	var normal := (b - a).cross(d - a).normalized()
	quad(parent, "RoofSlope", tile, normal, a, b, c, d)
	var thickness := Vector3.DOWN * depth
	quad(parent, "RoofUnderside", fascia, -normal, d + thickness, c + thickness, b + thickness, a + thickness)
	quad(parent, "EaveFascia", fascia, Vector3(0, 0, signf(a.z - d.z)), b, a, a + thickness, b + thickness)
	quad(parent, "VergeFascia", fascia, (a - b).normalized(), a, d, d + thickness, a + thickness)
	quad(parent, "VergeFascia", fascia, (b - a).normalized(), c, b, b + thickness, c + thickness)

static func beam(parent: Node3D, node_name: String, surface: Material, a: Vector3, b: Vector3, width: float) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, width, a.distance_to(b))
	mesh.material = surface
	instance.mesh = mesh
	parent.add_child(instance, true)
	instance.position = (a + b) * 0.5
	var direction := a.direction_to(b)
	instance.look_at(parent.to_global(instance.position + direction),
		Vector3.RIGHT if absf(direction.dot(Vector3.UP)) > 0.97 else Vector3.UP)

static func quad(parent: Node3D, node_name: String, surface: Material, normal: Vector3, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	add_surface(parent, node_name, surface, normal, [a, b, c, a, c, d],
		[Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 1), Vector2(1, 0), Vector2(0, 0)])

static func triangle(parent: Node3D, node_name: String, surface: Material, normal: Vector3, a: Vector3, b: Vector3, c: Vector3) -> void:
	add_surface(parent, node_name, surface, normal, [a, b, c], [Vector2(0, 1), Vector2(1, 1), Vector2(0.5, 0)])

static func add_surface(parent: Node3D, node_name: String, surface: Material, normal: Vector3, points: Array[Vector3], uvs: Array[Vector2]) -> void:
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	builder.set_material(surface)
	for first in range(0, points.size(), 3):
		var reverse := (points[first + 1] - points[first]).cross(points[first + 2] - points[first]).dot(normal) > 0.0
		for index: int in ([first, first + 2, first + 1] if reverse else [first, first + 1, first + 2]):
			builder.set_normal(normal)
			builder.set_uv(uvs[index])
			builder.add_vertex(points[index])
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = builder.commit()
	parent.add_child(instance, true)

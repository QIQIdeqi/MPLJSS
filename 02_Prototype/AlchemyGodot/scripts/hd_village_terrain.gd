extends Node3D

const GRASS := preload("res://art/grass.png")
const DIRT := preload("res://art/dirt.png")
const COBBLE := preload("res://art/cobblestone.png")
const WOOD := preload("res://art/village_hd/WoodGrain.png")
const WATER_SHADER := preload("res://shaders/hd_village_water.gdshader")
const ORIGIN := Vector2(640, 360)
const SCALE := 100.0
const WATER_Y := -0.33
const RIVER_HALF_WIDTH := 43.0
const BRIDGE_START := Vector2(145, 511)
const BRIDGE_END := Vector2(417, 414)
const BRIDGE_HALF_WIDTH := 31.0
# World-pixel center, half extents and rise in world units. Edging uses the same outlines.
const GARDEN_BEDS := [
	[Vector2(36, 614), Vector2(30, 20), 0.20],
	[Vector2(142, 650), Vector2(43, 22), 0.15],
	[Vector2(198, 705), Vector2(46, 22), 0.10],
]
const RIVER := [
	Vector2(-576, 69), Vector2(-300, 174), Vector2(-100, 249), Vector2(9, 298), Vector2(93, 349),
	Vector2(185, 397), Vector2(271, 459), Vector2(344, 510), Vector2(429, 550),
	Vector2(518, 588), Vector2(616, 638), Vector2(702, 707), Vector2(850, 840),
	Vector2(1010, 1040), Vector2(1130, 1232)
]
const GROUND_SHADER := """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform float snow_cover : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D grass : source_color, repeat_enable, filter_nearest_mipmap_anisotropic;
uniform sampler2D dirt : source_color, repeat_enable, filter_nearest_mipmap_anisotropic;
uniform sampler2D cobble : source_color, repeat_enable, filter_nearest_mipmap_anisotropic;

void fragment() {
	vec2 fleck = floor(UV * 48.0);
	float variation = fract(sin(dot(fleck, vec2(12.9898, 78.233))) * 43758.5453);
	float path = smoothstep(0.15, 0.82, COLOR.r + (variation - 0.5) * 0.19);
	vec3 ground = mix(texture(grass, UV * 0.89).rgb, texture(dirt, UV).rgb, path);
	ground = mix(ground, texture(cobble, UV * 1.1).rgb, COLOR.b * path * 0.78);
	float furrow = mix(0.73, 1.09, smoothstep(-0.75, 0.7, cos(UV.y * 77.0)));
	ground = mix(ground, texture(dirt, UV * 1.6).rgb * vec3(0.63, 0.44, 0.32) * furrow, COLOR.a * 0.94);
	float patch = sin(UV.x * 2.65 + UV.y * 1.37) * cos(UV.y * 3.06 - UV.x * 1.13);
	float mottle = mix(0.90, 1.07, patch * 0.5 + 0.5);
	ground *= mix(vec3(mottle), vec3(0.52, 0.58, 0.49), COLOR.g * 0.58);
	float slope = smoothstep(0.52, 0.93, dot(NORMAL, VIEW_MATRIX[1].xyz));
	float drift = variation * 0.26 + patch * 0.14;
	float spread = smoothstep(0.06, 0.62, snow_cover + drift - 0.18);
	float snow = min(snow_cover * 1.5, 1.0) * spread * slope;
	snow *= mix(0.94, 0.32, path) * (1.0 - COLOR.g * 0.89);
	vec3 snow_color = mix(vec3(0.69, 0.79, 0.87), vec3(0.91, 0.95, 0.98), variation);
	ALBEDO = mix(ground, snow_color, snow);
	ROUGHNESS = mix(0.90, 0.78, snow);
}
"""

const TIMBER_SHADER := """
shader_type spatial;
uniform sampler2D grain : source_color, repeat_enable, filter_nearest_mipmap_anisotropic;
uniform vec4 tint : source_color = vec4(1.0);
uniform int axis = 0;
uniform float offset = 0.0;
varying vec3 timber_position;

void vertex() {
	timber_position = VERTEX;
}

void fragment() {
	vec3 p = timber_position;
	vec2 along = vec2(p.x, p.y + p.z);
	if (axis == 1) {
		along = vec2(p.z, p.x + p.y);
	} else if (axis == 2) {
		along = vec2(p.y, p.x + p.z);
	}
	vec3 wood = texture(grain, along * vec2(0.82, 2.6) + vec2(offset, offset * 0.37)).rgb;
	ALBEDO = mix(tint.rgb, wood * tint.rgb * 1.60, 0.61);
	ROUGHNESS = 0.91;
}
"""

var road_polygon: PackedVector2Array
var ground_material: ShaderMaterial
var snow_cover := 0.0

func _ready() -> void:
	build_ground()
	build_water()
	build_bridge()
	build_banks()

static func world_at(pixel: Vector2) -> Vector3:
	var planar := (pixel - ORIGIN) / SCALE
	return Vector3(planar.x, height_at(pixel), planar.y)

static func height_at(pixel: Vector2) -> float:
	var closest := Geometry2D.get_closest_point_to_segment(pixel, BRIDGE_START, BRIDGE_END)
	var length := BRIDGE_START.distance_to(BRIDGE_END)
	var progress := (pixel - BRIDGE_START).dot((BRIDGE_END - BRIDGE_START).normalized()) / length
	if progress >= 0.0 and progress <= 1.0 and pixel.distance_to(closest) <= BRIDGE_HALF_WIDTH:
		return bridge_height(progress)
	return ground_height(pixel, river_distance(pixel))

static func river_distance(pixel: Vector2) -> float:
	var distance := INF
	for i in RIVER.size() - 1:
		var closest := Geometry2D.get_closest_point_to_segment(pixel, RIVER[i], RIVER[i + 1])
		distance = minf(distance, pixel.distance_squared_to(closest))
	return sqrt(distance)

static func dry_ground_height(pixel: Vector2) -> float:
	var roll := sin(pixel.x * 0.010 + pixel.y * 0.003) * 0.13 + cos(pixel.y * 0.011) * 0.08
	var north_rise := 0.53 * (1.0 - smoothstep(0.0, 330.0, pixel.y))
	var east_rise := 0.16 * smoothstep(920.0, 1360.0, pixel.x)
	var ridge := 0.30 * smoothstep(75.0, 380.0, -pixel.y)
	return roll + north_rise + east_rise + ridge

static func garden_edge_distance(pixel: Vector2, center: Vector2, half_size: Vector2) -> float:
	var edge := (pixel - center).abs() - half_size
	return maxf(edge.x, edge.y)

static func ground_height(pixel: Vector2, river_gap: float) -> float:
	var dry := dry_ground_height(pixel)
	for bed in GARDEN_BEDS:
		var edge := garden_edge_distance(pixel, bed[0], bed[1])
		if edge < 12.0:
			var terrace := dry_ground_height(bed[0]) + float(bed[2])
			dry = maxf(dry, lerpf(dry, terrace, 1.0 - smoothstep(1.0, 14.0, edge)))
	var bank := smoothstep(RIVER_HALF_WIDTH * 0.58, RIVER_HALF_WIDTH + 15.0, river_gap)
	return lerpf(-0.69, dry, bank)

static func bridge_height(progress: float) -> float:
	var begin := ground_height(BRIDGE_START, river_distance(BRIDGE_START))
	var end := ground_height(BRIDGE_END, river_distance(BRIDGE_END))
	return lerpf(begin, end, progress) + 0.05 + sin(progress * PI) * 0.28

func path_weight(pixel: Vector2) -> float:
	if road_polygon.size() < 3:
		return 0.0
	var closest := 1100.0
	for i in road_polygon.size():
		var edge := Geometry2D.get_closest_point_to_segment(pixel, road_polygon[i], road_polygon[(i + 1) % road_polygon.size()])
		closest = minf(closest, pixel.distance_squared_to(edge))
	var distance := sqrt(closest)
	if Geometry2D.is_point_in_polygon(pixel, road_polygon):
		return smoothstep(-14.0, 19.0, distance)
	return smoothstep(-14.0, 19.0, -distance)

func build_ground() -> void:
	var geometry := SurfaceTool.new()
	geometry.begin(Mesh.PRIMITIVE_TRIANGLES)
	const COLS := 155
	const ROWS := 122
	for y in ROWS:
		for x in COLS:
			var pixel := Vector2(x * 16 - 576, y * 16 - 704)
			var p := (pixel - ORIGIN) / SCALE
			var river_gap := river_distance(pixel)
			var wet := 1.0 - smoothstep(22.0, 61.0, river_gap)
			var plaza := 1.0 - smoothstep(42.0, 128.0, pixel.distance_to(Vector2(603, 315)))
			var workshop := 1.0 - smoothstep(10.0, 76.0, pixel.distance_to(Vector2(936, 310)))
			var herb_yard := 1.0 - smoothstep(26.0, 87.0, pixel.distance_to(Vector2(245, 272)))
			var unloading_yard := 1.0 - smoothstep(43.0, 94.0, pixel.distance_to(Vector2(743, 194)))
			var work_yard := 1.0 - smoothstep(30.0, 86.0, pixel.distance_to(Vector2(972, 284)))
			var yard := maxf(herb_yard * 0.62, maxf(unloading_yard * 0.80, work_yard * 0.88))
			geometry.set_uv(p * 0.85)
			var road := path_weight(pixel)
			var garden := 0.0
			for bed in GARDEN_BEDS:
				var edge := garden_edge_distance(pixel, bed[0], bed[1])
				garden = maxf(garden, 1.0 - smoothstep(-5.0, 6.0, edge))
			garden *= 1.0 - road
			geometry.set_color(Color(maxf(road, yard), wet, maxf(plaza, maxf(workshop, work_yard * 0.64)), garden))
			geometry.add_vertex(Vector3(p.x, ground_height(pixel, river_gap), p.y))
	for y in ROWS - 1:
		for x in COLS - 1:
			var i := y * COLS + x
			for index in [i, i + 1, i + COLS, i + 1, i + COLS + 1, i + COLS]:
				geometry.add_index(index)
	geometry.generate_normals()
	var shader := Shader.new()
	shader.code = GROUND_SHADER
	ground_material = ShaderMaterial.new()
	ground_material.shader = shader
	ground_material.set_shader_parameter("grass", GRASS)
	ground_material.set_shader_parameter("dirt", DIRT)
	ground_material.set_shader_parameter("cobble", COBBLE)
	add_mesh("Terrain", geometry.commit(), ground_material)

func set_snow_cover(amount: float) -> void:
	if is_equal_approx(snow_cover, amount):
		return
	snow_cover = amount
	ground_material.set_shader_parameter("snow_cover", snow_cover)

func river_side(index: int) -> Vector2:
	var before: Vector2 = RIVER[maxi(index - 1, 0)]
	var after: Vector2 = RIVER[mini(index + 1, RIVER.size() - 1)]
	return (after - before).normalized().orthogonal()

func build_water() -> void:
	var geometry := SurfaceTool.new()
	geometry.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stream_length := 0.0
	for i in RIVER.size():
		var river_point: Vector2 = RIVER[i]
		if i > 0:
			stream_length += river_point.distance_to(RIVER[i - 1]) / SCALE
		var across := river_side(i) * RIVER_HALF_WIDTH * 1.06
		for edge in 2:
			var p := (river_point + across * (-1.0 if edge == 0 else 1.0) - ORIGIN) / SCALE
			geometry.set_uv(Vector2(stream_length, edge))
			geometry.add_vertex(Vector3(p.x, WATER_Y, p.y))
	for i in range(0, (RIVER.size() - 1) * 2, 2):
		for index in [i, i + 2, i + 1, i + 1, i + 2, i + 3]:
			geometry.add_index(index)
	geometry.generate_normals()
	var material := ShaderMaterial.new()
	material.shader = WATER_SHADER
	var water := add_mesh("FlowingCreek", geometry.commit(), material)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func build_bridge() -> void:
	var bridge := Node3D.new()
	bridge.name = "RaisedTimberBridge"
	add_child(bridge)
	var heading := BRIDGE_START.direction_to(BRIDGE_END)
	var side := heading.orthogonal()
	var span := BRIDGE_START.distance_to(BRIDGE_END) / SCALE
	var yaw := -heading.angle()
	var wood_shader := Shader.new()
	wood_shader.code = TIMBER_SHADER
	var timber := wood_material(wood_shader, Color("#8d6d54"), 0, 0.12)
	var post := wood_material(wood_shader, Color("#86654e"), 2, 0.42)
	var rail := wood_material(wood_shader, Color("#aa8365"), 0, 0.23)
	var plank_colors: Array[ShaderMaterial] = []
	for tint in ["#c7a57e", "#b79876", "#d1b187", "#b49270", "#caab84"]:
		plank_colors.append(wood_material(wood_shader, Color(tint), 1, plank_colors.size() * 0.17))
	const PLANK_COUNT := 27
	for i in PLANK_COUNT:
		var t := (float(i) + 0.5) / PLANK_COUNT
		var point := BRIDGE_START.lerp(BRIDGE_END, t)
		var width := BRIDGE_HALF_WIDTH * 2.0 / SCALE
		add_box(bridge, "Deck", at_height(point, bridge_height(t) - 0.042),
			Vector3(span / PLANK_COUNT * 0.96, 0.084, width), yaw, plank_colors[(i * 7) % plank_colors.size()])
	for edge in [-1, 1]:
		var offset := side * (BRIDGE_HALF_WIDTH + 2.0) * float(edge)
		const RAIL_SECTIONS := 6
		for i in RAIL_SECTIONS:
			var t1 := float(i) / RAIL_SECTIONS
			var t2 := float(i + 1) / RAIL_SECTIONS
			var first := BRIDGE_START.lerp(BRIDGE_END, t1) + offset
			var last := BRIDGE_START.lerp(BRIDGE_END, t2) + offset
			var start_y := bridge_height(t1)
			var end_y := bridge_height(t2)
			for beam_y in [-0.12, 0.21, 0.34]:
				var beam := add_box(bridge, "Rail", at_height(first.lerp(last, 0.5), (start_y + end_y) * 0.5 + beam_y),
					Vector3(span / RAIL_SECTIONS + 0.035, 0.055, 0.053), yaw, timber if beam_y < 0.0 else rail)
				beam.rotate_object_local(Vector3.FORWARD, -atan2(end_y - start_y, span / RAIL_SECTIONS))
		for i in RAIL_SECTIONS + 1:
			var t := float(i) / RAIL_SECTIONS
			var point := BRIDGE_START.lerp(BRIDGE_END, t) + offset
			var bottom := ground_height(point, river_distance(point)) - 0.04
			var top := bridge_height(t) + 0.42
			add_box(bridge, "Post", at_height(point, (top + bottom) * 0.5), Vector3(0.087, top - bottom, 0.085), yaw, post)
			add_box(bridge, "PostCap", at_height(point, top), Vector3(0.108, 0.031, 0.108), yaw, rail)

func build_banks() -> void:
	var stones := Node3D.new()
	stones.name = "RiverBankStones"
	add_child(stones)
	var rock := SphereMesh.new()
	rock.radial_segments = 6
	rock.rings = 3
	var rock_materials: Array[StandardMaterial3D] = []
	for tint in ["#6b6757", "#807b62", "#77725c", "#92907b"]:
		var stone := color_material(Color(tint).lightened(0.16))
		stone.albedo_texture = COBBLE
		stone.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		rock_materials.append(stone)
	var random := RandomNumberGenerator.new()
	random.seed = 12783
	for i in range(1, RIVER.size() - 1):
		var center: Vector2 = RIVER[i]
		var next: Vector2 = RIVER[i + 1]
		var section_length := center.distance_to(next)
		var count := floori(section_length / 16.0)
		for side in [-1, 1]:
			for index in count:
				var t := (float(index) + random.randf_range(0.1, 0.8)) / count
				var offset := river_side(i).lerp(river_side(i + 1), t)
				var point := center.lerp(next, t) + offset * (RIVER_HALF_WIDTH + random.randf_range(-1.0, 6.0)) * float(side)
				if point.x < -80.0 or point.x > 1300.0 or point.y > 810.0:
					continue
				if path_weight(point) > 0.36:
					continue
				if point.distance_to(Geometry2D.get_closest_point_to_segment(point, BRIDGE_START, BRIDGE_END)) < BRIDGE_HALF_WIDTH + 11.0:
					continue
				var node := MeshInstance3D.new()
				node.mesh = rock
				node.material_override = rock_materials[random.randi_range(0, rock_materials.size() - 1)]
				node.position = at_height(point, ground_height(point, river_distance(point)) + 0.026)
				node.scale = Vector3(random.randf_range(0.14, 0.27), random.randf_range(0.09, 0.18), random.randf_range(0.13, 0.29))
				node.rotation.y = random.randf_range(0, TAU)
				stones.add_child(node)

static func at_height(pixel: Vector2, height: float) -> Vector3:
	var point := (pixel - ORIGIN) / SCALE
	return Vector3(point.x, height, point.y)

func add_mesh(label: String, mesh: Mesh, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.material_override = material
	add_child(node)
	return node

func add_box(group: Node3D, label: String, point: Vector3, dimensions: Vector3, yaw: float, material: Material) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = dimensions
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = box
	node.material_override = material
	node.position = point
	node.rotation.y = yaw
	group.add_child(node, true)
	return node

func color_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.87
	return material

func wood_material(shader: Shader, tint: Color, axis: int, offset: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("grain", WOOD)
	material.set_shader_parameter("tint", tint)
	material.set_shader_parameter("axis", axis)
	material.set_shader_parameter("offset", offset)
	return material

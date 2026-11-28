extends Node3D
## Renders the generated battle layout. Gameplay collision and spawn positions stay in 2D.

const GRASS := preload("res://art/grass.png")
const OAK := preload("res://art/oak.png")
const BUSH := preload("res://art/bush.png")
const BANK_ROCKS := preload("res://art/village_hd/BankRocks.png")
const FENCE := preload("res://art/fence.png")
const CRATES := preload("res://art/crates.png")
const GROUND_SHADER := preload("res://shaders/hd_battle_ground.gdshader")
const VILLAGE_BUILDING := preload("res://scripts/hd_village_building.gd")
const PIXELS_PER_UNIT := 100.0
const BACKDROP_EXTENT := 33.0
const BACKDROP_STEP := 0.8

var generated: Node3D
var ground_noise_scale := 1.0
var snow_cover := 0.0
var snow_materials: Array[ShaderMaterial] = []
var foreground_cards: Dictionary[Sprite3D, Image] = {}
var backdrop_mesh: ArrayMesh
var backdrop_bounds := Rect2()
var chunk_nodes: Dictionary = {}
var terrain_sets: Dictionary = {}
var streaming := false

func rebuild(tiles: Array, props: Array, bounds: Rect2) -> void:
	streaming = false
	chunk_nodes.clear()
	terrain_sets.clear()
	_reset_generated()
	_build_ground(tiles, bounds)
	_build_props(props)

func _reset_generated() -> void:
	if is_instance_valid(generated):
		remove_child(generated)
		generated.queue_free()
	snow_materials.clear()
	foreground_cards.clear()
	generated = Node3D.new()
	generated.name = "GeneratedBattleLandscape"
	add_child(generated)

func sync_chunks(chunks: Dictionary, props_by_chunk: Dictionary) -> void:
	if not streaming:
		streaming = true
		chunk_nodes.clear()
		terrain_sets.clear()
		_reset_generated()
	for coord: Vector2i in chunk_nodes.keys():
		if chunks.has(coord):
			continue
		var previous: Node3D = chunk_nodes[coord]
		for card: Sprite3D in foreground_cards.keys():
			if not is_instance_valid(card) or previous.is_ancestor_of(card):
				foreground_cards.erase(card)
		for material in previous.get_meta("snow_materials", []):
			snow_materials.erase(material)
		generated.remove_child(previous)
		previous.queue_free()
		chunk_nodes.erase(coord)
	var all_tiles: Array = []
	for layout: Dictionary in chunks.values():
		all_tiles.append_array(layout.tiles)
	for coord: Vector2i in chunks:
		var layout: Dictionary = chunks[coord]
		if not chunk_nodes.has(coord):
			var chunk := Node3D.new()
			chunk.name = "Chunk_%d_%d" % [coord.x, coord.y]
			generated.add_child(chunk)
			chunk_nodes[coord] = chunk
			var before := snow_materials.size()
			_build_ground(layout.tiles, layout.bounds, true, chunk, all_tiles)
			_build_props(props_by_chunk.get(coord, []), chunk)
			chunk.set_meta("snow_materials", snow_materials.slice(before))
		else:
			# The one-cell lookup border includes adjacent chunks, so blended surfaces meet at seams.
			var ground: MeshInstance3D = chunk_nodes[coord].get_node("BattleGround")
			_set_ground_surface(ground.material_override, layout.tiles, layout.bounds, all_tiles, true)

func set_snow_cover(amount: float) -> void:
	amount = clampf(amount, 0.0, 1.0)
	if is_equal_approx(snow_cover, amount):
		return
	snow_cover = amount
	for material in snow_materials:
		material.set_shader_parameter("snow_cover", snow_cover)

func _build_ground(tiles: Array, bounds: Rect2, streamed := false, parent: Node3D = null, neighbors: Array = []) -> void:
	var material := ShaderMaterial.new()
	material.shader = GROUND_SHADER
	material.set_shader_parameter("ground_noise_scale", ground_noise_scale)
	_set_ground_surface(material, tiles, bounds, neighbors, streamed)
	_track_snow(material)
	var field := Rect2(bounds.position / PIXELS_PER_UNIT, bounds.size / PIXELS_PER_UNIT)
	var ground := MeshInstance3D.new()
	ground.name = "BattleGround"
	if streamed:
		var plane := PlaneMesh.new()
		plane.size = field.size
		ground.mesh = plane
		ground.position = Vector3(field.get_center().x, 0, field.get_center().y)
	else:
		if backdrop_mesh == null or backdrop_bounds != field:
			backdrop_mesh = _mountain_mesh(field)
			backdrop_bounds = field
		ground.mesh = backdrop_mesh
	ground.material_override = material
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent else generated).add_child(ground)
	if not streamed:
		_build_backdrop_props(field)

func _set_ground_surface(material: ShaderMaterial, tiles: Array, bounds: Rect2, neighbors: Array, streamed: bool) -> void:
	var tile_size: Vector2 = tiles[0].rect.size if not tiles.is_empty() else bounds.size
	var grid := Vector2i((bounds.size / tile_size).round())
	var padding := Vector2i.ONE if streamed else Vector2i.ZERO
	var lookup_size := grid + padding * 2
	var lookup := Image.create_empty(lookup_size.x, lookup_size.y, false, Image.FORMAT_RF)
	var textures: Array[Texture2D] = [GRASS]
	var source := neighbors if streamed and not neighbors.is_empty() else tiles
	for tile: Dictionary in source:
		var texture: Texture2D = tile.texture
		if not textures.has(texture):
			textures.append(texture)
	# Keep the texture array independent of dictionary insertion / chunk visitation order.
	textures.sort_custom(func(a: Texture2D, b: Texture2D) -> bool:
		return a != b and (a == GRASS or (b != GRASS and a.resource_path < b.resource_path)))
	var layer_ids: Dictionary[Texture2D, int] = {}
	for i in textures.size():
		layer_ids[textures[i]] = i
	for tile: Dictionary in source:
		var texture: Texture2D = tile.texture
		var tile_rect: Rect2 = tile.rect
		var cell := Vector2i(((tile_rect.position - bounds.position) / tile_size).round()) + padding
		if cell.x >= 0 and cell.y >= 0 and cell.x < lookup_size.x and cell.y < lookup_size.y:
			lookup.set_pixelv(cell, Color(float(layer_ids[texture]), 0.0, 0.0))
	var signature := ""
	for texture in textures:
		signature += str(texture.get_instance_id()) + ":"
	if not terrain_sets.has(signature):
		var images: Array[Image] = []
		for texture in textures:
			images.append(_ground_image(texture))
		var terrain := Texture2DArray.new()
		if terrain.create_from_images(images) != OK:
			push_error("Could not build the battle ground texture array")
			return
		terrain_sets[signature] = terrain
	material.set_shader_parameter("terrain_layers", terrain_sets[signature])
	material.set_shader_parameter("tile_lookup", ImageTexture.create_from_image(lookup))
	material.set_shader_parameter("map_origin", (bounds.position - Vector2(padding) * tile_size) / PIXELS_PER_UNIT)
	material.set_shader_parameter("cell_size", tile_size / PIXELS_PER_UNIT)

func _mountain_mesh(field: Rect2) -> ArrayMesh:
	var area := field.grow(BACKDROP_EXTENT)
	var columns := ceili(area.size.x / BACKDROP_STEP) + 1
	var rows := ceili(area.size.y / BACKDROP_STEP) + 1
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in rows:
		for x in columns:
			var at := area.position + Vector2(x, z) * BACKDROP_STEP
			mesh.add_vertex(Vector3(at.x, _mountain_height(at, field), at.y))
	for z in rows - 1:
		for x in columns - 1:
			var a := z * columns + x
			for index: int in [a, a + 1, a + columns, a + 1, a + columns + 1, a + columns]:
				mesh.add_index(index)
	mesh.generate_normals()
	return mesh.commit()

func _mountain_height(at: Vector2, field: Rect2) -> float:
	var local := at - field.get_center()
	var edge := local.abs() - field.size * 0.5
	var outside := maxf(edge.x, edge.y)
	if outside <= BACKDROP_STEP:
		return 0.0
	var rise := smoothstep(BACKDROP_STEP, 6.0, outside)
	var folds := 0.30 * sin(local.x * 1.4 + local.y * 0.6) + 0.18 * cos(local.y * 2.0 - local.x * 0.8)
	if at.y > field.end.y:
		return rise * (0.38 + folds * 0.48)
	var west := (local - Vector2(-11.4, -8.6)) / Vector2(6.6, 5.2)
	var east := (local - Vector2(10.7, -9.7)) / Vector2(6.0, 5.5)
	var spur := (local - Vector2(-2.3, -8.4)) / Vector2(4.7, 3.8)
	var far := (local - Vector2(1.8, -18.0)) / Vector2(16.0, 6.6)
	var hills := 4.4 * exp(-west.length_squared()) + 5.8 * exp(-east.length_squared())
	hills += 3.4 * exp(-spur.length_squared()) + 7.2 * exp(-far.length_squared())
	return rise * (0.42 + hills + folds)

func _build_backdrop_props(field: Rect2) -> void:
	var oak_material := VILLAGE_BUILDING.snow_material(OAK, 0)
	var rock_material := VILLAGE_BUILDING.snow_material(BANK_ROCKS, 0)
	_track_snow(oak_material)
	_track_snow(rock_material)
	var oak_foot := _foot_offset(OAK)
	var rock_foot := _foot_offset(BANK_ROCKS)
	var rng := RandomNumberGenerator.new()
	rng.seed = 84123
	for z in 7:
		for x in 15:
			var at := field.get_center() + Vector2((x - 7) * 2.05, -11.8 + z * 1.7)
			at += Vector2(rng.randf_range(-0.75, 0.75), rng.randf_range(-0.65, 0.65))
			if field.grow(1.35).has_point(at) or rng.randf() < 0.43:
				continue
			_add_backdrop_prop(OAK, oak_material, oak_foot, at, field, rng.randf_range(1.0, 1.9), rng.randf() > 0.5)
	for offset: Vector2 in [Vector2(-8.8, -0.1), Vector2(-8.3, -2.3), Vector2(-7.6, -5.1),
			Vector2(-4.5, -5.5), Vector2(-3.2, -5.9), Vector2(-0.5, -5.1),
			Vector2(3.1, -6.1), Vector2(4.3, -5.5), Vector2(7.9, -4.5),
			Vector2(8.5, -2.8), Vector2(8.2, 0.0), Vector2(8.5, 2.8)]:
		var at := field.get_center() + offset
		_add_backdrop_prop(BANK_ROCKS, rock_material, rock_foot, at, field, rng.randf_range(0.8, 1.45), rng.randf() > 0.5)

func _add_backdrop_prop(texture: Texture2D, material: ShaderMaterial, foot: float, at: Vector2,
		field: Rect2, size: float, flipped: bool) -> void:
	var card := Sprite3D.new()
	card.texture = texture
	card.offset.y = foot
	card.pixel_size = size / texture.get_height()
	card.flip_h = flipped
	card.shaded = true
	card.material_override = material
	card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	card.position = Vector3(at.x, _mountain_height(at, field) - 0.035, at.y)
	generated.add_child(card)

func _ground_image(texture: Texture2D) -> Image:
	var image := texture.get_image()
	if image == null or image.is_empty():
		image = GRASS.get_image()
	if image.is_compressed():
		image.decompress()
	image.clear_mipmaps()
	image.convert(Image.FORMAT_RGBA8)
	var target_size := GRASS.get_size()
	if image.get_size() != Vector2i(target_size):
		image.resize(int(target_size.x), int(target_size.y), Image.INTERPOLATE_LANCZOS)
	image.generate_mipmaps()
	return image

func _build_props(props: Array, parent: Node3D = null) -> void:
	var foot_offsets: Dictionary[Texture2D, float] = {}
	var foliage_materials: Dictionary[Texture2D, ShaderMaterial] = {}
	var occlusion_masks: Dictionary[Texture2D, Image] = {}
	for source: Sprite2D in props:
		var texture := source.texture
		if not foot_offsets.has(texture):
			foot_offsets[texture] = _foot_offset(texture)
		var card := Sprite3D.new()
		card.name = "Prop"
		card.texture = texture
		card.pixel_size = 1.0 / PIXELS_PER_UNIT
		card.offset = Vector2(source.offset.x, foot_offsets[texture])
		card.scale = Vector3(absf(source.scale.x), absf(source.scale.y), 1.0)
		card.flip_h = source.flip_h != (source.scale.x < 0.0)
		card.rotation_degrees.x = -27.0
		card.position = Vector3(source.position.x / PIXELS_PER_UNIT, 0.005, source.position.y / PIXELS_PER_UNIT)
		card.shaded = true
		card.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		card.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		card.alpha_scissor_threshold = 0.46
		card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if texture != null:
			if not foliage_materials.has(texture):
				var material := VILLAGE_BUILDING.snow_material(texture, 0)
				_track_snow(material)
				foliage_materials[texture] = material
			card.material_override = foliage_materials[texture]
		(parent if parent else generated).add_child(card, true)
		if texture != BUSH:
			if not occlusion_masks.has(texture):
				var mask := texture.get_image()
				if mask.is_compressed():
					mask.decompress()
				occlusion_masks[texture] = mask
			foreground_cards[card] = occlusion_masks[texture]

func _foot_offset(texture: Texture2D) -> float:
	var image := texture.get_image()
	if image != null and image.is_compressed():
		image.decompress()
	var bottom := image.get_used_rect().end.y if image != null else texture.get_height()
	return float(bottom) - texture.get_height() * 0.5

func _track_snow(material: ShaderMaterial) -> void:
	material.set_shader_parameter("snow_cover", snow_cover)
	snow_materials.append(material)

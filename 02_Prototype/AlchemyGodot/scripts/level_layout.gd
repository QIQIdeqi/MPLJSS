@tool
extends RefCounted

const Preset = preload("res://levels/preset.gd")
const Brush = preload("res://levels/brush.gd")

static func build(preset: Preset, seed_value: int, bounds: Rect2, spawn: Vector2,
		arena_half_size := Vector2.ZERO, preview := false) -> Dictionary:
	var grid := preset.grid
	if grid.x < 1 or grid.y < 1 or grid.x > 64 or grid.y > 64 or bounds.size.x <= 0 or bounds.size.y <= 0:
		return _failed("网格应为 1–64 格，地图尺寸必须大于零")
	if preset.object_density < 0.0 or preset.object_density > 1.0 or preset.object_spacing < 0.0 or preset.protected_half_width < 0.0:
		return _failed("全局密度应为 0–1，间距与通路半宽必须为非负数")
	var total := grid.x * grid.y
	var minima := PackedInt32Array()
	var maxima := PackedInt32Array()
	var grounds: Array[int] = []
	var objects: Array[int] = []
	for i in preset.palette.size():
		var brush := preset.palette[i]
		if brush == null or brush.texture == null:
			return _failed("素材 %d 缺少纹理" % (i + 1))
		var collision_valid := brush.collision == Vector2.ZERO or (brush.collision.x > 0 and brush.collision.y > 0)
		if not brush.ground and (brush.size.x <= 0 or brush.size.y <= 0 or not collision_valid):
			return _failed("%s 的显示尺寸或碰撞尺寸无效" % brush.display_name)
		var count := brush.count_range
		var density := brush.density_range
		if count.x < -1 or count.y < -1 or not _valid_density(density.x) or not _valid_density(density.y):
			return _failed("%s 的次数或密度范围无效" % brush.display_name)
		var lower := maxi(maxi(0, count.x), ceili(density.x * total - 0.0001))
		var upper := total if count.y < 0 else mini(count.y, total)
		if density.y >= 0:
			upper = mini(upper, floori(density.y * total + 0.0001))
		if lower > upper:
			return _failed("%s 的次数与密度范围没有交集" % brush.display_name)
		minima.append(lower)
		maxima.append(upper)
		if brush.ground:
			grounds.append(i)
		else:
			objects.append(i)

	var ground_rng := RandomNumberGenerator.new()
	var prop_rng := RandomNumberGenerator.new()
	ground_rng.seed = seed_value ^ 0x47524f55 ^ (preset.ground_seed_offset if preview else 0)
	prop_rng.seed = seed_value ^ 0x50524f50 ^ (preset.prop_seed_offset if preview else 0)
	var ground_cells := preset.locked_ground.duplicate() if preview else {}
	var prop_cells := preset.locked_props.duplicate() if preview else {}
	var ground_counts := _count_locks(ground_cells, grounds, total, maxima)
	var prop_counts := _count_locks(prop_cells, objects, total, maxima)
	if ground_counts.is_empty() or prop_counts.is_empty():
		return _failed("锁定格超出网格或素材范围")

	var ground_order := _shuffled_cells(total, ground_rng)
	for id in grounds:
		for i in range(ground_counts[id], minima[id]):
			while not ground_order.is_empty() and ground_cells.has(ground_order.back()):
				ground_order.pop_back()
			if ground_order.is_empty() or preset.palette[id].weight <= 0:
				return _failed("%s 的最小地面格数无法满足" % preset.palette[id].display_name)
			ground_cells[ground_order.pop_back()] = id
			ground_counts[id] += 1

	var size := bounds.size / Vector2(grid)
	var patches := {}
	var tiles: Array[Dictionary] = []
	for cell in total:
		if not ground_cells.has(cell):
			var patch := Vector2i(cell % grid.x, floori(float(cell) / grid.x)) / maxi(1, preset.ground_patch)
			var id: int = patches.get(patch, -1)
			if id < 0 or ground_counts[id] >= maxima[id]:
				id = _weighted(grounds, preset, ground_counts, maxima, ground_rng)
				patches[patch] = id
			if id < 0:
				return _failed("地面素材总上限或权重不足，无法连续铺满地图")
			ground_cells[cell] = id
			ground_counts[id] += 1
		var brush := preset.palette[ground_cells[cell]]
		tiles.append({"cell": cell, "brush": ground_cells[cell], "rect": Rect2(_corner(cell, grid, size, bounds.position), size), "texture": brush.texture})

	var props: Array[Dictionary] = []
	var arena := arena_half_size if arena_half_size != Vector2.ZERO else preset.arena_half_size(bounds)
	for cell: int in prop_cells:
		var id: int = prop_cells[cell]
		if id == -1:
			continue
		var item := _prop_at(preset.palette[id], id, cell, tiles[cell].rect.get_center(), seed_value)
		if not _fits(item, preset, bounds, spawn, arena, props):
			return _failed("锁定物件与通路、边界或其他物件冲突")
		props.append(item)
	var object_order := _shuffled_cells(total, prop_rng)
	for id in objects:
		for i in range(prop_counts[id], minima[id]):
			var placed := false
			for cell in object_order:
				if not prop_cells.has(cell) and preset.palette[id].weight > 0 and _place(preset, id, cell, tiles, props, bounds, spawn, arena, seed_value):
					prop_cells[cell] = id
					prop_counts[id] += 1
					placed = true
					break
			if not placed:
				return _failed("%s 的最小物件数无法满足，请检查间距与保护区" % preset.palette[id].display_name)
	for cell in object_order:
		if prop_cells.has(cell) or prop_rng.randf() >= preset.object_density:
			continue
		var id := _weighted(objects, preset, prop_counts, maxima, prop_rng)
		if id >= 0 and _place(preset, id, cell, tiles, props, bounds, spawn, arena, seed_value):
			prop_counts[id] += 1
	return {"tiles": tiles, "props": props, "error": ""}

static func _valid_density(value: float) -> bool:
	return value == -1.0 or (value >= 0.0 and value <= 1.0)

static func _count_locks(locks: Dictionary, layer: Array[int], total: int, maxima: PackedInt32Array) -> PackedInt32Array:
	var counts := PackedInt32Array()
	counts.resize(maxima.size() + 1)
	for cell: int in locks:
		var id: int = locks[cell]
		if cell < 0 or cell >= total:
			return PackedInt32Array()
		if id == -1:
			continue
		if not layer.has(id):
			return PackedInt32Array()
		counts[id] += 1
		if counts[id] > maxima[id]:
			return PackedInt32Array()
	return counts

static func _shuffled_cells(total: int, rng: RandomNumberGenerator) -> Array[int]:
	var cells: Array[int] = []
	cells.assign(range(total))
	for i in range(total - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var previous := cells[i]
		cells[i] = cells[j]
		cells[j] = previous
	return cells

static func _weighted(ids: Array[int], preset: Preset, counts: PackedInt32Array, maxima: PackedInt32Array, rng: RandomNumberGenerator) -> int:
	var weights := PackedFloat32Array()
	for id in ids:
		weights.append(preset.palette[id].weight if counts[id] < maxima[id] else 0.0)
	if weights.is_empty() or weights.count(0.0) == weights.size():
		return -1
	return ids[rng.rand_weighted(weights)]

static func _corner(cell: int, grid: Vector2i, size: Vector2, origin: Vector2) -> Vector2:
	return origin + Vector2(cell % grid.x, floori(float(cell) / grid.x)) * size

static func _prop_at(brush: Brush, id: int, cell: int, position: Vector2, seed_value: int) -> Dictionary:
	var jitter := RandomNumberGenerator.new()
	jitter.seed = seed_value ^ (cell * 7919 + id)
	var scale_factor := jitter.randf_range(0.9, 1.1)
	return {"cell": cell, "brush": id, "position": position, "texture": brush.texture,
		"size": brush.size * scale_factor, "collision": brush.collision * scale_factor,
		"foot_fraction": brush.foot_fraction, "boss_interior": brush.boss_interior}

static func _place(preset: Preset, id: int, cell: int, tiles: Array[Dictionary], props: Array[Dictionary],
		bounds: Rect2, spawn: Vector2, arena: Vector2, seed_value: int) -> bool:
	var item := _prop_at(preset.palette[id], id, cell, tiles[cell].rect.get_center(), seed_value)
	if not _fits(item, preset, bounds, spawn, arena, props):
		return false
	props.append(item)
	return true

static func _fits(item: Dictionary, preset: Preset, bounds: Rect2, spawn: Vector2, arena: Vector2, props: Array[Dictionary]) -> bool:
	var at: Vector2 = item.position
	var half: Vector2 = item.collision * 0.5
	var corridor := maxf(preset.protected_half_width, 20.0)
	if not bounds.grow(-24.0).has_point(at):
		return false
	var playable := preset.playable_bounds(bounds)
	if not Rect2(playable.position + half, playable.size - half * 2.0).has_point(at):
		return false
	if absf(at.x - spawn.x) < corridor + half.x or absf(at.y - spawn.y) < corridor + half.y:
		return false
	if at.distance_to(spawn) < 105.0 + half.length():
		return false
	if not preset.boss:
		var portal := preset.portal_position(bounds)
		var path := Geometry2D.get_closest_point_to_segment(at, spawn, portal)
		if at.distance_to(portal) < 82.0 + half.length() or at.distance_to(path) < corridor + half.length():
			return false
	if preset.boss and (not item.boss_interior or half != Vector2.ZERO):
		if ((at - bounds.get_center()) / (arena + half + Vector2.ONE * 24.0)).length_squared() <= 1.0:
			return false
	for other in props:
		if at.distance_to(other.position) < preset.object_spacing:
			return false
		# Two solid footprints leave at least 32 px between them for Lilita's 28 px collider.
		var padding := 16.0 if half != Vector2.ZERO and other.collision != Vector2.ZERO else 12.0
		var occupied := Rect2(at - half, half * 2.0).grow(padding)
		if occupied.intersects(Rect2(other.position - other.collision * 0.5, other.collision).grow(padding)):
			return false
	return true

static func _failed(message: String) -> Dictionary:
	return {"tiles": [], "props": [], "error": message}

extends RefCounted
## Runtime chunks contain plain layout data. Loot and encounter state are owned by field.gd.

const Preset = preload("res://levels/preset.gd")
const Layout = preload("res://scripts/level_layout.gd")

var preset: Preset
var seed_value := 0
var level_id: StringName
var spawn := Vector2(640, 430)
var active_chunks: Dictionary = {}
var center := Vector2i(2147483647, 2147483647)
var last_radius := Vector2i.ZERO

func setup(settings: Preset, run_seed: int, stage_id: StringName, spawn_at: Vector2) -> void:
	preset = settings
	seed_value = run_seed
	level_id = stage_id
	spawn = spawn_at
	active_chunks.clear()
	center = Vector2i(2147483647, 2147483647)

func coordinate(at: Vector2) -> Vector2i:
	return Vector2i(floori(at.x / preset.chunk_size.x), floori(at.y / preset.chunk_size.y))

func chunk_seed(coord: Vector2i) -> int:
	return ("%d:%s:%d:%d" % [seed_value, level_id, coord.x, coord.y]).hash()

func build_chunk(coord: Vector2i) -> Dictionary:
	if preset.chunk_size.x < 640 or preset.chunk_size.y < 360:
		return {"error": "无限地图区块至少需要 640×360 px", "tiles": [], "props": []}
	var area := Rect2(Vector2(coord * preset.chunk_size), Vector2(preset.chunk_size))
	var result := Layout.build(preset, chunk_seed(coord), area, spawn)
	result["coord"] = coord
	result["bounds"] = area
	result["seed"] = chunk_seed(coord)
	return result

func update(at: Vector2, radius := Vector2i(1, 1)) -> Dictionary:
	if preset.chunk_size.x < 640 or preset.chunk_size.y < 360:
		return {"added": {}, "removed": [], "chunks": active_chunks, "bounds": Rect2(), "error": "无限地图区块至少需要 640×360 px"}
	var next := coordinate(at)
	radius = radius.clamp(Vector2i.ONE, Vector2i(3, 3))
	var added := {}
	var removed: Array[Vector2i] = []
	var area := Rect2(Vector2((next - radius) * preset.chunk_size), Vector2((radius * 2 + Vector2i.ONE) * preset.chunk_size))
	if next == center and radius == last_radius:
		return {"added": added, "removed": removed, "chunks": active_chunks, "bounds": area, "error": ""}
	# Build the incoming strip before discarding existing chunks; failure keeps the last good field.
	for y in range(next.y - radius.y, next.y + radius.y + 1):
		for x in range(next.x - radius.x, next.x + radius.x + 1):
			var coord := Vector2i(x, y)
			if not active_chunks.has(coord):
				var data := build_chunk(coord)
				if not data.error.is_empty():
					return {"added": {}, "removed": [], "chunks": active_chunks, "bounds": area, "error": data.error}
				added[coord] = data
	for coord: Vector2i in active_chunks:
		if absi(coord.x - next.x) > radius.x or absi(coord.y - next.y) > radius.y:
			removed.append(coord)
	for coord in removed:
		active_chunks.erase(coord)
	active_chunks.merge(added)
	center = next
	last_radius = radius
	return {"added": added, "removed": removed, "chunks": active_chunks, "bounds": area, "error": ""}

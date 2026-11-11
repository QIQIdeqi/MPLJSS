@tool
extends Control

signal cell_pressed(cell: int, unlock: bool)

const Preset = preload("res://levels/preset.gd")
const BOUNDS := Preset.MAP_BOUNDS
var layout := {}
var preset: Preset
var spawn := Vector2(640, 450)

func _draw() -> void:
	if preset == null:
		return
	var map := preview_rect()
	var ratio := map.size / BOUNDS.size
	var tiles: Array = layout.get("tiles", [])
	for tile: Dictionary in tiles:
		var cell: Rect2 = tile.rect
		var target := Rect2(map.position + cell.position * ratio, cell.size * ratio)
		draw_texture_rect(tile.texture, target, false)
		draw_rect(target, Color(0.05, 0.08, 0.06, 0.26), false, 1)
	var props: Array = layout.get("props", []).duplicate()
	props.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.position.y < b.position.y)
	for prop: Dictionary in props:
		var foot: Vector2 = map.position + prop.position * ratio
		var art: Vector2 = prop.size * ratio
		draw_texture_rect(prop.texture, Rect2(foot - art * Vector2(0.5, prop.foot_fraction), art), false)
	var layers: Array[Dictionary] = [preset.locked_ground, preset.locked_props]
	for i in layers.size():
		var layer := layers[i]
		for cell: int in layer:
			if cell >= 0 and cell < tiles.size():
				var area: Rect2 = tiles[cell].rect
				var inset := 1.0 if i == 0 else 3.0
				var mark := Color.GOLD if i == 0 else Color.AQUAMARINE
				draw_rect(Rect2(map.position + area.position * ratio, area.size * ratio).grow(-inset), mark, false, 1)
	draw_circle(map.position + spawn * ratio, 4, Color.AQUAMARINE)
	if preset.boss:
		var center := map.position + BOUNDS.get_center() * ratio
		var arena := preset.arena_half_size() * ratio
		var points := PackedVector2Array()
		for i in 49:
			points.append(center + Vector2.from_angle(TAU * i / 48.0) * arena)
		draw_polyline(points, Color.CORAL, 1.0, true)
	else:
		draw_circle(map.position + preset.portal_position() * ratio, 4, Color.CORAL)
	var playable := preset.playable_bounds()
	var outline := Rect2(map.position + (playable.position - BOUNDS.position) * ratio, playable.size * ratio)
	draw_rect(outline, Color(0.22, 0.035, 0.05, 0.8), false, 3.0, true)
	draw_rect(outline, Color(1.0, 0.39, 0.44, 0.95), false, 1.25, true)

func _gui_input(event: InputEvent) -> void:
	if preset == null or not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index != MOUSE_BUTTON_LEFT and event.button_index != MOUSE_BUTTON_RIGHT:
		return
	var map := preview_rect()
	if map.has_point(event.position):
		var grid: Vector2i = preset.grid
		if grid.x <= 0 or grid.y <= 0:
			return
		var cell := Vector2i((event.position - map.position) / map.size * Vector2(grid))
		cell_pressed.emit(cell.y * grid.x + cell.x, event.button_index == MOUSE_BUTTON_RIGHT)
		accept_event()

func preview_rect() -> Rect2:
	var ratio := minf(size.x / BOUNDS.size.x, size.y / BOUNDS.size.y)
	var extent := BOUNDS.size * ratio
	return Rect2((size - extent) * 0.5, extent)

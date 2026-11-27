extends Node2D

const FX := preload("res://scripts/combo_fx_composition.gd")

var _fx := FX.new()


func show_effect(info: Dictionary) -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fx.show_effect(info)


func clear_effects() -> void:
	_fx.clear_effects()
	queue_redraw()


func _process(delta: float) -> void:
	if _fx.advance(delta):
		queue_redraw()


func _draw() -> void:
	for shape in _fx.shapes:
		var points: PackedVector2Array = shape.points
		var elevations: PackedFloat32Array = shape.get("elevations", PackedFloat32Array())
		if not elevations.is_empty():
			points = points.duplicate()
			for index in points.size():
				points[index].y -= (elevations[index] - FX.GROUND) * 0.65
		elif absf(float(shape.height) - FX.GROUND) > 1.0:
			var y_offset := Vector2.UP * (float(shape.height) - FX.GROUND) * 0.65
			points = points.duplicate()
			for index in points.size():
				points[index] += y_offset
		if not elevations.is_empty() and Geometry2D.triangulate_polygon(points).is_empty():
			continue
		draw_colored_polygon(points, shape.color)
	for card in _fx.cards:
		var at: Vector2 = card.at
		at.y -= maxf(float(card.height) - FX.GROUND, 0.0) * 0.65
		var size := Vector2.ONE * float(card.size)
		var frame := int(card.frame)
		var source := Vector2(posmod(frame, FX.COLS), floori(float(frame) / FX.COLS)) * FX.CELL
		draw_texture_rect_region(card.texture, Rect2(at - size * 0.5, size),
			Rect2(source, Vector2.ONE * FX.CELL), Color(1, 1, 1, float(card.opacity)))

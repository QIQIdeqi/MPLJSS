extends Button

signal ingredient_dropped(material: int, is_support: bool)

@export var material_id := -1
@export var is_support := false

func _get_drag_data(_position: Vector2) -> Variant:
	if material_id < 0 or disabled:
		return null
	var preview := TextureRect.new()
	preview.texture = icon
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.custom_minimum_size = Vector2(40, 40)
	set_drag_preview(preview)
	return {"material": material_id, "is_support": is_support}

func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	return not disabled and material_id < 0 and data is Dictionary and data.get("material") is int and data.get("is_support") == is_support

func _drop_data(_position: Vector2, data: Variant) -> void:
	ingredient_dropped.emit(data.material, is_support)

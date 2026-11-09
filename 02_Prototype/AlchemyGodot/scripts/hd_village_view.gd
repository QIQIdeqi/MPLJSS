extends CanvasLayer

const WORLD := preload("res://scripts/hd_village.gd")
var world_view: Node3D

func attach(village: Node2D) -> void:
	layer = -1
	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.handle_input_locally = false
	container.add_child(viewport)
	world_view = WORLD.new()
	viewport.add_child(world_view)
	world_view.setup(village.get_node("Actors/Lilita"), village.get_node("WalkBoundaries/RoadAndRiverbank").polygon)
	village.get_node("Backdrop").hide()
	village.get_node("Actors/Lilita/Art").hide()

func _process(delta: float) -> void:
	world_view.update_view(delta)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_T:
			world_view.preview_next_time()
		KEY_Y:
			world_view.preview_next_weather()
		KEY_V:
			world_view.street_view = not world_view.street_view
		_:
			return
	get_viewport().set_input_as_handled()

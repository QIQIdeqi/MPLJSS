extends CanvasLayer

const WORLD := preload("res://scripts/hd_battle_world.gd")
const GAMEPLAY_CANVAS_LAYER := 2

var world_view: WORLD
var source_viewport: Viewport
var previous_canvas_mask: int
var field: Node2D

func attach(source: Node2D) -> void:
	field = source
	layer = -1
	source_viewport = get_viewport()
	previous_canvas_mask = source_viewport.canvas_cull_mask
	# Share the physics canvas with a capture viewport, but keep the HUD on the game window.
	field.visibility_layer = GAMEPLAY_CANVAS_LAYER
	source_viewport.canvas_cull_mask &= ~(GAMEPLAY_CANVAS_LAYER | WORLD.SOURCE_HIDDEN_LAYER)
	tag_world_tree(field.get_node("Actors"))
	get_tree().node_added.connect(tag_added_world_item)
	var effects_capture := SubViewport.new()
	effects_capture.size = Vector2i(field.MAP.size)
	effects_capture.disable_3d = true
	effects_capture.transparent_bg = true
	effects_capture.canvas_cull_mask = GAMEPLAY_CANVAS_LAYER
	effects_capture.world_2d = source_viewport.find_world_2d()
	effects_capture.gui_disable_input = true
	effects_capture.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(effects_capture)

	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.gui_disable_input = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	world_view = WORLD.new()
	viewport.add_child(world_view)
	world_view.setup(field, effects_capture.get_texture())

func tag_world_tree(node: Node) -> void:
	if node is CanvasItem:
		node.visibility_layer = GAMEPLAY_CANVAS_LAYER
	for child in node.get_children():
		tag_world_tree(child)

func tag_added_world_item(node: Node) -> void:
	if node is CanvasItem and (field.get_node("Actors").is_ancestor_of(node) or node.get_parent() == field):
		node.visibility_layer = GAMEPLAY_CANVAS_LAYER

func _exit_tree() -> void:
	if is_instance_valid(source_viewport):
		source_viewport.canvas_cull_mask = previous_canvas_mask

func rebuild() -> void:
	world_view.rebuild()

func screen_at(point: Vector2) -> Vector2:
	return world_view.screen_at(point)

func _process(delta: float) -> void:
	if is_instance_valid(world_view):
		world_view.update_view(delta)

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_instance_valid(world_view) or world_view.field.brew.is_open() or world_view.field.portal_dialog.visible:
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_T:
			world_view.preview_next_time()
		KEY_Y:
			world_view.preview_next_weather()
		KEY_V:
			world_view.cycle_view_angle()
		_:
			return
	get_viewport().set_input_as_handled()

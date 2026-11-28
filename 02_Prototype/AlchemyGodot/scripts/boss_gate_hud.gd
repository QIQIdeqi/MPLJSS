extends Control

const GOLD := Color("#ffdc84")
const CAPPED := Color("#71decd")
const DARK := Color("#1b2221")
const BRANCH_RANGE := 1500.0
const SAFE_START := Vector2(26, 58)
const DOOR_RADIUS := 16.0
const SAFE_END_MARGIN := Vector2(220, 96)

var field: Node2D
var countdown: Label
var prompt: Label
var stay_hint: Label
var door_marker := Vector2.INF
var door_heading := Vector2.ZERO
var branch_marker := Vector2.INF
var capped := false

func _ready() -> void:
	countdown = make_label("Countdown", 19)
	prompt = make_label("Prompt", 19)
	stay_hint = make_label("StayHint", 16)
	add_child(countdown)
	add_child(prompt)
	add_child(stay_hint)
	countdown.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	countdown.offset_left = -180
	countdown.offset_right = 180
	countdown.offset_top = 92
	countdown.offset_bottom = 124

func make_label(label_name: String, font_size: int) -> Label:
	var label := Label.new()
	label.name = label_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", GOLD)
	label.add_theme_color_override("font_outline_color", DARK)
	label.add_theme_constant_override("outline_size", 7)
	return label

func attach(source: Node2D) -> void:
	field = source
	show()

func _process(_delta: float) -> void:
	if not is_instance_valid(field):
		return
	visible = field.stage_active and not field.ended
	if not visible:
		return
	var blocked: bool = field.world_controls_blocked() or get_tree().paused
	var can_interact: bool = field.can_interact_with_boss_gate()
	var opened: bool = field.portal_ready
	var door := project_point(field.portal_position)
	update_gate(field.boss_gate_threshold() - field.run_time, opened, door, can_interact, field.gate_cut_capped())
	if blocked:
		door_marker = Vector2.INF
	branch_marker = Vector2.INF if blocked else nearest_branch_marker()
	stay_hint.visible = field.field_events != null and field.field_events.origin_hint_left > 0.0 and not blocked
	if stay_hint.visible:
		position_label(stay_hint, "停留读条", project_point(field.player.position) + Vector2(0, 31))
	if can_interact and not field.first_gate_prompt:
		field.first_gate_prompt = true
		field.record_greyford("gate_prompt", {})
	queue_redraw()

func update_gate(remaining_s: float, opened: bool, door: Vector2, can_interact: bool, cut_capped: bool) -> void:
	capped = cut_capped
	countdown.text = "Boss 门开启 · %d 秒" % maxi(0, ceili(remaining_s))
	if opened:
		countdown.text = "Boss 门已开启" if not can_interact else "可挑战 Boss"
	prompt.visible = can_interact
	if can_interact:
		position_label(prompt, "F 挑战", door - Vector2(0, 72))
	door_marker = Vector2.INF
	if opened and not can_interact and not safe_rect().has_point(door):
		door_marker = pin_to_edge(door, DOOR_RADIUS + 1.0)
		door_heading = (door - safe_rect().get_center()).normalized()

func position_label(label: Label, value: String, center: Vector2) -> void:
	label.text = value
	label.reset_size()
	label.position = center - label.size * 0.5

func project_point(at: Vector2) -> Vector2:
	if is_instance_valid(field.hd_view):
		return field.hd_view.screen_at(at)
	return field.get_global_transform_with_canvas() * at

func safe_rect() -> Rect2:
	return Rect2(SAFE_START, (size - SAFE_START - SAFE_END_MARGIN).max(Vector2.ONE))

func pin_to_edge(at: Vector2, margin := 0.0) -> Vector2:
	var safe := safe_rect().grow(-margin)
	var center := safe.get_center()
	var direction := at - center
	var extent := safe.size * 0.5
	var scale := maxf(absf(direction.x) / extent.x, absf(direction.y) / extent.y)
	return center + direction / maxf(1.0, scale)

func nearest_branch_marker() -> Vector2:
	if field.field_events == null:
		return Vector2.INF
	var runtime = field.field_events
	var player_at: Vector2 = field.player.position
	var chunk: Vector2i = field.chunk_at(player_at)
	var best := BRANCH_RANGE * BRANCH_RANGE
	var target := Vector2.INF
	for coord: Vector2i in runtime.points:
		if coord == chunk or runtime.completed.has(coord):
			continue
		var at: Vector2 = runtime.points[coord]
		var distance := player_at.distance_squared_to(at)
		if distance <= best:
			best = distance
			target = at
	return pin_to_edge(project_point(target)) if target.is_finite() else Vector2.INF

func draw_diamond(at: Vector2, radius: float, fill: Color) -> void:
	var points := PackedVector2Array([at + Vector2.UP * radius, at + Vector2.RIGHT * radius,
		at + Vector2.DOWN * radius, at + Vector2.LEFT * radius, at + Vector2.UP * radius])
	draw_colored_polygon(points.slice(0, 4), fill)
	draw_polyline(points, DARK, 2.0, true)

func _draw() -> void:
	if branch_marker.is_finite():
		draw_diamond(branch_marker, 7.0, CAPPED if capped else GOLD)
	if door_marker.is_finite():
		draw_circle(door_marker, DOOR_RADIUS, DARK, true, -1.0, true)
		draw_arc(door_marker, DOOR_RADIUS, 0, TAU, 24, GOLD, 2.0, true)
		var lateral := door_heading.orthogonal() * 5.0
		draw_colored_polygon(PackedVector2Array([door_marker + door_heading * 10.0,
			door_marker - door_heading * 6.0 + lateral, door_marker - door_heading * 6.0 - lateral]), GOLD)

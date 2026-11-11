extends CharacterBody2D

enum Kind { SKELETON, BAT, SPIDER, WOLF, SLIME, MUSHROOM, WATER_SPIRIT }
enum State { CHASE, WINDUP, STRIKE, RECOVER }

const SPEEDS := [88.0, 107.0, 75.0, 119.0, 71.0, 63.0, 71.0]
const RANGES := [48.0, 110.0, 228.0, 90.0, 62.0, 186.0, 245.0]
const WINDUPS := [0.46, 0.49, 0.53, 0.42, 0.36, 0.68, 0.57]
const STRIKES := [0.18, 0.30, 0.18, 0.25, 0.34, 0.24, 0.24]
const RECOVERY := [0.72, 0.80, 1.15, 0.91, 0.83, 2.10, 1.42]
const WALK := [0, 1, 0, 2]
const SWING_RADIUS := 54.0
const SWING_HALF_ANGLE := 0.92
const DASH_SPEEDS := [0.0, 420.0, 0.0, 350.0, 180.0, 0.0, 0.0]
const SPORE_RADIUS := 47.0
const SLIME_RADIUS := 28.0
const DAMAGE := 9.0
const ART_SCALE := 0.86
const HURT_SECONDS := 0.18
const REACTIONS := [
	preload("res://art/enemies/reactions/skeleton.png"),
	preload("res://art/enemies/reactions/bat.png"),
	preload("res://art/enemies/reactions/spider.png"),
	preload("res://art/enemies/reactions/wolf.png"),
	preload("res://art/enemies/reactions/slime.png"),
	preload("res://art/enemies/reactions/mushroom.png"),
	preload("res://art/enemies/reactions/water_spirit.png"),
]
const REACTION_DIRECTION := [0, 1, 2, 1]
const REACTION_SCALES := [
	Vector2(0.98, 0.79), Vector2(0.86, 0.81), Vector2(0.86, 0.82),
	Vector2(0.80, 0.80), Vector2(0.72, 0.72), Vector2(0.70, 0.70), Vector2(0.74, 0.74),
]
const DEATH_SECONDS := [0.65, 0.72, 0.47, 0.68, 0.57, 0.62, 0.77]

var kind: Kind
var state := State.CHASE
var remaining := 0.0
var aim := Vector2.DOWN
var locked_target := Vector2.ZERO
var travel_bounds: Rect2
var facing := 0
var motion_time := 0.0
var tagged := false
var hop_blocked := false
var art: Sprite2D
var movement_atlas: Texture2D
var reaction_facing := 0
var hurt_left := 0.0
var dying := false
var death_tween: Tween

func setup(enemy_kind: int, bounds: Rect2, atlas: Texture2D) -> void:
	travel_bounds = bounds.grow(-14.0)
	kind = enemy_kind as Kind
	movement_atlas = atlas
	collision_layer = 4
	collision_mask = 0 if kind == Kind.BAT else 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var feet := CollisionShape2D.new()
	var radius := CircleShape2D.new()
	radius.radius = 9.0
	feet.shape = radius
	add_child(feet)
	art = Sprite2D.new()
	art.name = "Art"
	art.texture = atlas
	art.hframes = 4
	art.vframes = 4
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.offset.y = -34
	art.scale = Vector2.ONE * ART_SCALE
	add_child(art)
	update_art()

func advance(delta: float, player_pos: Vector2, hurt: Callable, fire_web: Callable, slow: float = 1.0) -> void:
	if dying:
		return
	hurt_left = maxf(0.0, hurt_left - delta)
	var offset := player_pos - global_position
	var distance := offset.length()
	var target_direction := offset.normalized() if distance > 0.1 else aim
	remaining -= delta
	match state:
		State.CHASE:
			facing = direction_row(target_direction)
			if distance <= RANGES[kind] and (kind == Kind.BAT or clear_path(player_pos)):
				aim = target_direction
				locked_target = player_pos
				state = State.WINDUP
				remaining = WINDUPS[kind]
				velocity = Vector2.ZERO
			else:
				velocity = target_direction * SPEEDS[kind] * slow
				move_and_slide()
				motion_time += delta
		State.WINDUP:
			if remaining <= 0.0:
				state = State.STRIKE
				remaining = STRIKES[kind]
				tagged = false
				hop_blocked = false
				match kind:
					Kind.SKELETON:
						if distance <= SWING_RADIUS and aim.dot(target_direction) >= cos(SWING_HALF_ANGLE) and clear_path(player_pos):
							hurt.call(DAMAGE, aim)
					Kind.SPIDER:
						fire_web.call(global_position, aim)
					Kind.MUSHROOM:
						fire_web.call(locked_target, aim, kind)
					Kind.WATER_SPIRIT:
						fire_web.call(global_position, aim, kind)
		State.STRIKE:
			if DASH_SPEEDS[kind] > 0.0:
				var start := global_position
				var movement: Vector2 = aim * DASH_SPEEDS[kind] * slow * clampf(remaining + delta, 0.0, delta)
				var obstacle := move_and_collide(movement) if not hop_blocked else null
				global_position = global_position.clamp(travel_bounds.position, travel_bounds.end)
				if obstacle:
					if kind == Kind.SLIME:
						hop_blocked = true
					else:
						remaining = 0.0
				if kind == Kind.SLIME:
					if remaining <= 0.0 and global_position.distance_squared_to(player_pos) <= SLIME_RADIUS * SLIME_RADIUS and clear_path(player_pos):
						hurt.call(DAMAGE, aim)
				elif not tagged:
					var nearest := Geometry2D.get_closest_point_to_segment(player_pos, start, global_position)
					if nearest.distance_squared_to(player_pos) <= 24.0 * 24.0 and (kind == Kind.BAT or clear_path(player_pos)):
						tagged = true
						hurt.call(DAMAGE, aim)
			if remaining <= 0.0:
				state = State.RECOVER
				remaining = RECOVERY[kind]
				velocity = Vector2.ZERO
		State.RECOVER:
			if remaining <= 0.0:
				state = State.CHASE
	update_art()
	queue_redraw()

func clear_path(goal: Vector2) -> bool:
	if global_position.is_equal_approx(goal):
		return true
	var ray := PhysicsRayQueryParameters2D.create(global_position, goal, 1)
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

static func direction_row(direction: Vector2) -> int:
	if absf(direction.x) > absf(direction.y):
		return 1 if direction.x > 0.0 else 3
	return 0 if direction.y >= 0.0 else 2

func show_hurt() -> void:
	if not dying:
		hurt_left = HURT_SECONDS
		reaction_facing = facing
		update_art()

func play_death() -> Tween:
	if dying:
		return death_tween
	dying = true
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	queue_redraw()
	var start_y := art.position.y
	reaction_facing = facing
	show_reaction_frame(1, 0)
	art.modulate = Color.WHITE
	death_tween = create_tween()
	death_tween.tween_method(func(progress: float) -> void:
		show_reaction_frame(1, 0 if progress < 0.42 else 1)
		art.position.y = lerpf(start_y, 0.0, smoothstep(0.0, 0.55, progress))
		art.modulate.a = 1.0 - smoothstep(0.66, 1.0, progress)
	, 0.0, 1.0, DEATH_SECONDS[kind])
	return death_tween

func show_reaction_frame(row: int, frame: int) -> void:
	if art.texture != REACTIONS[kind]:
		art.texture = REACTIONS[kind]
		art.hframes = 6
		art.vframes = 2
		art.offset.y = -36 if kind == Kind.WATER_SPIRIT else -34
	art.scale = Vector2.ONE * REACTION_SCALES[kind][row]
	art.flip_h = reaction_facing == 3
	art.frame_coords = Vector2i(REACTION_DIRECTION[reaction_facing] * 2 + frame, row)

func update_art() -> void:
	var frame_column := 0
	if state == State.STRIKE:
		frame_column = 2 if kind == Kind.SLIME else 3
	elif kind == Kind.SLIME and state == State.RECOVER and remaining > RECOVERY[kind] - 0.14:
		frame_column = 3
	elif state == State.WINDUP:
		frame_column = 1
	elif state == State.CHASE or kind == Kind.BAT:
		frame_column = WALK[int(motion_time * (13.0 if kind == Kind.BAT else 8.0)) % WALK.size()]
	art.position.y = 0.0
	if kind == Kind.BAT:
		art.position.y = -7.0 if state == State.STRIKE else -19.0 - sin(motion_time * 10.0) * 4.0
	elif kind == Kind.SLIME and state == State.STRIKE:
		art.position.y = -sin(PI * clampf(remaining / STRIKES[kind], 0.0, 1.0)) * 20.0
	art.modulate = Color(1.19, 1.08, 0.89) if state == State.WINDUP else Color.WHITE
	if hurt_left > 0.0:
		show_reaction_frame(0, 0 if hurt_left > HURT_SECONDS * 0.5 else 1)
		return
	if art.texture != movement_atlas:
		art.texture = movement_atlas
		art.hframes = 4
		art.vframes = 4
		art.offset.y = -34
		art.flip_h = false
		art.scale = Vector2.ONE * ART_SCALE
	art.frame_coords = Vector2i(frame_column, facing)

func _draw() -> void:
	if dying:
		return
	draw_set_transform(Vector2(0, 1), 0.0, Vector2(1.0, 0.39))
	draw_circle(Vector2.ZERO, 15.0 if kind == Kind.BAT else 13.0, Color(0.09, 0.07, 0.06, 0.36))
	draw_set_transform(Vector2.ZERO)
	if state != State.WINDUP and state != State.STRIKE:
		return
	match kind:
		Kind.SKELETON:
			var angle := aim.angle()
			var color := Color(1.0, 0.73, 0.32, 0.87)
			draw_arc(Vector2.ZERO, SWING_RADIUS, angle - SWING_HALF_ANGLE, angle + SWING_HALF_ANGLE, 20, color, 4.0 if state == State.STRIKE else 2.0, true)
		Kind.BAT:
			if state == State.WINDUP:
				draw_line(Vector2.ZERO, aim * DASH_SPEEDS[kind] * STRIKES[kind], Color(0.98, 0.45, 0.54, 0.79), 2.5, true)
		Kind.SPIDER:
			if state == State.WINDUP:
				draw_dashed_line(Vector2.ZERO, aim * 80.0, Color(0.88, 0.93, 1.0, 0.78), 2.0, 6.0)
		Kind.WOLF:
			if state == State.WINDUP:
				var end: Vector2 = aim * DASH_SPEEDS[kind] * STRIKES[kind]
				var color := Color("#ffc46e")
				draw_line(Vector2.ZERO, end, color, 2.0, true)
				draw_polyline(PackedVector2Array([end - aim.rotated(0.6) * 11.0, end, end - aim.rotated(-0.6) * 11.0]), color, 2.0, true)
		Kind.SLIME:
			if state == State.WINDUP:
				var landing: Vector2 = aim * DASH_SPEEDS[kind] * STRIKES[kind]
				draw_arc(landing, SLIME_RADIUS, 0.0, TAU, 24, Color("#78e9af"), 2.0, true)
		Kind.MUSHROOM:
			if state == State.WINDUP:
				draw_arc(to_local(locked_target), SPORE_RADIUS, 0.0, TAU, 32, Color("#dbaeeb"), 2.0, true)
		Kind.WATER_SPIRIT:
			if state == State.WINDUP:
				draw_dashed_line(Vector2.ZERO, aim * 115.0, Color("#76dbff"), 2.0, 7.0)

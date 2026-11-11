extends Node2D

const ART := preload("res://art/boss_corruption.png")
const REACTION := preload("res://art/enemies/reactions/boss.png")
const ATTACK := preload("res://audio/S_BossAttack.wav")
const LOCK := preload("res://audio/BossLock.wav")
const START := Vector2(640, 270)
const DASH_DISTANCE := 240.0
const DASH_SPEED := 400.0
const SHOT_SPEED := 160.0
const BOUNDS := Rect2(50, 105, 1180, 550)
const RADIUS := 22.0
const MAX_HP := 6000.0 / 18.0

enum Phase { AIM_DASH, DASH, AIM_FAN, SECOND_FAN, RECOVER }

var body: CharacterBody2D
var art: Sprite2D
var sound: AudioStreamPlayer
var entry: Dictionary
var preparation := 2.0
var phase: Phase
var elapsed := 0.0
var aim := Vector2.DOWN
var locked := false
var dash_remaining := DASH_DISTANCE
var dash_hit := false
var next_dash := false
var shots: Array[Dictionary] = []
var wave := 0
var travel_bounds := BOUNDS
var dying := false
var art_motion: Tween
var art_scale := 86.0 / ART.get_height()

func setup(actors: Node2D, dash_first: bool, playable_bounds: Rect2 = BOUNDS) -> void:
	travel_bounds = BOUNDS.intersection(playable_bounds)
	body = CharacterBody2D.new()
	body.collision_layer = 4
	body.collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	body.add_child(shape)
	art = Sprite2D.new()
	art.texture = ART
	art.scale = Vector2.ONE * art_scale
	art.offset.y = -ART.get_height() * (208.0 / 448.0)
	body.add_child(art)
	actors.add_child(body)
	body.position = START
	entry = {"body": body, "hp": MAX_HP, "boss": true}
	sound = AudioStreamPlayer.new()
	sound.volume_db = -13
	add_child(sound)
	next_dash = dash_first
	start_attack()

func show_hurt() -> void:
	if dying:
		return
	if art_motion:
		art_motion.kill()
	show_reaction_frame(0, 0)
	art_motion = create_tween()
	art_motion.tween_method(func(progress: float) -> void:
		show_reaction_frame(0, mini(2, floori(progress * 3.0)))
	, 0.0, 1.0, 0.24)
	art_motion.tween_callback(restore_base_art)

func play_death() -> Tween:
	if dying:
		return art_motion
	dying = true
	shots.clear()
	sound.stop()
	body.velocity = Vector2.ZERO
	body.set_deferred("collision_layer", 0)
	body.set_deferred("collision_mask", 0)
	queue_redraw()
	if art_motion:
		art_motion.kill()
	show_reaction_frame(1, 0)
	art_motion = create_tween()
	art_motion.tween_method(func(progress: float) -> void:
		show_reaction_frame(1, mini(4, floori(progress * 5.5)))
		art.modulate.a = 1.0 - smoothstep(0.77, 1.0, progress)
	, 0.0, 1.0, 0.76)
	return art_motion

func show_reaction_frame(row: int, column: int) -> void:
	if art.texture != REACTION:
		art.texture = REACTION
		art.hframes = 5
		art.vframes = 2
		art.offset.y = -73
		art.scale = Vector2.ONE * 0.54
	art.frame_coords = Vector2i(column, row)

func restore_base_art() -> void:
	art.texture = ART
	art.hframes = 1
	art.vframes = 1
	art.offset.y = -208
	art.scale = Vector2.ONE * art_scale

func advance(delta: float, player: CharacterBody2D, hurt: Callable, burst: Callable) -> void:
	if dying:
		return
	if preparation > 0.0:
		preparation = maxf(0, preparation - delta)
		return
	elapsed += delta
	var direction := body.position.direction_to(player.position)
	if not direction.is_zero_approx() and not locked and phase != Phase.DASH:
		aim = direction
	art.flip_h = aim.x < 0.0
	match phase:
		Phase.AIM_DASH:
			lock_aim(0.6)
			if elapsed >= 1.0:
				phase = Phase.DASH
				dash_remaining = DASH_DISTANCE
				dash_hit = false
				play(ATTACK)
				burst.call(body.position, Color(1, 0.4, 0.1))
		Phase.DASH:
			var before := body.position
			var step := minf(delta * DASH_SPEED, dash_remaining)
			var movement := aim * step
			var next := (before + movement).clamp(travel_bounds.position, travel_bounds.end)
			var collision := body.move_and_collide(next - before)
			dash_remaining -= step
			if not dash_hit and Geometry2D.get_closest_point_to_segment(player.position, before, body.position).distance_to(player.position) <= 29.0:
				dash_hit = hurt.call(24.0, aim)
			if collision or next != before + movement or dash_remaining <= 0.0:
				recover()
		Phase.AIM_FAN:
			lock_aim(0.95)
			if elapsed >= 1.25:
				fire()
				phase = Phase.SECOND_FAN
				elapsed = 0.0
				locked = false
		Phase.SECOND_FAN:
			lock_aim(0.5)
			if elapsed >= 0.8:
				fire()
				recover()
		Phase.RECOVER:
			if elapsed >= 1.0:
				start_attack()
	for i in range(shots.size() - 1, -1, -1):
		var shot := shots[i]
		if shot.fade >= 0.0:
			shot.fade -= delta
			if shot.fade <= 0.0:
				shots.remove_at(i)
			continue
		var before: Vector2 = shot.point
		shot.point += shot.direction * SHOT_SPEED * delta
		shot.life -= delta
		if shot.life <= 0.0 or not travel_bounds.has_point(shot.point) or wall_hit(before, shot.point) != shot.point:
			shots.remove_at(i)
			continue
		if Geometry2D.get_closest_point_to_segment(player.position, before, shot.point).distance_to(player.position) <= 15.0 and hurt.call(18.0, Vector2.ZERO):
			for sibling in shots:
				if sibling.wave == shot.wave:
					sibling.fade = 0.15
	queue_redraw()

func start_attack() -> void:
	phase = Phase.AIM_DASH if next_dash else Phase.AIM_FAN
	next_dash = not next_dash
	elapsed = 0.0
	locked = false

func lock_aim(at: float) -> void:
	if elapsed >= at and not locked:
		locked = true
		play(LOCK)

func recover() -> void:
	phase = Phase.RECOVER
	elapsed = 0.0
	locked = false

func fire() -> void:
	wave += 1
	for i in 5:
		shots.append({"point": body.position, "direction": aim.rotated(deg_to_rad(-30 + i * 15)), "life": 5.0, "fade": -1.0, "wave": wave})
	play(ATTACK)

func play(stream: AudioStream) -> void:
	sound.stream = stream
	sound.play()

func wall_hit(from: Vector2, to: Vector2) -> Vector2:
	var ray := PhysicsRayQueryParameters2D.create(from, to, 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(ray)
	return hit.get("position", to)

func _draw() -> void:
	if dying or not is_instance_valid(body):
		return
	if preparation <= 0.0 and phase == Phase.AIM_DASH:
		var side := aim.orthogonal() * 20.0
		var travel := aim * DASH_DISTANCE
		if body.test_move(body.transform, travel):
			var low := 0.0
			var high := 1.0
			for i in 8:
				var mid := (low + high) * 0.5
				if body.test_move(body.transform, travel * mid):
					high = mid
				else:
					low = mid
			travel *= low
		var end := (body.position + travel).clamp(travel_bounds.position, travel_bounds.end)
		var tint := Color(1.0, 0.38, 0.12, 0.95)
		draw_line(body.position - side, body.position + side, tint, 2, true)
		draw_line(end - side, end + side, tint, 2, true)
		for offset in [side, -side]:
			if locked:
				draw_line(body.position + offset, end + offset, tint, 2, true)
			else:
				draw_dashed_line(body.position + offset, end + offset, tint, 2, 9, true, true)
	elif preparation <= 0.0 and (phase == Phase.AIM_FAN or (phase == Phase.SECOND_FAN and locked)):
		for i in 5:
			var end := (body.position + aim.rotated(deg_to_rad(-30 + i * 15)) * SHOT_SPEED * 5.0).clamp(travel_bounds.position, travel_bounds.end)
			draw_line(body.position, wall_hit(body.position, end), Color(0.15, 0.9, 1.0, 0.5), 3, true)
	for shot in shots:
		var alpha: float = 1.0 if shot.fade < 0.0 else shot.fade / 0.15
		draw_circle(shot.point, 9, Color(0.2, 0.85, 1.0, alpha * 0.23))
		draw_line(shot.point - shot.direction * 13.0, shot.point, Color(0.52, 0.95, 1.0, alpha), 4, true)

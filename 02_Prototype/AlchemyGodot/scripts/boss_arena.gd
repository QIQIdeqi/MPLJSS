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
const HIT_FLASH_SECONDS := 0.1
const HIT_FLASH_TINT := Color(2.0, 0.18, 0.16, 1.0)
const HIT_FLASH_SHADER := preload("res://shaders/monster_hit_flash_2d.gdshader")
const VARIANT_ART := [ART,
	preload("res://art/enemies/spider.png"), preload("res://art/enemies/mushroom.png"),
	preload("res://art/enemies/bat.png"), ART]
const VARIANT_REACTION := [REACTION,
	preload("res://art/enemies/reactions/spider.png"), preload("res://art/enemies/reactions/mushroom.png"),
	preload("res://art/enemies/reactions/bat.png"), REACTION]
const HEALTH := [MAX_HP, 400.0, 460.0, 500.0, 600.0]

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
var boss_style := 0
var display_name := "腐化之源"
var max_hp := MAX_HP
var zones: Array[Dictionary] = []
var target := Vector2.ZERO
var dash_chain := 0

func setup(actors: Node2D, dash_first: bool, playable_bounds: Rect2 = BOUNDS, style: int = 0, title: String = "腐化之源") -> void:
	boss_style = clampi(style, 0, 4)
	display_name = title
	max_hp = HEALTH[boss_style]
	travel_bounds = BOUNDS.intersection(playable_bounds)
	body = CharacterBody2D.new()
	body.collision_layer = 4
	body.collision_mask = 0 if boss_style == 3 else 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	body.add_child(shape)
	art = Sprite2D.new()
	var flash_material := ShaderMaterial.new()
	flash_material.shader = HIT_FLASH_SHADER
	art.material = flash_material
	restore_base_art()
	body.add_child(art)
	actors.add_child(body)
	body.position = START.clamp(travel_bounds.position + Vector2(25, 25), travel_bounds.end - Vector2(25, 25))
	entry = {"body": body, "hp": max_hp, "boss": true}
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
	art.modulate = HIT_FLASH_TINT
	art.material.set_shader_parameter("flash", 1.0)
	art_motion = create_tween()
	art_motion.tween_method(func(progress: float) -> void:
		show_reaction_frame(0, mini(2, floori(progress * 3.0)))
		art.modulate = HIT_FLASH_TINT if progress * 0.24 < HIT_FLASH_SECONDS else Color.WHITE
		art.material.set_shader_parameter("flash", 1.0 if progress * 0.24 < HIT_FLASH_SECONDS else 0.0)
	, 0.0, 1.0, 0.24)
	art_motion.tween_callback(restore_base_art)

func play_death() -> Tween:
	if dying:
		return art_motion
	var flash_on_death := art.modulate == HIT_FLASH_TINT
	dying = true
	shots.clear()
	zones.clear()
	sound.stop()
	body.velocity = Vector2.ZERO
	body.set_deferred("collision_layer", 0)
	body.set_deferred("collision_mask", 0)
	queue_redraw()
	if art_motion:
		art_motion.kill()
	show_reaction_frame(1, 0)
	art.modulate = HIT_FLASH_TINT if flash_on_death else Color.WHITE
	art.material.set_shader_parameter("flash", 1.0 if flash_on_death else 0.0)
	art_motion = create_tween()
	art_motion.tween_method(func(progress: float) -> void:
		show_reaction_frame(1, mini(4, floori(progress * 5.5)))
		art.modulate = HIT_FLASH_TINT if flash_on_death and progress * 0.76 < HIT_FLASH_SECONDS else Color.WHITE
		art.material.set_shader_parameter("flash", 1.0 if flash_on_death and progress * 0.76 < HIT_FLASH_SECONDS else 0.0)
		art.modulate.a = 1.0 - smoothstep(0.77, 1.0, progress)
	, 0.0, 1.0, 0.76)
	return art_motion

func show_reaction_frame(row: int, column: int) -> void:
	var atlas: Texture2D = VARIANT_REACTION[boss_style]
	if art.texture != atlas:
		art.texture = atlas
		art.hframes = 5 if boss_style in [0, 4] else 6
		art.vframes = 2
		art.offset.y = -73 if boss_style in [0, 4] else -34
		art.scale = Vector2.ONE * (0.54 if boss_style in [0, 4] else 1.35)
	art.frame_coords = Vector2i(column if boss_style in [0, 4] else mini(column, 1), row)

func restore_base_art() -> void:
	art.modulate = Color.WHITE
	art.material.set_shader_parameter("flash", 0.0)
	art.texture = VARIANT_ART[boss_style]
	art.hframes = 1 if boss_style in [0, 4] else 4
	art.vframes = 1 if boss_style in [0, 4] else 4
	art.frame = 0
	art.offset.y = -208 if boss_style in [0, 4] else -34
	art_scale = 86.0 / ART.get_height() if boss_style in [0, 4] else 1.35
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
		target = player.position
	art.flip_h = aim.x < 0.0
	match phase:
		Phase.AIM_DASH:
			lock_aim(0.6)
			if elapsed >= 1.0:
				phase = Phase.DASH
				dash_remaining = attack_distance()
				dash_hit = false
				play(ATTACK)
				burst.call(body.position, Color(1, 0.4, 0.1))
		Phase.DASH:
			var before := body.position
			var step := minf(delta * (460.0 if boss_style == 3 else DASH_SPEED), dash_remaining)
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
				if boss_style in [2, 4]:
					recover()
				else:
					phase = Phase.SECOND_FAN
					elapsed = 0.0
					locked = false
		Phase.SECOND_FAN:
			lock_aim(0.5)
			if elapsed >= 0.8:
				fire()
				recover()
		Phase.RECOVER:
			var rest := (0.45 if dash_chain == 0 else 1.5) if boss_style == 3 else (2.0 if boss_style == 2 else 1.0)
			if elapsed >= rest:
				if boss_style == 3 and dash_chain == 0:
					dash_chain = 1
					phase = Phase.AIM_DASH
					elapsed = 0.0
					locked = false
				else:
					dash_chain = 0
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
	for i in range(zones.size() - 1, -1, -1):
		var zone := zones[i]
		zone.remaining -= delta
		zone.next_hit -= delta
		if zone.remaining <= 0.0:
			zones.remove_at(i)
		elif zone.remaining <= zone.active_seconds and zone.next_hit <= 0.0 and player.position.distance_to(zone.position) <= zone.radius:
			zone.next_hit = 0.7
			hurt.call(12.0 if boss_style == 1 else 18.0, Vector2.ZERO)
	queue_redraw()

func start_attack() -> void:
	phase = Phase.AIM_DASH if boss_style == 3 or (boss_style in [0, 4] and next_dash) else Phase.AIM_FAN
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
	if boss_style in [0, 1]:
		for i in 5:
			shots.append({"point": body.position, "direction": aim.rotated(deg_to_rad(-30 + i * 15)), "life": 5.0, "fade": -1.0, "wave": wave})
	if boss_style == 1:
		add_zone(target, 63.0, 1.1, 2.8)
	elif boss_style == 2:
		# 六个方位留一条持续可读的缺口；第二次释放旋转覆盖顺序。
		for i in 5:
			var angle := TAU * float(i + wave) / 6.0
			add_zone(travel_bounds.get_center() + Vector2(cos(angle) * 175.0, sin(angle) * 112.0), 64.0, 1.15, 1.6)
	elif boss_style == 4:
		# 三个分区仅标记两个，给横移留出口；形象仍用现有首领占位。
		for i in 3:
			if i != wave % 3:
				add_zone(Vector2(travel_bounds.position.x + travel_bounds.size.x * (float(i) + 0.5) / 3.0, travel_bounds.get_center().y), minf(105.0, travel_bounds.size.y * 0.28), 1.25, 1.4)
	play(ATTACK)

func add_zone(at: Vector2, radius: float, warning: float, active_seconds: float) -> void:
	zones.append({"position": at.clamp(travel_bounds.position + Vector2.ONE * radius, travel_bounds.end - Vector2.ONE * radius),
		"radius": radius, "remaining": warning + active_seconds, "active_seconds": active_seconds, "next_hit": warning})

func attack_distance() -> float:
	return 300.0 if boss_style == 3 else DASH_DISTANCE

func attack_hint() -> String:
	return ["横向躲冲锋 · 穿过扇形弹间隙", "避开扇面蛛丝 · 提前绕出落网圈", "观察孢子顺序 · 向缺口转区", "诱导俯冲 · 横移应对二次转向", "横移让冲锋 · 进入未标记分区"][boss_style]

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
		var travel := aim * attack_distance()
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
	elif preparation <= 0.0 and boss_style in [0, 1] and (phase == Phase.AIM_FAN or (phase == Phase.SECOND_FAN and locked)):
		for i in 5:
			var end := (body.position + aim.rotated(deg_to_rad(-30 + i * 15)) * SHOT_SPEED * 5.0).clamp(travel_bounds.position, travel_bounds.end)
			draw_line(body.position, wall_hit(body.position, end), Color(0.15, 0.9, 1.0, 0.5), 3, true)
	for shot in shots:
		var alpha: float = 1.0 if shot.fade < 0.0 else shot.fade / 0.15
		draw_circle(shot.point, 9, Color(0.2, 0.85, 1.0, alpha * 0.23))
		draw_line(shot.point - shot.direction * 13.0, shot.point, Color(0.52, 0.95, 1.0, alpha), 4, true)
	for zone in zones:
		var active: bool = zone.remaining <= zone.active_seconds
		var tint := Color(0.79, 0.63, 0.91, 0.25 if active else 0.08) if boss_style == 2 else Color(0.93, 0.67, 0.43, 0.24 if active else 0.07)
		draw_circle(zone.position, zone.radius, tint)
		draw_arc(zone.position, zone.radius, 0.0, TAU, 40, Color(tint, 0.85), 3.0 if active else 1.5, true)

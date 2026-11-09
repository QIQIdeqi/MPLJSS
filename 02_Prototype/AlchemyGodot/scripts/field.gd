extends Node2D

const ENEMIES := [preload("res://art/enemy0.png"), preload("res://art/enemy1.png"), preload("res://art/enemy2.png"), preload("res://art/enemy3.png")]
const DROPS := [preload("res://art/coin.png"), preload("res://art/xp.png")]
const HD_VILLAGE := preload("res://scripts/hd_village_view.gd")
const BREW := preload("res://scenes/brew.tscn")
const BOSS := preload("res://scenes/boss_arena.tscn")
const FX := preload("res://scripts/battle_fx.gd")
const LEVEL_LAYOUT := preload("res://scripts/level_layout.gd")
const NORMAL_LAYOUT := preload("res://levels/normal.tres")
const BOSS_LAYOUT := preload("res://levels/boss.tres")
const GATE := Vector2(1155, 329)
const PORTAL := Vector2(1120, 330)
const SPAWN := Vector2(640, 430)
const BOSS_SPAWN := Vector2(640, 450)
const MAP := Rect2(0, 0, 1280, 720)
const CAMERA_ZOOM := 1.45

@export var combat := false
@export var field_seed: int = 0
@export_range(0, 600) var portal_open_seconds := 300.0
@export var save_path := "user://progress.cfg"
@onready var actors: Node2D = $Actors
@onready var player = $Actors/Lilita
@onready var status: Label = $Interface/Status
@onready var hint: Label = $Interface/Hint
@onready var music: AudioStreamPlayer = $Music

var rng := RandomNumberGenerator.new()
var tiles: Array = []
var enemies: Array[Dictionary] = []
var pickups: Array[Dictionary] = []
var props: Array[Node2D] = []
var blocks: Array[StaticBody2D] = []
var run_time := 0.0
var until_spawn := 2.6
var until_attack := 0.0
var hurt_cooldown := 0.0
var hp := 120.0
var xp := 0
var coins := 0
var level := 1
var kills := 0
var enemy_death_sound: AudioStreamPlayer
var inventory := [0, 0, 0, 0, 0, 0]
var brew
var boss
var effects: Node2D
var camera: Camera2D
var portal: Node2D
var portal_dialog: ConfirmationDialog
var portal_ready := false
var ended := false
var first_brew := false
var opening_supply_eligible := false
var save := ConfigFile.new()

func _ready() -> void:
	if not OS.get_cmdline_user_args().has("--migration-test"):
		save.load(save_path)
	camera = Camera2D.new()
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	add_child(camera)
	update_camera(0)
	effects = Node2D.new()
	effects.y_sort_enabled = true
	actors.add_child(effects)
	if combat:
		if field_seed == 0:
			rng.randomize()
		else:
			rng.seed = field_seed
		if not generate_field(false, rng.seed):
			finish(false)
			return
		enemy_death_sound = AudioStreamPlayer.new()
		enemy_death_sound.stream = preload("res://audio/S_EnemyDeath.wav")
		enemy_death_sound.volume_db = -16
		add_child(enemy_death_sound)
		brew = BREW.instantiate()
		$Interface.add_child(brew)
		brew.attach(self)
		brew.brew_settled.connect(on_brew_settled)
		first_brew = not bool(save.get_value("tutorial", "brew_introduced", false))
		opening_supply_eligible = not first_brew
		if first_brew:
			for i in 3:
				inventory[i] = 1
			save.set_value("tutorial", "brew_introduced", true)
			persist()
		portal_dialog = ConfirmationDialog.new()
		portal_dialog.title = "Boss 挑战"
		portal_dialog.dialog_text = "进入雾界草甸挑战腐化之源？\n保留当前生命、材料和丹药，挑战结束后结算。"
		portal_dialog.ok_button_text = "进入挑战"
		portal_dialog.cancel_button_text = "继续探索"
		portal_dialog.exclusive = true
		portal_dialog.confirmed.connect(enter_boss)
		$Interface.add_child(portal_dialog)
		for i in 8:
			spawn_enemy()
		play_music(preload("res://audio/Music_Field.wav"))
	else:
		if DisplayServer.get_name() != "headless":
			var view := HD_VILLAGE.new()
			add_child(view)
			view.attach(self)
		play_music(preload("res://audio/Music_Village.wav"))

func play_music(stream: AudioStreamWAV) -> void:
	var loop := stream.duplicate() as AudioStreamWAV
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_end = roundi(loop.get_length() * loop.mix_rate)
	music.stream = loop
	music.play()

func generate_field(boss_stage: bool, layout_seed: int) -> bool:
	var layout: Dictionary = LEVEL_LAYOUT.build(BOSS_LAYOUT if boss_stage else NORMAL_LAYOUT, layout_seed, MAP, BOSS_SPAWN if boss_stage else SPAWN)
	if not layout.error.is_empty():
		push_error(layout.error)
		return false
	for prop in props:
		prop.queue_free()
	for block in blocks:
		remove_child(block)
		block.queue_free()
	props.clear()
	blocks.clear()
	tiles = layout.tiles
	for prop in layout.props:
		props.append(make_sprite(prop.texture, prop.position, prop.size, prop.foot_fraction))
		if prop.collision != Vector2.ZERO:
			add_block(prop.position, prop.collision)
	queue_redraw()
	return true

func add_block(at: Vector2, size: Vector2) -> void:
	var block := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	shape.shape = rectangle
	block.add_child(shape)
	add_child(block)
	block.position = at
	blocks.append(block)

func _draw() -> void:
	if combat:
		for tile in tiles:
			draw_texture_rect(tile.texture, tile.rect, false)

func make_sprite(texture: Texture2D, at: Vector2, size: Vector2, foot_fraction := 0.38) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.scale = size / texture.get_size()
	sprite.offset.y = -texture.get_height() * foot_fraction
	actors.add_child(sprite)
	sprite.position = at
	return sprite

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if not combat and player.position.distance_to(GATE) < 92:
			get_tree().change_scene_to_file("res://scenes/battle.tscn")
		elif ended:
			get_tree().change_scene_to_file("res://scenes/village.tscn")
		elif portal_ready and player.position.distance_to(PORTAL) < 60 and not brew.is_open():
			portal_dialog.popup_centered()
			get_viewport().set_input_as_handled()
	if event.is_action_pressed("ui_cancel") and not combat:
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
	if combat and not ended and not portal_dialog.visible and (event.is_action_pressed("alchemy") or (event.is_action_pressed("ui_cancel") and brew.is_open())):
		brew.toggle()
		get_viewport().set_input_as_handled()

func update_camera(delta: float) -> void:
	var target: Vector2 = player.position + Vector2(0, -16)
	var zoom := CAMERA_ZOOM
	if is_instance_valid(boss) and is_instance_valid(boss.body) and (boss.preparation > 0.0 or player.position.distance_to(boss.body.position) < 320.0):
		var player_art: Vector2 = player.position - Vector2(0, 38)
		var boss_art: Vector2 = boss.body.position - Vector2(0, 42)
		target = (player_art + boss_art) * 0.5
		var spacing := (player_art - boss_art).abs() + Vector2(165, 175)
		zoom = minf(zoom, minf(1050.0 / spacing.x, 535.0 / spacing.y))
	var canvas := get_viewport_rect().size
	zoom = maxf(zoom, maxf(canvas.x / MAP.size.x, canvas.y / MAP.size.y))
	var weight := 1.0 if delta <= 0 else 1.0 - exp(-10.0 * delta)
	camera.zoom = camera.zoom.lerp(Vector2.ONE * zoom, weight)
	var half_view := canvas / camera.zoom * 0.5
	var motion := target - camera.position
	var deadzone := 0.0 if delta <= 0 else 6.0
	var desired := camera.position + motion.sign() * (motion.abs() - Vector2.ONE * deadzone).max(Vector2.ZERO)
	camera.position = camera.position.lerp(desired, weight).clamp(MAP.position + half_view, MAP.end - half_view)

func _physics_process(delta: float) -> void:
	update_camera(delta)
	if not combat:
		status.text = "格雷弗德村庄   ·   金币 %d" % int(save.get_value("village", "coins", 0))
		hint.text = "F  穿过雾门" if player.position.distance_to(GATE) < 92 else "WASD 移动   ·   前往右侧雾门   ·   T 时段  ·  Y 天气   ·   V 切换视角   ·   Esc 返回开始界面"
		return
	if ended:
		player.locked = true
		return
	var paused: bool = brew.blocks_world() or portal_dialog.visible
	player.locked = paused or (is_instance_valid(boss) and boss.preparation > 0.0)
	status.text = "%s   ·   生命 %d / 120   ·   等级 %d   ·   经验 %d / %d   ·   金币 %d   ·   %02d:%02d" % [
		"雾界草甸" if boss else "村庄外围", ceili(hp), level, xp, level * 6, coins, floori(run_time / 60.0), int(run_time) % 60]
	if paused:
		return
	hurt_cooldown = maxf(0.0, hurt_cooldown - delta)
	if boss:
		hint.text = "腐化之源   ·   %s" % ("准备 %d" % ceili(boss.preparation) if boss.preparation > 0 else "生命 %d%%   ·   橙色冲锋 / 蓝色扇形弹   ·   Q 炼金" % ceili(float(boss.entry.hp) * 100.0 / boss.MAX_HP))
		boss.advance(delta, player, hurt, burst)
		if ended or boss.preparation > 0:
			return
	else:
		run_time += delta
		if not portal_ready and run_time >= portal_open_seconds:
			portal_ready = true
			portal = FX.portal(effects, PORTAL)
		update_field_hint()
		until_spawn -= delta
		if until_spawn <= 0 and enemies.size() < 48:
			spawn_enemy()
			until_spawn = maxf(0.25, 1.25 - run_time * 0.011)
		for entry in enemies:
			var body: CharacterBody2D = entry.body
			var offset: Vector2 = player.position - body.position
			var slow_left := maxf(0, float(entry.get("slow_left", 0.0)) - delta)
			entry.slow_left = slow_left
			body.velocity = offset.normalized() * 92.0 * (float(entry.get("slow_factor", 1.0)) if slow_left > 0 else 1.0)
			body.move_and_slide()
			if offset.length_squared() < 27.0 * 27.0:
				hurt(9.0)
				if ended:
					return
	until_attack -= delta
	if until_attack <= 0:
		var nearest: Dictionary = {}
		var reach := 148.0
		for entry in enemies:
			var dist: float = player.position.distance_to(entry.body.position)
			if dist < reach:
				reach = dist
				nearest = entry
		if not nearest.is_empty():
			until_attack = 0.47
			attack_feedback(nearest.body.position)
			damage_enemy(nearest, 1.0 + float((level - 1) / 3))
	if ended:
		return
	brew.cast_equipped(delta, player.position, enemies, damage_brew_enemy)
	for i in range(pickups.size() - 1, -1, -1):
		var pickup := pickups[i]
		var art: Sprite2D = pickup.sprite
		art.offset.y = -art.texture.get_height() * (0.35 + 0.13 * sin(run_time * 7 + i))
		if is_instance_valid(pickup.motes):
			FX.update_xp_motes(art, pickup.motes)
		if art.position.distance_to(player.position) <= 46:
			if pickup.kind == 0:
				coins += 1
			else:
				xp += 1
				if xp >= level * 6:
					xp -= level * 6
					level += 1
			art.queue_free()
			pickups.remove_at(i)

func update_field_hint() -> void:
	if portal_ready:
		var difference: Vector2 = PORTAL - player.position
		if difference.length() < 60:
			hint.text = "F  进入 Boss 传送阵   ·   可继续探索"
		else:
			var direction: String = ["→", "↘", "↓", "↙", "←", "↖", "↑", "↗"][posmod(roundi(difference.angle() / (PI / 4)), 8)]
			hint.text = "%s Boss 传送阵已开放   ·   靠近按 F   ·   Q 炼金" % direction
	elif first_brew:
		hint.text = "首局材料已备好   ·   WASD 移动 / Space 闪避   ·   Q 选择主材与辅材，制成第一颗丹药"
	else:
		hint.text = "WASD 移动   ·   Space 闪避   ·   Q 炼金   ·   自动攻击"

func enter_boss() -> void:
	if ended or boss or not portal_ready or player.position.distance_to(PORTAL) >= 60 or brew.is_open():
		return
	if not generate_field(true, int(rng.randi()) + 1):
		hint.text = "Boss 场地生成失败，可继续探索"
		return
	brew.clear_projectiles()
	for entry in enemies:
		entry.body.queue_free()
	enemies.clear()
	for pickup in pickups:
		pickup.sprite.queue_free()
	pickups.clear()
	for fx in effects.get_children():
		fx.queue_free()
	portal = null
	portal_ready = false
	player.position = BOSS_SPAWN
	player.dodge = 0.0
	player.locked = true
	boss = BOSS.instantiate()
	add_child(boss)
	boss.setup(actors, rng.randf() < 0.5)
	enemies.append(boss.entry)
	update_camera(0.0)
	play_music(preload("res://audio/Music_Boss.wav"))

func on_brew_settled(accepted: bool, result: Dictionary) -> void:
	if not accepted:
		return
	first_brew = false
	var discoveries: Array = save.get_value("tutorial", "recipes", [])
	if not discoveries.has(result.skill):
		discoveries.append(result.skill)
		save.set_value("tutorial", "recipes", discoveries)
		persist()

func persist() -> bool:
	return OS.get_cmdline_user_args().has("--migration-test") or save.save(save_path) == OK

func hurt(amount: float, knock_direction := Vector2.ZERO) -> bool:
	if ended or hurt_cooldown > 0 or player.dodge > 0:
		return false
	hurt_cooldown = 0.55
	hp = maxf(0.0, hp - amount)
	if hp <= 0:
		player.show_death()
		finish(false)
	else:
		player.show_hurt()
		if not knock_direction.is_zero_approx():
			player.knockback = knock_direction * 133.333
			player.knockback_time = 0.15
	return true

func spawn_enemy() -> void:
	var at := Vector2(rng.randf_range(46, 1230), 115 if player.position.y > 340 else 650)
	var kind := rng.randi_range(0, ENEMIES.size() - 1)
	var body := CharacterBody2D.new()
	body.collision_layer = 4
	body.collision_mask = 1
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 9
	collision.shape = circle
	body.add_child(collision)
	var art := Sprite2D.new()
	art.texture = ENEMIES[kind]
	art.scale = Vector2.ONE * 1.25
	art.position.y = -8
	body.add_child(art)
	actors.add_child(body)
	body.position = at
	enemies.append({"body": body, "hp": 2.0, "boss": false})

func damage_brew_enemy(entry: Dictionary, damage: float, slow_seconds: float, slow_factor: float, color: Color) -> void:
	if ended or not enemies.has(entry):
		return
	entry.slow_left = maxf(slow_seconds, float(entry.get("slow_left", 0.0)))
	entry.slow_factor = slow_factor
	if color.g > 0.62 and color.r < 0.5 and color.b < 0.55:
		var cloud: Node2D = FX.poison(effects, entry.body.position)
		get_tree().create_timer(2.0).timeout.connect(func() -> void:
			if is_instance_valid(cloud):
				cloud.queue_free())
	else:
		burst(entry.body.position, color)
	damage_enemy(entry, damage)

func damage_enemy(entry: Dictionary, damage: float) -> void:
	entry.hp -= damage
	if entry.hp > 0:
		return
	var at: Vector2 = entry.body.position
	entry.body.queue_free()
	enemies.erase(entry)
	kills += 1
	enemy_death_sound.play()
	burst(at, Color(0.4, 0.8, 0.6))
	if entry.boss:
		finish(true)
		return
	inventory[(kills - 1) % 3] += 1
	if kills == 8 and opening_supply_eligible:
		for i in 3:
			if inventory[i] == 0:
				inventory[i] = 1
	if kills % 24 == 0:
		inventory[4] += 1
	add_pickup(at + Vector2(-9, 0), 0)
	add_pickup(at + Vector2(9, 0), 1)

func add_pickup(at: Vector2, kind: int) -> void:
	var sprite := make_sprite(DROPS[kind], at, Vector2(21, 21))
	var motes: CPUParticles2D
	if kind == 1 and pickups.filter(func(drop: Dictionary) -> bool: return drop.motes != null).size() < 24:
		motes = FX.xp_motes(sprite)
	pickups.append({"sprite": sprite, "kind": kind, "motes": motes})
	if kind == 0:
		FX.coin_shine(sprite)

func burst(at: Vector2, color: Color) -> void:
	FX.burst(effects, at, color)

func attack_feedback(at: Vector2) -> void:
	FX.hit(effects, at)
	FX.trail(effects, player.position - Vector2(0, 30), at, Color(1.0, 0.32, 0.55))

func finish(victory: bool) -> void:
	if ended:
		return
	ended = true
	player.locked = true
	if brew:
		brew.cancel_run()
	if is_instance_valid(boss):
		boss.shots.clear()
		boss.queue_redraw()
	save.set_value("village", "coins", int(save.get_value("village", "coins", 0)) + coins)
	var saved := persist()
	hint.text = "%s   ·   %s   ·   F 返回村庄" % ["腐化之源已击败" if victory else "试炼结束", "已结算 %d 金币" % coins if saved else "保存失败"]

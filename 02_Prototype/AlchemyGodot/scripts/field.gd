extends Node2D

const FIELD_ENEMY := preload("res://scripts/field_enemy.gd")
const ENEMY_WAVES := preload("res://levels/enemy_wave_table.gd")
const ENEMY_ROW := preload("res://levels/enemy_spawn_row.gd")
const DROPS := [preload("res://art/coin.png"), preload("res://art/xp.png")]
const HD_BATTLE := preload("res://scripts/hd_battle_view.gd")
const HD_VILLAGE := preload("res://scripts/hd_village_view.gd")
const BREW := preload("res://scenes/brew.tscn")
const BOSS := preload("res://scenes/boss_arena.tscn")
const FX := preload("res://scripts/battle_fx.gd")
const SKILL_FX := preload("res://scripts/skill_fx.gd")
const LEVEL_LAYOUT := preload("res://scripts/level_layout.gd")
const LEVEL_PRESET := preload("res://levels/preset.gd")
const ALCHEMY_SYSTEM := preload("res://scripts/alchemy/alchemy_system.gd")
const ALCHEMY_MANAGER := preload("res://scripts/alchemy/alchemy_manager.gd")
const UPGRADE_UI := preload("res://scenes/upgrade_ui.tscn")
const ENTRY_SELECT := preload("res://scenes/entry_select_ui.tscn")
const WORKBENCH := preload("res://scenes/workbench_ui.tscn")
const MATERIALS := preload("res://data/materials/material_data.gd")
const DROP_TABLE := preload("res://data/materials/drop_table.gd")
const RECIPES := preload("res://data/materials/recipe_data.gd")
const NORMAL_LAYOUT := preload("res://levels/normal.tres")
const BOSS_LAYOUT := preload("res://levels/boss.tres")
const GATE := Vector2(1155, 329)
const PORTAL := LEVEL_PRESET.DEFAULT_PORTAL
const SPAWN := Vector2(640, 430)
const BOSS_SPAWN := Vector2(640, 450)
const MAP := LEVEL_PRESET.MAP_BOUNDS
const CAMERA_ZOOM := 1.45

@export var combat := false
@export var enemy_config: ENEMY_WAVES
@export var field_seed: int = 0
@export_range(0, 600) var portal_open_seconds := 300.0
@export var save_path := "user://progress.cfg"
@onready var actors: Node2D = $Actors
@onready var player = $Actors/Lilita
@onready var status: Label = get_node_or_null("Interface/Status")
@onready var hint: Label = $Interface/Hint
@onready var music: AudioStreamPlayer = $Music

var rng := RandomNumberGenerator.new()
var tiles: Array = []
var enemies: Array[Dictionary] = []
var defeated_art: Dictionary[Node2D, Sprite2D] = {}
var pickups: Array[Dictionary] = []
var props: Array[Node2D] = []
var blocks: Array[StaticBody2D] = []
var run_time := 0.0
var until_spawn := 0.0
var spawn_wave := 0
var until_attack := 0.0
var hurt_cooldown := 0.0
var hp := 120.0
var xp := 0
var coins := 0
var level := 1
var kills := 0
var enemy_death_sound: AudioStreamPlayer
var enemy_hit_sound: AudioStreamPlayer
var hit_sound_cooldown := 0.0
var basic_projectiles: Array[Dictionary] = []
var fallback_skill_visuals: Array[Dictionary] = []
var inventory := [0, 0, 0, 0, 0, 0]
var brew
var alchemy_system: ALCHEMY_SYSTEM
var village_alchemy  # 村庄场景的炼金管理器（入场选择用）
var upgrade_ui
var entry_select_ui
var workbench_ui
var boss
var boss_death: Tween
var run_manager  # RunManager 本局素材账本 + 统一结算
var profile_store  # ProfileStore 永久库存
var material_drops: Array[Dictionary] = []  # 素材掉落实体 {"sprite", "material_id", "amount"}
var material_drop_float := 0.0
var pickup_notice := ""       # 短暂获得提示
var pickup_notice_time := 0.0
var effects: Node2D
var web_layer: Node2D
var web_shots: Array[Dictionary] = []
var spore_patches: Array[Dictionary] = []
var camera: Camera2D
var hd_view: HD_BATTLE
var portal: Node2D
var portal_position := PORTAL
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
		web_layer = Node2D.new()
		actors.add_child(web_layer)
		web_layer.draw.connect(draw_webs)
		enemy_death_sound = AudioStreamPlayer.new()
		enemy_death_sound.stream = preload("res://audio/S_EnemyDeath.wav")
		enemy_death_sound.volume_db = -16
		add_child(enemy_death_sound)
		enemy_hit_sound = AudioStreamPlayer.new()
		enemy_hit_sound.stream = preload("res://audio/S_EnemyHit.wav")
		enemy_hit_sound.volume_db = -13.0
		add_child(enemy_hit_sound)
		brew = BREW.instantiate()
		$Interface.add_child(brew)
		brew.attach(self)
		$Interface/CombatHUD.attach(self, MAP)
		brew.brew_settled.connect(on_brew_settled)
		# 新炼金能力与技能联动系统
		alchemy_system = ALCHEMY_SYSTEM.new()
		alchemy_system.name = "AlchemySystem"
		add_child(alchemy_system)
		alchemy_system.ability_id = RunConfig.selected_ability
		alchemy_system.setup(self, save)
		alchemy_system.upgrade_offered.connect(on_upgrade_offered)
		# 本局素材账本 + 永久库存（V1.1 资源闭环）
		profile_store = ProfileStore.new()
		profile_store.setup(save)
		run_manager = RunManager.new()
		run_manager.setup(profile_store)
		run_manager.start_run("run_%d" % Time.get_ticks_msec())
		run_manager.material_collected.connect(on_material_collected)
		# 入场消耗（初始能力不消耗）
		consume_entry_ability()
		upgrade_ui = UPGRADE_UI.instantiate()
		add_child(upgrade_ui)
		upgrade_ui.setup(self)
		upgrade_ui.chosen.connect(apply_upgrade)
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
		if enemy_config:
			var count := mini(enemy_config.opening_count, enemy_config.alive_cap(0))
			var phase := rng.randf()
			for i in count:
				add_enemy(enemy_config.pick_row(0, (i + phase) / count))
			until_spawn = enemy_config.interval(0)
		if DisplayServer.get_name() != "headless":
			hd_view = HD_BATTLE.new()
			add_child(hd_view)
			hd_view.attach(self)
			queue_redraw()
		play_music(preload("res://audio/Music_Field.wav"))
	else:
		if DisplayServer.get_name() != "headless":
			var view := HD_VILLAGE.new()
			add_child(view)
			view.attach(self)
		# 村庄：初始化永久库存 + 炼金服务 + 入场选择 + 炼金工房
		profile_store = ProfileStore.new()
		profile_store.setup(save)
		village_alchemy = ALCHEMY_MANAGER.new()
		village_alchemy.setup(save)
		entry_select_ui = ENTRY_SELECT.instantiate()
		add_child(entry_select_ui)
		entry_select_ui.setup(self, profile_store)
		entry_select_ui.selected.connect(on_entry_selected)
		var alchemy_service := AlchemyService.new()
		alchemy_service.setup(profile_store)
		workbench_ui = WORKBENCH.instantiate()
		add_child(workbench_ui)
		workbench_ui.setup(self, alchemy_service, profile_store)
		play_music(preload("res://audio/Music_Village.wav"))

func on_entry_selected(ability_id: StringName) -> void:
	if ability_id == &"":
		return  # 取消入场
	RunConfig.set_ability(ability_id)
	get_tree().change_scene_to_file("res://scenes/battle.tscn")

func play_music(stream: AudioStreamWAV) -> void:
	var loop := stream.duplicate() as AudioStreamWAV
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_end = roundi(loop.get_length() * loop.mix_rate)
	music.stream = loop
	music.play()

func generate_field(boss_stage: bool, layout_seed: int) -> bool:
	var preset: LEVEL_PRESET = BOSS_LAYOUT if boss_stage else NORMAL_LAYOUT
	var layout: Dictionary = LEVEL_LAYOUT.build(preset, layout_seed, MAP, BOSS_SPAWN if boss_stage else SPAWN)
	if not layout.error.is_empty():
		push_error(layout.error)
		return false
	player.movement_bounds = preset.playable_bounds()
	portal_position = preset.portal_position()
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
	if is_instance_valid(hd_view):
		hd_view.rebuild()
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
	if combat and not is_instance_valid(hd_view):
		for tile in tiles:
			draw_texture_rect(tile.texture, tile.rect, false)
		draw_rect(player.movement_bounds, Color(1.0, 0.55, 0.58, 0.60), false, 2.0, true)

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
			if is_instance_valid(entry_select_ui) and not entry_select_ui.visible:
				entry_select_ui.open()
			get_viewport().set_input_as_handled()
		elif ended:
			get_tree().change_scene_to_file("res://scenes/village.tscn")
		elif portal_ready and player.position.distance_to(portal_position) < 60 and not brew.is_open():
			portal_dialog.popup_centered()
			get_viewport().set_input_as_handled()
	if event.is_action_pressed("alchemy"):
		# 村庄：按 Q 呼出炼金工房（制作能力）
		if not combat and is_instance_valid(workbench_ui) and not workbench_ui.visible:
			workbench_ui.open()
			get_viewport().set_input_as_handled()
	if event.is_action_pressed("ui_cancel") and not combat:
		if is_instance_valid(workbench_ui) and workbench_ui.visible:
			workbench_ui.close()
		elif is_instance_valid(entry_select_ui) and entry_select_ui.visible:
			entry_select_ui.close()
		else:
			get_tree().change_scene_to_file("res://scenes/menu.tscn")
		get_viewport().set_input_as_handled()
	# V1.1：局内不提供炼金工房，Q 键不再呼出旧炼丹 UI（素材自动掉落+拾取，返回时统一结算）

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
		hint.text = "F  选择能力入场" if player.position.distance_to(GATE) < 92 else "WASD 移动   ·   Q 炼金工房   ·   前往右侧雾门   ·   Esc 返回开始界面"
		return
	if ended or boss_death:
		player.locked = true
		return
	var paused: bool = brew.blocks_world() or portal_dialog.visible
	player.locked = paused or (is_instance_valid(boss) and boss.preparation > 0.0)
	if paused:
		return
	hit_sound_cooldown = maxf(0.0, hit_sound_cooldown - delta)
	advance_basic_projectiles(delta)
	advance_fallback_skill_visuals(delta)
	if ended or boss_death:
		return
	if pickup_notice_time > 0.0:
		pickup_notice_time = maxf(0.0, pickup_notice_time - delta)
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
			portal = FX.portal(effects, portal_position)
		update_field_hint()
		if enemy_config:
			var wave := enemy_config.wave_index(run_time)
			if wave != spawn_wave:
				spawn_wave = wave
				until_spawn = minf(until_spawn, enemy_config.interval(wave))
			until_spawn -= delta
			if until_spawn <= 0.0 and enemies.size() < enemy_config.alive_cap(wave):
				spawn_enemy()
				until_spawn = enemy_config.interval(wave)
		advance_webs(delta)
		if ended:
			return
		for entry in enemies:
			var body: FIELD_ENEMY = entry.body
			var slow_left := maxf(0, float(entry.get("slow_left", 0.0)) - delta)
			entry.slow_left = slow_left
			var slow := float(entry.get("slow_factor", 1.0)) if slow_left > 0.0 else 1.0
			body.advance(delta, player.global_position, hurt, fire_web, slow)
			if ended:
				return
	# V2：魔法弹恢复为独立普通攻击；它不占技能槽，也不进入十技能/升级池。
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
			launch_basic_projectile(nearest)
	if ended or boss_death:
		return
	# 新技能系统：炼金能力改造 + 元素联动（替换旧 brew.cast_equipped）
	if alchemy_system:
		alchemy_system.tick(delta, player.position, enemies, damage_brew_enemy)
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
					offer_upgrade()
			art.queue_free()
			pickups.remove_at(i)
	# 素材掉落吸附拾取（V1.1 第3.2节）：玩家进入范围自动入账
	material_drop_float += delta
	for i in range(material_drops.size() - 1, -1, -1):
		var drop := material_drops[i]
		var dsprite: Sprite2D = drop.sprite
		if not is_instance_valid(dsprite):
			material_drops.remove_at(i)
			continue
		# 轻微漂浮动画
		dsprite.position.y += sin(material_drop_float * 6.0 + i) * 0.15
		if dsprite.position.distance_to(player.position) <= 40:
			if run_manager:
				run_manager.collect_material(String(drop.material_id), int(drop.amount))
			dsprite.queue_free()
			material_drops.remove_at(i)

func update_field_hint() -> void:
	# 获得提示优先显示（短暂）
	if pickup_notice_time > 0.0:
		hint.text = "获得  %s   ·   本局素材 %d" % [pickup_notice, _run_mat_total()]
		return
	if portal_ready:
		var difference: Vector2 = portal_position - player.position
		if difference.length() < 60:
			hint.text = "F  进入 Boss 传送阵   ·   可继续探索"
		else:
			var direction: String = ["→", "↘", "↓", "↙", "←", "↖", "↑", "↗"][posmod(roundi(difference.angle() / (PI / 4)), 8)]
			hint.text = "%s Boss 传送阵已开放   ·   靠近按 F" % direction
	else:
		hint.text = "WASD 移动   ·   Space 闪避   ·   自动攻击   ·   素材 %d" % _run_mat_total()

func _run_mat_total() -> int:
	return run_manager.ledger.total() if (run_manager and run_manager.ledger) else 0

func launch_basic_projectile(target: Dictionary) -> void:
	if ended or boss_death or not enemies.has(target) or not is_instance_valid(target.get("body")):
		return
	var state := {"kind":"projectile", "skill_id":"magic_bolt", "pos":player.position,
		"target":target, "left":2.0, "finished":false, "damage":1.0 + float((level - 1) / 3)}
	basic_projectiles.append(state)
	play_skill_fx({"skill_id":"magic_bolt", "event":"cast", "from":player.position,
		"target":target.body.position, "color":Color(0.65, 0.30, 1.00), "speed":620.0, "state":state})

func advance_basic_projectiles(delta: float) -> void:
	for index in range(basic_projectiles.size() - 1, -1, -1):
		var state := basic_projectiles[index]
		var target: Dictionary = state.target
		state.left = float(state.left) - delta
		if ended or boss_death or state.left <= 0.0 or not enemies.has(target) or not is_instance_valid(target.get("body")) or float(target.get("hp", 0.0)) <= 0.0:
			state.finished = true
		else:
			state.pos = (state.pos as Vector2).move_toward(target.body.position, 620.0 * delta)
			if (state.pos as Vector2).distance_to(target.body.position) <= 18.0:
				state.finished = true
				play_skill_fx({"skill_id":"magic_bolt", "event":"impact", "from":state.pos,
					"target":target.body.position, "color":Color(0.65, 0.30, 1.00), "state":state})
				damage_enemy(target, float(state.damage))
		if state.finished:
			basic_projectiles.remove_at(index)

func clear_combat_effects() -> void:
	for state in basic_projectiles:
		state.finished = true
	basic_projectiles.clear()
	if is_instance_valid(alchemy_system) and alchemy_system.skills:
		alchemy_system.skills.clear_active()
	for visual in fallback_skill_visuals:
		if is_instance_valid(visual.node):
			visual.node.queue_free()
	fallback_skill_visuals.clear()
	if is_instance_valid(hd_view) and is_instance_valid(hd_view.world_view):
		hd_view.world_view.clear_skill_fx()

func _exit_tree() -> void:
	clear_combat_effects()

func enter_boss() -> void:
	if ended or boss or not portal_ready or player.position.distance_to(portal_position) >= 60 or brew.is_open():
		return
	if not generate_field(true, int(rng.randi()) + 1):
		hint.text = "Boss 场地生成失败，可继续探索"
		return
	brew.clear_projectiles()
	clear_combat_effects()
	clear_webs()
	for entry in enemies:
		entry.body.queue_free()
	enemies.clear()
	for body in defeated_art:
		body.queue_free()
	defeated_art.clear()
	for pickup in pickups:
		pickup.sprite.queue_free()
	pickups.clear()
	for drop in material_drops:
		if is_instance_valid(drop.sprite):
			drop.sprite.queue_free()
	material_drops.clear()
	for fx in effects.get_children():
		fx.queue_free()
	portal = null
	portal_ready = false
	player.position = BOSS_SPAWN
	player.dodge = 0.0
	player.locked = true
	boss = BOSS.instantiate()
	add_child(boss)
	boss.setup(actors, rng.randf() < 0.5, player.movement_bounds)
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

# 升级三选一触发（由经验升级时调用）
func offer_upgrade() -> void:
	if not alchemy_system:
		return
	var candidates: Array = alchemy_system.roll_upgrades()
	if candidates.is_empty():
		return
	if is_instance_valid(upgrade_ui):
		upgrade_ui.offer(candidates)

func apply_upgrade(pick: Dictionary) -> void:
	if alchemy_system:
		alchemy_system.apply_upgrade(pick)

# 入场消耗能力（V1.1 第6.3节：成功启动本局才扣，初始能力不扣）
func consume_entry_ability() -> void:
	if not alchemy_system or not profile_store:
		return
	var id: StringName = alchemy_system.ability_id
	if id == preload("res://data/alchemy_abilities/alchemy_ability_data.gd").ABILITY_INITIAL:
		return
	# 成功进入本局（_ready 已执行）才扣除一份，失败加载不会走到这里
	if profile_store.consume_ability(String(id)):
		profile_store.save_profile()

func on_upgrade_offered(candidates: Array) -> void:
	pass

# 元素联动效果回调（由 AlchemySystem 触发）
func on_synergy_effect(syn: Dictionary, at: Vector2) -> void:
	# 联动视觉 + 伤害（对范围内敌人结算一次）
	var radius: float = float(syn.get("radius", 100.0)) * 0.2
	var dmg: float = float(syn.get("damage", 20.0))
	var color: Color = syn.get("color", Color.WHITE)
	for entry in enemies:
		if entry.get("hp", 0.0) > 0.0 and is_instance_valid(entry.body):
			if entry.body.position.distance_to(at) <= radius:
				damage_brew_enemy(entry, dmg, 0.0, 1.0, color)
	SKILL_FX.explosion(effects, at, color, radius * 2.0)

# 技能释放视觉表现（由 SkillManager 通过 alchemy_system 回调触发）
# info: {"skill_id", "behavior", "from", "target", "color", "radius", "speed", "element"}
func play_skill_fx(info: Dictionary) -> void:
	var skill_id: String = String(info.get("skill_id", ""))
	var event_name: String = String(info.get("event", "cast"))
	var behavior: String = String(info.get("behavior", ""))
	var from: Vector2 = info.get("from", Vector2.ZERO)
	var target: Vector2 = info.get("target", Vector2.ZERO)
	var color: Color = info.get("color", Color.WHITE)
	var radius: float = float(info.get("radius", 0.0))
	var speed: float = float(info.get("speed", 620.0))
	# HD 战斗视图不会直接显示 Actors 下的普通 2D 节点；同一施法事件
	# 只交给其 3D 呈现层，避免与下方 2D 特效双播；非 HD 才继续走 2D。
	if is_instance_valid(hd_view) and is_instance_valid(hd_view.world_view):
		hd_view.world_view.show_skill_fx(info)
		return
	# 回退视图也追随同一逻辑状态，不再自行 tween 到施放时的旧坐标。
	var state: Dictionary = info.get("state", {})
	if not state.is_empty():
		if String(state.get("kind", "")) == "projectile":
			if event_name == "cast":
				var ball := Sprite2D.new()
				var glow := GradientTexture2D.new()
				glow.gradient = _material_gradient(color)
				glow.width = 20
				glow.height = 20
				glow.fill = GradientTexture2D.FILL_RADIAL
				glow.fill_from = Vector2(.5, .5)
				glow.fill_to = Vector2.ZERO
				ball.texture = glow
				effects.add_child(ball)
				ball.position = state.pos + Vector2(0, -24)
				fallback_skill_visuals.append({"state":state, "node":ball, "fade":0.45})
			elif event_name == "impact":
				FX.hit(effects, target + Vector2(0, -24), .46)
			return
		if String(state.get("kind", "")) == "zone":
			if event_name == "impact":
				var cloud := FX.poison(effects, target, radius / 90.0)
				cloud.modulate = Color(color, .48)
				fallback_skill_visuals.append({"state":state, "node":cloud, "fade":0.45})
			return
	# 非 HD 回退层也保留 V2 的独立视觉语义，避免测试/低配模式只出现通用白点。
	match skill_id:
		"sk_blast_flask":
			if event_name == "cast":
				SKILL_FX.projectile(effects, from, target, color, speed)
			else:
				SKILL_FX.explosion(effects, target, color, maxf(radius, 64.0))
			return
		"sk_clay_homunculus":
			if event_name == "cast":
				SKILL_FX.earth_spike(effects, from, color)
			elif event_name == "impact":
				SKILL_FX.explosion(effects, target, color, 22.0)
			return
		"sk_mithril_drop":
			if event_name == "cast": SKILL_FX.projectile(effects, from, target, color, speed)
			return
		"sk_gravity_stone":
			if event_name == "impact": SKILL_FX.aoe(effects, target, color, maxf(radius, 84.0))
			return
		"sk_corrosive_flask":
			if event_name == "cast": SKILL_FX.projectile(effects, from, target, color, speed)
			elif event_name == "impact": SKILL_FX.zone(effects, target, color, maxf(radius, 60.0))
			return
		"sk_mist_flask":
			if event_name == "cast": SKILL_FX.projectile(effects, from, target, color, speed)
			elif event_name == "impact": SKILL_FX.zone(effects, target, color, maxf(radius, 90.0))
			return
		"sk_crystal_growth":
			SKILL_FX.ice_spike(effects, from, target, color)
			return
		"sk_obsidian_blade":
			if event_name == "cast": SKILL_FX.wind_blade(effects, from, target, color)
			return
		"sk_spirit_gel":
			if event_name == "cast": SKILL_FX.projectile(effects, from, target, color, speed)
			elif event_name == "impact": SKILL_FX.explosion(effects, target, color, 36.0)
			return
		"sk_soul_needle":
			if event_name == "cast":
				SKILL_FX.line(effects, from, target, color)
			elif event_name == "impact":
				SKILL_FX.explosion(effects, target, color, 16.0)
			return
	match skill_id:
		"magic_bolt":
			SKILL_FX.magic_bolt(effects, from, target, color, speed)
			return
		"fireball":
			SKILL_FX.fireball(effects, from, target, color, maxf(radius, 30.0), speed)
			return
		"ice_spike":
			SKILL_FX.ice_spike(effects, from, target, color)
			return
		"thunder":
			SKILL_FX.thunder(effects, target, color)
			return
		"wind_blade":
			SKILL_FX.wind_blade(effects, from, target, color)
			return
		"cyclone":
			SKILL_FX.cyclone(effects, from, color, maxf(radius, 40.0))
			return
		"poison_fog":
			SKILL_FX.zone(effects, target, color, maxf(radius, 60.0))
			return
		"rockfall":
			SKILL_FX.rockfall(effects, target, color, maxf(radius, 50.0))
			return
		"beam":
			SKILL_FX.beam_strike(effects, from, target, color)
			return
		"earth_spike":
			SKILL_FX.earth_spike(effects, target, color)
			return
	match behavior:
		"projectile":
			SKILL_FX.projectile(effects, from, target, color, speed)
		"blast":
			SKILL_FX.blast(effects, from, target, color, maxf(radius, 30.0), speed)
		"line":
			SKILL_FX.line(effects, from, target, color)
		"instant":
			SKILL_FX.lightning(effects, target, color)
		"boomerang":
			SKILL_FX.line(effects, from, target, color)
		"orbit":
			SKILL_FX.orbit(effects, from, color, maxf(radius, 40.0))
		"zone":
			SKILL_FX.zone(effects, target, color, maxf(radius, 60.0))
		"aoe":
			SKILL_FX.aoe(effects, target, color, maxf(radius, 50.0))
		"beam":
			SKILL_FX.beam(effects, from, target, color)
		"spike":
			SKILL_FX.spike(effects, target, color)
		_:
			SKILL_FX.projectile(effects, from, target, color, speed)

func persist() -> bool:
	return OS.get_cmdline_user_args().has("--migration-test") or save.save(save_path) == OK

func advance_fallback_skill_visuals(delta: float) -> void:
	for index in range(fallback_skill_visuals.size() - 1, -1, -1):
		var visual := fallback_skill_visuals[index]
		var state: Dictionary = visual.state
		var node: Node2D = visual.node
		if not is_instance_valid(node):
			fallback_skill_visuals.remove_at(index)
			continue
		if String(state.kind) == "projectile":
			node.position = (state.pos as Vector2) + Vector2(0, -24)
			if bool(state.finished):
				node.queue_free()
				fallback_skill_visuals.remove_at(index)
		elif bool(state.finished):
			visual.fade = maxf(0.0, float(visual.fade) - delta)
			node.modulate.a = .48 * float(visual.fade) / .45
			if visual.fade <= 0.0:
				node.queue_free()
				fallback_skill_visuals.remove_at(index)

func hurt(amount: float, knock_direction := Vector2.ZERO) -> bool:
	if ended or boss_death or hurt_cooldown > 0 or player.dodge > 0 or amount <= 0.0:
		return false
	hurt_cooldown = 0.55
	hp = maxf(0.0, hp - amount)
	player.show_hurt()
	if hp <= 0:
		player.show_death()
		finish(false)
	else:
		if not knock_direction.is_zero_approx():
			player.knockback = knock_direction * 133.333
			player.knockback_time = 0.15
	return true

func spawn_enemy(kind: int = -1) -> void:
	if not enemy_config:
		return
	var row := enemy_config.row_for_kind(kind) if kind >= 0 else enemy_config.pick_row(enemy_config.wave_index(run_time), rng.randf())
	add_enemy(row)

func add_enemy(row: ENEMY_ROW) -> void:
	if not row or row.kind < 0 or row.kind >= FIELD_ENEMY.Kind.size():
		return
	var area: Rect2 = player.movement_bounds
	var at := Vector2(rng.randf_range(area.position.x + 14.0, area.end.x - 14.0),
		area.position.y + 5.0 if player.position.y > area.get_center().y else area.end.y - 5.0)
	var body := FIELD_ENEMY.new()
	body.setup(row.kind, area, row.atlas)
	actors.add_child(body)
	body.position = at
	enemies.append({"body": body, "hp": 2.0, "boss": false})

func fire_web(at: Vector2, direction: Vector2, kind: int = FIELD_ENEMY.Kind.SPIDER) -> void:
	if kind == FIELD_ENEMY.Kind.MUSHROOM:
		spore_patches.append({"position": at, "remaining": 2.8, "next_hit": 0.32})
	else:
		var water := kind == FIELD_ENEMY.Kind.WATER_SPIRIT
		web_shots.append({"position": at, "direction": direction, "remaining": 1.0 if water else 1.15, "water": water})
	web_layer.queue_redraw()

func advance_webs(delta: float) -> void:
	if web_shots.is_empty() and spore_patches.is_empty():
		return
	advance_spores(delta)
	if ended:
		return
	for i in range(web_shots.size() - 1, -1, -1):
		var shot := web_shots[i]
		var at: Vector2 = shot.position
		var speed := 330.0 if shot.water else 280.0
		var step: Vector2 = shot.direction * speed * minf(delta, shot.remaining)
		var goal := at + step
		var ray := PhysicsRayQueryParameters2D.create(at, goal, 1)
		ray.hit_from_inside = true
		var obstacle := get_world_2d().direct_space_state.intersect_ray(ray)
		var player_at: Vector2 = player.global_position
		var end: Vector2 = obstacle.get("position", goal)
		var nearest := Geometry2D.get_closest_point_to_segment(player_at, at, end)
		var hit_player := nearest.distance_squared_to(player_at) <= 15.0 * 15.0
		if hit_player and not obstacle.is_empty():
			hit_player = (player_at - at).dot(shot.direction) < at.distance_to(end)
		shot.remaining -= delta
		if hit_player or not obstacle.is_empty() or shot.remaining <= 0.0 or not MAP.has_point(to_local(goal)):
			web_shots.remove_at(i)
		else:
			shot.position = goal
		if hit_player:
			hurt(FIELD_ENEMY.DAMAGE)
			if ended:
				return
	web_layer.queue_redraw()

func advance_spores(delta: float) -> void:
	for i in range(spore_patches.size() - 1, -1, -1):
		var patch := spore_patches[i]
		patch.remaining -= delta
		if patch.remaining <= 0.0:
			spore_patches.remove_at(i)
			continue
		patch.next_hit -= delta
		if patch.next_hit <= 0.0 and player.global_position.distance_squared_to(patch.position) <= FIELD_ENEMY.SPORE_RADIUS ** 2:
			patch.next_hit = 0.68
			hurt(FIELD_ENEMY.DAMAGE)
			if ended:
				return

func clear_webs() -> void:
	web_shots.clear()
	spore_patches.clear()
	if is_instance_valid(web_layer):
		web_layer.queue_redraw()

func draw_webs() -> void:
	for patch in spore_patches:
		var at := web_layer.to_local(patch.position)
		var radius := FIELD_ENEMY.SPORE_RADIUS
		var age: float = 2.8 - patch.remaining
		var visibility := minf(patch.remaining / 0.45, 1.0)
		var armed := age >= 0.32
		web_layer.draw_circle(at, radius, Color(0.63, 0.32, 0.73, (0.29 if armed else 0.12) * visibility))
		web_layer.draw_arc(at, radius, 0, TAU, 32, Color(0.89, 0.69, 0.94, 0.78 * visibility), 2.0, true)
		if armed:
			for mote in range(7):
				var angle := mote * 2.39996 + age * 0.85
				var offset := Vector2.from_angle(angle) * (11.0 + mote * 4.0)
				web_layer.draw_circle(at + offset, 1.5 + (mote % 3) * 0.45, Color(0.93, 0.77, 1.0, 0.62 * visibility))
	for shot in web_shots:
		var at := web_layer.to_local(shot.position)
		var direction: Vector2 = shot.direction
		if shot.water:
			web_layer.draw_line(at - direction * 18.0, at, Color("#319bcf"), 5.0, true)
			web_layer.draw_circle(at, 6.0, Color("#48c2fb"))
			web_layer.draw_circle(at + Vector2(-1, -2), 2.5, Color("#d0f8ff"))
		else:
			var lateral := direction.orthogonal()
			var tint := Color("#e1f2f7")
			web_layer.draw_line(at - direction * 16.0 + lateral * 3.0, at, tint, 1.6, true)
			web_layer.draw_line(at - direction * 16.0 - lateral * 3.0, at, tint, 1.6, true)
			web_layer.draw_circle(at, 4.0, tint)

func damage_brew_enemy(entry: Dictionary, damage: float, slow_seconds: float, slow_factor: float, color: Color) -> void:
	if ended or not enemies.has(entry):
		return
	entry.slow_left = maxf(slow_seconds, float(entry.get("slow_left", 0.0)))
	entry.slow_factor = slow_factor
	# HD 技能已有专属 3D 表现，跳过通用 2D 命中爆点，防止同次命中重复显示。
	if not is_instance_valid(hd_view):
		if color.g > 0.62 and color.r < 0.5 and color.b < 0.55:
			var cloud: Node2D = FX.poison(effects, entry.body.position)
			get_tree().create_timer(2.0).timeout.connect(func() -> void:
				if is_instance_valid(cloud):
					cloud.queue_free())
		else:
			burst(entry.body.position, color)
	damage_enemy(entry, damage)

func damage_enemy(entry: Dictionary, damage: float) -> void:
	if ended or boss_death or not enemies.has(entry) or damage <= 0.0 or float(entry.get("hp", 0.0)) <= 0.0:
		return
	var body: Node2D = entry.body
	var dealt := minf(damage, float(entry.hp))
	entry.hp -= damage
	if is_instance_valid(hd_view) and is_instance_valid(hd_view.world_view):
		hd_view.world_view.show_damage_feedback(body.position, dealt)
	else:
		show_damage_number(body.position, dealt)
	if entry.boss:
		boss.show_hurt()
	else:
		body.show_hurt()
	if entry.hp > 0:
		if hit_sound_cooldown <= 0.0 and is_instance_valid(enemy_hit_sound):
			enemy_hit_sound.play()
			hit_sound_cooldown = .07
		return
	var at := body.position
	enemies.erase(entry)
	kills += 1
	enemy_death_sound.play()
	burst(at, Color(0.4, 0.8, 0.6))
	if entry.boss:
		defeated_art[body] = boss.art
		player.locked = true
		hint.text = "腐化之源正在崩解"
		boss_death = boss.play_death()
		boss_death.finished.connect(func() -> void:
			remove_defeated(body)
			boss_death = null
			finish(true), CONNECT_ONE_SHOT)
		return
	defeated_art[body] = body.art
	var death: Tween = body.play_death()
	death.finished.connect(remove_defeated.bind(body), CONNECT_ONE_SHOT)
	# 素材掉落（V1.1 第3章）：按掉落表生成，自动拾取写入本局账本
	drop_materials(at, entry.get("elite", false), entry.boss)
	if kills == 8 and opening_supply_eligible:
		for i in 3:
			if inventory[i] == 0:
				inventory[i] = 1
	if kills % 24 == 0:
		inventory[4] += 1
	add_pickup(at + Vector2(-9, 0), 0)
	add_pickup(at + Vector2(9, 0), 1)

func remove_defeated(body: Node2D) -> void:
	defeated_art.erase(body)
	body.queue_free()

func show_damage_number(at: Vector2, damage: float) -> void:
	var label := Label.new()
	label.text = "−%d" % ceili(damage)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.91, 1.0, .77))
	label.add_theme_color_override("font_outline_color", Color(.06, .09, .06, .85))
	label.add_theme_constant_override("outline_size", 3)
	label.position = at + Vector2(-12, -76)
	effects.add_child(label)
	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 22.0, .52).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, .52)
	tween.chain().tween_callback(label.queue_free)

# 怪物死亡素材掉落（V1.1 第3.2节）：按掉落表生成掉落实体，玩家吸附后自动拾取入账本
func drop_materials(at: Vector2, elite: bool, boss_entity: bool) -> void:
	if not run_manager:
		return
	var enemy_type := "boss" if boss_entity else ("elite" if elite else "common")
	var drops: Array = DROP_TABLE.for_enemy_type(enemy_type)
	for entry in drops:
		if rng.randf() > float(entry.chance):
			continue
		var amount := rng.randi_range(int(entry.min), int(entry.max))
		if amount <= 0:
			continue
		spawn_material_drop(at, String(entry.material_id), amount)

# 生成素材掉落实体（地面掉落物，等待玩家吸附拾取）
func spawn_material_drop(at: Vector2, material_id: String, amount: int) -> void:
	var color := _material_color(material_id)
	var sprite := Sprite2D.new()
	var tex := GradientTexture2D.new()
	tex.gradient = _material_gradient(color)
	tex.width = 16
	tex.height = 16
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.0, 0.0)
	sprite.texture = tex
	sprite.scale = Vector2.ONE * 0.9
	actors.add_child(sprite)
	sprite.position = at + Vector2(rng.randf_range(-6.0, 6.0), rng.randf_range(-6.0, 6.0))
	material_drops.append({"sprite": sprite, "material_id": material_id, "amount": amount})

func _material_color(material_id: String) -> Color:
	match material_id:
		"fire_powder": return Color(1.00, 0.55, 0.20)   # 火粉 橙红
		"dew": return Color(0.35, 0.75, 1.00)           # 露水 浅蓝
		"magic_shard": return Color(0.65, 0.45, 1.00)   # 魔法碎片 紫
		"wind_crystal": return Color(0.45, 0.90, 0.60)  # 风晶 翠绿
		"earth_core": return Color(0.70, 0.55, 0.35)    # 土髓 土棕
		_: return Color(0.9, 0.9, 0.9)

func _material_gradient(color: Color) -> Gradient:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(color.r, color.g, color.b, 0.95), Color(color.r, color.g, color.b, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 1.0])
	return g

func on_material_collected(run_id: String, material_id: String, amount: int) -> void:
	# HUD 获得提示（V1.1 第3.3节）：短暂显示最近获得的素材
	var name := MATERIALS.name_of(material_id)
	show_pickup_notice("%s ×%d" % [name, amount])

# 短暂获得提示（覆盖 hint 约 1.2 秒）
func show_pickup_notice(text: String) -> void:
	pickup_notice = text
	pickup_notice_time = 1.2

# 统一素材结算（V1.1 第4章）：所有返回入口调用
func settle_run() -> void:
	if run_manager:
		run_manager.settle_run_materials("exit")

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
	var impact := FX.hit(effects, at)
	var tint := Color(1.0, 0.32, 0.55)
	if is_instance_valid(hd_view):
		hd_view.world_view.raise_attack(impact, player.position, at, tint)
	else:
		FX.trail(effects, player.position - Vector2(0, 30), at, tint)

func finish(victory: bool) -> void:
	if ended:
		return
	ended = true
	clear_combat_effects()
	clear_webs()
	player.locked = true
	if brew:
		brew.cancel_run()
	if is_instance_valid(boss):
		boss.shots.clear()
		boss.queue_redraw()
	# 统一素材结算：本局已拾取素材全部带出（V1.1 第4章）
	settle_run()
	# 未拾取的地面素材掉落不带出（V1.1 第4.1节），清理
	for drop in material_drops:
		if is_instance_valid(drop.sprite):
			drop.sprite.queue_free()
	material_drops.clear()
	save.set_value("village", "coins", int(save.get_value("village", "coins", 0)) + coins)
	var saved := persist()
	var mat_total: int = run_manager.ledger.total() if (run_manager and run_manager.ledger) else 0
	hint.text = "%s   ·   %s   ·   素材 +%d   ·   F 返回村庄" % ["腐化之源已击败" if victory else "试炼结束", "已结算 %d 金币" % coins if saved else "保存失败", mat_total]

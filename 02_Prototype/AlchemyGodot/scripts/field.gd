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
const INFINITE_LAYOUT := preload("res://scripts/infinite_field_layout.gd")
const FIELD_EVENTS := preload("res://scripts/field_event_runtime.gd")
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
@export var level_id: StringName = &""
@export var layout_preset: LEVEL_PRESET
@export var spawn_position := SPAWN
@export var stage_is_boss := false
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
var level_catalog: Resource
var stage_active := true
var startup_error := ""
var startup_complete := false
var incoming_run: Dictionary = {}
var entry_busy := false
var run_rewards_saved := false
var infinite_layout
var field_events: FIELD_EVENTS
var chunk_nodes: Dictionary = {}
var dormant_drops: Dictionary = {}
var last_stream_chunk := Vector2i(2147483647, 2147483647)

func is_infinite_field() -> bool:
	return combat and not stage_is_boss and layout_preset != null and layout_preset.infinite

func chunk_at(at: Vector2) -> Vector2i:
	var size := Vector2(layout_preset.chunk_size)
	return Vector2i(floori(at.x / size.x), floori(at.y / size.y))

func active_map_bounds() -> Rect2:
	return player.movement_bounds if is_infinite_field() else MAP

func stream_field(force := false) -> bool:
	if not is_infinite_field() or infinite_layout == null:
		return true
	var coordinate := chunk_at(player.position)
	if not force and coordinate == last_stream_chunk:
		return true
	var change: Dictionary = infinite_layout.update(player.position)
	if not String(change.error).is_empty():
		push_warning(change.error)
		return false
	last_stream_chunk = coordinate
	for coord: Vector2i in change.removed:
		store_chunk_drops(coord)
		if not chunk_nodes.has(coord):
			continue
		for node in chunk_nodes[coord].props + chunk_nodes[coord].blocks:
			node.get_parent().remove_child(node)
			node.queue_free()
		chunk_nodes.erase(coord)
	for coord: Vector2i in change.added:
		var nodes := {"props": [], "blocks": []}
		for item in change.added[coord].props:
			nodes.props.append(make_sprite(item.texture, item.position, item.size, item.foot_fraction))
			if item.collision != Vector2.ZERO:
				add_block(item.position, item.collision)
				nodes.blocks.append(blocks.back())
		chunk_nodes[coord] = nodes
		restore_chunk_drops(coord)
	tiles.clear()
	props.clear()
	blocks.clear()
	for coord in change.chunks:
		tiles.append_array(change.chunks[coord].tiles)
		props.append_array(chunk_nodes[coord].props)
		blocks.append_array(chunk_nodes[coord].blocks)
	player.movement_bounds = change.bounds
	for entry in enemies:
		if not entry.boss:
			entry.body.travel_bounds = change.bounds.grow(-14.0)
	if is_instance_valid(hd_view):
		hd_view.rebuild()
	if field_events:
		field_events.sync()
	queue_redraw()
	return true

func store_chunk_drops(coord: Vector2i) -> void:
	var stored: Array = dormant_drops.get(coord, [])
	for i in range(pickups.size() - 1, -1, -1):
		var drop := pickups[i]
		if chunk_at(drop.sprite.position) == coord:
			stored.append({"position": drop.sprite.position, "kind": drop.kind})
			drop.sprite.queue_free()
			pickups.remove_at(i)
	for i in range(material_drops.size() - 1, -1, -1):
		var drop := material_drops[i]
		if chunk_at(drop.sprite.position) == coord:
			stored.append({"position": drop.sprite.position, "material_id": drop.material_id, "amount": drop.amount})
			drop.sprite.queue_free()
			material_drops.remove_at(i)
	if not stored.is_empty():
		dormant_drops[coord] = stored

func restore_chunk_drops(coord: Vector2i) -> void:
	for drop in dormant_drops.get(coord, []):
		if drop.has("kind"):
			add_pickup(drop.position, drop.kind)
		else:
			spawn_material_drop(drop.position, drop.material_id, drop.amount, false)
	dormant_drops.erase(coord)

func props_by_chunk() -> Dictionary:
	var result := {}
	for coord in chunk_nodes:
		result[coord] = chunk_nodes[coord].props
	return result

func profile_path() -> String:
	return "" if OS.get_cmdline_user_args().has("--migration-test") else save_path

func _ready() -> void:
	if not OS.get_cmdline_user_args().has("--migration-test"):
		var load_error := ProfileStore.load_save(save, save_path)
		if load_error != OK and load_error != ERR_FILE_NOT_FOUND:
			startup_error = "存档读取失败，请保留存档并检查文件。"
	level_catalog = load("res://levels/catalog.tres")
	if level_id == &"":
		level_id = &"greyford_01" if combat else &"village_greyford"
	var definition = level_catalog.find_level(level_id) if level_catalog else null
	if definition:
		layout_preset = definition.layout
		enemy_config = definition.enemy_config
		spawn_position = definition.spawn_position
		stage_is_boss = definition.kind == 2
	if has_node("EntrySpawn"):
		$EntrySpawn.position = spawn_position
	player.position = spawn_position
	$Interface.visible = stage_active
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
		if not generate_field(stage_is_boss, rng.seed):
			startup_error = "关卡随机布局无法生成，请调整物件数量或密度。"
			stage_active = false
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
		alchemy_system.ability_id = String(incoming_run.get("ability", RunConfig.selected_ability))
		alchemy_system.setup(self, save)
		alchemy_system.upgrade_offered.connect(on_upgrade_offered)
		# 本局素材账本 + 永久库存（V1.1 资源闭环）
		profile_store = ProfileStore.new()
		profile_store.setup(save, profile_path())
		run_manager = RunManager.new()
		run_manager.setup(profile_store)
		run_manager.start_run(String(incoming_run.get("run_id", RunConfig.new_run_id())))
		run_manager.material_collected.connect(on_material_collected)
		upgrade_ui = UPGRADE_UI.instantiate()
		add_child(upgrade_ui)
		upgrade_ui.setup(self)
		upgrade_ui.chosen.connect(apply_upgrade)
		first_brew = not bool(save.get_value("tutorial", "brew_introduced", false))
		opening_supply_eligible = not first_brew
		if first_brew and incoming_run.is_empty():
			for i in 3:
				inventory[i] = 1
			save.set_value("tutorial", "brew_introduced", true)
			# 入口准备时不写盘；成功确认的库存事务会一并保存教学标记。
			if stage_active:
				persist()
		portal_dialog = ConfirmationDialog.new()
		portal_dialog.title = "Boss 挑战"
		portal_dialog.dialog_text = "进入雾界草甸挑战腐化之源？\n保留当前生命、材料和丹药，挑战结束后结算。"
		portal_dialog.ok_button_text = "进入挑战"
		portal_dialog.cancel_button_text = "继续探索"
		portal_dialog.exclusive = true
		portal_dialog.confirmed.connect(enter_boss)
		$Interface.add_child(portal_dialog)
		if not incoming_run.is_empty():
			restore_run(incoming_run)
		if stage_is_boss:
			start_boss_actor()
		elif enemy_config:
			var count := mini(enemy_config.opening_count, enemy_config.alive_cap(0))
			var phase := rng.randf()
			for i in count:
				add_enemy(enemy_config.pick_row(0, (i + phase) / count))
			until_spawn = enemy_config.interval(0)
		if stage_active:
			activate_stage()
	else:
		if DisplayServer.get_name() != "headless":
			var view := HD_VILLAGE.new()
			add_child(view)
			view.attach(self)
		# 村庄：初始化永久库存 + 炼金服务 + 入场选择 + 炼金工房
		profile_store = ProfileStore.new()
		profile_store.setup(save, profile_path())
		village_alchemy = ALCHEMY_MANAGER.new()
		village_alchemy.setup(save)
		var last_level := StringName(save.get_value("entry", "level_id", "greyford_01"))
		if level_catalog and level_catalog.find_level(last_level):
			RunConfig.selected_level_id = last_level
		entry_select_ui = ENTRY_SELECT.instantiate()
		add_child(entry_select_ui)
		entry_select_ui.setup(self, profile_store, level_catalog)
		entry_select_ui.confirmed.connect(on_entry_confirmed)
		entry_select_ui.cancelled.connect(RunConfig.cancel_entry)
		var alchemy_service := AlchemyService.new()
		alchemy_service.setup(profile_store)
		workbench_ui = WORKBENCH.instantiate()
		add_child(workbench_ui)
		workbench_ui.setup(self, alchemy_service, profile_store)
		play_music(preload("res://audio/Music_Village.wav"))
	if is_infinite_field():
		field_events = FIELD_EVENTS.new()
		field_events.setup(self)
	startup_complete = startup_error.is_empty()

func prepare_stage(id: StringName, handoff: Dictionary = {}) -> Node2D:
	var definition = level_catalog.find_level(id) if level_catalog else null
	if not definition or not definition.enabled or definition.kind == 0 or not ResourceLoader.exists(definition.scene_path):
		return null
	var packed := load(definition.scene_path) as PackedScene
	if not packed:
		return null
	var next = packed.instantiate()
	if not next.get_script() or not next.has_method("activate_stage") or not next.has_node("Actors/Lilita") or not next.has_node("Interface/CombatHUD") or not next.has_node("Music"):
		next.free()
		return null
	next.level_id = id
	next.save_path = save_path
	next.stage_active = false
	next.incoming_run = handoff.duplicate(true)
	next.field_seed = int(handoff.get("stage_seed", 0))
	next.process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(next)
	if not next.startup_complete or next.profile_store == null or not next.startup_error.is_empty():
		next.queue_free()
		return null
	return next

func on_entry_confirmed(id: StringName, ability_id: StringName) -> void:
	if entry_busy:
		return
	var definition = level_catalog.find_level(id) if level_catalog else null
	if not definition or not definition.enabled or not definition.selectable or definition.kind != 1:
		entry_select_ui.show_error("这个关卡当前不能从村庄出发。")
		return
	if not startup_error.is_empty():
		entry_select_ui.show_error(startup_error)
		return
	if not level_catalog.validation_errors().is_empty():
		entry_select_ui.show_error("关卡总表存在配置错误，请先在编辑器里校验并修正。")
		return
	entry_busy = true
	entry_select_ui.set_busy(true)
	RunConfig.begin_entry(id, ability_id)
	var next = prepare_stage(id)
	if next == null:
		entry_select_ui.show_error("关卡加载或布局生成失败，未扣库存。请检查关卡配置。")
	elif not next.profile_store.commit_entry_ability(String(ability_id), String(id), RunConfig.entry_id):
		next.queue_free()
		entry_select_ui.show_error("库存不足或保存失败，未扣库存，请重新选择。")
	else:
		RunConfig.confirm_entry()
		publish_stage(next)
		return
	RunConfig.cancel_entry()
	entry_busy = false
	entry_select_ui.set_busy(false)

func publish_stage(next: Node2D) -> void:
	var tree := get_tree()
	# 旧 HD 视图先退出，恢复画布遮罩；新视图随后接管，避免场景叠加。
	tree.root.remove_child(self)
	tree.current_scene = next
	next.activate_stage()
	queue_free()

func activate_stage() -> void:
	stage_active = true
	process_mode = Node.PROCESS_MODE_INHERIT
	$Interface.show()
	if combat:
		if DisplayServer.get_name() != "headless" and not is_instance_valid(hd_view):
			hd_view = HD_BATTLE.new()
			add_child(hd_view)
			hd_view.attach(self)
			if not incoming_run.get("outdoor", {}).is_empty():
				for key in incoming_run.outdoor:
					if key == "weather_state":
						for weather_key in incoming_run.outdoor.weather_state:
							hd_view.world_view.weather.set(weather_key, incoming_run.outdoor.weather_state[weather_key])
					else:
						hd_view.world_view.set(key, incoming_run.outdoor[key])
		queue_redraw()
		play_music(preload("res://audio/Music_Boss.wav") if stage_is_boss else preload("res://audio/Music_Field.wav"))
		player.locked = stage_is_boss

func play_music(stream: AudioStreamWAV) -> void:
	var loop := stream.duplicate() as AudioStreamWAV
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_end = roundi(loop.get_length() * loop.mix_rate)
	music.stream = loop
	music.play()

func generate_field(boss_stage: bool, layout_seed: int) -> bool:
	var preset: LEVEL_PRESET = layout_preset if layout_preset else (BOSS_LAYOUT if boss_stage else NORMAL_LAYOUT)
	if is_infinite_field():
		infinite_layout = INFINITE_LAYOUT.new()
		infinite_layout.setup(preset, layout_seed, level_id, spawn_position)
		player.clamp_to_battle_bounds = false
		return stream_field(true)
	player.clamp_to_battle_bounds = true
	var layout: Dictionary = LEVEL_LAYOUT.build(preset, layout_seed, MAP, spawn_position)
	if not layout.error.is_empty():
		push_warning(layout.error)
		return false
	player.movement_bounds = preset.playable_bounds()
	portal_position = preset.portal_position()
	if has_node("BossPortal"):
		$BossPortal.position = portal_position
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
		if not is_infinite_field():
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
			if is_instance_valid(entry_select_ui) and not entry_select_ui.visible and not workbench_ui.visible:
				entry_select_ui.open()
			get_viewport().set_input_as_handled()
		elif ended:
			leave_run(false)
		elif portal_ready and player.position.distance_to(portal_position) < 60 and not brew.is_open():
			var definition = level_catalog.find_level(level_id)
			var target = level_catalog.find_level(definition.boss_level_id) if definition else null
			portal_dialog.dialog_text = "挑战%s？\n保留当前生命、已拾材料和能力；地面未拾物品离场清除。" % (target.boss_name if target else "Boss")
			portal_dialog.popup_centered()
			get_viewport().set_input_as_handled()
	if event.is_action_pressed("alchemy"):
		# 村庄：按 Q 呼出炼金工房（制作能力）
		if not combat and startup_error.is_empty() and is_instance_valid(workbench_ui) and not workbench_ui.visible and not entry_select_ui.visible:
			workbench_ui.open()
			get_viewport().set_input_as_handled()
	if event.is_action_pressed("ui_cancel") and not combat:
		get_viewport().set_input_as_handled()
		if is_instance_valid(workbench_ui) and workbench_ui.visible:
			workbench_ui.close()
		elif is_instance_valid(entry_select_ui) and entry_select_ui.visible:
			entry_select_ui.close()
		else:
			var packed := load("res://scenes/menu.tscn") as PackedScene
			if packed == null:
				hint.text = "开始界面加载失败，请重试返回。"
				return
			RunConfig.reset()
			_replace_scene(packed.instantiate())
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
	camera.position = camera.position.lerp(desired, weight)
	if not is_infinite_field():
		camera.position = camera.position.clamp(MAP.position + half_view, MAP.end - half_view)

func _physics_process(delta: float) -> void:
	if not stage_active:
		return
	update_camera(delta)
	if not combat:
		player.locked = entry_busy or entry_select_ui.visible or workbench_ui.visible
		status.text = "格雷弗德村庄   ·   金币 %d" % int(save.get_value("village", "coins", 0))
		hint.text = "F  出战准备 · 选择关卡与能力" if player.position.distance_to(GATE) < 92 else "WASD 移动   ·   Q 炼金工房   ·   前往右侧雾门   ·   Esc 返回开始界面"
		return
	if ended or boss_death:
		player.locked = true
		return
	var paused: bool = brew.blocks_world() or portal_dialog.visible
	player.locked = paused or (is_instance_valid(boss) and boss.preparation > 0.0)
	if paused:
		return
	if is_infinite_field():
		stream_field()
		if field_events:
			field_events.tick()
		for i in range(enemies.size() - 1, -1, -1):
			var entry := enemies[i]
			if player.position.distance_to(entry.body.position) > 1800.0:
				entry.body.queue_free()
				enemies.remove_at(i)
	hit_sound_cooldown = maxf(0.0, hit_sound_cooldown - delta)
	advance_basic_projectiles(delta)
	advance_fallback_skill_visuals(delta)
	if ended or boss_death:
		return
	if pickup_notice_time > 0.0:
		pickup_notice_time = maxf(0.0, pickup_notice_time - delta)
	hurt_cooldown = maxf(0.0, hurt_cooldown - delta)
	if boss:
		hint.text = "%s   ·   %s" % [boss.display_name, "准备 %d" % ceili(boss.preparation) if boss.preparation > 0 else "生命 %d%%   ·   先读地面预警，再横向移动   ·   Space 闪避" % ceili(float(boss.entry.hp) * 100.0 / boss.max_hp)]
		boss.advance(delta, player, hurt, burst)
		if ended or boss.preparation > 0:
			return
	else:
		run_time += delta
		if not portal_ready and run_time >= portal_open_seconds:
			portal_ready = true
			if is_infinite_field():
				portal_position = (Vector2(chunk_at(player.position)) + Vector2(0.5, 0.5)) * Vector2(layout_preset.chunk_size)
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
		hint.text = pickup_notice if pickup_notice.begins_with("发现") else "获得  %s   ·   本局素材 %d" % [pickup_notice, _run_mat_total()]
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
	var definition = level_catalog.find_level(level_id) if level_catalog else null
	var target_id: StringName = definition.boss_level_id if definition else &""
	var target = level_catalog.find_level(target_id) if level_catalog else null
	if target == null or target.kind != 2:
		hint.text = "尚未配置 Boss 场景，可继续探索"
		return
	portal_dialog.hide()
	var state := capture_run()
	# 场地种子只由开局种子和稳定关卡 ID 派生，不受击杀/掉落随机数影响。
	state.stage_seed = int((str(rng.seed) + ":" + String(target_id)).hash()) + 1
	var next = prepare_stage(target_id, state)
	if next == null:
		hint.text = "Boss 场景或布局加载失败，可继续探索；本局状态未改变"
		return
	RunConfig.set_handoff(state)
	publish_stage(next)
	RunConfig.take_handoff()

func start_boss_actor() -> void:
	player.locked = true
	boss = BOSS.instantiate()
	add_child(boss)
	var definition = level_catalog.find_level(level_id) if level_catalog else null
	boss.setup(actors, rng.randf() < 0.5, player.movement_bounds, definition.boss_style if definition else 0, definition.boss_name if definition else "腐化之源")
	enemies.append(boss.entry)
	update_camera(0.0)

func capture_run() -> Dictionary:
	var state := {"run_id": run_manager.run_id, "ability": alchemy_system.ability_id,
		"stage_seed": rng.seed, "rng_seed": rng.seed, "rng_state": rng.state, "run_rewards_saved": run_rewards_saved,
		"materials": run_manager.ledger.materials.duplicate(true),
		"settlement_status": run_manager.ledger.settlement_status, "skills": [],
		"chain_cooldowns": alchemy_system.skills.chain_cooldowns.duplicate(true),
		"synergy_cooldowns": alchemy_system.synergies.cooldowns.duplicate(true),
		"upgrade_rng_seed": alchemy_system.upgrades.rng.seed,
		"upgrade_rng_state": alchemy_system.upgrades.rng.state,
		"player_cooldown": player.cooldown, "legacy_brew": {}, "outdoor": {}}
	for key in ["hp", "xp", "level", "coins", "kills", "run_time", "until_attack", "hurt_cooldown", "inventory", "first_brew", "opening_supply_eligible"]:
		state[key] = get(key).duplicate(true) if get(key) is Array else get(key)
	for runtime in alchemy_system.skills.runtimes:
		state.skills.append({"id":runtime.skill_id, "level":runtime.level, "cooldown":runtime.cooldown_left,
			"cooldown_total":runtime.cooldown_total, "config":runtime.config.duplicate(true)})
	for key in ["pills", "equipped", "bag", "cooldowns"]:
		state.legacy_brew[key] = brew.get(key).duplicate(true)
	if is_instance_valid(hd_view):
		for key in ["view_angle", "cycle_time", "clock", "camera_offset"]:
			state.outdoor[key] = hd_view.world_view.get(key)
		state.outdoor.weather_state = {}
		for key in ["current", "elapsed", "cloud_cover", "snow_cover", "upcoming", "flash_timer"]:
			var value = hd_view.world_view.weather.get(key)
			state.outdoor.weather_state[key] = value.duplicate() if value is Array else value
	return state

func restore_run(state: Dictionary) -> void:
	for key in ["hp", "xp", "level", "coins", "kills", "run_time", "until_attack", "hurt_cooldown", "inventory", "first_brew", "opening_supply_eligible", "run_rewards_saved"]:
		if state.has(key):
			set(key, state[key])
	rng.seed = int(state.get("rng_seed", rng.seed))
	rng.state = int(state.get("rng_state", rng.state))
	run_manager.ledger.materials = state.materials.duplicate(true)
	run_manager.ledger.settlement_status = state.settlement_status
	for item in state.skills:
		if alchemy_system.skills.add_skill(item.id):
			var runtime: SkillRuntime = alchemy_system.skills.runtime_for(item.id)
			runtime.level = int(item.level)
			runtime.config = item.config.duplicate(true)
			runtime.cooldown_left = float(item.cooldown)
			runtime.cooldown_total = maxf(runtime.cooldown_left, float(item.get("cooldown_total", runtime.cooldown())))
	alchemy_system.skills.chain_cooldowns = state.chain_cooldowns.duplicate(true)
	alchemy_system.synergies.cooldowns = state.synergy_cooldowns.duplicate(true)
	alchemy_system.upgrades.rng.seed = int(state.upgrade_rng_seed)
	alchemy_system.upgrades.rng.state = int(state.upgrade_rng_state)
	player.cooldown = state.player_cooldown
	for key in state.legacy_brew:
		brew.set(key, state.legacy_brew[key].duplicate(true))

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
# info: {"skill_id", "event", "from", "target", "color", "radius", "speed", "split_side", "state"}
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
	var split_side := int(info.get("split_side", 0))
	if event_name == "split_cast":
		var sideways := from.direction_to(target).orthogonal()
		if sideways.is_zero_approx():
			sideways = Vector2.DOWN
		var center := from + Vector2(0, -24)
		SKILL_FX.explosion(effects, center - sideways * 14.0, Color("#78ebcf"), 12.0)
		SKILL_FX.explosion(effects, center + sideways * 14.0, Color("#d198ff"), 12.0)
		return
	if split_side != 0:
		var accent := Color("#78ebcf") if split_side < 0 else Color("#d198ff")
		color = color.lerp(accent, 0.44)
	# 回退视图与 3D 共用逻辑状态，在真实发射、落地和区域开始时各播一次。
	var state: Dictionary = info.get("state", {})
	var state_kind := String(state.get("kind", ""))
	if state_kind in ["projectile", "blast_flask"]:
		if event_name in ["cast", "flight"]:
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
			ball.position = (state.pos as Vector2) + Vector2(0, -24)
			fallback_skill_visuals.append({"state":state, "node":ball, "fade":0.0})
			return
		if event_name == "impact" and state_kind == "projectile":
			if split_side == 0:
				FX.hit(effects, target + Vector2(0, -24), .46)
			else:
				SKILL_FX.explosion(effects, target + Vector2(0, -24), color, 16.0)
			return
	if event_name == "zone_start" and state_kind in ["zone", "pull"]:
		var cloud := FX.poison(effects, target, radius / 90.0)
		cloud.modulate = Color(color, .48)
		fallback_skill_visuals.append({"state":state, "node":cloud, "fade":0.45})
		return
	if skill_id.begins_with("sk_") or skill_id.begins_with("link_"):
		match event_name:
			"cast", "flight":
				if skill_id in ["sk_soul_needle", "link_soulbound_needle"]:
					SKILL_FX.line(effects, from, target, color)
				else:
					SKILL_FX.projectile(effects, from, target, color, speed)
			"summon_start":
				SKILL_FX.earth_spike(effects, target, color)
			"zone_start":
				SKILL_FX.zone(effects, target, color, radius)
			"hop":
				SKILL_FX.line(effects, from, target, color)
			"impact", "summon_strike", "summon_end":
				if skill_id == "sk_crystal_growth":
					SKILL_FX.ice_spike(effects, from, target, color)
				else:
					SKILL_FX.explosion(effects, target, color, clampf(radius, 16.0, 84.0))
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
	return ProfileStore.write_save(save, profile_path()) == OK

func advance_fallback_skill_visuals(delta: float) -> void:
	for index in range(fallback_skill_visuals.size() - 1, -1, -1):
		var visual := fallback_skill_visuals[index]
		var state: Dictionary = visual.state
		var node: Node2D = visual.node
		if not is_instance_valid(node):
			fallback_skill_visuals.remove_at(index)
			continue
		if String(state.kind) in ["projectile", "blast_flask"]:
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
	if is_infinite_field():
		for attempt in 24:
			at = player.position + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(640.0, 820.0)
			var blocked := false
			for block in blocks:
				var shape := block.get_child(0).shape as RectangleShape2D
				if Rect2(block.position - shape.size * 0.5, shape.size).grow(18.0).has_point(at):
					blocked = true
					break
			if not blocked:
				break
			if attempt == 23:
				return
	var body := FIELD_ENEMY.new()
	body.setup(row.kind, area, row.atlas)
	var stats: Dictionary = enemy_config.stats_for(row, run_time)
	body.configure_difficulty(stats.damage_multiplier, stats.speed_multiplier)
	actors.add_child(body)
	body.position = at
	enemies.append({"body": body, "hp": stats.hp, "max_hp": stats.hp, "boss": false})

func fire_web(at: Vector2, direction: Vector2, kind: int = FIELD_ENEMY.Kind.SPIDER, damage_multiplier := 1.0) -> void:
	if kind == FIELD_ENEMY.Kind.MUSHROOM:
		spore_patches.append({"position": at, "remaining": 2.8, "next_hit": 0.32, "damage_multiplier": damage_multiplier})
	else:
		var water := kind == FIELD_ENEMY.Kind.WATER_SPIRIT
		web_shots.append({"position": at, "direction": direction, "remaining": 1.0 if water else 1.15, "water": water, "damage_multiplier": damage_multiplier})
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
		if hit_player or not obstacle.is_empty() or shot.remaining <= 0.0 or not active_map_bounds().has_point(to_local(goal)):
			web_shots.remove_at(i)
		else:
			shot.position = goal
		if hit_player:
			hurt(FIELD_ENEMY.DAMAGE * float(shot.get("damage_multiplier", 1.0)))
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
			hurt(FIELD_ENEMY.DAMAGE * float(patch.get("damage_multiplier", 1.0)))
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
		hint.text = "%s正在崩解" % boss.display_name
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
func spawn_material_drop(at: Vector2, material_id: String, amount: int, scatter := true) -> void:
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
	sprite.position = at + (Vector2(rng.randf_range(-6.0, 6.0), rng.randf_range(-6.0, 6.0)) if scatter else Vector2.ZERO)
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
func settle_run() -> bool:
	if run_rewards_saved:
		return true
	if not run_manager:
		return false
	var before: Dictionary = profile_store.snapshot()
	save.set_value("village", "coins", int(save.get_value("village", "coins", 0)) + coins)
	if not run_manager.settle_run_materials("exit"):
		profile_store.restore(before)
		return false
	run_rewards_saved = true
	return true

func leave_run(to_menu := false) -> void:
	if not ended:
		finish(false)
	if not settle_run():
		hint.text = "保存失败，仍保留本局，请重试返回。"
		return
	RunConfig.reset()
	var village = level_catalog.find_level(&"village_greyford") if level_catalog else null
	var village_path: String = village.scene_path if village else "res://scenes/levels/village_greyford.tscn"
	var packed := load("res://scenes/menu.tscn" if to_menu else village_path) as PackedScene
	if packed == null:
		hint.text = "返回场景加载失败，本局已保存，请检查关卡总表。"
		return
	var next = packed.instantiate()
	_replace_scene(next)

func _replace_scene(next: Node) -> void:
	# All field exits preserve the active profile path before the new scene's _ready().
	next.save_path = save_path
	var tree := get_tree()
	tree.root.remove_child(self)
	tree.root.add_child(next)
	tree.current_scene = next
	queue_free()

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
	var saved := settle_run()
	# 未拾取的地面素材掉落不带出（V1.1 第4.1节），清理
	for drop in material_drops:
		if is_instance_valid(drop.sprite):
			drop.sprite.queue_free()
	material_drops.clear()
	var mat_total: int = run_manager.ledger.total() if (run_manager and run_manager.ledger) else 0
	hint.text = "%s   ·   %s   ·   素材 +%d   ·   F 返回村庄" % ["腐化之源已击败" if victory else "试炼结束", "已结算 %d 金币" % coins if saved else "保存失败", mat_total]

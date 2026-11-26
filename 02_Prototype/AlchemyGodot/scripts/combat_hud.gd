extends Control

const SKILLS := preload("res://data/brew_skills.gd").ROWS
const INGREDIENTS := preload("res://scripts/brew.gd").ICONS
const SLOT_COOLDOWN := preload("res://scripts/skill_slot_cooldown.gd")
const ABILITIES := preload("res://data/alchemy_abilities/alchemy_ability_data.gd")

var field
var panel := ""
var map_bounds: Rect2
var slot_cooldowns: Array[SLOT_COOLDOWN] = []
var phase_caption: Label

@onready var minimap: Control = $Right/Map
@onready var overlay: ColorRect = $Overlay
@onready var title: Label = $Overlay/Frame/Content/Title
@onready var actions: VBoxContainer = $Overlay/Frame/Content/Scroll/Actions

func _ready() -> void:
	phase_caption = Label.new()
	phase_caption.name = "PacingPhase"
	phase_caption.position = Vector2(-230, 46)
	phase_caption.size = Vector2(664, 32)
	phase_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_caption.add_theme_font_size_override("font_size", 14)
	phase_caption.add_theme_color_override("font_color", Color("#f0dca9"))
	phase_caption.add_theme_color_override("font_shadow_color", Color("#10140f"))
	phase_caption.add_theme_constant_override("shadow_offset_x", 1)
	phase_caption.add_theme_constant_override("shadow_offset_y", 1)
	phase_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Top.add_child(phase_caption)
	$Bottom/Alchemy.pressed.connect(toggle_alchemy)
	$Bottom/Bag.pressed.connect(toggle_bag)
	minimap.draw.connect(draw_minimap)
	$Foot.max_value = 120
	for i in 6:
		var slot: TextureRect = get_node("Bottom/Slot%d" % i)
		var cooldown := SLOT_COOLDOWN.new()
		slot.add_child(cooldown)
		cooldown.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot_cooldowns.append(cooldown)

func attach(world: Node2D, bounds: Rect2) -> void:
	field = world
	map_bounds = bounds

func _process(_delta: float) -> void:
	if not is_instance_valid(field):
		return
	$Top/Time.text = "%02d:%02d" % [floori(field.run_time / 60.0), int(field.run_time) % 60]
	var definition = field.level_catalog.find_level(field.level_id)
	phase_caption.text = "%s · %s" % [definition.display_name if definition else "战斗", field.enemy_config.phase_name(field.run_time) if not field.stage_is_boss else "独立 Boss 战"]
	if _has_split_alchemy():
		phase_caption.text += " · 分裂炼金（等待首个技能）" if field.alchemy_system.skills.runtimes.is_empty() else " · 分裂炼金"
	$Right/Kills.text = str(field.kills)
	$Right/Coins.text = str(field.coins)
	$Bottom/Level.text = "Lv.%d" % field.level
	$Bottom/XP.max_value = field.level * 6
	$Bottom/XP.value = field.xp
	$Bottom/XPText.text = "%d / %d" % [field.xp, field.level * 6]
	var brewing: bool = is_instance_valid(field.brew) and field.brew.blocks_world()
	phase_caption.visible = not field.stage_is_boss and not brewing
	$Bottom.visible = not brewing
	$Notice.visible = not brewing
	$Notice/Text.text = field.hint.text
	var foot: Vector2 = field.hd_view.screen_at(field.player.position) if is_instance_valid(field.hd_view) else field.player.get_global_transform_with_canvas().origin
	$Foot.position = foot + Vector2(-33, 9)
	$Foot.visible = not brewing and not field.ended
	$Foot.value = field.hp
	$Boss.visible = is_instance_valid(field.boss) and not field.ended
	if $Boss.visible:
		$Boss/Name.text = field.boss.display_name
		$Boss/Health.max_value = field.boss.max_hp
		$Boss/Health.value = field.boss.entry.hp
	if is_instance_valid(field.alchemy_system):
		update_slots()
	$Bottom/Bag.disabled = field.ended
	# V1.1：局内不提供炼金工房，炼金按钮始终禁用（旧局内炼丹已移除）
	$Bottom/Alchemy.disabled = true
	minimap.queue_redraw()

func _has_split_alchemy() -> bool:
	return is_instance_valid(field.alchemy_system) and field.alchemy_system.skills.ability_id == ABILITIES.ABILITY_SPLIT

func update_slots() -> void:
	var runtimes: Array = field.alchemy_system.skills.runtimes if is_instance_valid(field.alchemy_system) else []
	for i in slot_cooldowns.size():
		var rank: Label = get_node("Bottom/Level%d" % i)
		var slot: TextureRect = get_node("Bottom/Slot%d" % i)
		var rt: SkillRuntime = runtimes[i] if i < runtimes.size() else null
		slot_cooldowns[i].show_runtime(rt)
		if rt != null:
			rank.text = "Lv.%d" % rt.level
			slot.tooltip_text = "%s · %s" % [rt.base.name, rt.base.attribute]
		else:
			rank.text = ""
			slot.tooltip_text = ""

func map_point(at: Vector2) -> Vector2:
	return (at - map_bounds.position) / map_bounds.size * minimap.size

func draw_minimap() -> void:
	if not is_instance_valid(field):
		return
	if field.is_infinite_field():
		map_bounds = Rect2(field.player.position - Vector2(640, 360), Vector2(1280, 720))
	minimap.draw_rect(Rect2(Vector2.ZERO, minimap.size), Color("#292820"))
	for tile in field.tiles:
		var bounds: Rect2 = tile.rect
		if not bounds.intersects(map_bounds):
			continue
		bounds = bounds.intersection(map_bounds)
		var path: String = tile.texture.resource_path
		var tone := Color("#4e5538")
		if path.ends_with("/dirt.png"):
			tone = Color("#7b6345")
		elif path.ends_with("/cobblestone.png"):
			tone = Color("#6c695a")
		minimap.draw_rect(Rect2(map_point(bounds.position), bounds.size / map_bounds.size * minimap.size), tone)
	for prop in field.props:
		if map_bounds.has_point(prop.position):
			minimap.draw_circle(map_point(prop.position), 1.8, Color("#242d20"))
	for enemy in field.enemies:
		if is_instance_valid(enemy.body) and map_bounds.has_point(enemy.body.position):
			minimap.draw_circle(map_point(enemy.body.position), 4.0 if enemy.boss else 2.4, Color("#e26d61"))
	if is_instance_valid(field.portal):
		minimap.draw_circle(map_point(field.portal.position).clamp(Vector2(5,5), minimap.size-Vector2(5,5)), 4.0, Color("#8ce7ed"))
	var at := map_point(field.player.position)
	minimap.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -6), at + Vector2(5, 5), at + Vector2(0, 2), at + Vector2(-5, 5)]), Color("#ffe3a1"))

func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(field) or not is_instance_valid(field.brew) or field.portal_dialog.visible:
		return
	if event.is_action_pressed("skill_bag") and not field.brew.is_open() and not field.ended and panel != "pause":
		toggle_bag()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and not field.brew.is_open() and not field.ended:
		if panel.is_empty():
			open_panel("pause")
		else:
			close_panel()
		get_viewport().set_input_as_handled()

func toggle_alchemy() -> void:
	# V1.1：局内不提供炼金工房，此按钮已禁用，不再呼出旧局内炼丹。
	pass

func toggle_bag() -> void:
	if panel == "bag":
		close_panel()
	elif panel.is_empty() and not field.ended and not field.brew.is_open() and not field.portal_dialog.visible:
		open_panel("bag")

func open_panel(kind: String) -> void:
	panel = kind
	var half_height := 99.0 if kind == "pause" else 150.0
	$Overlay/Frame.offset_top = -half_height
	$Overlay/Frame.offset_bottom = half_height
	get_tree().paused = true
	overlay.show()
	for item in actions.get_children():
		actions.remove_child(item)
		item.queue_free()
	if kind == "pause":
		title.text = "暂停"
		add_action("继续战斗", close_panel)
		add_action("返回开始界面", return_to_menu)
	else:
		title.text = "已装备技能 · 分裂炼金" if _has_split_alchemy() else "已装备技能"
		var skills: SkillManager = field.alchemy_system.skills if is_instance_valid(field.alchemy_system) else null
		var runtimes: Array = skills.runtimes if skills != null else []
		if runtimes.is_empty():
			var empty := Label.new()
			empty.text = "升级获得新技能"
			empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			empty.custom_minimum_size.y = 42
			empty.add_theme_font_size_override("font_size", 15)
			empty.add_theme_color_override("font_color", Color("#ddc5a5"))
			actions.add_child(empty)
		for rt in runtimes:
			add_action("%s  Lv.%d  ·  %s" % [rt.base.name, rt.level, rt.base.attribute], Callable())
		if skills != null:
			var chain_names := PackedStringArray()
			for chain in skills.unlocked_chains():
				chain_names.append(chain.name)
			if not chain_names.is_empty():
				var note := Label.new()
				note.text = "已激活组合 · 不占槽\n%s" % "、".join(chain_names)
				note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				note.add_theme_color_override("font_color", Color("#ddc5a5"))
				actions.add_child(note)
		add_action("返回战斗", close_panel)

func add_action(caption: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size.y = 38
	button.disabled = not callback.is_valid()
	actions.add_child(button)
	if callback.is_valid():
		button.pressed.connect(callback)

func equip_skill(id: int) -> void:
	field.brew.equip_skill(id)
	open_panel("bag")

func close_panel() -> void:
	overlay.hide()
	panel = ""
	get_tree().paused = false

func return_to_menu() -> void:
	close_panel()
	field.leave_run(true)

extends Control

const SKILLS := preload("res://data/brew_skills.gd").ROWS
const INGREDIENTS := preload("res://scripts/brew.gd").ICONS

var field
var panel := ""
var map_bounds: Rect2

@onready var minimap: Control = $Right/Map
@onready var overlay: ColorRect = $Overlay
@onready var title: Label = $Overlay/Frame/Content/Title
@onready var actions: VBoxContainer = $Overlay/Frame/Content/Scroll/Actions

func _ready() -> void:
	$Bottom/Alchemy.pressed.connect(toggle_alchemy)
	$Bottom/Bag.pressed.connect(toggle_bag)
	minimap.draw.connect(draw_minimap)
	$Foot.max_value = 120

func attach(world: Node2D, bounds: Rect2) -> void:
	field = world
	map_bounds = bounds

func _process(_delta: float) -> void:
	if not is_instance_valid(field):
		return
	$Top/Time.text = "%02d:%02d" % [floori(field.run_time / 60.0), int(field.run_time) % 60]
	$Right/Kills.text = str(field.kills)
	$Right/Coins.text = str(field.coins)
	$Bottom/Level.text = "Lv.%d" % field.level
	$Bottom/XP.max_value = field.level * 6
	$Bottom/XP.value = field.xp
	$Bottom/XPText.text = "%d / %d" % [field.xp, field.level * 6]
	var brewing: bool = is_instance_valid(field.brew) and field.brew.blocks_world()
	$Bottom.visible = not brewing
	$Notice.visible = not brewing
	$Notice/Text.text = field.hint.text
	var foot: Vector2 = field.hd_view.screen_at(field.player.position) if is_instance_valid(field.hd_view) else field.player.get_global_transform_with_canvas().origin
	$Foot.position = foot + Vector2(-33, 9)
	$Foot.visible = not brewing and not field.ended
	$Foot.value = field.hp
	$Boss.visible = is_instance_valid(field.boss) and not field.ended
	if $Boss.visible:
		$Boss/Health.max_value = field.boss.MAX_HP
		$Boss/Health.value = field.boss.entry.hp
	if is_instance_valid(field.brew):
		update_slots()
	$Bottom/Bag.disabled = field.ended
	$Bottom/Alchemy.disabled = field.ended
	minimap.queue_redraw()

func update_slots() -> void:
	for i in range(6):
		var icon: TextureRect = get_node("Bottom/Icon%d" % i)
		var rank: Label = get_node("Bottom/Level%d" % i)
		var slot: TextureRect = get_node("Bottom/Slot%d" % i)
		if i < field.brew.equipped.size():
			var id: int = field.brew.equipped[i]
			var pill: Dictionary = field.brew.pills[id]
			icon.texture = INGREDIENTS[int(pill.main)]
			rank.text = "Lv.%d" % pill.level
			slot.tooltip_text = SKILLS[id].name
		else:
			icon.texture = null
			rank.text = ""
			slot.tooltip_text = ""

func map_point(at: Vector2) -> Vector2:
	return (at - map_bounds.position) / map_bounds.size * minimap.size

func draw_minimap() -> void:
	if not is_instance_valid(field):
		return
	minimap.draw_rect(Rect2(Vector2.ZERO, minimap.size), Color("#292820"))
	for tile in field.tiles:
		var bounds: Rect2 = tile.rect
		var path: String = tile.texture.resource_path
		var tone := Color("#4e5538")
		if path.ends_with("/dirt.png"):
			tone = Color("#7b6345")
		elif path.ends_with("/cobblestone.png"):
			tone = Color("#6c695a")
		minimap.draw_rect(Rect2(map_point(bounds.position), bounds.size / map_bounds.size * minimap.size), tone)
	for prop in field.props:
		minimap.draw_circle(map_point(prop.position), 1.8, Color("#242d20"))
	for enemy in field.enemies:
		if is_instance_valid(enemy.body):
			minimap.draw_circle(map_point(enemy.body.position), 4.0 if enemy.boss else 2.4, Color("#e26d61"))
	if is_instance_valid(field.portal):
		minimap.draw_circle(map_point(field.portal.position), 4.0, Color("#8ce7ed"))
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
	if panel.is_empty() and not field.ended and not field.portal_dialog.visible:
		field.brew.toggle()

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
		title.text = "技能背包"
		if field.brew.equipped.is_empty() and field.brew.bag.is_empty():
			var empty := Label.new()
			empty.text = "使用炼金获得技能"
			empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			empty.custom_minimum_size.y = 42
			empty.add_theme_font_size_override("font_size", 15)
			empty.add_theme_color_override("font_color", Color("#ddc5a5"))
			actions.add_child(empty)
		for id in field.brew.equipped:
			add_action("已装配 · %s  Lv.%d" % [SKILLS[id].name, field.brew.pills[id].level], Callable())
		for id in field.brew.bag:
			add_action("装配 · %s  Lv.%d" % [SKILLS[id].name, field.brew.pills[id].level], equip_skill.bind(id))
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
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

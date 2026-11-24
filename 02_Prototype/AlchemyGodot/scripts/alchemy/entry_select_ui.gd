extends CanvasLayer
## 出战草稿只负责选择；库存扣除和场景提交由 field 统一处理。

signal confirmed(level_id: StringName, ability_id: StringName)
signal cancelled

const ABILITIES := preload("res://data/alchemy_abilities/alchemy_ability_data.gd")
const ALCHEMY_ICON := preload("res://art/ui/combat/icon_alchemy.png")
const ABILITY_SYMBOLS := {"burst": "✦", "bounce": "↝", "pierce": "➜", "split": "⋈", "homing": "◎", "echo": "◌"}
const REFERENCE_SIZE := Vector2(1180, 620)
const GOLD := Color("f0d498")
const MUTED := Color("b4a58b")

var field
var profile: ProfileStore
var catalog: Resource
var selected_level: StringName = &""
var selected_ability: StringName = &"initial"
var busy := false
var buttons: Array[Button] = []
var level_buttons: Dictionary = {}
var ability_buttons: Dictionary = {}

@onready var panel: Control = $Panel
@onready var level_list: VBoxContainer = %LevelList
@onready var initial_list: VBoxContainer = %InitialAbility
@onready var ability_grid: GridContainer = %AbilityGrid
@onready var preview: TextureRect = %LevelPreview
@onready var destination_title: Label = %DestinationTitle
@onready var destination_description: Label = %DestinationDescription
@onready var boss_rule: Label = %BossRule
@onready var destination_summary: Label = %DestinationSummary
@onready var ability_summary: Label = %AbilitySummary
@onready var cost_summary: Label = %CostSummary
@onready var feedback: Label = %Feedback
@onready var confirm_button: Button = %Confirm

func _ready() -> void:
	%Cancel.pressed.connect(_cancel)
	%Close.pressed.connect(_cancel)
	confirm_button.pressed.connect(_confirm)
	get_viewport().size_changed.connect(_fit_panel)
	_fit_panel()

func setup(p_field, p_profile, p_catalog = null) -> void:
	field = p_field
	profile = p_profile
	catalog = p_catalog if p_catalog else load("res://levels/catalog.tres")
	var run_config := get_node_or_null("/root/RunConfig")
	if run_config and catalog and catalog.find_level(run_config.selected_level_id):
		selected_level = run_config.selected_level_id

func open() -> void:
	busy = false
	%Cancel.disabled = false
	%Close.disabled = false
	build_ui()
	visible = true
	_fit_panel()
	if level_buttons.has(selected_level):
		level_buttons[selected_level].grab_focus()
	else:
		%Cancel.grab_focus()

func close() -> void:
	visible = false
	busy = false

func show_error(message: String) -> void:
	set_busy(false)
	feedback.text = message
	feedback.add_theme_color_override("font_color", Color("ffafa0"))

func set_busy(value: bool) -> void:
	busy = value
	%Cancel.disabled = value
	%Close.disabled = value
	_refresh_selection()
	if value:
		feedback.text = "正在准备关卡…"
		feedback.add_theme_color_override("font_color", MUTED)

func build_ui() -> void:
	for container in [level_list, initial_list, ability_grid]:
		for child in container.get_children():
			child.free()
	buttons.clear()
	level_buttons.clear()
	ability_buttons.clear()
	var levels: Array = catalog.selectable_levels() if catalog else []
	if levels.is_empty():
		selected_level = &""
		var empty := _label("暂无可出发关卡\n请检查关卡总表", 16, MUTED)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		level_list.add_child(empty)
	elif not levels.any(func(entry): return entry.level_id == selected_level):
		selected_level = levels[0].level_id
	for i in levels.size():
		var entry = levels[i]
		var button := _card(entry.display_name, "目的地 %02d" % (i + 1), "", 84)
		button.name = "Level_%s" % entry.level_id
		button.tooltip_text = entry.description
		button.pressed.connect(select_level.bind(entry.level_id))
		level_list.add_child(button)
		level_buttons[entry.level_id] = button
		buttons.append(button)
	initial_list.add_child(_ability_button(&"initial", "基础炼金", "技能按基础机制运行", "永久可用 · 不消耗"))
	for ability in ABILITIES.ABILITIES:
		var count: int = profile.ability_count(ability.id) if profile else 0
		var stock := "库存 ×%d" % count if count > 0 else "暂无库存 · 需先制作"
		ability_grid.add_child(_ability_button(ability.id, ability.name, ability.desc, stock))
	if not _ability_available(selected_ability):
		selected_ability = &"initial"
	feedback.text = "切换关卡和能力不会消耗库存，确认出发后才会消耗。"
	feedback.add_theme_color_override("font_color", MUTED)
	_refresh_selection()

func select_level(level_id: StringName) -> void:
	if busy:
		return
	var entry = catalog.find_level(level_id) if catalog else null
	if not entry or not entry.enabled or not entry.selectable:
		return
	selected_level = level_id
	_refresh_selection()

func select_ability(ability_id: StringName) -> void:
	if busy or not _ability_available(ability_id):
		return
	selected_ability = ability_id
	_refresh_selection()

func _refresh_selection() -> void:
	if not is_node_ready():
		return
	var entry = catalog.find_level(selected_level) if catalog else null
	for id in level_buttons:
		_style_card(level_buttons[id], id == selected_level, busy)
	for id in ability_buttons:
		_style_card(ability_buttons[id], id == selected_ability, busy or not _ability_available(id))
	destination_title.text = entry.display_name if entry else "暂无可选关卡"
	destination_description.text = entry.description if entry else "请在「Alchemy 关卡」中配置可出发的普通关卡。"
	preview.texture = entry.preview if entry else null
	preview.visible = preview.texture != null
	boss_rule.text = "自由挑战 · 5 分钟后可自愿进入 Boss 场" if entry and not String(entry.boss_level_id).is_empty() else ""
	destination_summary.text = entry.display_name if entry else "未选择目的地"
	ability_summary.text = _ability_name(selected_ability)
	cost_summary.text = "不消耗" if selected_ability == &"initial" else "入场消耗 1 份 · 库存 %d" % (profile.ability_count(selected_ability) if profile else 0)
	cost_summary.add_theme_color_override("font_color", Color("bad8a7") if selected_ability == &"initial" else GOLD)
	confirm_button.disabled = busy or entry == null or not entry.enabled or not entry.selectable or not _ability_available(selected_ability)
	confirm_button.text = "准备中…" if busy else "确认出发  ›"

func _ability_button(id: StringName, title: String, description: String, stock: String) -> Button:
	var button := _card(title, description, stock, 78 if id == &"initial" else 70, id)
	button.name = "Ability_%s" % id
	button.tooltip_text = "%s\n%s\n%s" % [title, description, stock]
	button.pressed.connect(select_ability.bind(id))
	ability_buttons[id] = button
	buttons.append(button)
	return button

func _card(title: String, description: String, stock: String, height: float, ability_id: StringName = &"") -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, height)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_contents = true
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(margin)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)
	if not String(ability_id).is_empty():
		if ability_id == &"initial":
			var icon := TextureRect.new()
			icon.texture = ALCHEMY_ICON
			icon.custom_minimum_size = Vector2(40, 40)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(icon)
		else:
			var symbol := _label(ABILITY_SYMBOLS.get(String(ability_id), "✦"), 26, GOLD)
			symbol.custom_minimum_size = Vector2(30, 0)
			symbol.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			row.add_child(symbol)
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 2)
	row.add_child(content)
	var heading := _label(title, 16, GOLD)
	if String(ability_id).is_empty():
		heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		heading.max_lines_visible = 2
	content.add_child(heading)
	var detail := _label(description, 11, MUTED)
	detail.max_lines_visible = 1
	content.add_child(detail)
	if not stock.is_empty():
		content.add_child(_label(stock, 11, Color("d7b974")))
	return button

func _style_card(button: Button, chosen: bool, disabled: bool) -> void:
	button.disabled = disabled
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("49351fd9") if chosen else Color("201a16bb")
		style.border_color = Color("efcc81") if chosen else Color("796246")
		style.set_border_width_all(2 if chosen or state == "focus" else 1)
		style.set_corner_radius_all(5)
		if state == "hover" or state == "focus":
			style.border_color = GOLD
			style.bg_color = Color("5a4126e0")
		elif state == "pressed":
			style.bg_color = Color("75512bef")
		button.add_theme_stylebox_override(state, style)
	button.modulate = Color(1, 1, 1, 0.68) if disabled and not busy else Color.WHITE

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label

func _ability_available(id: StringName) -> bool:
	return id == &"initial" or (profile != null and profile.ability_count(id) > 0 and not ABILITIES.by_id(String(id)).is_empty())

func _ability_name(id: StringName) -> String:
	return "基础炼金" if id == &"initial" else ABILITIES.by_id(String(id)).get("name", "未选择能力")

func _confirm() -> void:
	if busy or confirm_button.disabled:
		return
	set_busy(true)
	confirmed.emit(selected_level, selected_ability)

func _cancel() -> void:
	if busy:
		return
	close()
	cancelled.emit()

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_cancel()

func _fit_panel() -> void:
	if not is_instance_valid(panel):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var factor := minf((viewport_size.x - 40.0) / REFERENCE_SIZE.x, (viewport_size.y - 36.0) / REFERENCE_SIZE.y)
	panel.size = REFERENCE_SIZE
	panel.scale = Vector2.ONE * factor
	panel.position = (viewport_size - REFERENCE_SIZE * factor) * 0.5

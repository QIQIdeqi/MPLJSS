extends Control

const SKILLS := preload("res://data/skills/skill_data.gd")
const ABILITIES := preload("res://data/alchemy_abilities/alchemy_ability_data.gd")
const COMBO_TIPS := {
	&"combo_furnace": "靠近三根木桩点亮余火，往想喷火的方向走出火星区域。",
	&"combo_thunder_coat": "测试受击时，金色雷衣破开并显示减伤。附近有攻击者时会回击。",
	&"combo_tide_mirror": "发射测试敌弹，观察青色水镜挡弹、反向推出水浪。",
	&"combo_rewind_anchor": "召出一组测试追兵，观察脚点锚印和追兵退回原位。",
	&"combo_cleanser": "先布置孢子区，待地面变亮后朝危险区闪避。",
	&"combo_crystal_gate": "靠近木桩时朝同一方向跑一段。看到出口后，在入口按空格。",
	&"combo_crystal_wall": "把三根木桩放到同一侧可检查墙体生成。绕墙需在实战验证。",
	&"combo_opening_counter": "靠近木桩并显示前摇。脚下亮起金色火星，稍后在角色周围踩踏。",
	&"combo_dew_pickup": "用测试击杀事件生成露滴，缺血时走过去拾取。",
}
const TEST_CONDITIONS := {
	&"combo_thunder_coat": "测试受击",
	&"combo_tide_mirror": "发射测试敌弹",
	&"combo_rewind_anchor": "模拟追兵靠近",
	&"combo_cleanser": "布置测试孢子区",
	&"combo_opening_counter": "显示测试前摇",
	&"combo_dew_pickup": "生成测试露滴",
}

var stage
var _panel: PanelContainer
var _body: VBoxContainer
var _fold_button: Button
var _status: Label
var _split_toggle: CheckButton
var _basic_attack_toggle: CheckButton
var _dummy_options: OptionButton
var _tabs: TabBar
var _scroll: ScrollContainer
var _skills_page: VBoxContainer
var _combos_page: VBoxContainer
var _skill_details: HBoxContainer
var _selected_name: Label
var _cooldown: Label
var _level_controls: HBoxContainer
var _levels: Array[Button] = []
var _skill_names: Dictionary[StringName, Button] = {}
var _skill_toggles: Dictionary[StringName, Button] = {}
var _combo_buttons: Dictionary[StringName, Button] = {}
var _selected_skill: StringName = &""
var _selected_combo: StringName = &""
var _combo_tip: Label
var _test_condition_button: Button
var _refresh_left := 0.0
var _selection_style: StyleBoxFlat


func setup(source) -> void:
	stage = source
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	_refresh()


func toggle_panel() -> void:
	_body.visible = not _body.visible
	_fold_button.text = "收起" if _body.visible else "展开"
	_panel.anchor_bottom = 1.0 if _body.visible else 0.0
	_panel.offset_bottom = -16.0 if _body.visible else 59.0
	_refresh()


func _process(delta: float) -> void:
	if not is_instance_valid(stage) or not _body.visible:
		return
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = 0.10
		_refresh_status()


func _build() -> void:
	_selection_style = StyleBoxFlat.new()
	_selection_style.bg_color = Color("#394331")
	_selection_style.border_color = Color("#869575")
	_selection_style.set_border_width_all(1)
	_selection_style.set_corner_radius_all(3)
	_selection_style.content_margin_left = 5.0
	_selection_style.content_margin_right = 5.0
	_panel = PanelContainer.new()
	_panel.name = "SkillTestControls"
	add_child(_panel)
	_panel.anchor_bottom = 1.0
	_panel.offset_left = 16.0
	_panel.offset_top = 16.0
	_panel.offset_right = 360.0
	_panel.offset_bottom = -16.0
	_panel.add_theme_stylebox_override("panel", _panel_style())

	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 9)
	_panel.add_child(contents)
	var header := HBoxContainer.new()
	contents.add_child(header)
	var title := _label("技能测试场", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_fold_button = _button(header, "收起", toggle_panel)
	_fold_button.tooltip_text = "Tab 展开或收起测试面板"
	_button(header, "返回菜单", stage.return_to_menu)

	_body = VBoxContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 8)
	contents.add_child(_body)
	_body.add_child(_label("WASD 移动   空格 闪避   Tab 面板", 13, Color("#bfccc1")))
	_status = _label("", 14, Color("#dbe5d6"))
	_body.add_child(_status)
	_build_arena_controls()

	_tabs = TabBar.new()
	_tabs.focus_mode = Control.FOCUS_NONE
	_tabs.add_tab("基础技能  %d" % SKILLS.ROWS.size())
	_tabs.add_tab("组合技  %d" % SKILLS.CHAINS.size())
	_tabs.tab_changed.connect(_show_page)
	_body.add_child(_tabs)

	_scroll = ScrollContainer.new()
	_scroll.name = "SkillList"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.custom_minimum_size.y = 110.0
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.get_v_scroll_bar().focus_mode = Control.FOCUS_NONE
	_body.add_child(_scroll)
	var pages := VBoxContainer.new()
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(pages)
	_skills_page = VBoxContainer.new()
	pages.add_child(_skills_page)
	_combos_page = VBoxContainer.new()
	pages.add_child(_combos_page)
	_build_lists()

	_skill_details = HBoxContainer.new()
	_selected_name = _label("", 15)
	_selected_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skill_details.add_child(_selected_name)
	_cooldown = _label("", 13, Color("#bfccc1"))
	_skill_details.add_child(_cooldown)
	_body.add_child(_skill_details)

	_level_controls = HBoxContainer.new()
	_level_controls.add_child(_label("等级", 14))
	for level in range(1, 6):
		var button := _button(_level_controls, str(level), _set_level.bind(level))
		button.name = "Level%d" % level
		button.toggle_mode = true
		button.add_theme_stylebox_override("pressed", _selection_style)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_levels.append(button)
	_body.add_child(_level_controls)
	_combo_tip = _label("", 14, Color("#f6d38d"))
	_combo_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(_combo_tip)
	_test_condition_button = _button(_body, "", _trigger_test_condition)
	_test_condition_button.name = "TestCondition"
	_show_page(0)


func _build_arena_controls() -> void:
	var options := HBoxContainer.new()
	_split_toggle = _check_button(options, "分裂炼金", stage.set_test_split)
	_split_toggle.name = "SplitAlchemy"
	_basic_attack_toggle = _check_button(options, "魔法弹", stage.set_test_basic_attack)
	_basic_attack_toggle.name = "BasicAttack"
	_body.add_child(options)

	var tools := HBoxContainer.new()
	_dummy_options = OptionButton.new()
	_dummy_options.name = "DummyCount"
	_dummy_options.focus_mode = Control.FOCUS_NONE
	for count in [1, 3, 5]:
		_dummy_options.add_item("%d 根木桩" % count, count)
	_dummy_options.item_selected.connect(_change_dummy_count)
	tools.add_child(_dummy_options)
	_button(tools, "半血", stage.set_test_half_health.bind(true))
	_button(tools, "满血", stage.set_test_half_health.bind(false))
	_body.add_child(tools)

	var actions := HBoxContainer.new()
	_button(actions, "重置冷却", stage.reset_test_cooldowns)
	_button(actions, "清空技能", _clear_skills)
	_body.add_child(actions)


func _build_lists() -> void:
	for skill: Dictionary in SKILLS.ROWS:
		var id := StringName(skill.id)
		var row := HBoxContainer.new()
		_skills_page.add_child(row)
		var name_button := _button(row, "", _select_skill.bind(id))
		name_button.name = "Select_" + String(id)
		name_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_button.toggle_mode = true
		name_button.add_theme_stylebox_override("pressed", _selection_style)
		name_button.add_theme_font_size_override("font_size", 15)
		name_button.tooltip_text = skill.get("description", "点击选择并调整技能等级")
		_skill_names[id] = name_button
		var toggle := _button(row, "", _toggle_skill.bind(id))
		toggle.name = "Equip_" + String(id)
		toggle.custom_minimum_size.x = 52.0
		_skill_toggles[id] = toggle

	var guidance := _label("点击名称，只装备这组配对技能。", 13, Color("#bfccc1"))
	_combos_page.add_child(guidance)
	for combo: Dictionary in SKILLS.CHAINS:
		var id := StringName(combo.id)
		var first: Dictionary = SKILLS.by_id(combo.parents[0])
		var second: Dictionary = SKILLS.by_id(combo.parents[1])
		var button := _button(_combos_page, "%s   %s + %s" % [combo.name, first.name, second.name],
			_equip_combo.bind(id))
		button.name = String(id)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 14)
		button.toggle_mode = true
		button.add_theme_stylebox_override("pressed", _selection_style)
		button.tooltip_text = COMBO_TIPS.get(id, "")
		_combo_buttons[id] = button


func _show_page(index: int) -> void:
	_skills_page.visible = index == 0
	_combos_page.visible = index == 1
	_level_controls.visible = index == 0
	_skill_details.visible = index == 0
	_combo_tip.visible = index == 1
	_refresh_test_condition_button()
	_scroll.scroll_vertical = 0

func _trigger_test_condition() -> void:
	if TEST_CONDITIONS.has(_selected_combo):
		stage.prepare_test_condition(_selected_combo)
		_refresh()

func _refresh_test_condition_button() -> void:
	var caption: String = TEST_CONDITIONS.get(_selected_combo, "")
	_test_condition_button.text = caption
	_test_condition_button.visible = _tabs.current_tab == 1 and not caption.is_empty()


func _select_skill(id: StringName) -> void:
	_selected_skill = id
	_refresh()


func _toggle_skill(id: StringName) -> void:
	_selected_skill = id
	_selected_combo = &""
	stage.toggle_test_skill(id)
	_refresh()


func _set_level(level: int) -> void:
	if _selected_skill != &"":
		stage.set_test_skill_level(_selected_skill, level)
		_refresh()


func _equip_combo(id: StringName) -> void:
	_selected_combo = id
	_selected_skill = StringName(SKILLS.combo_by_id(id).parents[0])
	stage.equip_test_combo(id)
	_refresh()


func _clear_skills() -> void:
	_selected_combo = &""
	stage.clear_test_skills()
	_refresh()


func _change_dummy_count(index: int) -> void:
	stage.set_test_dummy_count(_dummy_options.get_item_id(index))


func _refresh() -> void:
	var manager: SkillManager = stage.test_skills()
	_split_toggle.set_pressed_no_signal(manager.ability_id == ABILITIES.ABILITY_SPLIT)
	_basic_attack_toggle.set_pressed_no_signal(stage.test_basic_attack)
	_dummy_options.select(_dummy_options.get_item_index(stage.test_dummy_count))
	for skill: Dictionary in SKILLS.ROWS:
		var id := StringName(skill.id)
		var name_button: Button = _skill_names[id]
		var toggle: Button = _skill_toggles[id]
		var runtime := manager.runtime_for(id)
		var equipped := runtime != null
		name_button.text = "%s  ·  %s" % [skill.name, skill.attribute]
		if equipped:
			name_button.text += "  Lv.%d" % runtime.level
		name_button.set_pressed_no_signal(id == _selected_skill)
		toggle.text = "移除" if equipped else "装备"
	for id in _combo_buttons:
		_combo_buttons[id].set_pressed_no_signal(id == _selected_combo)
	_combo_tip.text = COMBO_TIPS.get(_selected_combo, "装好技能后，仍按原本的条件触发。")
	_refresh_test_condition_button()
	_refresh_status()


func _refresh_status() -> void:
	var manager: SkillManager = stage.test_skills()
	_status.text = "已装备 %d   组合 %d   生命 %.0f / %.0f" % [
		manager.runtimes.size(), manager.unlocked_chains().size(), stage.hp, stage.MAX_HP]
	var runtime := manager.runtime_for(_selected_skill)
	_selected_name.text = SKILLS.by_id(_selected_skill).get("name", "选择技能")
	_cooldown.text = "" if _selected_skill == &"" else "未装备"
	if runtime != null:
		_cooldown.text = "冷却 %.1f 秒" % runtime.cooldown_left if not runtime.ready() else "就绪"
	for index in _levels.size():
		_levels[index].disabled = runtime == null
		_levels[index].set_pressed_no_signal(runtime != null and runtime.level == index + 1)


func _button(parent: Container, caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.y = 27.0
	button.add_theme_font_size_override("font_size", 14)
	button.text = caption
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _check_button(parent: Container, caption: String, action: Callable) -> CheckButton:
	var button := CheckButton.new()
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 14)
	button.text = caption
	button.toggled.connect(action)
	parent.add_child(button)
	return button


func _label(content: String, size: int, color := Color("#f1eadb")) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.text = content
	return label


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#17231eed")
	style.border_color = Color("#6c8068")
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.set_content_margin_all(12.0)
	return style

extends CanvasLayer
# 入场选择能力 UI（V1.1 第6.2节）
# 进入战斗前选择：初始能力（始终可选）或已制作的炼金能力（有库存时可选）。

signal selected(ability_id: StringName)

const ABILITIES := preload("res://data/alchemy_abilities/alchemy_ability_data.gd")

var field
var profile: ProfileStore  # 永久库存（能力库存）
var buttons: Array = []


func setup(p_field, p_profile) -> void:
	field = p_field
	profile = p_profile

func open() -> void:
	build_ui()
	visible = true

func close() -> void:
	visible = false

func build_ui() -> void:
	var list: VBoxContainer = $Panel/Margin/VBox/Scroll/List
	for b in buttons:
		if is_instance_valid(b):
			b.queue_free()
	buttons.clear()
	# 初始能力（始终可选，永久可用）
	var init_btn := _make_button("基础炼金（初始能力）", "永久可用 · 不消耗 · 技能按基础机制运行", ABILITIES.ABILITY_INITIAL, true)
	list.add_child(init_btn)
	buttons.append(init_btn)
	# 六种炼金能力（有库存可选，明确提示本次入场消耗 1 份）
	for ab in ABILITIES.ABILITIES:
		var qty: int = profile.ability_count(ab.id) if profile else 0
		var btn := _make_button("%s  ×%d" % [ab.name, qty], "%s\n本次入场消耗 1 份" % ab.desc, ab.id, qty > 0)
		list.add_child(btn)
		buttons.append(btn)

func _make_button(title: String, desc: String, ability_id: StringName, enabled: bool) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 64)
	btn.text = "%s\n%s" % [title, desc]
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn.disabled = not enabled
	if enabled:
		btn.pressed.connect(_choose.bind(ability_id))
	return btn

func _choose(ability_id: StringName) -> void:
	# 代码层兜底校验：自制能力库存为 0 时不可选（UI 按钮已 disabled，这里双保险）
	if ability_id != ABILITIES.ABILITY_INITIAL:
		if not profile or profile.ability_count(String(ability_id)) <= 0:
			return
	visible = false
	selected.emit(ability_id)

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		# 取消入场选择，返回（不消耗）
		visible = false
		selected.emit(&"")

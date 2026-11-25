extends CanvasLayer
# 炼金工房 UI（讨论版第7、8、10章）
# 隐藏配方实验：材料选择 → 投入槽 → 实验提交 → 成功/失败反馈 → 配方图鉴。
# UI 只展示数据并请求 AlchemyService，不直接改库存。

const ABILITIES := preload("res://data/alchemy_abilities/alchemy_ability_data.gd")
const MATERIALS := preload("res://data/materials/material_data.gd")
const RECIPES := preload("res://data/materials/recipe_data.gd")

var field
var service: AlchemyService  # 炼金服务（实验匹配/扣料/加能力）
var profile: ProfileStore
var selected_materials: Array = []   # 已选材料ID（投入槽，每种最多1份）
var buttons: Array = []              # 材料按钮
var slot_buttons: Array = []         # 投入槽按钮


func setup(p_field, p_service, p_profile) -> void:
	field = p_field
	service = p_service
	profile = p_profile

func _ready() -> void:
	$Panel/Margin/Scroll/VBox/ExperimentBtn.pressed.connect(_submit_experiment)

func open() -> void:
	selected_materials.clear()
	build_ui()
	visible = true

func close() -> void:
	visible = false

func build_ui() -> void:
	for b in buttons:
		if is_instance_valid(b):
			b.queue_free()
	buttons.clear()
	slot_buttons.clear()
	var title: Label = $Panel/Margin/Scroll/VBox/Title
	title.text = "炼金工房 · 实验"
	var tier: int = profile.tier_limit() if profile else 2
	var info: Label = $Panel/Margin/Scroll/VBox/Info
	info.text = "永久素材库存（当前阶段最多投入 %d 种材料）" % tier
	var mat_row: VBoxContainer = $Panel/Margin/Scroll/VBox/Materials
	_refresh_materials(mat_row)
	var slot_label: Label = $Panel/Margin/Scroll/VBox/SlotLabel
	slot_label.text = "投入材料（%d / %d）" % [selected_materials.size(), tier]
	var slot_row: HBoxContainer = $Panel/Margin/Scroll/VBox/Slots
	_refresh_slots(slot_row)
	var feedback: Label = $Panel/Margin/Scroll/VBox/Feedback
	feedback.text = ""
	_refresh_codex()

func _refresh_materials(mat_row: VBoxContainer) -> void:
	for c in mat_row.get_children():
		c.queue_free()
	for m in MATERIALS.MATERIALS:
		var qty: int = profile.material_count(m.id) if profile else 0
		var already: bool = selected_materials.has(m.id)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 44)
		btn.text = "%s  ×%d%s" % [m.name, qty, "（已投入）" if already else ""]
		btn.disabled = already or qty <= 0
		if not btn.disabled:
			btn.pressed.connect(_select_material.bind(m.id))
		mat_row.add_child(btn)
		buttons.append(btn)

func _refresh_slots(slot_row: HBoxContainer) -> void:
	for c in slot_row.get_children():
		c.queue_free()
	var tier: int = profile.tier_limit() if profile else 2
	for i in range(tier):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 44)
		if i < selected_materials.size():
			var mid: String = selected_materials[i]
			btn.text = MATERIALS.name_of(mid)
			btn.pressed.connect(_remove_material.bind(i))
		else:
			btn.text = "空槽"
			btn.disabled = true
		slot_row.add_child(btn)
		slot_buttons.append(btn)

func _select_material(material_id: String) -> void:
	if not selected_materials.has(material_id):
		selected_materials.append(material_id)
		build_ui()

func _remove_material(index: int) -> void:
	if index >= 0 and index < selected_materials.size():
		selected_materials.remove_at(index)
		build_ui()

func _submit_experiment() -> void:
	if not service:
		return
	var recipe := RECIPES.match(selected_materials)
	var first := not recipe.is_empty() and not service.is_recipe_found(String(recipe.recipe_id))
	var result: Dictionary = service.experiment(selected_materials)
	selected_materials.clear()
	build_ui()
	var feedback: Label = $Panel/Margin/Scroll/VBox/Feedback
	if result.success:
		var ab_name: String = service.ability_name(String(result.ability_id))
		feedback.text = "实验成功！获得炼金能力「%s」%s" % [ab_name, "（新配方已发现！）" if first else ""]
	else:
		feedback.text = "实验失败：%s" % String(result.error)

# 图鉴：已发现的配方显示产出能力，未发现隐藏
func _refresh_codex() -> void:
	var codex: VBoxContainer = $Panel/Margin/Scroll/VBox/Codex
	for c in codex.get_children():
		c.queue_free()
	var title := Label.new()
	title.text = "配方图鉴"
	title.add_theme_font_size_override("font_size", 16)
	codex.add_child(title)
	var found_any := false
	for r in RECIPES.RECIPES:
		var rid: String = String(r.recipe_id)
		var state: String = profile.recipe_state(rid) if profile else "unknown"
		var line := Label.new()
		if state == "found":
			var ab := ABILITIES.by_id(String(r.ability_id))
			line.text = "「%s」→ %s" % [_recipe_materials_text(r.inputs), ab.get("name", "") if not ab.is_empty() else ""]
			line.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
			found_any = true
		else:
			line.text = "？？？（未发现）"
			line.add_theme_color_override("font_color", Color(0.5, 0.45, 0.4))
		codex.add_child(line)
	if not found_any:
		var hint := Label.new()
		hint.text = "通过实验发现配方"
		hint.add_theme_color_override("font_color", Color(0.6, 0.55, 0.5))
		codex.add_child(hint)

func _recipe_materials_text(inputs: Array) -> String:
	var names: Array = []
	for mid in inputs:
		names.append(MATERIALS.name_of(String(mid)))
	return " + ".join(names)

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

extends CanvasLayer
# 炼金工房 UI（V1.1 第5.3节）
# 局外据点唯一炼金制作入口：展示配方、素材库存、能力库存，炼制按钮。
# UI 只展示数据并请求 AlchemyService，不直接改库存。

const ABILITIES := preload("res://data/alchemy_abilities/alchemy_ability_data.gd")
const MATERIALS := preload("res://data/materials/material_data.gd")

var field
var service: AlchemyService  # 炼金服务（校验/扣料/加能力）
var profile: ProfileStore
var buttons: Array = []
var recipe_buttons: Array = []


func setup(p_field, p_service, p_profile) -> void:
	field = p_field
	service = p_service
	profile = p_profile

func open() -> void:
	build_ui()
	visible = true

func close() -> void:
	visible = false

func build_ui() -> void:
	for b in buttons:
		if is_instance_valid(b):
			b.queue_free()
	buttons.clear()
	recipe_buttons.clear()
	var title: Label = $Panel/Margin/VBox/Title
	title.text = "炼金工房"
	var materials_label: Label = $Panel/Margin/VBox/Materials
	var mat_text := "永久素材库存："
	for m in MATERIALS.MATERIALS:
		mat_text += "  %s ×%d" % [m.name, profile.material_count(m.id) if profile else 0]
	materials_label.text = mat_text
	var list: VBoxContainer = $Panel/Margin/VBox/Scroll/List
	for ab in ABILITIES.ABILITIES:
		var missing: Dictionary = service.missing_materials(ab.id) if service else {}
		var can := service.can_craft(ab.id) if service else false
		var btn := _make_recipe_button(ab, missing, can)
		list.add_child(btn)
		recipe_buttons.append(btn)

func _make_recipe_button(ab: Dictionary, missing: Dictionary, can: bool) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 72)
	var missing_text := ""
	if not missing.is_empty():
		var parts: Array = []
		for mid in missing:
			parts.append("%s 缺 %d" % [MATERIALS.name_of(String(mid)), int(missing[mid])])
		missing_text = "\n缺料：" + "、".join(parts)
	btn.text = "%s   库存 ×%d%s" % [ab.name, profile.ability_count(ab.id) if profile else 0,
		missing_text if not missing.is_empty() else ("\n" + ab.desc)]
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn.disabled = not can
	if can:
		btn.pressed.connect(_craft.bind(ab.id))
	return btn

func _craft(ability_id: String) -> void:
	if service:
		service.craft_recipe(ability_id)
	build_ui()  # 刷新库存显示

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

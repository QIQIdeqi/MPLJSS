extends Control

const CLOCK_SHADER := preload("res://shaders/skill_cooldown.gdshader")

var background: ColorRect
var mask: ColorRect
var clock: ShaderMaterial
var skill_name: Label
var seconds: Label
var shown_skill: StringName

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	background = ColorRect.new()
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.offset_left = 4.0
	background.offset_top = 4.0
	background.offset_right = -4.0
	background.offset_bottom = -4.0
	mask = ColorRect.new()
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clock = ShaderMaterial.new()
	clock.shader = CLOCK_SHADER
	mask.material = clock
	background.add_child(mask)
	mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	skill_name = _add_label(10, 0.02, 0.29)
	seconds = _add_label(16, 0.29, 0.76)
	hide()

func show_runtime(runtime: SkillRuntime) -> void:
	visible = runtime != null
	if runtime == null:
		shown_skill = &""
		return
	if shown_skill != runtime.skill_id:
		shown_skill = runtime.skill_id
		var tint: Color = runtime.base.get("color", Color.WHITE)
		background.color = Color(tint, 0.31)
		skill_name.text = String(runtime.base.get("name", "")).left(2)
		skill_name.add_theme_color_override("font_color", tint.lerp(Color("#fff2d8"), 0.66))

	var left := runtime.cooldown_left
	var cooling := left > 0.0
	mask.visible = cooling
	seconds.visible = cooling
	if cooling:
		clock.set_shader_parameter("remaining", clampf(left / maxf(0.001, runtime.cooldown_total), 0.0, 1.0))
		# Rounding upward avoids displaying 0.0 while the skill is still on cooldown.
		var tenths := maxi(1, ceili(left * 10.0 - 0.00001))
		seconds.text = "%.1fs" % (float(tenths) / 10.0)

func _add_label(font_size: int, top: float, bottom: float) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("#fff4dd"))
	label.add_theme_color_override("font_outline_color", Color("#15110d"))
	label.add_theme_constant_override("outline_size", 3)
	add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.anchor_top = top
	label.anchor_bottom = bottom
	return label

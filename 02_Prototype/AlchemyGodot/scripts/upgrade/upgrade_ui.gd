extends CanvasLayer
# 局内升级三选一 UI（策划案第7章）
# 升级时弹出，展示三个候选，玩家选择后应用。

signal chosen(pick: Dictionary)

var field
var candidates: Array = []
var buttons: Array = []


func setup(p_field) -> void:
	field = p_field

func offer(cands: Array) -> void:
	candidates = cands
	build_ui()
	visible = true
	get_tree().paused = true

func build_ui() -> void:
	# 清空旧按钮
	for b in buttons:
		if is_instance_valid(b):
			b.queue_free()
	buttons.clear()
	var title: Label = $Panel/Margin/VBox/Title
	title.text = "升级 · 三选一"
	var row: HBoxContainer = $Panel/Margin/VBox/Row
	for i in candidates.size():
		var pick: Dictionary = candidates[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(240, 160)
		btn.text = "%s\n\n%s" % [pick.get("label", ""), pick.get("desc", "")]
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.pressed.connect(_choose.bind(pick))
		row.add_child(btn)
		buttons.append(btn)

func _choose(pick: Dictionary) -> void:
	get_tree().paused = false
	visible = false
	chosen.emit(pick)

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		# 升级三选一不允许跳过（按策划案，选择后应用），但允许 Esc 关闭兜底
		pass

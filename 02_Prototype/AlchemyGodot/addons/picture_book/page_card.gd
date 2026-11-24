@tool
extends PanelContainer

signal selected(index: int)
signal moved(from: int, to: int)
const Player = preload("res://scripts/picture_book/player.gd")
var page_index := 0
var owner_token := 0

func setup(book: Resource, index: int, active: bool, token: int) -> void:
	page_index = index
	owner_token = token
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var style := StyleBoxFlat.new()
	style.bg_color = Color("243343") if active else Color("20252e")
	style.border_color = Color("77d4c5") if active else Color("414754")
	style.set_border_width_all(2 if active else 1)
	style.set_content_margin_all(7)
	style.set_corner_radius_all(5)
	add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var label := Label.new()
	label.text = "%02d  %s" % [index + 1, book.pages[index].title]
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)
	var view := Player.new()
	view.custom_minimum_size = Vector2(156, 88)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(view)
	view.show_static(book, index)
	var info := Label.new()
	info.text = ["图：保留", "图：换新", "图：清空"][book.pages[index].image_action] + "  " + ["文：保留", "文：换新", "文：清空"][book.pages[index].text_action]
	info.add_theme_font_size_override("font_size", 11)
	info.modulate = Color("aebacb")
	box.add_child(info)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		selected.emit(page_index)
		accept_event()

func _get_drag_data(_at: Vector2) -> Variant:
	var hint := Label.new()
	hint.text = "移动第 %d 页" % (page_index + 1)
	set_drag_preview(hint)
	return {"picture_book_page": page_index, "owner_token": owner_token}

func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("owner_token", -1) == owner_token and data.has("picture_book_page")

func _drop_data(_at: Vector2, data: Variant) -> void:
	if _can_drop_data(_at, data):
		moved.emit(int(data.picture_book_page), page_index)

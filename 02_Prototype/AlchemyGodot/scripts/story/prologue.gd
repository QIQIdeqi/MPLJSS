extends Control
## Presentation only; the menu owns saving and the transition into the village.

signal completed
signal back_requested

@export var book: Resource
@onready var player: Control = $Player

func _ready() -> void:
	$Controls/Previous.pressed.connect(previous_page)
	$Controls/Next.pressed.connect(next_page)
	$Controls/Skip.pressed.connect(finish_prologue)
	$Controls/Back.pressed.connect(return_to_menu)
	player.page_changed.connect(_page_changed)
	player.finished.connect(finish_prologue)
	grab_focus()
	if book == null or not book.validate().is_empty():
		show_error("序章绘本无效，请返回开始界面检查剧情配置。")
		return
	player.play(book)

func _page_changed(index: int) -> void:
	$Caption.text = "序章 · %d / %d" % [index + 1, book.pages.size()]
	$Controls/Previous.disabled = index == 0
	$Controls/Next.text = "进入村庄" if index == book.pages.size() - 1 else "确认 / 下一页"
	$Error.hide()

func previous_page() -> void:
	if book != null:
		player.play(book, maxi(0, player.index - 1))

func next_page() -> void:
	if player.is_playing:
		player.advance()
	else:
		finish_prologue()

func finish_prologue() -> void:
	player.stop()
	completed.emit()

func return_to_menu() -> void:
	player.stop()
	back_requested.emit()

func show_error(text: String) -> void:
	player.stop()
	$Error.text = text
	$Error.show()
	$Controls/Next.text = "重试进入村庄"

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		player.advance()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		return_to_menu()

extends Control
const Player = preload("res://scripts/picture_book/player.gd")
@export var book: Resource = preload("res://picture_books/demo/sample.tres")

func _ready() -> void:
	var player := Player.new()
	add_child(player)
	player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	player.play(book)
	player.finished.connect(func(): get_tree().quit())

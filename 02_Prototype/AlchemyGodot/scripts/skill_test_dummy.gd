extends Node2D

static var _texture: ImageTexture
var art := Sprite2D.new()
var _flash_left := 0.0


func _ready() -> void:
	if _texture == null:
		_texture = _make_texture()
	art.name = "Art"
	art.texture = _texture
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.position.y = -20.0
	add_child(art)
	set_process(false)


func show_hurt() -> void:
	_flash_left = 0.11
	art.modulate = Color(1.65, 1.12, 0.87)
	set_process(true)


func _process(delta: float) -> void:
	_flash_left -= delta
	if _flash_left <= 0.0:
		art.modulate = Color.WHITE
		set_process(false)


static func _make_texture() -> ImageTexture:
	var image := Image.create_empty(32, 42, false, Image.FORMAT_RGBA8)
	var outline := Color("#342520")
	var oak := Color("#98623f")
	var highlight := Color("#c58f5e")
	# Stake, crossbar and angled base.
	image.fill_rect(Rect2i(12, 4, 8, 34), outline)
	image.fill_rect(Rect2i(13, 5, 6, 32), oak)
	image.fill_rect(Rect2i(14, 5, 2, 30), highlight)
	image.fill_rect(Rect2i(2, 13, 28, 6), outline)
	image.fill_rect(Rect2i(3, 14, 26, 4), oak)
	image.fill_rect(Rect2i(4, 14, 24, 1), highlight)
	image.fill_rect(Rect2i(8, 36, 16, 4), outline)
	image.fill_rect(Rect2i(10, 36, 12, 2), oak)
	image.fill_rect(Rect2i(6, 39, 20, 3), outline)
	image.fill_rect(Rect2i(8, 39, 16, 1), oak)
	# Painted target with three rings over a chamfered board.
	for y in range(8, 32):
		for x in range(4, 28):
			var distance := Vector2(x - 15.5, y - 19.5).length_squared()
			if distance <= 138.0:
				var color := outline
				if distance <= 112.0:
					color = highlight if y < 18 else oak
				if distance <= 74.0:
					color = Color("#d0b285")
				if distance <= 49.0:
					color = Color("#a34738")
				if distance <= 24.0:
					color = Color("#efd5a5")
				if distance <= 7.0:
					color = Color("#c25c46")
				image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)

extends SceneTree

const Book = preload("res://scripts/picture_book/book.gd")
const Page = preload("res://scripts/picture_book/page.gd")
const Player = preload("res://scripts/picture_book/player.gd")
const IMAGE_A = preload("res://art/village.png")
const IMAGE_B = preload("res://art/stone.png")

var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("PICTURE_BOOK: " + message)

func make_page(label_text: String, texture: Texture2D = null) -> Resource:
	var page: Resource = Page.new()
	page.text = label_text
	page.image = texture
	return page

func run() -> void:
	var book: Resource = Book.new()
	var a: Resource = make_page("第一句", IMAGE_A)
	var b: Resource = make_page("换字，图片不闪", null)
	b.image_action = Page.Action.KEEP
	b.text_delay = 0.25
	b.text_duration = 1.0
	var c: Resource = make_page("另一张图", IMAGE_B)
	book.pages.assign([a, b, c])
	expect(book.validate().is_empty(), "valid project textures and rectangles")
	expect(book.resolve(1).image == IMAGE_A, "KEEP inherits the preceding effective image")
	book.pages.assign([a, c, b])
	expect(book.resolve(2).image == IMAGE_B, "reorder re-resolves inheritance from the new predecessor")
	book.pages.assign([b, a, c])
	expect(book.resolve(0).image == null, "first page KEEP is empty, not a cached previous image")
	book.pages.assign([a, b, c])
	var copy: Resource = b.duplicate(true)
	copy.text = "副本独立"
	copy.text_rect = Rect2(10, 20, 300, 90)
	expect(b.text == "换字，图片不闪" and b.text_rect != copy.text_rect, "duplicated page content and layout are independent")
	var clear_page: Resource = Page.new()
	clear_page.image_action = Page.Action.CLEAR
	clear_page.text_action = Page.Action.CLEAR
	var inherit_page: Resource = Page.new()
	inherit_page.image_action = Page.Action.KEEP
	inherit_page.text_action = Page.Action.KEEP
	book.pages.assign([a, clear_page, inherit_page])
	expect(book.resolve(2).image == null and book.resolve(2).text == "", "CLEAR persists through later KEEP")
	book.pages.assign([a, b, c])
	var player: Control = Player.new()
	player.size = Vector2(960, 600)
	root.add_child(player)
	await process_frame
	player.set_process(false)
	player.play(book, 1)
	expect(player.index == 1 and player.is_transitioning, "middle-page playback begins that page's entry")
	expect(player.image_current.texture == IMAGE_A and player.image_current.modulate.a == 1.0, "inherited image fully visible at entry start")
	expect(player.text_previous.text == "第一句" and player.text_previous.modulate.a == 1.0, "old text remains visible during new text delay")
	expect(player.text_current.text == "换字，图片不闪" and player.text_current.modulate.a == 0.0, "new text starts in a separate transparent buffer")
	player._process(0.75)
	expect(is_equal_approx(player.text_previous.modulate.a, 0.5) and is_equal_approx(player.text_current.modulate.a, 0.5), "text crossfade has both buffers, no blank midpoint")
	expect(player.image_current.texture == IMAGE_A and player.image_current.modulate.a == 1.0, "image stays opaque throughout text change")
	var confirm := InputEventKey.new()
	confirm.keycode = KEY_ENTER
	confirm.pressed = true
	player._unhandled_input(confirm)
	expect(player.index == 1 and not player.is_transitioning, "confirm completes transition without swallowing the page")
	expect(player.text_current.modulate.a == 1.0 and not player.text_previous.visible, "confirm leaves clean final buffers")
	confirm.echo = true
	player._unhandled_input(confirm)
	expect(player.index == 1, "held-key echo cannot skip pages")
	confirm.echo = false
	player._unhandled_input(confirm)
	expect(player.index == 2, "second deliberate confirm advances exactly one page")
	player.stop()
	player.show_static(book, 1)
	player._unhandled_input(confirm)
	expect(player.index == 1 and not player.is_playing, "editing static view never consumes confirm as playback")
	b.auto_advance = true
	b.hold_seconds = 1.0
	player.play(book, 1)
	player._process(1.24)
	expect(player.index == 1 and player.is_transitioning, "auto hold does not start before delayed entry finishes")
	player._process(0.02)
	player._process(0.98)
	expect(player.index == 1 and not player.is_transitioning, "auto counts post-entry hold only")
	player._process(0.02)
	expect(player.index == 2, "auto advances after complete entry plus hold")
	player.replay(book, 1)
	player._process(10.0)
	expect(player.index == 1 and not player.is_playing, "replay does not auto-advance even on an auto page")
	player.play(book, 1)
	player.advance()
	player._process(0.99)
	expect(player.index == 1, "manual completion starts a fresh automatic hold")
	player._process(0.02)
	expect(player.index == 2, "automatic hold also works after manual completion")
	player.play(book, 1)
	player.show_static(book, 0)
	player._process(30.0)
	expect(player.index == 0 and player.text_current.text == "第一句", "restart/static cancels all old animation and auto state")
	var ended: Array[bool] = [false]
	player.finished.connect(func() -> void: ended[0] = true)
	player.play(book, 2)
	player.advance()
	player.advance()
	expect(ended[0] and not player.is_playing and player.index == 2, "last-page advance signals finished and retains the frame")
	b.text_duration = -0.5
	expect(not book.validate().is_empty(), "invalid negative transition is rejected")
	b.text_duration = 1.0
	b.text_rect.size.x = 0.0
	expect(not book.validate().is_empty(), "zero-width text frame is rejected")
	player.queue_free()
	await process_frame
	if failures == 0:
		print("PICTURE_BOOK_RUNTIME_PASS inheritance reorder clear duplicate crossfade input auto replay restart validation")
	quit(0 if failures == 0 else 1)

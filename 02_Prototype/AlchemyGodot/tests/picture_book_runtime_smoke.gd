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
	expect(player.image_current.texture == IMAGE_A and player.image_current.modulate.a == 0.0, "KEEP resolves content but starts a new page entrance")
	expect(not player.text_previous.visible, "previous page does not crossfade into this page")
	player._process(0.75)
	expect(is_equal_approx(player.text_current.modulate.a, 0.5), "independent delayed text fade")
	expect(player.image_current.modulate.a == 1.0, "image completes before delayed text")
	var confirm := InputEventKey.new()
	confirm.keycode = KEY_ENTER
	confirm.pressed = true
	player._unhandled_input(confirm)
	expect(player.index == 1 and player.phase == "hold", "confirm finishes entrance only")
	confirm.echo = true
	player._unhandled_input(confirm)
	expect(player.phase == "hold", "key repeat ignored")
	confirm.echo = false
	player._unhandled_input(confirm)
	expect(player.index == 1 and player.phase == "exit", "hold confirm begins exit only")
	player._unhandled_input(confirm)
	expect(player.index == 2 and player.phase == "enter" and player.text_current.modulate.a == 0.0, "exit confirm enters next page without completing it")
	player.show_static(book, 1)
	player._unhandled_input(confirm)
	expect(player.index == 1 and not player.is_playing, "static editing does not advance")
	b.auto_advance = true
	b.hold_seconds = 1.0
	player.play(book, 1)
	player._process(1.24)
	expect(player.phase == "enter", "hold waits until all entrance tracks finish")
	player._process(0.02)
	player._process(0.98)
	expect(player.phase == "hold", "auto hold counts from entrance end")
	player._process(0.02)
	expect(player.phase == "exit" and player.index == 1, "auto hold starts full-page exit")
	player._process(0.51)
	expect(player.index == 2, "auto moves on only after exit")
	player.replay(book, 1)
	player._process(10.0)
	expect(player.phase == "hold" and player.index == 1 and not player.is_playing, "single replay stops at hold")
	player.play(book, 1)
	player.advance()
	player._process(0.99)
	expect(player.phase == "hold", "manual entrance completion starts fresh hold")
	player._process(0.02)
	expect(player.phase == "exit", "auto timer works after manual completion")
	player.show_static(book, 0)
	player._process(30.0)
	expect(player.index == 0 and player.text_current.text == "第一句", "static cancels all prior timers")
	var ended: Array[int] = [0]
	player.finished.connect(func() -> void: ended[0] += 1)
	player.play(book, 2)
	player.advance()
	player.advance()
	expect(ended[0] == 0 and player.phase == "exit", "last page must exit before finish")
	player.advance()
	player.advance()
	player._process(20.0)
	expect(ended[0] == 1 and player.phase == "done" and not player.is_playing, "finished emitted exactly once")
	b.text_duration = -0.5
	expect(not book.validate().is_empty(), "invalid negative transition is rejected")
	b.text_duration = 1.0
	b.text_rect.size.x = 0.0
	expect(not book.validate().is_empty(), "zero-width text frame is rejected")
	player.queue_free()
	await process_frame
	if failures == 0:
		print("PICTURE_BOOK_RUNTIME_PASS inheritance reorder clear duplicate entrance-exit input auto replay restart validation")
	quit(0 if failures == 0 else 1)

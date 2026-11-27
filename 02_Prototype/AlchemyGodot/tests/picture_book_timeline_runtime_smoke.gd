extends SceneTree
const Book = preload("res://scripts/picture_book/book.gd")
const Page = preload("res://scripts/picture_book/page.gd")
const Player = preload("res://scripts/picture_book/player.gd")
const IMAGE = preload("res://art/village.png")
var failures: int = 0
func _initialize() -> void:
	run.call_deferred()
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error("TIMELINE: " + message)
func run() -> void:
	var book: Resource = Book.new()
	var page: Resource = Page.new()
	page.image = IMAGE
	page.text = "时间轴测试"
	page.image_delay = 0.5
	page.image_duration = 1.0
	page.text_delay = 2.0
	page.text_duration = 1.0
	page.hold_seconds = 2.0
	page.exit_duration = 1.0
	page.text_backdrop_color = Color(0, 0, 0, 0.5)
	book.pages.assign([page, page.duplicate(true)])
	var player: Control = Player.new()
	player.size = Vector2(1920, 720)
	root.add_child(player)
	await process_frame
	player.set_process(false)
	var ended: Array[int] = [0]
	player.finished.connect(func() -> void: ended[0] += 1)
	player.seek(book, 0, 0.25)
	check(player.phase == "enter" and player.image_current.modulate.a == 0.0 and player.text_current.modulate.a == 0.0, "initial wait")
	player.seek(book, 0, 1.0)
	check(is_equal_approx(player.image_current.modulate.a, 0.5) and player.text_current.modulate.a == 0.0, "first independent track")
	player.seek(book, 0, 1.75)
	check(player.image_current.modulate.a == 1.0 and player.text_current.modulate.a == 0.0, "gap between tracks")
	player.seek(book, 0, 2.5)
	check(player.image_current.modulate.a == 1.0 and is_equal_approx(player.text_current.modulate.a, 0.5), "second track")
	player.seek(book, 0, 4.0)
	check(player.phase == "hold" and player.timeline_time == 4.0, "seek manual hold")
	player.seek(book, 0, 5.5)
	check(player.phase == "exit" and is_equal_approx(player.image_current.modulate.a, 0.5) and is_equal_approx(player.text_current.modulate.a, 0.5), "whole page fades together")
	check(player.background.color == book.background_color, "background remains book color during exit")
	player.seek(book, 0, 100.0)
	check(player.phase == "done" and player.timeline_time == 6.0 and player.index == 0 and ended[0] == 0, "seek clamps without finish or next page")
	player._process(100.0)
	check(player.index == 0 and not player.is_playing, "seek is stable")
	page.text_delay = 0.75
	player.seek(book, 0, 1.0)
	check(is_equal_approx(player.image_current.modulate.a, 0.5) and is_equal_approx(player.text_current.modulate.a, 0.25), "overlapping tracks")
	check(player.image_current.size.x == 1920.0 and player.image_current.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED, "full-area image covers ultrawide viewport")
	page.image_rect = Rect2(424, 112, 800, 450)
	player.show_static(book, 0)
	check(player.image_current.position == page.image_rect.position and player.image_current.size == page.image_rect.size, "legacy custom composition retained")
	page.image_fit = Page.ImageFit.CONTAIN
	player.show_static(book, 0)
	check(player.image_current.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "optional contain")
	check(player.text_current.get_theme_stylebox("normal").bg_color == page.text_backdrop_color, "backdrop is part of text label fade")
	page.image_delay = 0.0
	page.image_duration = 0.0
	page.text_delay = 0.0
	page.text_duration = 0.0
	page.hold_seconds = 0.0
	page.exit_duration = 0.0
	book.pages.assign([page])
	player.play(book)
	check(player.phase == "hold", "zero entrance immediately holds")
	player.advance()
	check(player.phase == "exit" and ended[0] == 0, "zero exit still isolates click transition")
	player.advance()
	player.advance()
	check(player.phase == "done" and ended[0] == 1, "rapid clicks finish once")
	page.auto_advance = true
	book.pages.assign([page, page.duplicate(true), page.duplicate(true)])
	player.play(book)
	player._process(0.1)
	check(player.phase == "done" and player.index == 2 and ended[0] == 2, "all-zero auto pages terminate without loop")
	player.replay(book, 0)
	player._process(100)
	check(player.phase == "hold" and not player.is_playing and player.index == 0, "zero-duration replay remains single page")
	player.stop()
	page.image_duration = 1.0
	player.play(book)
	check(player.phase == "enter" and player.timeline_time == 0 and player.image_current.modulate.a == 0.0, "restart clears all previous timing")
	page.exit_duration = -1.0
	check(not book.validate().is_empty(), "invalid new exit field rejected")
	var legacy: Resource = load("res://picture_books/demo/sample.tres")
	check(legacy != null and legacy.validate().is_empty() and legacy.pages[0].exit_duration == 0.5, "legacy resource defaults remain valid")
	player.queue_free()
	await process_frame
	if failures == 0:
		print("PICTURE_BOOK_TIMELINE_RUNTIME_PASS delay gap overlap seek exit manual auto zero restart legacy cover backdrop")
	quit(0 if failures == 0 else 1)

extends SceneTree
const Player = preload("res://scripts/picture_book/player.gd")
const Book = preload("res://scripts/picture_book/book.gd")
const Page = preload("res://scripts/picture_book/page.gd")
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error("PAPER: " + message)
func run() -> void:
	await process_frame
	var menu = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	var original_aspect = root.content_scale_aspect
	menu.get_node("Actions/Start").pressed.emit()
	var overlay = menu.prologue
	var p = overlay.player
	p.set_process(false)
	var book = overlay.book
	check(book.background_texture != null, "P00 owns its paper texture")
	check(root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_EXPAND, "P00 fills window beyond 16:9")
	var capture := OS.get_cmdline_user_args().has("--paper-capture")
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(1024,768),Vector2i(1680,720)]:
		root.size = dimensions
		await process_frame
		await process_frame
		p.play(book, 0)
		check(p.image_current.modulate.a == 0 and p.text_current.modulate.a == 0, "entrance begins above the blank sheet")
		check(p.background_image.modulate.a == 1 and p.background_image.visible, "paper stays fully opaque")
		check(p.background_image.get_rect() == Rect2(Vector2.ZERO, p.size), "paper fills every pixel of player")
		p.advance()
		p.advance()
		check(p.phase == "exit", "second click begins exit")
		p.advance()
		check(p.index == 1 and p.phase == "enter" and p.image_current.modulate.a == 0 and p.text_current.modulate.a == 0, "third click leaves actual next-page zero-alpha frame")
		check(p.background_image.modulate.a == 1, "skip never fades paper")
		if capture:
			await RenderingServer.frame_post_draw
			var im: Image = root.get_texture().get_image()
			check(absf(float(im.get_width()) / im.get_height() - float(root.size.x) / root.size.y) < .01, "render texture covers actual window aspect without black bars")
			for point in [Vector2i.ZERO, Vector2i(im.get_width()-1,0), Vector2i(0,im.get_height()-1), im.get_size()-Vector2i.ONE, im.get_size()/2]:
				var c := im.get_pixelv(point)
				check(c.r > .7 and c.g > .6 and c.b > .5 and c.a > .99, "zero-alpha frame is opaque pale paper at edges and centre")
			var destination := "user://blank-transition-%dx%d.png" % [dimensions.x,dimensions.y]
			im.save_png(destination)
			print("PAPER_NATIVE_FRAME requested=", dimensions, " window=",root.size," image=",im.get_size()," page=2 phase=enter image_alpha=0 text_alpha=0 paper_alpha=1")
		var end: float = p.entrance_duration + book.pages[1].hold_seconds + book.pages[1].exit_duration
		p.seek(book,1,end)
		check(p.image_current.modulate.a == 0 and p.text_current.modulate.a == 0 and p.background_image.modulate.a == 1, "timeline end uses the same persistent paper")
		p.play(book,0)
		p._process(p.entrance_duration + book.pages[0].hold_seconds + book.pages[0].exit_duration + .001)
		check(p.index == 1 and p.phase == "enter", "automatic exit enters next page without extra pause")
		check(p.background_image.modulate.a == 1, "automatic crossing preserves paper")
	var legacy = Book.new()
	legacy.pages.append(Page.new())
	p.show_static(legacy,0)
	check(not p.background_image.visible and p.background.color == legacy.background_color, "textureless old books restore their original backdrop")
	menu.cancel_prologue()
	await process_frame
	check(root.content_scale_aspect == original_aspect, "leaving P00 restores game scaling")
	menu.queue_free()
	await process_frame
	if failures == 0:
		print("PICTURE_BOOK_PAPER_PASS constant-alpha native-edges skip automatic seek legacy scoped-window-aspect")
	quit(0 if failures == 0 else 1)

extends SceneTree
## Reads the saved production resources; simulates the shared player without real-time waits.
## No ResourceSaver, profile store, or player-save writes are used by this test.

const Player = preload("res://scripts/picture_book/player.gd")
const Book = preload("res://scripts/picture_book/book.gd")
const Page = preload("res://scripts/picture_book/page.gd")
const Story = preload("res://scripts/story_editor/story_document.gd")
const BOOK_PATH := "res://picture_books/prologue/prologue.tres"
const STORY_PATH := "res://stories/prologue.tres"
const SOURCE := "res://../../00_Doc/美术/序章绘本/storyboard/"
const HOLDS := [6.0, 7.0, 7.0, 8.0, 7.0, 7.0, 8.0, 7.0]
const EXPECTED_LINE_COUNTS := [1, 2, 1, 2, 1, 2, 2, 1]
const LINES := [
	"我最先记住的，是她的笑。",
	"家里常有人等着喝药。我等着吃饭。",
	"原来大人有时候也要人喂。",
	"我也试了一次。药没配好，动静倒不小。",
	"后来，她教我先认清锅里放的是什么。",
	"有些人叫她魔女。我还是叫她妈妈。",
	"那晚她还没睡。我以为她明天会晚一点起床。",
	"妈妈？",
]

var failures := 0
var checks := 0

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, message: String) -> bool:
	checks += 1
	if not condition:
		failures += 1
		push_error("PROLOGUE: " + message)
	return condition

func run() -> void:
	if not expect(ResourceLoader.exists(BOOK_PATH) and ResourceLoader.exists(STORY_PATH), "saved book and story resources exist"):
		quit(1)
		return
	var book: Resource = ResourceLoader.load(BOOK_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	var story: Resource = ResourceLoader.load(STORY_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	if not expect(book != null and book.get_script() == Book and story != null and story.get_script() == Story, "resources use the shared book and story models"):
		quit(1)
		return
	var book_hash := FileAccess.get_sha256(BOOK_PATH)
	var story_hash := FileAccess.get_sha256(STORY_PATH)
	expect(book.validate().is_empty(), "production book validates")
	expect(story.validate().is_empty(), "production story validates its persisted book reference")
	expect(book.text_shadow_color.a <= 0.3, "P00 uses a low-opacity shadow")
	var defaults: Resource = Book.new()
	defaults.pages.append(Page.new())
	expect(defaults.background_color == Color("18212b") and defaults.text_shadow_color == Color(0, 0, 0, 0.85), "old books retain the dark background and black 85-percent text-shadow defaults")
	expect(defaults.resolve(0).text_shadow_color == defaults.text_shadow_color, "resolved page exposes the backward-compatible shadow style")
	if not expect(book.pages.size() == 8 and story.nodes.size() == 1, "eight pages and exactly one prologue node"):
		quit(1)
		return
	var node: Resource = story.find_node("story_p00_prologue")
	if expect(node != null, "stable prologue node ID is persisted"):
		expect(node.title == "P00｜序章：格蕾丝和我", "prologue node uses the agreed title")
		expect(not node.condition_enabled and node.completed_level_id.is_empty(), "prologue has no completion prerequisite")
		expect(node.before_book_path == BOOK_PATH and node.after_book_path.is_empty() and node.arrival_events.is_empty(), "only the pre-story slot is bound; no after-book or arrival events")
	var readme_path := ProjectSettings.globalize_path(SOURCE + "README.md").simplify_path()
	var readme := FileAccess.get_file_as_string(readme_path)
	var readme_lines: Array[String] = []
	for line: String in readme.split("\n"):
		if line.begins_with("| 0"):
			var cells := line.split("|", false)
			if cells.size() >= 2:
				readme_lines.append(cells[1].strip_edges())
	expect(readme_lines == LINES, "expected narration matches the current eight-row source README verbatim")
	var hold_total := 0.0
	var entry_total := 0.0
	for i in 8:
		var page: Resource = book.pages[i]
		var path := "res://picture_books/prologue/images/scene-%02d.png" % (i + 1)
		expect(page.image_action == Page.Action.REPLACE and page.text_action == Page.Action.REPLACE, "page %d supplies its own picture and narration" % (i + 1))
		expect(page.text.replace("\r", "").replace("\n", "") == LINES[i] and str(book.resolve(i).text).replace("\n", "") == LINES[i], "page %d preserves narration and order" % (i + 1))
		expect(Rect2(0, 0, 1280, 720).encloses(page.image_rect) and Rect2(0, 0, 1280, 640).encloses(page.text_rect), "page %d artwork and text remain inside the canvas and above controls" % (i + 1))
		expect(page.font_size >= 28 and page.text_color.a > 0.9, "page %d retains legible opaque narration" % (i + 1))
		expect(page.text_backdrop_color.a == 0.0, "page %d has no subtitle box" % (i + 1))
		expect(not page.text.contains("，\n"), "no forced line break inside a sentence")
		if expect(page.image != null, "page %d has a real imported texture" % (i + 1)):
			expect(page.image.resource_path == path and page.image.get_size() == Vector2(1672, 941), "page %d uses the correct 1672×941 source image" % (i + 1))
			var original := ProjectSettings.globalize_path(SOURCE + "scene-%02d.png" % (i + 1)).simplify_path()
			expect(FileAccess.file_exists(original) and FileAccess.get_sha256(path) == FileAccess.get_sha256(original), "page %d PNG is an exact copy of the source art" % (i + 1))
		expect(page.auto_advance and page.hold_seconds >= 6.0 and page.hold_seconds <= 8.0, "page %d stores the agreed automatic hold" % (i + 1))
		hold_total += page.hold_seconds
		entry_total += maxf(page.image_delay + page.image_duration, page.text_delay + page.text_duration)
	expect(hold_total >= 48.0 and hold_total <= 64.0, "authored holds retain the six-to-eight second reading rhythm")
	var player: Control = Player.new()
	player.size = Vector2(1280, 720)
	player.set_process(false)
	root.add_child(player)
	await process_frame
	player.show_static(book, 0)
	var background: ColorRect = player.background
	expect(background != null and background.color == book.background_color, "the actual player applies the prologue background")
	expect(player.text_current.get_theme_color("font_color") == book.pages[0].text_color and player.text_current.get_theme_color("font_shadow_color") == book.text_shadow_color, "the actual text buffer applies ink color and removes its shadow")
	player.show_static(defaults, 0)
	expect(background != null and background.color == Color("18212b") and player.text_current.get_theme_color("font_shadow_color") == Color(0, 0, 0, 0.85), "switching to an old book restores both original default styles")
	# Actual Label shaping includes theme/style content margins; font metrics alone
	# miss clipped third lines. Verify rendered line visibility at each aspect.
	for dimensions: Vector2 in [Vector2(1280, 720), Vector2(1024, 768), Vector2(1680, 720)]:
		player.size = dimensions
		for page_index in 8:
			player.show_static(book, page_index)
			await process_frame
			var label: Label = player.text_current
			var expected_lines: int = EXPECTED_LINE_COUNTS[page_index]
			var actual_lines := label.get_line_count()
			var visible_lines := label.get_visible_line_count()
			var line_details := "page=%d viewport=%s expected=%d actual=%d visible=%d" % [page_index + 1, dimensions, expected_lines, actual_lines, visible_lines]
			expect(actual_lines == expected_lines, "each authored sentence fits one line " + line_details)
			expect(visible_lines == actual_lines, "all narration lines visible " + line_details)
			expect(player.get_global_rect().encloses(label.get_global_rect()), "text safe region inside viewport page=%d viewport=%s" % [page_index + 1, dimensions])
	player.size = Vector2(1280, 720)
	var finished: Array[int] = [0]
	player.finished.connect(func() -> void: finished[0] += 1)
	var confirm := InputEventKey.new()
	confirm.keycode = KEY_ENTER
	confirm.pressed = true
	# Manual mode changes only a deep in-memory copy of the authored auto-playing resource.
	var manual: Resource = book.duplicate(true)
	for page: Resource in manual.pages:
		page.auto_advance = false
	player.play(manual)
	for i in 8:
		expect(player.index == i and player.phase == "enter", "page %d begins entry" % (i + 1))
		player._unhandled_input(confirm)
		expect(player.index == i and player.phase == "hold", "first confirm completes page %d only" % (i + 1))
		player._process(100.0)
		expect(player.index == i and player.phase == "hold", "manual page %d waits for confirmation" % (i + 1))
		player._unhandled_input(confirm)
		expect(player.index == i and player.phase == "exit", "second confirm starts page %d exit only" % (i + 1))
		player._unhandled_input(confirm)
		if i < 7:
			expect(player.index == i + 1 and player.phase == "enter", "rapid exit confirmation never consumes next page entry")
	expect(finished[0] == 1 and not player.is_playing and player.index == 7, "last exit signals completion once")
	player._unhandled_input(confirm)
	expect(finished[0] == 1, "finished playback ignores extra confirmation")
	var second: Resource = manual.pages[1]
	player.play(manual, 1)
	player._process(second.image_delay + second.image_duration * 0.5)
	expect(player.image_current.texture == second.image and is_equal_approx(player.image_current.modulate.a, 0.5), "middle-page image fades in from transparent")
	player.play(manual, 1)
	player._process(second.text_delay + second.text_duration * 0.5)
	expect(player.text_current.text == manual.resolve(1).text and is_equal_approx(player.text_current.modulate.a, 0.5), "middle-page narration fades in without flashing the previous text")
	finished[0] = 0
	player.play(book)
	var simulated_seconds := 0.0
	var exit_total := 0.0
	for i in 8:
		var page: Resource = book.pages[i]
		var entry := maxf(page.image_delay + page.image_duration, page.text_delay + page.text_duration)
		expect(player.index == i, "automatic playback reaches page %d in order" % (i + 1))
		player._process(entry)
		simulated_seconds += entry
		expect(player.index == i and not player.is_transitioning, "automatic hold begins only after page %d entry" % (i + 1))
		player._process(page.hold_seconds - 0.001)
		simulated_seconds += page.hold_seconds - 0.001
		expect(player.index == i and player.is_playing, "automatic page %d stays for its full post-entry hold" % (i + 1))
		player._process(0.002)
		simulated_seconds += 0.002
		expect(player.index == i and player.phase == "exit", "automatic reading hold is followed by exit")
		player._process(page.exit_duration)
		exit_total += page.exit_duration
		simulated_seconds += page.exit_duration
	expect(finished[0] == 1 and not player.is_playing and player.index == 7, "automatic playback finishes exactly once after all eight holds")
	expect(absf(simulated_seconds - (hold_total + entry_total + exit_total)) < 0.02, "deterministic complete duration includes every entry plus the reading holds and exits")
	expect(FileAccess.get_sha256(BOOK_PATH) == book_hash and FileAccess.get_sha256(STORY_PATH) == story_hash, "playback and manual test copies never rewrite either saved resource")
	player.queue_free()
	await process_frame
	if failures == 0:
		print("PROLOGUE_PICTURE_BOOK_PASS checks=%d pages=8 hold=%.1fs total=%.2fs source_copy narration story_ref manual entry_hold_exit auto" % [checks, hold_total, hold_total + entry_total + exit_total])
	quit(0 if failures == 0 else 1)

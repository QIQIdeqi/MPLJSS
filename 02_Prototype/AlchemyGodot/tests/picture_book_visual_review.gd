extends SceneTree
## Optional visual QA launcher. Requires an explicitly isolated XDG directory.
## Uses the production menu and its Start button. Only a deep in-memory book copy
## becomes manual; the authored P00 resource and its automatic rhythm stay intact.
var menu: Control
var configured := false
func _initialize() -> void:
	launch.call_deferred()
func launch() -> void:
	if not OS.get_environment("XDG_DATA_HOME").contains("picture-book-review"):
		push_error("Use a new dedicated XDG_DATA_HOME containing picture-book-review; refusing ordinary saves.")
		quit(2)
		return
	await process_frame
	print("REVIEW_USER_DATA=", OS.get_user_data_dir())
	menu = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
func _process(_delta: float) -> bool:
	if not is_instance_valid(menu) and is_instance_valid(current_scene) and "prologue" in current_scene:
		menu = current_scene
		configured = false
	if not is_instance_valid(menu) or not is_instance_valid(menu.prologue):
		configured = false
		return false
	if not configured:
		configured = true
		var overlay = menu.prologue
		overlay.book = overlay.book.duplicate(true)
		for page in overlay.book.pages:
			page.auto_advance = false
		overlay.player.phase_changed.connect(func(value: String): print("REVIEW_PHASE page=", overlay.player.index+1, " phase=", value))
		overlay.player.play(overlay.book)
		overlay.player.advance()
		print("REVIEW_READY page=1 phase=hold resource_unchanged=true")
	return false

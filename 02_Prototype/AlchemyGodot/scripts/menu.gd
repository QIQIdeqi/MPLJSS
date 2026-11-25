extends Control

const VILLAGE_FALLBACK := "res://scenes/levels/village_greyford.tscn"
const PROLOGUE_SCENE := preload("res://scenes/story/prologue.tscn")
const PROLOGUE_ID := "story_p00_prologue"
@export var save_path := "user://progress.cfg"
@export_file("*.tres") var prologue_story_path := "res://stories/prologue.tres"
var message: Label
var prologue: Control
var pending_prologue: ConfigFile

func _ready() -> void:
	$Actions/Start.pressed.connect(start_new)
	$Actions/Continue.pressed.connect(continue_game)
	$Actions/Quit.pressed.connect(get_tree().quit)
	refresh_continue()
	$Actions/Start.grab_focus()
	var music := AudioStreamPlayer.new()
	add_child(music)
	music.stream = preload("res://audio/Music_Menu.wav")
	var loop := music.stream.duplicate() as AudioStreamWAV
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_end = roundi(loop.get_length() * loop.mix_rate)
	music.stream = loop
	music.volume_db = -14
	music.play()

func start_new() -> void:
	if is_instance_valid(prologue):
		return
	var book := load_prologue_book()
	if book == null:
		return
	# The rolling .bak is replaced by later story/profile saves; keep the previous game separately.
	if not profile_path().is_empty() and FileAccess.file_exists(save_path):
		var backup_path := save_path + ".before_new_game"
		var suffix := 2
		while FileAccess.file_exists(backup_path):
			backup_path = save_path + ".before_new_game.%d" % suffix
			suffix += 1
		var backup_error := DirAccess.copy_absolute(ProjectSettings.globalize_path(save_path), ProjectSettings.globalize_path(backup_path))
		if backup_error != OK:
			show_message("旧进度备份失败，未开始新游戏，请检查存储空间后重试。")
			return
	var data := ConfigFile.new()
	data.set_value("village", "coins", 0)
	data.set_value("story", "prologue_completed", false)
	if ProfileStore.write_save(data, profile_path()) != OK:
		show_message("新存档保存失败，未开始序章，请检查存储空间后重试。")
		return
	show_prologue(book, data)

func profile_path() -> String:
	return "" if OS.get_cmdline_user_args().has("--migration-test") else save_path

func refresh_continue() -> void:
	if OS.get_cmdline_user_args().has("--migration-test"):
		$Actions/Continue.disabled = pending_prologue == null
		return
	var data := ConfigFile.new()
	var has_save := FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path + ".bak")
	$Actions/Continue.disabled = not has_save or ProfileStore.load_save(data, save_path) != OK

func continue_game() -> void:
	if is_instance_valid(prologue):
		return
	var data := ConfigFile.new()
	if profile_path().is_empty():
		if pending_prologue == null:
			show_message("当前内存试玩没有可继续的进度，请开始新游戏。")
			return
		data = pending_prologue
	elif ProfileStore.load_save(data, save_path) != OK:
		show_message("存档读取失败，请保留存档并检查文件。")
		return
	# Old saves predate this flag and must keep their original Continue route.
	if bool(data.get_value("story", "prologue_completed", true)):
		enter_village()
		return
	var book := load_prologue_book()
	if book != null:
		show_prologue(book, data)

func load_prologue_book() -> Resource:
	var document: Resource = load(prologue_story_path) if ResourceLoader.exists(prologue_story_path) else null
	if document == null or not document.has_method("find_node") or not document.validate().is_empty():
		show_message("序章配置无效，请在剧情编辑器检查 P00 节点和绘本。")
		return null
	var node: Resource = document.find_node(PROLOGUE_ID)
	if node == null or node.before_book_path.is_empty():
		show_message("P00 序章没有关联绘本，请在剧情编辑器检查战前绘本槽。")
		return null
	return load(node.before_book_path)

func show_prologue(book: Resource, data: ConfigFile) -> void:
	RunConfig.reset()
	pending_prologue = data
	prologue = PROLOGUE_SCENE.instantiate()
	prologue.book = book
	prologue.completed.connect(complete_prologue)
	prologue.back_requested.connect(cancel_prologue)
	$Actions.hide()
	if is_instance_valid(message):
		message.hide()
	add_child(prologue)

func complete_prologue() -> void:
	if not is_instance_valid(prologue) or pending_prologue == null:
		return
	pending_prologue.set_value("story", "prologue_completed", true)
	if ProfileStore.write_save(pending_prologue, profile_path()) != OK:
		pending_prologue.set_value("story", "prologue_completed", false)
		prologue.show_error("进度保存失败。可重试进入村庄，或返回菜单保留未完成状态。")
		return
	if not enter_village():
		prologue.show_error(message.text)

func cancel_prologue() -> void:
	if not is_instance_valid(prologue):
		return
	remove_child(prologue)
	prologue.queue_free()
	prologue = null
	$Actions.show()
	refresh_continue()
	$Actions/Continue.grab_focus()
	show_message("序章尚未看完，点击“继续游戏”可重新观看。")

func enter_village() -> bool:
	var catalog = load("res://levels/catalog.tres")
	var definition = catalog.find_level(&"village_greyford") if catalog else null
	var path: String = definition.scene_path if definition and definition.enabled and definition.kind == 0 else VILLAGE_FALLBACK
	if not ResourceLoader.exists(path, "PackedScene"):
		show_message("村庄场景配置无效，请在关卡总表检查村庄场景。")
		return false
	var packed := load(path) as PackedScene
	var next = packed.instantiate() if packed else null
	if next == null or not "save_path" in next:
		if next != null:
			next.free()
		show_message("村庄加载失败，请检查关卡总表。")
		return false
	next.save_path = save_path
	var tree := get_tree()
	RunConfig.reset()
	tree.root.remove_child(self)
	tree.root.add_child(next)
	tree.current_scene = next
	queue_free()
	return true

func show_message(text: String) -> void:
	if not is_instance_valid(message):
		message = Label.new()
		add_child(message)
		message.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		message.offset_top = -30
		message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		message.add_theme_color_override("font_color", Color("ffb49d"))
	message.text = text
	message.show()

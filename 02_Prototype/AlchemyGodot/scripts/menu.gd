extends Control

const VILLAGE_FALLBACK := "res://scenes/levels/village_greyford.tscn"
@export var save_path := "user://progress.cfg"
var message: Label

func _ready() -> void:
	$Actions/Start.pressed.connect(start_new)
	$Actions/Continue.pressed.connect(enter_village)
	$Actions/Quit.pressed.connect(get_tree().quit)
	var data := ConfigFile.new()
	var has_save := not OS.get_cmdline_user_args().has("--migration-test") and (FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path + ".bak"))
	$Actions/Continue.disabled = not has_save or ProfileStore.load_save(data, save_path) != OK
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
	var data := ConfigFile.new()
	data.set_value("village", "coins", 0)
	if ProfileStore.write_save(data, "" if OS.get_cmdline_user_args().has("--migration-test") else save_path) != OK:
		show_message("新存档保存失败，未进入村庄，请检查存储空间后重试。")
		return
	enter_village()

func enter_village() -> void:
	var catalog = load("res://levels/catalog.tres")
	var definition = catalog.find_level(&"village_greyford") if catalog else null
	var path: String = definition.scene_path if definition and definition.enabled and definition.kind == 0 else VILLAGE_FALLBACK
	if not ResourceLoader.exists(path, "PackedScene"):
		show_message("村庄场景配置无效，请在关卡总表检查村庄场景。")
		return
	var packed := load(path) as PackedScene
	var next = packed.instantiate() if packed else null
	if next == null or not "save_path" in next:
		if next != null:
			next.free()
		show_message("村庄加载失败，请检查关卡总表。")
		return
	next.save_path = save_path
	var tree := get_tree()
	RunConfig.reset()
	tree.root.remove_child(self)
	tree.root.add_child(next)
	tree.current_scene = next
	queue_free()

func show_message(text: String) -> void:
	if not is_instance_valid(message):
		message = Label.new()
		add_child(message)
		message.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		message.offset_top = -30
		message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		message.add_theme_color_override("font_color", Color("ffb49d"))
	message.text = text

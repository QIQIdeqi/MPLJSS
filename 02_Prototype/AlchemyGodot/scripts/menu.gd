extends Control

func _ready() -> void:
	$Actions/Start.pressed.connect(start_new)
	$Actions/Continue.pressed.connect(enter_village)
	$Actions/Quit.pressed.connect(get_tree().quit)
	$Actions/Continue.disabled = not FileAccess.file_exists("user://progress.cfg")
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
	data.save("user://progress.cfg")
	enter_village()

func enter_village() -> void:
	get_tree().change_scene_to_file("res://scenes/village.tscn")

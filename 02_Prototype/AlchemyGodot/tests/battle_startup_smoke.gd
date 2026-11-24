extends SceneTree

# 无界面启动检查：强制解析并实例化开始游戏后加载的战斗场景。
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var battle_scene := load("res://scenes/battle.tscn") as PackedScene
	if battle_scene == null:
		push_error("battle_startup_smoke: battle scene failed to load")
		quit(1)
		return
	var battle := battle_scene.instantiate()
	if battle.get_script() == null:
		push_error("battle_startup_smoke: field script failed to compile")
		battle.free()
		quit(1)
		return
	root.add_child(battle)
	await process_frame
	await process_frame
	if battle.alchemy_system == null or battle.run_manager == null:
		push_error("battle_startup_smoke: battle systems failed to initialize")
		quit(1)
		return
	print("battle_startup_smoke: battle scene instantiated successfully")
	quit()

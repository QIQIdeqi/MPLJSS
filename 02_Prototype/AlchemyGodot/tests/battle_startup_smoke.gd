extends SceneTree

# 无界面启动检查：强制解析并实例化开始游戏后加载的战斗场景。
const BATTLE_SCENE := preload("res://scenes/battle.tscn")

func _initialize() -> void:
	var battle := BATTLE_SCENE.instantiate()
	root.add_child(battle)
	await process_frame
	await process_frame
	print("battle_startup_smoke: battle scene instantiated successfully")
	quit()

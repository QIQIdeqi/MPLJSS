extends Node
# 全局运行时配置（autoload 单例）
# 跨场景传递：本局选择的炼金能力、入场消耗状态等。

const ABILITIES := preload("res://data/alchemy_abilities/alchemy_ability_data.gd")

var selected_ability: StringName = ABILITIES.ABILITY_INITIAL  # 本局能力
var entry_confirmed := false  # 是否已确认入场（用于消耗判定）


func set_ability(id: StringName) -> void:
	selected_ability = id

func reset() -> void:
	selected_ability = ABILITIES.ABILITY_INITIAL
	entry_confirmed = false

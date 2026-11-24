@tool
extends Resource
## One monster and its relative spawn weight in each wave.

@export_enum("骨棒骷髅", "白翼蝙蝠", "黑斑蛛", "灰鬃幼狼", "水蓝史莱姆", "赤斑菇", "流水灵") var kind := 0
@export var display_name := ""
@export var atlas: Texture2D
@export var wave_weights: PackedFloat32Array
@export_group("战斗数值（测试默认）")
@export_range(0.1, 500.0, 0.1) var base_hp := 3.0
@export_range(0.1, 3.0, 0.05) var damage_multiplier := 1.0
@export_range(0.5, 1.2, 0.01) var speed_multiplier := 1.0

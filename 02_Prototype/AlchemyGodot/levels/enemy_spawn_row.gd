@tool
extends Resource
## One monster and its relative spawn weight in each wave.

@export_enum("骨棒骷髅", "白翼蝙蝠", "黑斑蛛", "灰鬃幼狼", "水蓝史莱姆", "赤斑菇", "流水灵") var kind := 0
@export var display_name := ""
@export var atlas: Texture2D
@export var wave_weights: PackedFloat32Array

@tool
extends Resource

const Brush = preload("res://levels/brush.gd")

@export var grid := Vector2i(24, 18)
@export_range(1, 8) var ground_patch := 3
@export_range(0.0, 1.0) var object_density := 0.24
@export var object_spacing := 74.0
@export var protected_half_width := 32.0
@export var boss := false
@export var palette: Array[Brush] = []
@export_group("编辑器预览")
@export var preview_seed := 77
@export_storage var ground_seed_offset := 0
@export_storage var prop_seed_offset := 0
@export_storage var locked_ground: Dictionary = {}
@export_storage var locked_props: Dictionary = {}

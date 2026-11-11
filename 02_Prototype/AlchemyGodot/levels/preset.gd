@tool
extends Resource

const Brush = preload("res://levels/brush.gd")
const MAP_BOUNDS := Rect2(0, 0, 1280, 720)
const DEFAULT_PLAYABLE_BOUNDS := Rect2(32, 110, 1216, 542)
const DEFAULT_PORTAL := Vector2(1120, 330)
const MIN_PLAYABLE_SIZE := Vector2i(640, 360)
const MAX_PLAYABLE_SIZE := Vector2i(1280, 720)

@export var grid := Vector2i(24, 18)
@export_range(1, 8) var ground_patch := 3
@export_range(0.0, 1.0) var object_density := 0.24
@export var object_spacing := 74.0
@export var protected_half_width := 32.0
@export var boss := false
@export var palette: Array[Brush] = []
@export_group("战斗边界（像素）")
@export var playable_size := Vector2i(DEFAULT_PLAYABLE_BOUNDS.size):
	set(value):
		var next := value.clamp(MIN_PLAYABLE_SIZE, MAX_PLAYABLE_SIZE)
		if playable_size != next:
			playable_size = next
			emit_changed()
@export_group("编辑器预览")
@export var preview_seed := 77
@export_storage var ground_seed_offset := 0
@export_storage var prop_seed_offset := 0
@export_storage var locked_ground: Dictionary = {}
@export_storage var locked_props: Dictionary = {}

func playable_bounds(bounds: Rect2 = MAP_BOUNDS) -> Rect2:
	var size := Vector2(playable_size).min(bounds.size)
	var center := bounds.position + DEFAULT_PLAYABLE_BOUNDS.get_center() / MAP_BOUNDS.size * bounds.size
	return Rect2((center - size * 0.5).clamp(bounds.position, bounds.end - size), size)

func portal_position(bounds: Rect2 = MAP_BOUNDS) -> Vector2:
	var playable := playable_bounds(bounds)
	var preferred := bounds.position + DEFAULT_PORTAL / MAP_BOUNDS.size * bounds.size
	return preferred.clamp(playable.position + Vector2(55, 45), playable.end - Vector2(55, 45))

func arena_half_size(bounds: Rect2 = MAP_BOUNDS) -> Vector2:
	return bounds.size * Vector2(0.29, 0.34) * (playable_bounds(bounds).size / DEFAULT_PLAYABLE_BOUNDS.size)

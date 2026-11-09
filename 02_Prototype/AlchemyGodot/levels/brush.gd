@tool
extends Resource

@export var display_name := ""
@export var texture: Texture2D
@export var ground := false
@export_range(0, 100) var weight := 1.0
## X is the minimum and Y the maximum. Each -1 endpoint is unrestricted.
@export var count_range := Vector2i(-1, -1)
## Fraction of all map cells. This intersects Count Range.
@export var density_range := Vector2(-1, -1)
@export var size := Vector2(64, 64)
## Zero means this object is decorative and has no collision.
@export var collision := Vector2.ZERO
@export_range(0.0, 1.0) var foot_fraction := 0.88
@export var boss_interior := false

extends Sprite2D
# 旋风环绕特效：围绕中心点旋转的风刃，一段时间后消失。

var center := Vector2.ZERO
var radius := 60.0
var angular_speed := 6.0
var lifetime := 0.8
var _age := 0.0


func setup(p_center: Vector2, p_radius: float, p_lifetime: float) -> void:
	center = p_center
	radius = p_radius
	lifetime = p_lifetime
	global_position = center + Vector2(radius, 0)


func _process(delta: float) -> void:
	_age += delta
	var angle := _age * angular_speed
	global_position = center + Vector2(cos(angle), sin(angle)) * radius
	if _age >= lifetime:
		queue_free()

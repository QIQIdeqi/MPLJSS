extends RefCounted

const SKILLS := preload("res://data/skills/skill_data.gd")

var _manager: WeakRef


func setup(manager) -> void:
	_manager = weakref(manager)


func scale(id: StringName) -> float:
	var manager: Variant = _manager.get_ref() if _manager != null else null
	var recipe := SKILLS.combo_by_id(id)
	if manager == null or recipe.is_empty():
		return 0.0
	var first: SkillRuntime = manager.runtime_for(recipe.parents[0])
	var second: SkillRuntime = manager.runtime_for(recipe.parents[1])
	if first == null or second == null:
		return 0.0
	var level := clampi(mini(first.level, second.level), 1, 5)
	return 1.0 + 0.18 * (level - 1)


func ready(id: StringName) -> bool:
	var manager: Variant = _manager.get_ref() if _manager != null else null
	return manager != null and float(manager.chain_cooldowns.get(id, 0.0)) <= 0.0 and scale(id) > 0.0


func commit(id: StringName) -> float:
	var manager: Variant = _manager.get_ref() if _manager != null else null
	if manager == null or float(manager.chain_cooldowns.get(id, 0.0)) > 0.0:
		return 0.0
	var multiplier := scale(id)
	if multiplier > 0.0:
		manager.chain_cooldowns[id] = float(SKILLS.combo_by_id(id).cooldown)
	return multiplier


func emit(id: StringName, info: Dictionary) -> void:
	var manager: Variant = _manager.get_ref() if _manager != null else null
	if manager == null or not is_instance_valid(manager.field) or not manager.field.has_method("play_skill_fx"):
		return
	var payload := info.duplicate()
	payload.skill_id = id
	payload.color = SKILLS.combo_by_id(id).get("color", Color.WHITE)
	manager.field.play_skill_fx(payload)


func clip(context: Dictionary, from: Vector2, target: Vector2) -> Vector2:
	var segment_clip: Callable = context.get("clip_segment", Callable())
	if segment_clip.is_valid():
		return segment_clip.call(from, target)
	var bounds: Rect2 = context.get("bounds", Rect2())
	if not bounds.has_area() or bounds.has_point(target):
		return target
	var motion := target - from
	var clipped_fraction := 1.0
	for axis in [0, 1]:
		if not is_zero_approx(motion[axis]):
			var edge: float = bounds.end[axis] if motion[axis] > 0.0 else bounds.position[axis]
			clipped_fraction = minf(clipped_fraction, (edge - from[axis]) / motion[axis])
	return from.lerp(target, clampf(clipped_fraction, 0.0, 1.0))


func clear_path(context: Dictionary, from: Vector2, target: Vector2) -> bool:
	return clip(context, from, target).distance_squared_to(target) < 0.04

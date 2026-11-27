class_name SkillManager
extends RefCounted

# V2 的逻辑层：投射物、区域、刻印和固定连锁都在这里保有真实寿命，
# 不在施放帧直接结算全部伤害。field 只负责敌人、伤害反馈与视觉桥接。
const SKILLS := preload("res://data/skills/skill_data.gd")
const ABILITIES := preload("res://data/alchemy_abilities/alchemy_ability_data.gd")
const BLAST_FLASK := &"sk_blast_flask"
const SPLIT_LAUNCH_OFFSET := 16.0

var field
var ability_id: StringName = ABILITIES.ABILITY_INITIAL
var runtimes: Array[SkillRuntime] = []
var max_skill_slots := 6
var active: Array[Dictionary] = []
var chain_cooldowns: Dictionary = {}
var brittle_marks: Dictionary[int, Dictionary] = {}
var combat_clock := 0.0

func setup(p_ability_id: StringName, p_field) -> void:
	ability_id = p_ability_id
	field = p_field

func add_skill(skill_id: StringName) -> bool:
	if runtimes.size() >= max_skill_slots or has_skill(skill_id):
		return false
	var runtime := SkillRuntime.new()
	runtime.setup(skill_id, ability_id, [])
	if runtime.base.is_empty():
		return false
	runtimes.append(runtime)
	return true

func has_skill(skill_id: StringName) -> bool:
	return runtime_for(skill_id) != null

func runtime_for(skill_id: StringName) -> SkillRuntime:
	for runtime in runtimes:
		if runtime.skill_id == skill_id:
			return runtime
	return null

# 组合从当前拥有的基础技能推导，不加入 runtimes（装备槽）。
func unlocked_chains() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for chain: Dictionary in SKILLS.CHAINS:
		if has_skill(StringName(chain.parents[0])) and has_skill(StringName(chain.parents[1])):
			result.append(chain)
	return result

func clear() -> void:
	runtimes.clear()
	clear_active()
	chain_cooldowns.clear()

func clear_active() -> void:
	combat_clock = 0.0
	for state in active:
		state.finished = true
	active.clear()
	for mark: Dictionary in brittle_marks.values():
		mark.finished = true
	brittle_marks.clear()

func cast_equipped(delta: float, player_pos: Vector2, enemies: Array, apply_hit: Callable,
		context: Dictionary = {}) -> void:
	combat_clock += delta
	for chain_id in chain_cooldowns.keys():
		chain_cooldowns[chain_id] = maxf(0.0, float(chain_cooldowns[chain_id]) - delta)
	for runtime in runtimes:
		runtime.tick(delta)
		if not runtime.ready():
			continue
		if _cast_extension(runtime, player_pos, enemies, context):
			continue
		var target := densest_enemy(player_pos, runtime.range_px(), enemies) if runtime.behavior() == SKILLS.BEHAVIOR_BOTTLE else nearest_enemy(player_pos, runtime.range_px(), enemies)
		if target.is_empty():
			continue # 无有效目标不进入冷却
		runtime.reset_cooldown()
		_cast(runtime, player_pos, target, enemies)
	_update_active(delta, player_pos, enemies, apply_hit, context)

# 返回 true 代表此技能走扩展规则，等待触发时也不进入旧的自动索敌流程。
func _cast_extension(runtime: SkillRuntime, from: Vector2, enemies: Array, context: Dictionary) -> bool:
	var split := ability_id == ABILITIES.ABILITY_SPLIT
	var facing: Vector2 = context.get("facing", Vector2.DOWN)
	if facing.is_zero_approx():
		facing = Vector2.DOWN
	match runtime.behavior():
		SKILLS.BEHAVIOR_FEATHER_DRAUGHT, SKILLS.BEHAVIOR_WIND_BOOTS, \
		SKILLS.BEHAVIOR_RETURN_WIND_POWDER, SKILLS.BEHAVIOR_DEW_TONIC:
			# 角色移动、闪避与实际治疗条件由玩家侧处理。
			pass
		SKILLS.BEHAVIOR_THUNDER_SALT, SKILLS.BEHAVIOR_FROST_POWDER:
			_cast_extension_toss(runtime, from, enemies, split)
		SKILLS.BEHAVIOR_FIRE_OIL:
			if bool(context.get("moving", false)) and not nearest_enemy(from, runtime.range_px(), enemies).is_empty():
				runtime.reset_cooldown()
				active.append({"kind": "oil_trail", "runtime": runtime, "pos": from,
					"left": float(runtime.value("lay_time")), "sample_distance": 0.0, "split": split,
					"lane_hits": {-1: {}, 0: {}, 1: {}}, "finished": false})
				_emit_fx(runtime, "cast", from, from + facing * 24.0)
		SKILLS.BEHAVIOR_MERCURY_RING:
			var radius := runtime.radius_px() * (ABILITIES.SPLIT_AREA_RATIO if split else 1.0)
			if not nearest_enemy(from, radius, enemies).is_empty():
				runtime.reset_cooldown()
				if split:
					_start_mercury_ring(runtime, from, radius, -1, 0.0)
					_start_mercury_ring(runtime, from, radius, 1, .10)
				else:
					_start_mercury_ring(runtime, from, radius, 0, 0.0)
		SKILLS.BEHAVIOR_WIND_FLASK:
			_cast_wind_flask(runtime, from, facing, enemies, split, context.get("bounds", Rect2()))
		SKILLS.BEHAVIOR_RENEWAL_FLASK:
			var heal: Callable = context.get("heal", Callable())
			if heal.is_valid() and float(context.get("missing_health", 0.0)) > 0.0:
				runtime.reset_cooldown()
				var bounds: Rect2 = context.get("bounds", Rect2())
				if split:
					var offset := facing.orthogonal().normalized() * 20.0
					_start_renewal_pool(runtime, _clamp_to_bounds(from - offset, bounds), -1)
					_start_renewal_pool(runtime, _clamp_to_bounds(from + offset, bounds), 1)
				else:
					_start_renewal_pool(runtime, _clamp_to_bounds(from, bounds), 0)
		_:
			return false
	return true

func _cast_extension_toss(runtime: SkillRuntime, from: Vector2, enemies: Array, split: bool) -> void:
	var frost := runtime.behavior() == SKILLS.BEHAVIOR_FROST_POWDER
	var target := _extension_toss_target(from, runtime.range_px(), enemies, frost)
	if target.is_empty():
		return
	runtime.reset_cooldown()
	if not split:
		_start_extension_toss(runtime, from, target, frost, Vector2.ZERO, 0)
		return
	var secondary := _extension_toss_target(from, runtime.range_px(), enemies, frost, target.body)
	var point: Vector2 = target.body.position
	var direction := from.direction_to(point)
	var lateral := (Vector2.RIGHT if direction.is_zero_approx() else direction).orthogonal()
	var offset := lateral * SPLIT_LAUNCH_OFFSET
	_start_extension_toss(runtime, from - offset, target, frost, -offset if secondary.is_empty() else Vector2.ZERO, -1)
	_start_extension_toss(runtime, from + offset, target if secondary.is_empty() else secondary,
		frost, offset if secondary.is_empty() else Vector2.ZERO, 1)

func _extension_toss_target(from: Vector2, reach: float, enemies: Array, frost: bool,
		excluded: Node2D = null) -> Dictionary:
	var target := {}
	var priority := false
	var best_distance := INF
	for entry: Dictionary in enemies:
		if not _living(entry) or entry.body == excluded:
			continue
		var elite := bool(entry.get("boss", false)) or bool(entry.get("elite", false))
		var distance := from.distance_squared_to(entry.body.position)
		if distance > reach * reach or (frost and elite):
			continue
		if target.is_empty() or (elite and not priority) or (elite == priority and distance < best_distance):
			target = entry
			priority = elite
			best_distance = distance
	return target

func _start_extension_toss(runtime: SkillRuntime, from: Vector2, target: Dictionary, frost: bool,
		landing_offset: Vector2, side: int) -> void:
	var landing: Vector2 = target.body.position
	if frost:
		landing += landing_offset
	var speed := float(runtime.value("speed", 720.0))
	var duration := maxf(.08, from.distance_to(landing) / speed) if frost else float(runtime.value("flight_time", .32))
	var state := {
		"kind": "extension_toss", "runtime": runtime, "frost": frost, "pos": from, "origin": from,
		"target": target, "landing": landing, "direction": from.direction_to(landing),
		"left": duration, "duration": duration, "flight_height": 0.0, "speed": from.distance_to(landing) / duration,
		"radius": runtime.radius_px() * (1.0 if side == 0 else ABILITIES.SPLIT_AREA_RATIO),
		"ratio": 1.0 if side == 0 else ABILITIES.SPLIT_DAMAGE_RATIO, "split_side": side, "finished": false,
	}
	active.append(state)
	_emit_state_fx(state, "cast", from, landing)

func _start_mercury_ring(runtime: SkillRuntime, at: Vector2, radius: float, side: int, delay: float) -> void:
	var speed := float(runtime.value("speed"))
	var state := {
		"kind": "mercury_ring", "runtime": runtime, "pos": at, "radius": radius,
		"current_radius": 0.0, "speed": speed, "duration": radius / speed, "delay": delay, "hit": {},
		"ratio": 1.0 if side == 0 else ABILITIES.SPLIT_DAMAGE_RATIO, "split_side": side, "finished": false,
	}
	active.append(state)
	if delay <= 0.0:
		_emit_state_fx(state, "zone_start", at, at)

func _cast_wind_flask(runtime: SkillRuntime, from: Vector2, facing: Vector2, enemies: Array, split: bool,
		bounds: Rect2) -> void:
	var radius := runtime.range_px() * (ABILITIES.SPLIT_AREA_RATIO if split else 1.0)
	var half_angle := deg_to_rad(float(runtime.value("half_angle_degrees")))
	var candidates: Array[Dictionary] = []
	for entry: Dictionary in enemies:
		if _living(entry) and not bool(entry.get("boss", false)) and from.distance_to(entry.body.position) <= radius:
			candidates.append(entry)
	if candidates.is_empty():
		return
	var direction := facing.normalized()
	var best_count := -1
	var best_distance := INF
	for candidate: Dictionary in candidates:
		var point: Vector2 = candidate.body.position
		var aim := from.direction_to(point)
		if aim.is_zero_approx():
			aim = facing.normalized()
		var count := 0
		for entry in candidates:
			if _inside_wind_cone(from, aim, entry.body.position, half_angle):
				count += 1
		var distance := from.distance_squared_to(point)
		if count > best_count or (count == best_count and distance < best_distance):
			direction = aim
			best_count = count
			best_distance = distance
	runtime.reset_cooldown()
	var push := float(runtime.value("push_units")) * SKILLS.UNIT * (ABILITIES.SPLIT_DAMAGE_RATIO if split else 1.0)
	var sides: Array = [-1, 1] if split else [0]
	var pushed := {}
	for side: int in sides:
		var angle := direction.rotated(deg_to_rad(20.0) * side)
		_emit_fx(runtime, "impact", from, from + angle * radius, {
			"direction": angle, "radius": radius, "half_angle": half_angle, "split_side": side})
		for entry in candidates:
			var body: Node2D = entry.body
			if pushed.has(body) or not _inside_wind_cone(from, angle, body.position, half_angle):
				continue
			pushed[body] = true
			var away := from.direction_to(body.position)
			if away.is_zero_approx():
				away = angle
			var displacement := away * push * (.5 if bool(entry.get("elite", false)) else 1.0)
			displacement = _clamp_to_bounds(body.position + displacement, bounds) - body.position
			if body is CharacterBody2D:
				body.move_and_collide(displacement)
			else:
				body.position += displacement

func _inside_wind_cone(from: Vector2, direction: Vector2, point: Vector2, half_angle: float) -> bool:
	var toward := from.direction_to(point)
	return toward.is_zero_approx() or direction.dot(toward) >= cos(half_angle)

func _clamp_to_bounds(point: Vector2, bounds: Rect2) -> Vector2:
	return point.clamp(bounds.position, bounds.end) if bounds.has_area() else point

func _start_renewal_pool(runtime: SkillRuntime, at: Vector2, side: int) -> void:
	var duration := float(runtime.value("duration"))
	_add_effect_state({
		"kind": "renewal_pool", "runtime": runtime, "pos": at, "left": duration, "duration": duration,
		"radius": runtime.radius_px() * (1.0 if side == 0 else ABILITIES.SPLIT_AREA_RATIO), "split_side": side,
		"next_tick": float(runtime.value("tick_interval")),
		"amount": float(runtime.value("heal")) * (1.0 if side == 0 else ABILITIES.SPLIT_DAMAGE_RATIO),
	}, "zone_start")

func _cast(runtime: SkillRuntime, from: Vector2, target: Dictionary, enemies: Array = []) -> void:
	if ability_id == ABILITIES.ABILITY_SPLIT:
		_cast_split(runtime, from, target, enemies)
	else:
		_cast_branch(runtime, from, target)

func _cast_split(runtime: SkillRuntime, from: Vector2, target: Dictionary, enemies: Array) -> void:
	var point: Vector2 = target.body.position
	var direction := from.direction_to(point)
	var lateral := (Vector2.RIGHT if direction.is_zero_approx() else direction).orthogonal()
	var other := _split_target(from, point, runtime.range_px(), target, enemies)
	var grouped := other.is_empty()
	if grouped:
		other = target
	_emit_fx(runtime, "split_cast", from, point)
	if grouped and runtime.behavior() == SKILLS.BEHAVIOR_MARK:
		_apply_brittle_mark(runtime, other, {
			"ratio": 2.0 * ABILITIES.SPLIT_DAMAGE_RATIO, "split_merged": true,
		})
		return
	for side: int in [-1, 1]:
		var branch_target: Dictionary = target if side < 0 else other
		var offset := lateral * SPLIT_LAUNCH_OFFSET * side
		var branch := {"split_side":side, "ratio":ABILITIES.SPLIT_DAMAGE_RATIO,
			"split_offset":offset}
		if grouped:
			# 两个地面效果落在同一目标的两侧，仍以玩家的原始射程为上限。
			branch.landing = from + (point + offset * 2.25 - from).limit_length(runtime.range_px())
		_cast_branch(runtime, from + offset, branch_target, branch)

func _split_target(from: Vector2, point: Vector2, reach: float, first: Dictionary, enemies: Array) -> Dictionary:
	var closest := {}
	var best := INF
	for entry in enemies:
		if not _living(entry) or entry.body == first.body:
			continue
		var position: Vector2 = entry.body.position
		if from.distance_squared_to(position) > reach * reach:
			continue
		var distance := point.distance_squared_to(position)
		if distance < best:
			best = distance
			closest = entry
	return closest

func _cast_branch(runtime: SkillRuntime, from: Vector2, target: Dictionary, branch: Dictionary = {}) -> void:
	var point: Vector2 = target.body.position
	var ratio := float(branch.get("ratio", 1.0))
	if runtime.skill_id == BLAST_FLASK:
		_launch_blast_flask(runtime, from, branch.get("landing", point), branch)
		return
	var behavior := runtime.behavior()
	match behavior:
		SKILLS.BEHAVIOR_MARK:
			_apply_brittle_mark(runtime, target, branch)
		SKILLS.BEHAVIOR_CRYSTAL:
			var direction := from.direction_to(point)
			var radius := 42.0 * _branch_area_ratio(branch)
			for index in int(runtime.value("count", 5)):
				active.append({"kind":"delayed_hit", "runtime":runtime, "left":float(runtime.value("step_delay", .06)) * index,
					"pos":from + direction * (58.0 + index * 46.0), "radius":radius, "ratio":ratio,
					"direction":direction, "split_side":int(branch.get("split_side", 0)), "direct_hit":true})
		SKILLS.BEHAVIOR_NEEDLE:
			_spawn_needles(runtime, target, ratio, branch)
		SKILLS.BEHAVIOR_POOL, SKILLS.BEHAVIOR_MIST:
			_spawn_projectile(runtime, from, target, "zone_on_hit", ratio, branch)
		SKILLS.BEHAVIOR_PULL:
			_spawn_projectile(runtime, from, target, "pull_on_hit", ratio, branch)
		SKILLS.BEHAVIOR_BOTTLE:
			_spawn_projectile(runtime, from, target, "blast_on_hit", ratio, branch)
		SKILLS.BEHAVIOR_BOUNCE:
			_spawn_projectile(runtime, from, target, "bounce_on_hit", ratio, branch)
		SKILLS.BEHAVIOR_BLADE:
			_spawn_projectile(runtime, from, target, "pierce_on_hit", ratio, branch)
		SKILLS.BEHAVIOR_GEL:
			_spawn_projectile(runtime, from, target, "gel_on_hit", ratio, branch)

func _branch_area_ratio(state: Dictionary) -> float:
	return ABILITIES.SPLIT_AREA_RATIO if int(state.get("split_side", 0)) != 0 else 1.0

func _apply_brittle_mark(runtime: SkillRuntime, target: Dictionary, branch: Dictionary) -> void:
	if not _living(target):
		return
	var body_id: int = target.body.get_instance_id()
	_take_brittle_mark(body_id)
	var point: Vector2 = target.body.position
	var mark := {
		"kind": "brittle_mark", "runtime": runtime, "target": target, "pos": point,
		"left": float(runtime.value("duration", 2.5)), "ratio": float(branch.get("ratio", 1.0)),
		"split_side": int(branch.get("split_side", 0)),
		"split_merged": bool(branch.get("split_merged", false)),
		"finished": false,
	}
	brittle_marks[body_id] = mark
	_emit_state_fx(mark, "mark_start", point, point)

func _update_brittle_marks(delta: float, enemies: Array) -> void:
	for body_id: int in brittle_marks.keys():
		var mark: Dictionary = brittle_marks[body_id]
		var target: Dictionary = mark.target
		mark.left = float(mark.left) - delta
		if mark.left <= 0.0 or not _living(target) or not enemies.has(target):
			_take_brittle_mark(body_id)
		else:
			mark.pos = target.body.position

func _take_brittle_mark(body_id: int) -> Dictionary:
	var mark: Dictionary = brittle_marks.get(body_id, {})
	if not mark.is_empty():
		brittle_marks.erase(body_id)
		mark.finished = true
	return mark

func discard_brittle_mark(entry: Dictionary) -> void:
	if is_instance_valid(entry.get("body")):
		_take_brittle_mark(entry.body.get_instance_id())

# 由直接命中在扣血前调用，使附伤与本次命中合并。
func break_brittle_mark(entry: Dictionary) -> float:
	if not _living(entry):
		return 0.0
	var mark := _take_brittle_mark(entry.body.get_instance_id())
	if mark.is_empty():
		return 0.0
	var point: Vector2 = entry.body.position
	mark.pos = point
	_emit_state_fx(mark, "mark_break", point, point)
	var runtime: SkillRuntime = mark.runtime
	return runtime.damage() * float(mark.ratio)

func _launch_blast_flask(runtime: SkillRuntime, from: Vector2, landing: Vector2, branch: Dictionary = {}) -> void:
	# 只在范围内选中活目标时出手。药瓶瞄准地面，出手后不再依赖怪物节点。
	var state := {
		"kind": "blast_flask",
		"runtime": runtime,
		"pos": from,
		"landing": landing,
		"direction": from.direction_to(landing),
		"radius": runtime.radius_px() * _branch_area_ratio(branch),
		"ratio": float(branch.get("ratio", 1.0)),
		"split_side": int(branch.get("split_side", 0)),
		"speed": maxf(1.0, float(runtime.config.get("speed", 310.0))),
		"finished": false,
	}
	active.append(state)
	_emit_fx(runtime, "cast", from, landing, state)

func _spawn_projectile(runtime: SkillRuntime, from: Vector2, target: Dictionary, impact: String,
		ratio := 1.0, branch: Dictionary = {}) -> void:
	if not _living(target):
		return
	var point: Vector2 = target.body.position
	var speed := maxf(1.0, float(runtime.config.get("speed", 420.0)))
	var state := {"kind":"projectile", "runtime":runtime, "pos":from,
		"target":target, "direction":from.direction_to(point), "impact":impact,
		"ratio":ratio, "speed":speed, "left":maxf(.35, runtime.range_px() / speed + .25),
		"finished":false}
	if impact in ["zone_on_hit", "pull_on_hit", "blast_on_hit"]:
		# 药剂和引力石在出手时锁定地面，目标消失不会中断落地。
		point = branch.get("landing", point)
		state.landing = point
		state.direction = from.direction_to(point)
		state.radius = runtime.radius_px() * _branch_area_ratio(branch)
	state.split_side = int(branch.get("split_side", 0))
	active.append(state)
	_emit_state_fx(state, "flight", from, point)

func _spawn_needles(runtime: SkillRuntime, target: Dictionary, ratio := 1.0, branch: Dictionary = {}) -> void:
	for index in int(runtime.value("count", 3)):
		var launch_delay := float(runtime.value("interval", .12)) * index
		active.append({"kind":"delayed_projectile", "runtime":runtime, "left":launch_delay,
			"target":target, "ratio":ratio, "branch":branch})

func _update_active(delta: float, player_pos: Vector2, enemies: Array, apply_hit: Callable,
		context: Dictionary = {}) -> void:
	_update_brittle_marks(delta, enemies)
	for index in range(active.size() - 1, -1, -1):
		var state := active[index]
		var finished := false
		match String(state.kind):
			"extension_toss":
				finished = _advance_extension_toss(state, delta, enemies, apply_hit)
			"oil_trail":
				finished = _advance_oil_trail(state, delta, player_pos, context.get("bounds", Rect2()))
			"oil_patch":
				finished = _advance_oil_patch(state, delta, enemies, apply_hit)
			"mercury_ring":
				finished = _advance_mercury_ring(state, delta, enemies, apply_hit)
			"renewal_pool":
				finished = _advance_renewal_pool(state, delta, player_pos, context.get("heal", Callable()))
			"delayed_projectile":
				state.left = float(state.left) - delta
				if state.left <= 0.0:
					var runtime: SkillRuntime = state.runtime
					if _living(state.target) and player_pos.distance_to(state.target.body.position) <= runtime.range_px():
						var branch: Dictionary = state.branch
						var origin: Vector2 = player_pos + (branch.get("split_offset", Vector2.ZERO) as Vector2)
						_spawn_projectile(runtime, origin, state.target, "needle_on_hit",
							float(state.ratio), branch)
					finished = true
			"delayed_hit":
				state.left = float(state.left) - delta
				if state.left <= 0.0:
					_emit_state_fx(state, "impact", state.pos, state.pos)
					_hit_area(state.runtime, state.pos, float(state.radius), enemies, apply_hit,
						float(state.ratio), 0.0, 0.0, bool(state.get("direct_hit", false)))
					finished = true
			"blast_flask":
				var landing: Vector2 = state.landing
				state.pos = (state.pos as Vector2).move_toward(landing, float(state.speed) * delta)
				if state.pos == landing:
					var runtime: SkillRuntime = state.runtime
					_emit_state_fx(state, "impact", landing, landing)
					_hit_area(runtime, landing, float(state.radius), enemies, apply_hit,
						float(state.ratio), 0.0, 0.0, true)
					if int(state.split_side) == 0:
						_apply_ability(runtime, landing, enemies, apply_hit)
					finished = true
			"projectile":
				state.left = float(state.left) - delta
				var locked_ground := state.has("landing")
				if not locked_ground and not _living(state.target):
					finished = true
				else:
					var point: Vector2 = state.landing if locked_ground else state.target.body.position
					var direction := (state.pos as Vector2).direction_to(point)
					if direction != Vector2.ZERO:
						state.direction = direction
					state.pos = (state.pos as Vector2).move_toward(point, float(state.speed) * delta)
					var tolerance := 0.0 if locked_ground else 18.0
					if (state.pos as Vector2).distance_to(point) <= tolerance:
						_resolve_projectile(state, point, enemies, apply_hit)
						finished = true
					elif state.left <= 0.0 and not locked_ground:
						finished = true
			"zone":
				state.left = float(state.left) - delta
				state.tick_left = float(state.tick_left) - delta
				if state.tick_left <= 0.0:
					state.tick_left += .5
					_emit_state_fx(state, "zone_tick", state.pos, state.pos)
					_hit_area(state.runtime, state.pos, float(state.radius), enemies, apply_hit, float(state.ratio), float(state.slow), float(state.slow_duration))
				if state.left <= 0.0:
					finished = true
			"pull":
				state.left = float(state.left) - delta
				# 两份引力各用一半牵引，重叠时不会把同一目标拉得比原版更快。
				var strength := 0.5 if int(state.get("split_side", 0)) != 0 else 1.0
				for entry in enemies:
					if _living(entry) and entry.body.position.distance_to(state.pos) <= float(state.radius):
						entry.body.position = entry.body.position.lerp(state.pos, minf(.12, delta * .55) * strength)
				if state.left <= 0.0:
					finished = true
		if state.get("finished", false):
			# 战斗回调可能结束整个场景并清空状态。
			return
		if finished:
			state.finished = true
			active.remove_at(index)
		else:
			active[index] = state

func _advance_extension_toss(state: Dictionary, delta: float, enemies: Array, apply_hit: Callable) -> bool:
	var target: Dictionary = state.target
	var frost := bool(state.frost)
	if not frost and (not _living(target) or not enemies.has(target)):
		return true
	var landing: Vector2 = state.landing if frost else target.body.position
	var runtime: SkillRuntime = state.runtime
	state.left = maxf(0.0, float(state.left) - delta)
	var progress := 1.0 - float(state.left) / float(state.duration)
	var origin: Vector2 = state.origin
	state.pos = origin.lerp(landing, progress)
	state.direction = origin.direction_to(landing)
	state.flight_height = 4.0 * float(runtime.value("flight_height")) * progress * (1.0 - progress)
	if float(state.left) > 0.00001:
		return false
	_emit_state_fx(state, "impact", landing, landing)
	if frost:
		var duration := float(runtime.value("duration")) * float(state.ratio)
		for entry: Dictionary in enemies:
			if not _living(entry) or bool(entry.get("boss", false)) or bool(entry.get("elite", false)):
				continue
			if landing.distance_to(entry.body.position) <= float(state.radius):
				var previous_freeze := float(entry.get("freeze_left", 0.0))
				entry.freeze_left = maxf(duration, previous_freeze)
				if previous_freeze <= 0.0:
					_emit_fx(runtime, "freeze_start", landing, entry.body.position, {
						"radius": 24.0, "duration": duration, "freeze_target": entry, "split_side": state.split_side,
					})
	else:
		_hit(runtime, target, apply_hit, float(state.ratio), 0.0, 0.0, enemies)
	return true

func _advance_oil_trail(state: Dictionary, delta: float, player_pos: Vector2, bounds: Rect2) -> bool:
	var runtime: SkillRuntime = state.runtime
	var origin: Vector2 = state.pos
	var end := origin.lerp(player_pos, minf(1.0, float(state.left) / maxf(delta, .00001)))
	var distance := origin.distance_to(end)
	var direction := origin.direction_to(end)
	var spacing := float(runtime.value("spacing"))
	var traveled := spacing - float(state.sample_distance)
	var sides: Array = [-1, 1] if bool(state.split) else [0]
	# 跳转不生成跨场景或跨瞬移位置的油路。
	if distance <= SKILLS.UNIT * 2.0:
		while traveled <= distance:
			for side: int in sides:
				var point := origin + direction * traveled + direction.orthogonal() * SPLIT_LAUNCH_OFFSET * side
				if not bounds.has_area() or bounds.has_point(point):
					_start_oil_patch(runtime, point, side, state.lane_hits[side])
			traveled += spacing
		state.sample_distance = spacing - (traveled - distance)
	else:
		state.sample_distance = 0.0
	state.pos = player_pos
	state.left = float(state.left) - delta
	return float(state.left) <= 0.00001

func _start_oil_patch(runtime: SkillRuntime, at: Vector2, side: int, lane_hits: Dictionary) -> void:
	var duration := float(runtime.value("duration"))
	_add_effect_state({
		"kind": "oil_patch", "runtime": runtime, "pos": at, "left": duration, "duration": duration,
		"radius": runtime.radius_px() * (1.0 if side == 0 else ABILITIES.SPLIT_AREA_RATIO),
		"ratio": 1.0 if side == 0 else ABILITIES.SPLIT_DAMAGE_RATIO, "split_side": side,
		"next_tick": float(runtime.value("tick_interval")), "lane_hits": lane_hits,
	}, "zone_start")

func _advance_oil_patch(state: Dictionary, delta: float, enemies: Array, apply_hit: Callable) -> bool:
	var runtime: SkillRuntime = state.runtime
	var interval := float(runtime.value("tick_interval"))
	state.left = maxf(0.0, float(state.left) - delta)
	var elapsed := float(state.duration) - float(state.left)
	if elapsed + 0.00001 >= float(state.next_tick):
		state.next_tick = float(state.next_tick) + interval
		var point: Vector2 = state.pos
		for entry: Dictionary in enemies.duplicate():
			if not _living(entry) or point.distance_to(entry.body.position) > float(state.radius):
				continue
			var id: int = entry.body.get_instance_id()
			if combat_clock + 0.00001 >= float(state.lane_hits.get(id, 0.0)):
				state.lane_hits[id] = combat_clock + interval
				_hit(runtime, entry, apply_hit, float(state.ratio))
				if state.finished:
					return true
	return float(state.left) <= 0.00001

func _advance_mercury_ring(state: Dictionary, delta: float, enemies: Array, apply_hit: Callable) -> bool:
	if float(state.delay) > 0.0:
		state.delay = float(state.delay) - delta
		if float(state.delay) > 0.00001:
			return false
		delta = maxf(0.0, -float(state.delay))
		state.delay = 0.0
		_emit_state_fx(state, "zone_start", state.pos, state.pos)
	var previous := float(state.current_radius)
	var radius := float(state.radius)
	var current := minf(radius, previous + float(state.speed) * delta)
	state.current_radius = current
	var point: Vector2 = state.pos
	for entry: Dictionary in enemies.duplicate():
		if not _living(entry):
			continue
		var distance := point.distance_to(entry.body.position)
		if distance < previous or distance > current:
			continue
		var id: int = entry.body.get_instance_id()
		if not state.hit.has(id):
			state.hit[id] = true
			_hit(state.runtime, entry, apply_hit, float(state.ratio), 0.0, 0.0, enemies)
			if state.finished:
				return true
	return current >= radius

func _advance_renewal_pool(state: Dictionary, delta: float, player_pos: Vector2, heal: Callable) -> bool:
	var runtime: SkillRuntime = state.runtime
	state.left = maxf(0.0, float(state.left) - delta)
	var elapsed := float(state.duration) - float(state.left)
	var point: Vector2 = state.pos
	var interval := float(runtime.value("tick_interval"))
	while elapsed + 0.00001 >= float(state.next_tick):
		state.next_tick = float(state.next_tick) + interval
		if heal.is_valid() and point.distance_to(player_pos) <= float(state.radius):
			var recovered := float(heal.call(float(state.amount)))
			if recovered > 0.0:
				_emit_state_fx(state, "heal", point, player_pos)
	return float(state.left) <= 0.00001

func _resolve_projectile(state: Dictionary, point: Vector2, enemies: Array, apply_hit: Callable) -> void:
	var runtime: SkillRuntime = state.runtime
	var ratio := float(state.get("ratio", 1.0))
	var radius := float(state.get("radius", runtime.radius_px()))
	var side := int(state.get("split_side", 0))
	_emit_state_fx(state, "impact", state.pos, point)
	match String(state.impact):
		"blast_on_hit": _hit_area(runtime, point, radius, enemies, apply_hit, ratio, 0.0, 0.0, true)
		"bounce_on_hit":
			_hit_projectile_chain(state, enemies, apply_hit, float(runtime.value("bounce_units", 3.2)) * SKILLS.UNIT)
		"pull_on_hit":
			_hit_area(runtime, point, radius * .62, enemies, apply_hit, ratio, 0.0, 0.0, true)
			_add_effect_state({"kind":"pull", "runtime":runtime, "pos":point,
				"left":float(runtime.value("duration", 2.4)), "radius":radius, "split_side":side}, "zone_start")
		"zone_on_hit":
			_add_effect_state({"kind":"zone", "runtime":runtime, "pos":point,
				"left":float(runtime.value("duration", 3.0)), "tick_left":.5,
				"radius":radius, "ratio":ratio, "slow":float(runtime.value("slow", 0.0)),
				"slow_duration":2.0, "split_side":side}, "zone_start")
		"pierce_on_hit":
			_hit_projectile_chain(state, enemies, apply_hit, runtime.range_px())
		"gel_on_hit":
			_hit(runtime, state.target, apply_hit, ratio, float(runtime.value("slow", .3)),
				float(runtime.value("slow_duration", 2.0)), enemies)
		"needle_on_hit":
			_hit(runtime, state.target, apply_hit, ratio, 0.0, 0.0, enemies)
	if state.finished:
		return
	if side == 0:
		_apply_ability(runtime, point, enemies, apply_hit)

func _hit_projectile_chain(state: Dictionary, enemies: Array, apply_hit: Callable, reach: float) -> void:
	var runtime: SkillRuntime = state.runtime
	var used: Array = []
	var current: Dictionary = state.target
	var previous: Vector2 = state.pos
	for turn in int(runtime.value("targets", 3)):
		if not _living(current):
			break
		var point: Vector2 = current.body.position
		used.append(current.body)
		if turn > 0:
			_emit_state_fx(state, "hop", previous, point)
		_hit(runtime, current, apply_hit, float(state.get("ratio", 1.0)), 0.0, 0.0, enemies)
		previous = point
		current = nearest_enemy(point, reach, enemies, used)

func _hit(runtime: SkillRuntime, entry: Dictionary, apply_hit: Callable, ratio := 1.0, slow := 0.0,
		slow_duration := 0.0, direct_targets: Array = []) -> void:
	if not _living(entry): return
	var damage := runtime.damage() * ratio
	if damage > 0.0 and not direct_targets.is_empty():
		damage += break_brittle_mark(entry)
	apply_hit.call(entry, damage, slow_duration, maxf(0.0, 1.0 - slow), runtime.base.color)

func _hit_area(runtime: SkillRuntime, at: Vector2, radius: float, enemies: Array, apply_hit: Callable,
		ratio := 1.0, slow := 0.0, slow_duration := 0.0, direct_hit := false) -> void:
	var direct_targets: Array = enemies if direct_hit else []
	for entry in enemies.duplicate():
		if _living(entry) and entry.body.position.distance_to(at) <= radius:
			_hit(runtime, entry, apply_hit, ratio, slow, slow_duration, direct_targets)

func _apply_ability(runtime: SkillRuntime, at: Vector2, enemies: Array, apply_hit: Callable) -> void:
	var ability := ABILITIES.by_id(ability_id)
	if ability.is_empty(): return
	match String(ability.effect_type):
		ABILITIES.EFFECT_BURST: _hit_area(runtime, at, 54.0, enemies, apply_hit, .30)
		ABILITIES.EFFECT_BOUNCE:
			var next := nearest_enemy(at, 150.0, enemies)
			if not next.is_empty(): _hit(runtime, next, apply_hit, .65)
		ABILITIES.EFFECT_ECHO: active.append({"kind":"delayed_hit", "runtime":runtime, "left":.35, "pos":at, "radius":48.0, "ratio":.55})

func _add_effect_state(state: Dictionary, event_name: String) -> void:
	state.finished = false
	active.append(state)
	_emit_state_fx(state, event_name, state.pos, state.pos)

func _emit_state_fx(state: Dictionary, event_name: String, from: Vector2, target: Vector2) -> void:
	_emit_fx(state.runtime, event_name, from, target, state)

func _emit_fx(runtime: SkillRuntime, event_name: String, from: Vector2, target: Vector2, state: Dictionary = {}) -> void:
	if field == null or not field.has_method("play_skill_fx"): return
	var info := {"skill_id":state.get("fx_id", runtime.skill_id), "event":event_name,
		"from":from, "target":target, "color":state.get("fx_color", runtime.base.color),
		"radius":state.get("radius", runtime.radius_px()),
		"speed":float(state.get("speed", runtime.config.get("speed", 420.0))), "split_side":int(state.get("split_side", 0))}
	if not state.is_empty():
		info.state = state
	field.play_skill_fx(info)

func _living(entry: Dictionary) -> bool:
	return entry.get("hp", 0.0) > 0.0 and is_instance_valid(entry.get("body")) and not entry.body.is_queued_for_deletion()

func nearest_enemy(at: Vector2, reach: float, enemies: Array, excluded: Array = []) -> Dictionary:
	var closest := {}
	var best := reach * reach
	for entry in enemies:
		if not _living(entry) or excluded.has(entry.body): continue
		var distance := at.distance_squared_to(entry.body.position)
		if distance <= best and (closest.is_empty() or distance < best):
			best = distance
			closest = entry
	return closest

func densest_enemy(at: Vector2, reach: float, enemies: Array) -> Dictionary:
	var best := {}
	var best_score := -INF
	for candidate in enemies:
		if not _living(candidate) or candidate.body.position.distance_to(at) > reach: continue
		var score := 0.0
		for other in enemies:
			if _living(other) and other.body.position.distance_to(candidate.body.position) <= 96.0:
				score += 1.0
		score -= candidate.body.position.distance_to(at) / maxf(reach, 1.0) * .15
		if score > best_score:
			best_score = score
			best = candidate
	return best

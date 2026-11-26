class_name SkillManager
extends RefCounted

# V2 的逻辑层：投射物、区域、刻印和固定连锁都在这里保有真实寿命，
# 不在施放帧直接结算全部伤害。field 只负责敌人、伤害反馈与视觉桥接。
const SKILLS := preload("res://data/skills/skill_data.gd")
const ABILITIES := preload("res://data/alchemy_abilities/alchemy_ability_data.gd")
const BLAST_FLASK := &"sk_blast_flask"
const BLAST_MARK := &"link_blast_mark"
const SPLIT_LAUNCH_OFFSET := 16.0

var field
var ability_id: StringName = ABILITIES.ABILITY_INITIAL
var runtimes: Array[SkillRuntime] = []
var max_skill_slots := 6
var active: Array[Dictionary] = []
var chain_cooldowns: Dictionary = {}
var brittle_marks: Dictionary[int, Dictionary] = {}

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
	for state in active:
		state.finished = true
	active.clear()
	for mark: Dictionary in brittle_marks.values():
		mark.finished = true
	brittle_marks.clear()

func cast_equipped(delta: float, player_pos: Vector2, enemies: Array, apply_hit: Callable) -> void:
	for chain_id in chain_cooldowns.keys():
		chain_cooldowns[chain_id] = maxf(0.0, float(chain_cooldowns[chain_id]) - delta)
	for runtime in runtimes:
		runtime.tick(delta)
		if not runtime.ready():
			continue
		var target := densest_enemy(player_pos, runtime.range_px(), enemies) if runtime.behavior() == SKILLS.BEHAVIOR_BOTTLE else nearest_enemy(player_pos, runtime.range_px(), enemies)
		if target.is_empty():
			continue # 无有效目标不进入冷却
		runtime.reset_cooldown()
		_cast(runtime, player_pos, target, enemies)
	_update_active(delta, player_pos, enemies, apply_hit)

func _cast(runtime: SkillRuntime, from: Vector2, target: Dictionary, enemies: Array = []) -> void:
	var point: Vector2 = target.body.position
	if ability_id == ABILITIES.ABILITY_SPLIT:
		_cast_split(runtime, from, target, enemies)
	else:
		_cast_branch(runtime, from, target)
	# 落点和破印型组合各自等待触发事件。
	if not _chain_on_impact(runtime) and runtime.behavior() != SKILLS.BEHAVIOR_MARK:
		_try_chain(runtime, from, point, target)

func _cast_split(runtime: SkillRuntime, from: Vector2, target: Dictionary, enemies: Array) -> void:
	var point: Vector2 = target.body.position
	var direction := from.direction_to(point)
	var lateral := (Vector2.RIGHT if direction.is_zero_approx() else direction).orthogonal()
	var other := _split_target(from, point, runtime.range_px(), target, enemies)
	var grouped := other.is_empty()
	if grouped:
		other = target
	var chain_gate := {"used": false}
	_emit_fx(runtime, "split_cast", from, point)
	if grouped and runtime.behavior() == SKILLS.BEHAVIOR_MARK:
		_apply_brittle_mark(runtime, other, {
			"ratio": 2.0 * ABILITIES.SPLIT_DAMAGE_RATIO, "split_chain_gate": chain_gate, "split_merged": true,
		})
		return
	for side: int in [-1, 1]:
		var branch_target: Dictionary = target if side < 0 else other
		var offset := lateral * SPLIT_LAUNCH_OFFSET * side
		var branch := {"split_side":side, "ratio":ABILITIES.SPLIT_DAMAGE_RATIO,
			"split_origin":from, "split_offset":offset, "split_chain_gate":chain_gate}
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

func _chain_on_impact(runtime: SkillRuntime) -> bool:
	return runtime.skill_id in [&"sk_gravity_stone", &"sk_mist_flask", &"sk_obsidian_blade"]

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
			_spawn_needles(runtime, target, false, ratio, branch)
		SKILLS.BEHAVIOR_POOL, SKILLS.BEHAVIOR_MIST:
			_spawn_projectile(runtime, from, target, "zone_on_hit", false, ratio, {}, branch)
		SKILLS.BEHAVIOR_PULL:
			_spawn_projectile(runtime, from, target, "pull_on_hit", false, ratio, {}, branch)
		SKILLS.BEHAVIOR_BOTTLE:
			_spawn_projectile(runtime, from, target, "blast_on_hit", false, ratio, {}, branch)
		SKILLS.BEHAVIOR_BOUNCE:
			_spawn_projectile(runtime, from, target, "bounce_on_hit", false, ratio, {}, branch)
		SKILLS.BEHAVIOR_BLADE:
			_spawn_projectile(runtime, from, target, "pierce_on_hit", false, ratio, {}, branch)
		SKILLS.BEHAVIOR_GEL:
			_spawn_projectile(runtime, from, target, "gel_on_hit", false, ratio, {}, branch)

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
		"split_side": int(branch.get("split_side", 0)), "split_chain_gate": branch.get("split_chain_gate", {}),
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

# 由直接命中在扣血前调用，使附伤与本次命中合并，致死时也能从破印位置发射碎片。
func break_brittle_mark(entry: Dictionary, enemies: Array) -> float:
	if not _living(entry):
		return 0.0
	var mark := _take_brittle_mark(entry.body.get_instance_id())
	if mark.is_empty():
		return 0.0
	var point: Vector2 = entry.body.position
	mark.pos = point
	_emit_state_fx(mark, "mark_break", point, point)
	_try_blast_mark(mark, entry, point, enemies)
	var runtime: SkillRuntime = mark.runtime
	return runtime.damage() * float(mark.ratio)

func _try_blast_mark(mark: Dictionary, entry: Dictionary, point: Vector2, enemies: Array) -> void:
	var gate: Dictionary = mark.split_chain_gate
	if gate.get("used", false) or float(chain_cooldowns.get(BLAST_MARK, 0.0)) > 0.0:
		return
	for chain: Dictionary in unlocked_chains():
		if StringName(chain.id) != BLAST_MARK:
			continue
		var runtime: SkillRuntime = mark.runtime
		var flask := runtime_for(BLAST_FLASK)
		var q := 1.0 + .18 * float(mini(runtime.level, flask.level) - 1)
		var excluded: Array = [entry.body]
		var radius: float = chain.radius
		var speed: float = chain.speed
		for _index in int(chain.targets):
			var target := nearest_enemy(point, radius, enemies, excluded)
			if target.is_empty():
				break
			excluded.append(target.body)
			var aim: Vector2 = target.body.position
			var shard := {
				"kind": "projectile", "impact": "shard_on_hit", "runtime": runtime, "target": target,
				"pos": point, "direction": point.direction_to(aim), "speed": speed,
				"left": maxf(.35, radius / speed + .25), "ratio": float(chain.damage_ratio) * q,
				"fx_id": BLAST_MARK, "fx_color": chain.color, "finished": false,
			}
			active.append(shard)
			_emit_state_fx(shard, "shard_flight", point, aim)
		if excluded.size() > 1:
			gate.used = true
			chain_cooldowns[BLAST_MARK] = float(chain.cooldown)
		return

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
		combo := false, ratio := 1.0, marked: Dictionary = {}, branch: Dictionary = {}) -> void:
	if not _living(target):
		return
	var point: Vector2 = target.body.position
	var speed := maxf(1.0, float(runtime.config.get("speed", 420.0)))
	var state := {"kind":"projectile", "runtime":runtime, "pos":from, "origin":from,
		"target":target, "direction":from.direction_to(point), "impact":impact, "combo":combo,
		"ratio":ratio, "speed":speed, "left":maxf(.35, runtime.range_px() / speed + .25),
		"finished":false}
	if impact in ["zone_on_hit", "pull_on_hit", "blast_on_hit"]:
		# 药剂和引力石在出手时锁定地面，目标消失不会中断落地。
		point = branch.get("landing", point)
		state.landing = point
		state.direction = from.direction_to(point)
		state.radius = runtime.radius_px() * _branch_area_ratio(branch)
	if not branch.is_empty():
		state.split_side = branch.split_side
		state.split_origin = branch.split_origin
		state.split_chain_gate = branch.split_chain_gate
	if combo:
		state.fx_id = &"link_soulbound_needle"
		state.fx_color = Color("91e7ef")
		state.marked = marked
	active.append(state)
	_emit_state_fx(state, "flight", from, point)

func _spawn_needles(runtime: SkillRuntime, target: Dictionary, combo: bool, ratio := 1.0, branch: Dictionary = {}) -> void:
	var amount := 3 if combo else int(runtime.value("count", 3))
	var marked := {}
	for index in amount:
		var launch_delay := .06 + .12 * index if combo else float(runtime.value("interval", .12)) * index
		active.append({"kind":"delayed_projectile", "runtime":runtime, "left":launch_delay,
			"target":target, "combo":combo, "ratio":ratio, "marked":marked, "branch":branch})

func _update_active(delta: float, player_pos: Vector2, enemies: Array, apply_hit: Callable) -> void:
	_update_brittle_marks(delta, enemies)
	for index in range(active.size() - 1, -1, -1):
		var state := active[index]
		var finished := false
		match String(state.kind):
			"delayed_projectile":
				state.left = float(state.left) - delta
				if state.left <= 0.0:
					var runtime: SkillRuntime = state.runtime
					if _living(state.target) and player_pos.distance_to(state.target.body.position) <= runtime.range_px():
						var branch: Dictionary = state.branch
						var origin: Vector2 = player_pos + (branch.get("split_offset", Vector2.ZERO) as Vector2)
						_spawn_projectile(runtime, origin, state.target, "needle_on_hit",
							bool(state.combo), float(state.ratio), state.marked, branch)
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
				var shard: bool = state.impact == "shard_on_hit"
				if not locked_ground and (not _living(state.target) or (shard and not enemies.has(state.target))):
					finished = true
				else:
					var point: Vector2 = state.landing if locked_ground else state.target.body.position
					var direction := (state.pos as Vector2).direction_to(point)
					if direction != Vector2.ZERO:
						state.direction = direction
					state.pos = (state.pos as Vector2).move_toward(point, float(state.speed) * delta)
					var tolerance := 0.0 if locked_ground or shard else 18.0
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

func _resolve_projectile(state: Dictionary, point: Vector2, enemies: Array, apply_hit: Callable) -> void:
	var runtime: SkillRuntime = state.runtime
	var ratio := float(state.get("ratio", 1.0))
	if state.impact == "shard_on_hit":
		_emit_state_fx(state, "shard_impact", state.pos, point)
		apply_hit.call(state.target, runtime.damage() * ratio, 0.0, 1.0, state.fx_color)
		return
	var radius := float(state.get("radius", runtime.radius_px()))
	var side := int(state.get("split_side", 0))
	if state.has("marked"):
		var body_id: int = state.target.body.get_instance_id()
		if not state.marked.has(body_id):
			state.marked[body_id] = true
			_emit_state_fx(state, "impact", state.pos, point)
	else:
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
			_hit(runtime, state.target, apply_hit, ratio, 0.0, 0.0, [] if state.combo else enemies)
	if state.finished:
		return
	if side == 0 and not bool(state.get("combo", false)):
		_apply_ability(runtime, point, enemies, apply_hit)
	if _chain_on_impact(runtime):
		var gate: Dictionary = state.get("split_chain_gate", {})
		if not gate.get("used", false):
			gate.used = true
			_try_chain(runtime, state.get("split_origin", state.origin), point, state.target)

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
		damage += break_brittle_mark(entry, direct_targets)
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

func _try_chain(runtime: SkillRuntime, from: Vector2, point: Vector2, target: Dictionary) -> void:
	for chain in unlocked_chains():
		if StringName(chain.carrier) != runtime.skill_id or float(chain_cooldowns.get(chain.id, 0.0)) > 0.0: continue
		var first: SkillRuntime = runtime_for(StringName(chain.parents[0]))
		var second: SkillRuntime = runtime_for(StringName(chain.parents[1]))
		chain_cooldowns[chain.id] = float(chain.cooldown)
		var q: float = 1.0 + .18 * float(min(first.level, second.level) - 1)
		var state := {"runtime":runtime, "fx_id":StringName(chain.id), "fx_color":chain.color, "pos":point}
		match String(chain.id):
			"link_mithril_orbit":
				state.merge({"kind":"zone", "left":2.6, "tick_left":.5, "radius":132.0,
					"ratio":.48 * q, "slow":0.0, "slow_duration":0.0})
				_add_effect_state(state, "zone_start")
			"link_corrosive_mist":
				state.merge({"kind":"zone", "left":4.0, "tick_left":.5, "radius":148.0,
					"ratio":.42 * q, "slow":.25, "slow_duration":1.5})
				_add_effect_state(state, "zone_start")
			"link_crystal_shatter_blade":
				state.merge({"kind":"delayed_hit", "left":.10, "radius":108.0, "ratio":.85 * q,
					"direction":from.direction_to(point)})
				active.append(state)
			"link_soulbound_needle":
				# 连锁针群不走职业炼金改造，仍获得父技能等级决定的固定倍率。
				_spawn_needles(runtime, target, true, q)

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

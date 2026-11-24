class_name SkillManager
extends RefCounted

# V2 的逻辑层：投射物、区域、召唤物和固定连锁都在这里保有真实寿命，
# 不在施放帧直接结算全部伤害。field 只负责敌人、伤害反馈与视觉桥接。
const SKILLS := preload("res://data/skills/skill_data.gd")
const ABILITIES := preload("res://data/alchemy_abilities/alchemy_ability_data.gd")

var field
var ability_id: StringName = ABILITIES.ABILITY_INITIAL
var runtimes: Array = []
var max_skill_slots := 6
var active: Array[Dictionary] = []
var chain_cooldowns: Dictionary = {}
var ability_efficiency := 1.0

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
	for runtime in runtimes:
		if runtime.skill_id == skill_id:
			return true
	return false

func runtime_for(skill_id: StringName) -> SkillRuntime:
	for runtime in runtimes:
		if runtime.skill_id == skill_id:
			return runtime
	return null

func clear() -> void:
	runtimes.clear()
	clear_active()
	chain_cooldowns.clear()
	ability_efficiency = 1.0

func clear_active() -> void:
	for state in active:
		state.finished = true
	active.clear()

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
		_cast(runtime, player_pos, target, enemies, apply_hit)
	_update_active(delta, player_pos, enemies, apply_hit)

func _cast(runtime: SkillRuntime, from: Vector2, target: Dictionary, enemies: Array, apply_hit: Callable) -> void:
	var behavior := runtime.behavior()
	if behavior == SKILLS.BEHAVIOR_SUMMON or behavior == SKILLS.BEHAVIOR_CRYSTAL:
		_emit_fx(runtime, "cast", from, target.body.position)
	match behavior:
		SKILLS.BEHAVIOR_SUMMON:
			active.append({"kind":"summon", "runtime":runtime, "pos":from, "left":float(runtime.value("life", 6.0)), "attack_left":0.15, "combo":false})
		SKILLS.BEHAVIOR_CRYSTAL:
			var direction := from.direction_to(target.body.position)
			for index in int(runtime.value("count", 5)):
				active.append({"kind":"delayed_hit", "runtime":runtime, "left":float(runtime.value("step_delay", .06)) * index, "pos":from + direction * (58.0 + index * 46.0), "radius":42.0, "ratio":1.0})
		SKILLS.BEHAVIOR_NEEDLE:
			_spawn_needles(runtime, from, target, false)
		SKILLS.BEHAVIOR_POOL, SKILLS.BEHAVIOR_MIST:
			_spawn_projectile(runtime, from, target, "zone_on_hit")
		SKILLS.BEHAVIOR_PULL:
			_spawn_projectile(runtime, from, target, "pull_on_hit")
		SKILLS.BEHAVIOR_BOTTLE:
			_spawn_projectile(runtime, from, target, "blast_on_hit")
		SKILLS.BEHAVIOR_BOUNCE:
			_spawn_projectile(runtime, from, target, "bounce_on_hit")
		SKILLS.BEHAVIOR_BLADE:
			_spawn_projectile(runtime, from, target, "pierce_on_hit")
		SKILLS.BEHAVIOR_GEL:
			_spawn_projectile(runtime, from, target, "gel_on_hit")
	# 以落点/首命中为载体的连锁在对应事件结算；魔偶与魂针则在生成根源时触发。
	if runtime.skill_id != &"sk_gravity_stone" and runtime.skill_id != &"sk_mist_flask" and runtime.skill_id != &"sk_obsidian_blade":
		_try_chain(runtime, from, target, enemies, apply_hit)

func _spawn_projectile(runtime: SkillRuntime, from: Vector2, target: Dictionary, impact: String, combo := false, ratio := 1.0) -> void:
	if not _living(target):
		return
	var state := {"kind":"projectile", "runtime":runtime, "skill_id":runtime.skill_id, "pos":from,
		"target":target, "impact":impact, "combo":combo, "ratio":ratio, "finished":false,
		"speed":float(runtime.config.get("speed", 420.0)),
		"left":maxf(.35, runtime.range_px() / maxf(1.0, float(runtime.config.get("speed", 420.0))))}
	active.append(state)
	_emit_fx(runtime, "cast", from, target.body.position, Color.TRANSPARENT, state)

func _spawn_needles(runtime: SkillRuntime, from: Vector2, target: Dictionary, combo: bool, ratio := 1.0) -> void:
	var amount := 3 if combo else int(runtime.value("count", 3))
	for index in amount:
		var launch_delay := .06 + .12 * index if combo else float(runtime.value("interval", .12)) * index
		active.append({"kind":"delayed_projectile", "runtime":runtime, "left":launch_delay, "pos":from, "target":target, "impact":"needle_on_hit", "combo":combo, "ratio":ratio})

func _update_active(delta: float, player_pos: Vector2, enemies: Array, apply_hit: Callable) -> void:
	for index in range(active.size() - 1, -1, -1):
		var state := active[index]
		var finished := false
		match String(state.kind):
			"delayed_projectile":
				state.left = float(state.left) - delta
				if state.left <= 0.0:
					_spawn_projectile(state.runtime, state.pos, state.target, "needle_on_hit", bool(state.combo), float(state.get("ratio", 1.0)))
					finished = true
			"delayed_hit":
				state.left = float(state.left) - delta
				if state.left <= 0.0:
					_emit_fx(state.runtime, "impact", state.pos, state.pos)
					_hit_area(state.runtime, state.pos, float(state.radius), enemies, apply_hit, float(state.ratio))
					finished = true
			"projectile":
				state.left = float(state.left) - delta
				var target: Dictionary = state.target
				if _living(target):
					state.pos = (state.pos as Vector2).move_toward(target.body.position, float(state.speed) * delta)
					if (state.pos as Vector2).distance_to(target.body.position) <= 18.0:
						_resolve_projectile(state, enemies, apply_hit)
						finished = true
				else:
					finished = true
			"zone":
				state.left = float(state.left) - delta
				state.tick_left = float(state.tick_left) - delta
				if state.tick_left <= 0.0:
					state.tick_left += .5
					_emit_fx(state.runtime, "tick", state.pos, state.pos)
					_hit_area(state.runtime, state.pos, float(state.radius), enemies, apply_hit, float(state.ratio), float(state.slow), float(state.slow_duration))
				if state.left <= 0.0:
					finished = true
			"pull":
				state.left = float(state.left) - delta
				for entry in enemies:
					if _living(entry) and entry.body.position.distance_to(state.pos) <= float(state.radius):
						entry.body.position = entry.body.position.lerp(state.pos, minf(.12, delta * .55))
				if state.left <= 0.0:
					finished = true
			"summon":
				state.left = float(state.left) - delta
				state.attack_left = float(state.attack_left) - delta
				var foe := nearest_enemy(state.pos, 520.0, enemies)
				if not foe.is_empty():
					state.pos = (state.pos as Vector2).move_toward(foe.body.position, float(state.runtime.value("speed_units", 4.5)) * SKILLS.UNIT * delta)
					if state.attack_left <= 0.0 and (state.pos as Vector2).distance_to(foe.body.position) <= 44.0:
						# 爆裂魔偶沿用魔偶的追击与拳击，但伤害必须乘固定连锁强度。
						_hit(state.runtime, foe, apply_hit, float(state.get("mult", 1.0)))
						_emit_fx(state.runtime, "impact", state.pos, foe.body.position)
						state.attack_left = float(state.runtime.value("interval", .9))
				if state.left <= 0.0:
					if bool(state.combo):
						_hit_area(state.runtime, state.pos, 78.0, enemies, apply_hit, 1.25 * float(state.get("mult", 1.0)))
					finished = true
		if finished:
			state.finished = true
			active.remove_at(index)
		else:
			active[index] = state

func _resolve_projectile(state: Dictionary, enemies: Array, apply_hit: Callable) -> void:
	var runtime: SkillRuntime = state.runtime
	var point: Vector2 = state.target.body.position if _living(state.target) else state.pos
	# 区域在真实落点创建后传出同一寿命状态；其余命中仍只发一次爆点。
	if String(state.impact) != "zone_on_hit":
		_emit_fx(runtime, "impact", state.pos, point, Color.TRANSPARENT, state)
	match String(state.impact):
		"blast_on_hit": _hit_area(runtime, point, runtime.radius_px(), enemies, apply_hit)
		"bounce_on_hit":
			var used: Array = []
			var current: Dictionary = state.target
			for _turn in int(runtime.value("targets", 3)):
				if current.is_empty(): break
				_hit(runtime, current, apply_hit)
				used.append(current.body)
				current = nearest_enemy(current.body.position, float(runtime.value("bounce_units", 3.2)) * SKILLS.UNIT, enemies, used)
		"pull_on_hit":
			_hit_area(runtime, point, runtime.radius_px() * .62, enemies, apply_hit)
			active.append({"kind":"pull", "runtime":runtime, "pos":point, "left":float(runtime.value("duration", 2.4)), "radius":runtime.radius_px()})
		"zone_on_hit":
			var zone := {"kind":"zone", "runtime":runtime, "skill_id":runtime.skill_id, "pos":point,
				"left":float(runtime.value("duration", 3.0)), "finished":false, "tick_left":.5,
				"radius":runtime.radius_px(), "ratio":1.0, "slow":float(runtime.value("slow", 0.0)), "slow_duration":2.0}
			active.append(zone)
			_emit_fx(runtime, "impact", state.pos, point, Color.TRANSPARENT, zone)
		"pierce_on_hit":
			var used: Array = []
			var current: Dictionary = state.target
			for _turn in int(runtime.value("targets", 3)):
				if current.is_empty(): break
				_hit(runtime, current, apply_hit)
				used.append(current.body)
				current = nearest_enemy(current.body.position, runtime.range_px(), enemies, used)
		"gel_on_hit":
			_hit(runtime, state.target, apply_hit, 1.0, float(runtime.value("slow", .3)), float(runtime.value("slow_duration", 2.0)))
		"needle_on_hit": _hit(runtime, state.target, apply_hit, float(state.get("ratio", 1.0)))
	if not bool(state.get("combo", false)):
		_apply_ability(runtime, point, enemies, apply_hit)
	if runtime.skill_id == &"sk_gravity_stone" or runtime.skill_id == &"sk_mist_flask" or runtime.skill_id == &"sk_obsidian_blade":
		_try_chain(runtime, state.pos, state.target, enemies, apply_hit)

func _hit(runtime: SkillRuntime, entry: Dictionary, apply_hit: Callable, ratio := 1.0, slow := 0.0, slow_duration := 0.0) -> void:
	if not _living(entry): return
	apply_hit.call(entry, runtime.damage() * ratio, slow_duration, maxf(0.0, 1.0 - slow), runtime.base.color)

func _hit_area(runtime: SkillRuntime, at: Vector2, radius: float, enemies: Array, apply_hit: Callable, ratio := 1.0, slow := 0.0, slow_duration := 0.0) -> void:
	for entry in enemies:
		if _living(entry) and entry.body.position.distance_to(at) <= radius:
			_hit(runtime, entry, apply_hit, ratio, slow, slow_duration)

func _apply_ability(runtime: SkillRuntime, at: Vector2, enemies: Array, apply_hit: Callable) -> void:
	var ability := ABILITIES.by_id(ability_id)
	if ability.is_empty(): return
	match String(ability.effect_type):
		ABILITIES.EFFECT_BURST: _hit_area(runtime, at, 54.0, enemies, apply_hit, .30 * ability_efficiency)
		ABILITIES.EFFECT_BOUNCE:
			var next := nearest_enemy(at, 150.0, enemies)
			if not next.is_empty(): _hit(runtime, next, apply_hit, .65 * ability_efficiency)
		ABILITIES.EFFECT_SPLIT: _hit_area(runtime, at, 72.0, enemies, apply_hit, .35 * ability_efficiency)
		ABILITIES.EFFECT_ECHO: active.append({"kind":"delayed_hit", "runtime":runtime, "left":.35, "pos":at, "radius":48.0, "ratio":.55 * ability_efficiency})

func _try_chain(runtime: SkillRuntime, from: Vector2, target: Dictionary, enemies: Array, apply_hit: Callable) -> void:
	for chain in SKILLS.CHAINS:
		if StringName(chain.carrier) != runtime.skill_id or float(chain_cooldowns.get(chain.id, 0.0)) > 0.0: continue
		var first: SkillRuntime = runtime_for(StringName(chain.parents[0]))
		var second: SkillRuntime = runtime_for(StringName(chain.parents[1]))
		if first == null or second == null: continue
		chain_cooldowns[chain.id] = float(chain.cooldown)
		var q: float = 1.0 + .18 * float(min(first.level, second.level) - 1)
		var proxy: SkillRuntime = runtime
		_emit_fx(proxy, String(chain.id), from, target.body.position, chain.color)
		match String(chain.id):
			"link_blast_homunculus": active.append({"kind":"summon", "runtime":proxy, "pos":from, "left":6.0, "attack_left":.15, "combo":true, "mult":q})
			"link_mithril_orbit": active.append({"kind":"zone", "runtime":proxy, "pos":target.body.position, "left":2.6, "tick_left":.5, "radius":132.0, "ratio":.48 * q, "slow":0.0, "slow_duration":0.0})
			"link_corrosive_mist": active.append({"kind":"zone", "runtime":proxy, "pos":target.body.position, "left":4.0, "tick_left":.5, "radius":148.0, "ratio":.42 * q, "slow":.25, "slow_duration":1.5})
			"link_crystal_shatter_blade": active.append({"kind":"delayed_hit", "runtime":proxy, "left":.10, "pos":target.body.position, "radius":108.0, "ratio":.85 * q})
			"link_soulbound_needle":
				# 连锁针群不走职业炼金改造，仍获得父技能等级决定的固定倍率。
				_spawn_needles(proxy, from, target, true, q)

func _emit_fx(runtime: SkillRuntime, event_name: String, from: Vector2, target: Vector2, override_color := Color.TRANSPARENT, state: Dictionary = {}) -> void:
	if field == null or not field.has_method("play_skill_fx"): return
	field.play_skill_fx({"skill_id":runtime.skill_id, "event":event_name, "from":from, "target":target, "color":override_color if override_color != Color.TRANSPARENT else runtime.base.color, "radius":runtime.radius_px(), "speed":float(runtime.config.get("speed", 420.0)), "state":state})

func _living(entry: Dictionary) -> bool:
	return entry.get("hp", 0.0) > 0.0 and is_instance_valid(entry.get("body")) and not entry.body.is_queued_for_deletion()

func nearest_enemy(at: Vector2, reach: float, enemies: Array, excluded: Array = []) -> Dictionary:
	var closest := {}
	var best := reach * reach
	for entry in enemies:
		if not _living(entry) or excluded.has(entry.body): continue
		var distance := at.distance_squared_to(entry.body.position)
		if distance < best:
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

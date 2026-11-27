extends SceneTree

const RECIPES := preload("res://data/materials/recipe_data.gd")
const STEP := 1.0 / 60.0
const MARK := &"sk_brittle_mark"
const CAST_EVENTS := {
	"sk_blast_flask": ["cast", 2],
	"sk_brittle_mark": ["flight", 2],
	"sk_mithril_drop": ["flight", 2],
	"sk_gravity_stone": ["flight", 2],
	"sk_corrosive_flask": ["flight", 2],
	"sk_mist_flask": ["flight", 2],
	"sk_crystal_growth": ["impact", 10],
	"sk_obsidian_blade": ["flight", 2],
	"sk_spirit_gel": ["flight", 2],
	"sk_soul_needle": ["flight", 6],
}

class FxRecorder:
	extends RefCounted

	var events: Array[Dictionary] = []

	func play_skill_fx(info: Dictionary) -> void:
		events.append(info.duplicate(true))

	func select(id: StringName, event: String) -> Array[Dictionary]:
		return events.filter(func(info: Dictionary) -> bool:
			return info.skill_id == id and info.event == event)

var recorder := FxRecorder.new()
var hits: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_expect(RECIPES.match(["earth_core", "fire_powder"]).get("recipe_id") == "recipe_split", "two-slot recipe")
	_expect(RECIPES.match(["magic_shard", "earth_core", "fire_powder"]).get("recipe_id") == "recipe_split", "old recipe ID still recognized")
	# 原技能的分裂施放规则。扩展技能由各自的动作及战斗用例覆盖。
	for id: String in CAST_EVENTS:
		_check_skill(StringName(id))
	_check_target_selection()
	_check_ground_lock()
	_check_retired_combinations()
	_check_brittle_mark()
	_check_split_marks()
	for enemy in enemies:
		enemy.body.queue_free()
	await process_frame
	print("SPLIT_ALCHEMY_%s %d checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(int(failures > 0))

func _expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("SPLIT_ALCHEMY: " + label)

func _set_targets(points: Array[Vector2]) -> void:
	for enemy in enemies:
		enemy.body.free()
	enemies.clear()
	for point in points:
		var body := Node2D.new()
		body.position = point
		root.add_child(body)
		enemies.append({"body":body, "hp":500.0})

func _manager(id: StringName, ability_id: StringName = &"split") -> SkillManager:
	hits.clear()
	recorder.events.clear()
	var manager := SkillManager.new()
	manager.setup(ability_id, recorder)
	manager.add_skill(id)
	return manager

func _check_skill(id: StringName) -> void:
	_set_targets([Vector2(128, -25), Vector2(142, 31)])
	var manager := _manager(id)
	var runtime := manager.runtime_for(id)
	manager.cast_equipped(0.0, Vector2.ZERO, [], _record_hit)
	_expect(recorder.events.is_empty() and is_zero_approx(runtime.cooldown_left), "%s no target and no cooldown" % id)
	manager.cast_equipped(0.0, Vector2.ZERO, enemies, _record_hit)
	_expect(is_equal_approx(runtime.cooldown_left, runtime.cooldown()) and manager.runtimes.size() == 1, "%s one slot and cooldown" % id)
	var expected_damage := runtime.damage() * 0.6
	if id == MARK:
		_expect(manager.brittle_marks.is_empty(), "vulnerability waits for the vials to land")
	_advance(manager, 450)
	var test: Array = CAST_EVENTS[String(id)]
	var events := recorder.select(id, test[0])
	_expect(events.size() == test[1], "%s expected branch event count" % id)
	var sides := {}
	for event in events:
		sides[event.split_side] = true
	_expect(sides.has(-1) and sides.has(1) and sides.size() == 2, "%s two visually tagged branches" % id)
	_expect(recorder.select(id, "split_cast").size() == 1 and manager.active.is_empty(), "%s one split cue and clean expiry" % id)
	if id == MARK:
		_expect(hits.is_empty(), "the split vials apply vulnerability without dealing damage")
		_expect(recorder.select(id, "impact").size() == 2 and recorder.select(id, "mark_start").size() == 2,
			"the two impacts leave a single status on each enemy")
		return
	_expect(not hits.is_empty(), "%s deals actual damage" % id)
	_expect(hits.all(func(hit: Dictionary) -> bool:
		return is_equal_approx(hit.damage, expected_damage)), "%s uses the 60 percent split multiplier" % id)
	if id in [&"sk_gravity_stone", &"sk_corrosive_flask", &"sk_mist_flask"]:
		var zones := recorder.select(id, "zone_start")
		_expect(zones.size() == 2 and zones.all(func(zone: Dictionary) -> bool:
			return (is_equal_approx(zone.radius, runtime.radius_px() * 0.8)
				and is_equal_approx(zone.state.left, float(runtime.value("duration"))))), "%s two 80 percent sized areas with original duration" % id)
	if id in [&"sk_mist_flask", &"sk_spirit_gel"]:
		_expect(hits.all(func(hit: Dictionary) -> bool:
			return is_equal_approx(hit.slow_factor, 0.7) and is_equal_approx(hit.slow_seconds, 2.0)), "%s preserves slow strength and duration" % id)

func _check_target_selection() -> void:
	_set_targets([Vector2(110, 1), Vector2(135, 45), Vector2(550, 1)])
	var manager := _manager(&"sk_spirit_gel")
	manager.cast_equipped(0.0, Vector2.ZERO, enemies, _record_hit)
	_advance(manager, 45)
	_expect(hits.size() == 2 and hits[0].target != hits[1].target, "two eligible enemies receive one hit each")
	_set_targets([Vector2(110, 1), Vector2(550, 1)])
	manager = _manager(&"sk_spirit_gel")
	manager.cast_equipped(0.0, Vector2.ZERO, enemies, _record_hit)
	_advance(manager, 45)
	_expect(hits.size() == 2 and hits[0].target == hits[1].target, "lone enemy receives both; out-of-range enemy is ignored")
	var shots := recorder.select(&"sk_spirit_gel", "flight")
	_expect(shots.size() == 2 and shots[0].from != shots[1].from, "two visible trajectories with a shared target")

func _check_ground_lock() -> void:
	_set_targets([Vector2(180, 0), Vector2(620, 0)])
	var manager := _manager(&"sk_blast_flask")
	manager.cast_equipped(0.0, Vector2.ZERO, enemies, _record_hit)
	var casts := recorder.select(&"sk_blast_flask", "cast")
	enemies[0].hp = 0.0
	_advance(manager, 100)
	var impacts := recorder.select(&"sk_blast_flask", "impact")
	_expect(impacts.size() == 2 and casts.size() == 2, "both thrown flasks land when their target dies")
	if impacts.size() == 2 and casts.size() == 2:
		_expect(casts[0].target != casts[1].target and impacts.all(func(info: Dictionary) -> bool:
			return casts.any(func(cast: Dictionary) -> bool:
				return info.split_side == cast.split_side and info.target == cast.target)), "the two locked ground points remain distinct")
	_expect(hits.is_empty(), "dead target and distant enemy are not hit")

func _check_retired_combinations() -> void:
	var pairs := [
		[&"sk_blast_flask", &"sk_brittle_mark"],
		[&"sk_mithril_drop", &"sk_gravity_stone"],
		[&"sk_corrosive_flask", &"sk_mist_flask"],
		[&"sk_crystal_growth", &"sk_obsidian_blade"],
		[&"sk_spirit_gel", &"sk_soul_needle"],
	]
	for ability: StringName in [&"initial", &"split"]:
		for pair: Array in pairs:
			_set_targets([Vector2(128, -25), Vector2(140, 27)])
			var manager := _manager(pair[0], ability)
			manager.add_skill(pair[1])
			manager.cast_equipped(0.0, Vector2.ZERO, enemies, _record_hit)
			_advance(manager, 90)
			var only_base_events := recorder.events.all(func(info: Dictionary) -> bool:
				return info.skill_id in pair)
			_expect(not recorder.events.is_empty() and only_base_events
				and manager.unlocked_chains().is_empty() and manager.chain_cooldowns.is_empty(),
				"%s: %s cast without a retired combination" % [ability, pair])

func _check_brittle_mark() -> void:
	_set_targets([Vector2(110, 0), Vector2(158, 45), Vector2(650, 0)])
	var manager := _manager(MARK, &"initial")
	var runtime := manager.runtime_for(MARK)
	var target := enemies[0]
	var id: int = target.body.get_instance_id()
	manager.cast_equipped(0.0, Vector2.ZERO, enemies, _record_hit)
	_expect(hits.is_empty() and manager.brittle_marks.is_empty() and recorder.select(MARK, "flight").size() == 1,
		"one vial flies before applying any vulnerability")
	_advance(manager, 18)
	_expect(manager.brittle_marks.size() == 2 and not manager.brittle_marks.has(enemies[2].body.get_instance_id())
		and recorder.select(MARK, "impact").size() == 1, "one landing marks only the enemies within the impact circle")
	if not manager.brittle_marks.has(id):
		return
	target.body.position.y += 12.0
	_advance(manager, 1)
	_expect(manager.brittle_marks[id].pos == target.body.position, "the mark follows its moving target")
	_expect(is_equal_approx(manager.brittle_damage_multiplier(target), 1.2)
		and is_equal_approx(manager.brittle_damage_multiplier(target), 1.2),
		"repeated damage queries see the same non-consumed modifier")
	_advance(manager, ceili((float(runtime.value("duration", 2.5)) + STEP) / STEP))
	_expect(manager.brittle_marks.is_empty() and is_equal_approx(manager.brittle_damage_multiplier(target), 1.0),
		"the vulnerability expires")
	runtime.level = 3
	manager._cast(runtime, Vector2.ZERO, target, enemies)
	_advance(manager, 18)
	_expect(is_equal_approx(manager.brittle_damage_multiplier(target), 1.22), "rank three grants 22 percent")
	var removed_mark: Dictionary = manager.brittle_marks.get(id, {})
	enemies.erase(target)
	_advance(manager, 1)
	_expect(not removed_mark.is_empty() and removed_mark.get("finished", false) and not manager.brittle_marks.has(id),
		"despawn invalidates both the mark and its visual state")
	target.body.free()

func _check_split_marks() -> void:
	_set_targets([Vector2(120, 0), Vector2(620, 0)])
	var manager := _manager(MARK)
	var runtime := manager.runtime_for(MARK)
	manager.cast_equipped(0.0, Vector2.ZERO, enemies, _record_hit)
	var flights := recorder.select(MARK, "flight")
	_advance(manager, 18)
	var impacts := recorder.select(MARK, "impact")
	_expect(flights.size() == 2 and flights[0].from != flights[1].from and flights[0].target != flights[1].target,
		"two split vials visibly take different trajectories")
	_expect(impacts.size() == 2 and impacts.all(func(impact: Dictionary) -> bool:
		return is_equal_approx(impact.radius, runtime.radius_px() * 0.8)),
		"split landing circles are both 80 percent of the original radius")
	_expect(recorder.select(MARK, "mark_start").size() == 1 and manager.brittle_marks.size() == 1
		and is_equal_approx(manager.brittle_damage_multiplier(enemies[0]), 1.2),
		"overlapping circles refresh a single status with full vulnerability strength")
	manager.clear_active()
	_expect(manager.brittle_marks.is_empty(), "clear releases marks")

func _advance(manager: SkillManager, frames: int) -> void:
	for frame in frames:
		manager._update_active(STEP, Vector2.ZERO, enemies, _record_hit)

func _record_hit(entry: Dictionary, damage: float, seconds: float, factor: float, _color: Color) -> void:
	hits.append({"target":entry.body.get_instance_id(), "damage":damage, "slow_seconds":seconds, "slow_factor":factor})

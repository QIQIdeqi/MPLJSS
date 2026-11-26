extends SceneTree

const RECIPES := preload("res://data/materials/recipe_data.gd")
const STEP := 1.0 / 60.0
const MARK := &"sk_brittle_mark"
const MARK_COMBO := &"link_blast_mark"
const CAST_EVENTS := {
	"sk_blast_flask": ["cast", 2],
	"sk_brittle_mark": ["mark_start", 2],
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
	_check_chain()
	_check_brittle_mark()
	_check_blast_mark()
	_check_split_mark_chain()
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
		_expect(hits.is_empty(), "split marks apply without dealing damage")
		var trigger := SkillRuntime.new()
		trigger.setup(&"sk_spirit_gel")
		for enemy in enemies:
			manager._cast_branch(trigger, Vector2.ZERO, enemy)
		expected_damage += trigger.damage()
	_advance(manager, 450)
	var test: Array = CAST_EVENTS[String(id)]
	var events := recorder.select(id, test[0])
	_expect(events.size() == test[1], "%s expected branch event count" % id)
	var sides := {}
	for event in events:
		sides[event.split_side] = true
	_expect(sides.has(-1) and sides.has(1) and sides.size() == 2, "%s two visually tagged branches" % id)
	_expect(recorder.select(id, "split_cast").size() == 1 and manager.active.is_empty(), "%s one split cue and clean expiry" % id)
	_expect(not hits.is_empty(), "%s deals actual damage" % id)
	_expect(hits.all(func(hit: Dictionary) -> bool:
		return is_equal_approx(hit.damage, expected_damage)), "%s uses the 60 percent split multiplier" % id)
	if id == MARK:
		_expect(hits.size() == 2 and hits[0].target != hits[1].target and recorder.select(id, "mark_break").size() == 2,
			"direct hits break the two split marks exactly once")
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
	manager = _manager(MARK)
	manager.cast_equipped(0.0, Vector2.ZERO, enemies, _record_hit)
	var marks := recorder.select(MARK, "mark_start")
	_expect(manager.brittle_marks.size() == 1 and marks.size() == 1 and marks[0].state.get("split_merged", false),
		"a split cast on one enemy leaves a single mark with a merged visual state")
	var single_bonus := manager.break_brittle_mark(enemies[0], enemies)
	_expect(is_equal_approx(single_bonus, manager.runtime_for(MARK).damage() * 1.2)
		and is_zero_approx(manager.break_brittle_mark(enemies[0], enemies)), "the lone target combines both split doses in one break")

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

func _check_chain() -> void:
	_set_targets([Vector2(128, -25), Vector2(140, 27)])
	var manager := _manager(&"sk_gravity_stone")
	manager.add_skill(&"sk_mithril_drop")
	manager.runtime_for(&"sk_mithril_drop").cooldown_left = 10.0
	manager.cast_equipped(0.0, Vector2.ZERO, enemies, _record_hit)
	_advance(manager, 90)
	var combos := recorder.select(&"link_mithril_orbit", "zone_start")
	_expect(combos.size() == 1 and combos[0].split_side == 0, "both split impacts can trigger only one unmodified fixed combo")
	manager.clear_active()
	_expect(manager.active.is_empty(), "clear removes both active branches and their combo")

func _check_brittle_mark() -> void:
	_set_targets([Vector2(110, 0), Vector2(650, 0)])
	var manager := _manager(MARK, &"initial")
	var runtime := manager.runtime_for(MARK)
	var target := enemies[0]
	var id: int = target.body.get_instance_id()
	manager.cast_equipped(0.0, Vector2.ZERO, enemies, _record_hit)
	_expect(hits.is_empty() and manager.brittle_marks.has(id) and recorder.select(MARK, "mark_start").size() == 1,
		"auto-cast marks the only in-range monster without damaging it")
	if not manager.brittle_marks.has(id):
		return
	target.body.position.y += 12.0
	_advance(manager, 1)
	_expect(manager.brittle_marks[id].pos == target.body.position, "the mark follows its moving target")
	var poison := SkillRuntime.new()
	poison.setup(&"sk_corrosive_flask")
	manager._cast_branch(poison, Vector2.ZERO, target)
	_advance(manager, 66)
	_expect(not hits.is_empty() and hits.all(func(hit: Dictionary) -> bool: return is_equal_approx(hit.damage, poison.damage())),
		"corrosive zone ticks deal only their own damage")
	_expect(manager.brittle_marks.has(id) and recorder.select(MARK, "mark_break").is_empty(), "damage-over-time leaves the mark primed")
	var bonus := manager.break_brittle_mark(target, enemies)
	_expect(is_equal_approx(bonus, runtime.damage()) and is_zero_approx(manager.break_brittle_mark(target, enemies)),
		"a direct attack can consume the bonus exactly once")
	_expect(recorder.select(MARK_COMBO, "shard_flight").is_empty(), "mark alone cannot trigger the fixed combo")
	manager.clear_active()
	manager._cast(runtime, Vector2.ZERO, target, enemies)
	_advance(manager, ceili((float(runtime.value("duration", 2.5)) + STEP) / STEP))
	_expect(manager.brittle_marks.is_empty() and is_zero_approx(manager.break_brittle_mark(target, enemies)),
		"an expired mark grants no bonus")
	manager._cast(runtime, Vector2.ZERO, target, enemies)
	var removed_mark: Dictionary = manager.brittle_marks.get(id, {})
	enemies.erase(target)
	_advance(manager, 1)
	_expect(not removed_mark.is_empty() and removed_mark.get("finished", false) and manager.brittle_marks.is_empty(),
		"despawn invalidates both the mark and its visual state")
	target.body.free()

func _check_blast_mark() -> void:
	_set_targets([Vector2(120, 0), Vector2(158, 28), Vector2(188, -32), Vector2(224, 40), Vector2(248, -20), Vector2(285, 0)])
	var manager := _manager(MARK, &"initial")
	var mark := manager.runtime_for(MARK)
	manager.add_skill(&"sk_blast_flask")
	manager.runtime_for(&"sk_blast_flask").level = 2
	mark.level = 3
	var gel := SkillRuntime.new()
	gel.setup(&"sk_spirit_gel")
	var victim := enemies[0]
	victim.hp = 1.0
	manager._cast(mark, Vector2.ZERO, victim, enemies)
	manager._cast_branch(gel, Vector2.ZERO, victim)
	for frame in 60:
		manager._update_active(STEP, Vector2.ZERO, enemies, _record_lethal_hit)
		if not hits.is_empty():
			break
	_expect(hits.size() == 1 and is_equal_approx(hits[0].damage, gel.damage() + mark.damage()) and victim.hp <= 0.0,
		"the lethal direct hit includes the bonus in one damage callback")
	var flights := recorder.select(MARK_COMBO, "shard_flight")
	_expect(flights.size() == 3 and is_equal_approx(float(manager.chain_cooldowns.get(MARK_COMBO, 0.0)), 6.0),
		"the lethal break launches three shards and starts the independent cooldown")
	var intended_targets := [enemies[1].body.position, enemies[2].body.position, enemies[3].body.position]
	_expect(flights.all(func(info: Dictionary) -> bool: return info.from == victim.body.position and info.target in intended_targets),
		"shards leave the break position and choose the nearest eligible secondary targets")
	_advance(manager, 60)
	var secondary_targets := {}
	for i in range(1, hits.size()):
		secondary_targets[hits[i].target] = true
	var expected_shard_damage := mark.damage() * 0.65 * 1.18
	_expect(hits.size() == 4 and secondary_targets.size() == 3 and hits.slice(1).all(
		func(hit: Dictionary) -> bool: return is_equal_approx(hit.damage, expected_shard_damage)),
		"each shard arrives and damages a distinct enemy using the lower parent level")
	_expect(recorder.select(MARK_COMBO, "shard_impact").size() == 3 and manager.active.is_empty(),
		"each shard impact is emitted once and all projectile states are released")

func _check_split_mark_chain() -> void:
	_set_targets([Vector2(120, 0), Vector2(134, 28), Vector2(168, 40)])
	var manager := _manager(MARK)
	manager.add_skill(&"sk_blast_flask")
	manager.runtime_for(&"sk_blast_flask").cooldown_left = 10.0
	manager.cast_equipped(0.0, Vector2.ZERO, enemies, _record_hit)
	var first := manager.break_brittle_mark(enemies[0], enemies)
	var shard_count := recorder.select(MARK_COMBO, "shard_flight").size()
	_advance(manager, 25)
	_expect(recorder.select(MARK_COMBO, "shard_impact").size() == 2
		and recorder.select(MARK, "mark_break").size() == 1, "a shard can damage a second marked enemy without consuming its mark")
	manager.chain_cooldowns.clear()
	var second := manager.break_brittle_mark(enemies[1], enemies)
	_expect(first > 0.0 and is_equal_approx(first, second) and shard_count == 2 and recorder.select(MARK_COMBO, "shard_flight").size() == shard_count,
		"two split marks can break, but share the one-combo-per-cast gate even when cooldown is reset")
	manager.clear_active()
	_expect(manager.brittle_marks.is_empty() and manager.active.is_empty(), "clear releases marks and combo projectiles")

func _advance(manager: SkillManager, frames: int) -> void:
	for frame in frames:
		manager._update_active(STEP, Vector2.ZERO, enemies, _record_hit)

func _record_hit(entry: Dictionary, damage: float, seconds: float, factor: float, _color: Color) -> void:
	hits.append({"target":entry.body.get_instance_id(), "damage":damage, "slow_seconds":seconds, "slow_factor":factor})

func _record_lethal_hit(entry: Dictionary, damage: float, seconds: float, factor: float, color: Color) -> void:
	_record_hit(entry, damage, seconds, factor, color)
	entry.hp -= damage

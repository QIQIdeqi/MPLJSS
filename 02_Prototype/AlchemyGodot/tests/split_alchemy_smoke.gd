extends SceneTree

const SKILLS := preload("res://data/skills/skill_data.gd")
const RECIPES := preload("res://data/materials/recipe_data.gd")
const STEP := 1.0 / 60.0
const CAST_EVENTS := {
	"sk_blast_flask": ["cast", 2],
	"sk_clay_homunculus": ["summon_start", 2],
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
	for id: String in SKILLS.ids():
		_check_skill(StringName(id))
	_check_target_selection()
	_check_ground_lock()
	_check_chain()
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

func _manager(id: StringName) -> SkillManager:
	hits.clear()
	recorder.events.clear()
	var manager := SkillManager.new()
	manager.setup(&"split", recorder)
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
		return is_equal_approx(hit.damage, runtime.damage() * 0.6)), "%s every hit is 60 percent with no extra area hit" % id)
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

func _advance(manager: SkillManager, frames: int) -> void:
	for frame in frames:
		manager._update_active(STEP, Vector2.ZERO, enemies, _record_hit)

func _record_hit(entry: Dictionary, damage: float, seconds: float, factor: float, _color: Color) -> void:
	hits.append({"target":entry.body.get_instance_id(), "damage":damage, "slow_seconds":seconds, "slow_factor":factor})

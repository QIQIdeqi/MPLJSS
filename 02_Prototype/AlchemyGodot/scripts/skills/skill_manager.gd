class_name SkillManager
extends RefCounted
# 技能管理器（策划案第9章）
# 管理本局技能实例、冷却、触发攻击。接口对齐旧 brew.gd 的 cast_equipped，方便替换。

const SKILLS := preload("res://data/skills/skill_data.gd")
const ABILITIES := preload("res://data/alchemy_abilities/alchemy_ability_data.gd")

const WORLD_SCALE := 0.2  # 数据单位 → 世界像素（与旧 brew.gd 一致）

var field  # field.gd 实例（供特效、联动回调）
var ability_id: StringName = ABILITIES.ABILITY_INITIAL
var runtimes: Array = []       # Array[SkillRuntime]
var max_skill_slots := 6       # 技能槽位（配置化，策划案第7.5节）
var rng := RandomNumberGenerator.new()

# 递归保护用（本局）
var attack_queue: Array = []

func _init() -> void:
	rng.randomize()

func setup(p_ability_id: StringName, p_field) -> void:
	ability_id = p_ability_id
	field = p_field

func add_skill(skill_id: StringName) -> bool:
	if runtimes.size() >= max_skill_slots:
		return false
	for rt in runtimes:
		if rt.skill_id == skill_id:
			return false
	var rt := SkillRuntime.new()
	rt.setup(skill_id, ability_id, [])
	runtimes.append(rt)
	return true

func has_skill(skill_id: StringName) -> bool:
	for rt in runtimes:
		if rt.skill_id == skill_id:
			return true
	return false

func clear() -> void:
	runtimes.clear()
	attack_queue.clear()

# 主循环：tick 冷却并触发可释放的技能。
# apply_hit: Callable(entry, damage, slow_seconds, slow_factor, color) —— 命中回调，对接 field.gd
func cast_equipped(delta: float, player_pos: Vector2, enemies: Array, apply_hit: Callable) -> void:
	for rt in runtimes:
		rt.tick(delta)
		if not rt.ready():
			continue
		var target := nearest_enemy(player_pos, float(rt.config.get("range", 0.0)) * WORLD_SCALE, enemies)
		if target.is_empty():
			continue
		rt.reset_cooldown()
		cast(rt, player_pos, target, enemies, apply_hit)

# 触发单个技能的基出攻击，并返回生成的信息（供视觉层使用）
func cast(rt: SkillRuntime, player_pos: Vector2, target: Dictionary, enemies: Array, apply_hit: Callable) -> Dictionary:
	var ctx := AttackContext.new()
	ctx.source_skill_id = rt.skill_id
	ctx.source_ability_id = ability_id
	ctx.chain_id = AttackContext.new_chain_id()
	var behavior: StringName = rt.behavior()
	var info := {"skill": rt.skill_id, "behavior": behavior, "pos": player_pos,
		"target": target.body.position, "color": rt.config.get("color", Color.WHITE),
		"element": rt.element(), "ctx": ctx}
	# 在伤害结算前发出施法视觉，避免脆弱敌人死亡后没有机会播放特效。
	_notify_skill_fx(rt, player_pos, target)
	match behavior:
		SKILLS.BEHAVIOR_PROJECTILE:
			cast_projectile(rt, player_pos, target, enemies, apply_hit, ctx)
		SKILLS.BEHAVIOR_BLAST:
			cast_blast(rt, player_pos, target, enemies, apply_hit, ctx)
		SKILLS.BEHAVIOR_LINE:
			cast_line(rt, player_pos, target, enemies, apply_hit, ctx)
		SKILLS.BEHAVIOR_INSTANT:
			cast_instant(rt, player_pos, target, enemies, apply_hit, ctx)
		SKILLS.BEHAVIOR_BOOMERANG:
			cast_line(rt, player_pos, target, enemies, apply_hit, ctx)  # 往返按直线命中近似
		SKILLS.BEHAVIOR_ORBIT:
			cast_orbit(rt, player_pos, target, enemies, apply_hit, ctx)
		SKILLS.BEHAVIOR_ZONE:
			cast_zone(rt, player_pos, target, enemies, apply_hit, ctx)
		SKILLS.BEHAVIOR_AOE:
			cast_aoe(rt, player_pos, target, enemies, apply_hit, ctx)
		SKILLS.BEHAVIOR_BEAM:
			cast_beam(rt, player_pos, target, enemies, apply_hit, ctx)
		SKILLS.BEHAVIOR_SPIKE:
			cast_spike(rt, player_pos, target, enemies, apply_hit, ctx)
		_:
			cast_projectile(rt, player_pos, target, enemies, apply_hit, ctx)
	# 元素联动检测（区域类技能）
	_check_synergy(rt, player_pos, target, enemies, apply_hit, ctx)
	return info

# 通知 field 层渲染技能特效（经 alchemy_system 转发）
func _notify_skill_fx(rt: SkillRuntime, from: Vector2, target: Dictionary) -> void:
	if field == null or not field.has_method("play_skill_fx"):
		return
	var fx_info := {
		"skill_id": rt.skill_id,
		"behavior": rt.behavior(),
		"from": from,
		"target": target.body.position,
		"color": rt.config.get("color", Color.WHITE),
		"radius": float(rt.config.get("radius", 0.0)) * WORLD_SCALE,
		"speed": float(rt.config.get("speed", 620.0)),
		"element": rt.element(),
	}
	field.play_skill_fx(fx_info)

# ---- 十种基础行为（命中逻辑）----

func _hit(rt: SkillRuntime, entry: Dictionary, apply_hit: Callable, ctx: AttackContext, ratio := 1.0) -> void:
	var dmg: float = rt.damage() * ratio
	var slow: float = rt.config.get("slow", 0.0)
	var factor: float = rt.config.get("factor", 1.0)
	var color: Color = rt.config.get("color", Color.WHITE)
	apply_hit.call(entry, dmg, slow, factor, color)
	ctx.mark_hit(entry)

func cast_projectile(rt: SkillRuntime, from: Vector2, target: Dictionary, enemies: Array, apply_hit: Callable, ctx: AttackContext) -> void:
	# 投射型：命中单一目标。弹射/穿透/分裂/回响由改造层处理。
	_hit(rt, target, apply_hit, ctx)
	_apply_effect(rt, target.body.position, target, enemies, apply_hit, ctx)

func cast_blast(rt: SkillRuntime, from: Vector2, target: Dictionary, enemies: Array, apply_hit: Callable, ctx: AttackContext) -> void:
	# 爆裂型：命中点爆炸，范围内敌人都受伤
	var center: Vector2 = target.body.position
	var radius: float = float(rt.config.get("radius", 0.0)) * WORLD_SCALE
	for entry in enemies:
		if _living(entry) and entry.body.position.distance_to(center) <= radius:
			_hit(rt, entry, apply_hit, ctx)
	_apply_effect(rt, center, target, enemies, apply_hit, ctx)

func cast_line(rt: SkillRuntime, from: Vector2, target: Dictionary, enemies: Array, apply_hit: Callable, ctx: AttackContext) -> void:
	# 直线型：命中路径上的敌人（近似：朝向目标方向的窄条）
	var dir: Vector2 = from.direction_to(target.body.position)
	var reach: float = float(rt.config.get("range", 0.0)) * WORLD_SCALE
	for entry in enemies:
		if not _living(entry):
			continue
		var rel: Vector2 = entry.body.position - from
		if rel.dot(dir) < 0.0 or rel.dot(dir) > reach:
			continue
		var lateral := absf(rel.cross(dir))
		if lateral <= 26.0:
			_hit(rt, entry, apply_hit, ctx)
	_apply_effect(rt, target.body.position, target, enemies, apply_hit, ctx)

func cast_instant(rt: SkillRuntime, from: Vector2, target: Dictionary, enemies: Array, apply_hit: Callable, ctx: AttackContext) -> void:
	# 瞬间打击型：落雷，命中目标及小范围
	var center: Vector2 = target.body.position
	var radius: float = float(rt.config.get("radius", 46.0)) * WORLD_SCALE
	for entry in enemies:
		if _living(entry) and entry.body.position.distance_to(center) <= radius:
			_hit(rt, entry, apply_hit, ctx)
	_apply_effect(rt, center, target, enemies, apply_hit, ctx)

func cast_orbit(rt: SkillRuntime, from: Vector2, target: Dictionary, enemies: Array, apply_hit: Callable, ctx: AttackContext) -> void:
	# 环绕型：围绕玩家，命中范围内敌人
	var radius: float = float(rt.config.get("radius", 66.0)) * WORLD_SCALE
	for entry in enemies:
		if _living(entry) and entry.body.position.distance_to(from) <= radius:
			_hit(rt, entry, apply_hit, ctx)
	_apply_effect(rt, from, target, enemies, apply_hit, ctx)

func cast_zone(rt: SkillRuntime, from: Vector2, target: Dictionary, enemies: Array, apply_hit: Callable, ctx: AttackContext) -> void:
	# 区域持续型：毒雾，生成区域（本帧结算一次，持续伤害由区域对象处理）
	var center: Vector2 = target.body.position
	var radius: float = float(rt.config.get("radius", 90.0)) * WORLD_SCALE
	for entry in enemies:
		if _living(entry) and entry.body.position.distance_to(center) <= radius:
			_hit(rt, entry, apply_hit, ctx)
	# 登记元素区域（供联动检测）
	_register_region(rt, center, radius)
	_apply_effect(rt, center, target, enemies, apply_hit, ctx)

func cast_aoe(rt: SkillRuntime, from: Vector2, target: Dictionary, enemies: Array, apply_hit: Callable, ctx: AttackContext) -> void:
	# 指定区域打击型：落石，命中敌群区域
	var center: Vector2 = target.body.position
	var radius: float = float(rt.config.get("radius", 80.0)) * WORLD_SCALE
	for entry in enemies:
		if _living(entry) and entry.body.position.distance_to(center) <= radius:
			_hit(rt, entry, apply_hit, ctx)
	_apply_effect(rt, center, target, enemies, apply_hit, ctx)

func cast_beam(rt: SkillRuntime, from: Vector2, target: Dictionary, enemies: Array, apply_hit: Callable, ctx: AttackContext) -> void:
	# 射线型：沿射线命中路径目标（近似直线命中）
	cast_line(rt, from, target, enemies, apply_hit, ctx)

func cast_spike(rt: SkillRuntime, from: Vector2, target: Dictionary, enemies: Array, apply_hit: Callable, ctx: AttackContext) -> void:
	# 地面突刺型：在敌人位置生成地刺，命中目标及小范围
	cast_instant(rt, from, target, enemies, apply_hit, ctx)

# 区域类技能登记元素区域（毒雾/旋风等持续区域）
func _register_region(rt: SkillRuntime, center: Vector2, radius: float) -> void:
	var el: StringName = rt.element()
	if el == SKILLS.ELEMENT_NONE:
		return
	if field != null and field.has_method("register_region"):
		field.register_region(rt.skill_id, el, center, radius, float(rt.config.get("duration", 1.0)))

# ---- 炼金能力改造（策划案第5章，递归保护）----

func _apply_effect(rt: SkillRuntime, at: Vector2, target: Dictionary, enemies: Array, apply_hit: Callable, ctx: AttackContext) -> void:
	var effect: StringName = rt.effect_type()
	if effect == &"":
		return
	match effect:
		ABILITIES.EFFECT_BURST:
			_effect_burst(rt, at, target, enemies, apply_hit, ctx)
		ABILITIES.EFFECT_BOUNCE:
			_effect_bounce(rt, at, target, enemies, apply_hit, ctx)
		ABILITIES.EFFECT_PIERCE:
			_effect_pierce(rt, at, target, enemies, apply_hit, ctx)
		ABILITIES.EFFECT_SPLIT:
			_effect_split(rt, at, target, enemies, apply_hit, ctx)
		ABILITIES.EFFECT_ECHO:
			_effect_echo(rt, at, target, enemies, apply_hit, ctx)
		# homing 在投射飞行层体现，命中层不额外处理

func _effect_burst(rt: SkillRuntime, at: Vector2, target: Dictionary, enemies: Array, apply_hit: Callable, ctx: AttackContext) -> void:
	if ctx.trigger_count(ABILITIES.EFFECT_BURST) >= int(rt.param("trigger_count", 3)):
		return
	ctx.mark_trigger(ABILITIES.EFFECT_BURST)
	var radius: float = float(rt.param("radius", 70.0)) * WORLD_SCALE
	var ratio: float = float(rt.param("damage_ratio", 0.5))
	for entry in enemies:
		if _living(entry) and entry.body.position.distance_to(at) <= radius and not ctx.has_hit(entry):
			_hit(rt, entry, apply_hit, ctx, ratio)

func _effect_bounce(rt: SkillRuntime, at: Vector2, target: Dictionary, enemies: Array, apply_hit: Callable, ctx: AttackContext) -> void:
	if ctx.trigger_count(ABILITIES.EFFECT_BOUNCE) >= int(rt.param("count", 2)):
		return
	ctx.mark_trigger(ABILITIES.EFFECT_BOUNCE)
	var search: float = float(rt.param("search_range", 180.0)) * WORLD_SCALE
	var decay: float = float(rt.param("decay", 0.8))
	var next := nearest_enemy(at, search, enemies, ctx.already_hit_targets)
	if next.is_empty():
		return
	_hit(rt, next, apply_hit, ctx, decay)
	# 递归弹射（受 count 上限保护）
	_effect_bounce(rt, next.body.position, next, enemies, apply_hit, ctx)

func _effect_pierce(rt: SkillRuntime, at: Vector2, target: Dictionary, enemies: Array, apply_hit: Callable, ctx: AttackContext) -> void:
	if ctx.trigger_count(ABILITIES.EFFECT_PIERCE) >= int(rt.param("count", 3)):
		return
	ctx.mark_trigger(ABILITIES.EFFECT_PIERCE)
	# 穿透：命中路径上未命中的下一个目标（近似：最近未命中敌人）
	var decay: float = float(rt.param("decay", 0.9))
	var next := nearest_enemy(at, float(rt.config.get("range", 0.0)) * WORLD_SCALE, enemies, ctx.already_hit_targets)
	if next.is_empty():
		return
	_hit(rt, next, apply_hit, ctx, decay)
	_effect_pierce(rt, next.body.position, next, enemies, apply_hit, ctx)

func _effect_split(rt: SkillRuntime, at: Vector2, target: Dictionary, enemies: Array, apply_hit: Callable, ctx: AttackContext) -> void:
	if not ctx.can_split() or not ctx.can_spawn_child():
		return
	if ctx.trigger_count(ABILITIES.EFFECT_SPLIT) >= 1:
		return
	ctx.mark_trigger(ABILITIES.EFFECT_SPLIT)
	var count: int = int(rt.param("count", 3))
	var ratio: float = float(rt.param("damage_ratio", 0.45))
	for i in count:
		var child := ctx.child()
		var nearest := nearest_enemy(at, float(rt.config.get("range", 0.0)) * WORLD_SCALE, enemies, child.already_hit_targets)
		if nearest.is_empty():
			continue
		_hit(rt, nearest, apply_hit, child, ratio)

func _effect_echo(rt: SkillRuntime, at: Vector2, target: Dictionary, enemies: Array, apply_hit: Callable, ctx: AttackContext) -> void:
	if not ctx.can_echo():
		return
	ctx.mark_trigger("echo")
	# 回响：延迟复现（由 field 层用 timer 调度，这里标记并预结算一次低伤害）
	var ratio: float = float(rt.param("damage_ratio", 0.6))
	# 简化：立即结算一次较低伤害作为"回响"，延迟表现由视觉层补足
	for entry in enemies:
		if _living(entry) and entry.body.position.distance_to(at) <= float(rt.config.get("radius", 60.0)) * WORLD_SCALE and not ctx.has_hit(entry):
			_hit(rt, entry, apply_hit, ctx, ratio)

# ---- 元素联动检测（策划案第6章）----

func _check_synergy(rt: SkillRuntime, from: Vector2, target: Dictionary, enemies: Array, apply_hit: Callable, ctx: AttackContext) -> void:
	if field == null or not field.has_method("on_synergy_trigger"):
		return
	var el: StringName = rt.element()
	if el == SKILLS.ELEMENT_NONE:
		return
	# 由 field 层维护活跃元素区域，检测本技能元素与区域元素的配对
	field.on_synergy_trigger(rt.skill_id, el, target.body.position, rt.config.get("radius", 0.0) * WORLD_SCALE, ctx)

# ---- 工具 ----

func _living(entry: Dictionary) -> bool:
	return entry.get("hp", 0.0) > 0.0 and is_instance_valid(entry.get("body")) and not entry.body.is_queued_for_deletion()

func nearest_enemy(at: Vector2, reach: float, enemies: Array, excluded: Array = []) -> Dictionary:
	var closest := {}
	var nearest := reach * reach
	for entry in enemies:
		if not _living(entry) or excluded.has(entry):
			continue
		var d: float = at.distance_squared_to(entry.body.position)
		if d < nearest:
			nearest = d
			closest = entry
	return closest

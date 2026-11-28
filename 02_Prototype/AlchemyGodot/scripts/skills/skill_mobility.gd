extends RefCounted

const ABILITIES := preload("res://data/alchemy_abilities/alchemy_ability_data.gd")
const INDEPENDENT_MOVEMENT := preload("res://scripts/skills/skill_independent_movement.gd")
const FEATHER_DRAUGHT := &"sk_feather_draught"
const WIND_BOOTS := &"sk_wind_boots"
const RETURN_WIND := &"sk_return_wind_powder"
const DEW_TONIC := &"sk_dew_tonic"
const DEW_PULSE_DELAY := 0.24

var _skills: SkillManager
var _player: Node2D
var _play_fx: Callable
var independent: INDEPENDENT_MOVEMENT
var walk_speed_scale := 1.0
var _feather_charge := 0.0
var _feather_left := 0.0
var _feather_walk_scale := 1.0
var _feather_pulse_duration := 0.0
var _feather_side := 0
var _return_left := 0.0
var _may_open_return := false
var _dew_charge := 0.0
var _dew_interrupted := false
var _dew_pulse_left := 0.0
var _dew_pulse_amount := 0.0

func setup(skills: SkillManager, player: Node2D, play_fx: Callable) -> void:
	_skills = skills
	_player = player
	_play_fx = play_fx
	_player.set("track_dodge_motion", _on_dodge_motion)
	_player.set("resolve_gate_dodge", _take_gate)

func clear() -> void:
	walk_speed_scale = 1.0
	_feather_charge = 0.0
	_feather_left = 0.0
	_feather_pulse_duration = 0.0
	_feather_side = 0
	_return_left = 0.0
	_may_open_return = false
	_dew_charge = 0.0
	_dew_interrupted = false
	_dew_pulse_left = 0.0
	_dew_pulse_amount = 0.0
	if independent != null:
		independent.clear()

func tick(delta: float, at: Vector2, enemies: Array, context: Dictionary) -> void:
	if independent != null:
		independent.tick(delta, at, enemies, context)
	_return_left = maxf(0.0, _return_left - delta)
	var moving := bool(context.get("moving", false))
	_tick_feather(delta, at, moving)
	walk_speed_scale = _feather_walk_scale if feather_active() else 1.0
	if independent != null:
		walk_speed_scale = maxf(walk_speed_scale, independent.player_walk_scale())
	_tick_dew(delta, at, enemies, moving, context)
	_dew_interrupted = false

func interrupt_dew() -> void:
	_dew_charge = 0.0
	_dew_interrupted = true

func feather_active() -> bool:
	return _feather_left > 0.0

# 返回零表示本帧冷却中，否则返回这次闪避的位移倍率。
func choose_dodge(at: Vector2, heading: Vector2, ordinary_ready: bool, base_distance: float) -> float:
	var return_wind := _skills.runtime_for(RETURN_WIND)
	if _return_left > 0.0 and return_wind != null and return_wind.ready():
		_return_left = 0.0
		_may_open_return = false
		return_wind.reset_cooldown()
		_play_dodge(return_wind, at, at + heading * base_distance)
		return 1.0
	if not ordinary_ready:
		return 0.0
	_may_open_return = return_wind != null and return_wind.ready()
	if independent != null:
		independent.begin_ordinary_dodge(at)
	var boots := _skills.runtime_for(WIND_BOOTS)
	var boosted := boots != null and boots.ready()
	if not boosted:
		return 1.0
	boots.reset_cooldown()
	var bonus := float(boots.value("dodge_bonus"))
	if _is_split():
		bonus *= 2.0 * ABILITIES.SPLIT_DAMAGE_RATIO
	var scale := 1.0 + bonus
	_play_dodge(boots, at, at + heading * base_distance * scale)
	return scale

func on_dodge_finished(at: Vector2, heading: Vector2) -> void:
	if _may_open_return:
		var runtime := _skills.runtime_for(RETURN_WIND)
		if runtime != null and runtime.ready():
			_return_left = float(runtime.value("window"))
			if _is_split():
				_return_left *= 2.0 * ABILITIES.SPLIT_DAMAGE_RATIO
			_emit(runtime, "ready", at, at + heading, 0, _return_left, true)
	_may_open_return = false
	if independent != null:
		independent.finish_ordinary_dodge(at)

func _on_dodge_motion(from: Vector2, at: Vector2, knocked_back: bool) -> void:
	if independent != null:
		independent.observe_dodge_motion(from, at, knocked_back)

func _take_gate(at: Vector2) -> Variant:
	if independent == null:
		return null
	var target: Variant = independent.use_gate(at, true)
	if target is Vector2:
		_may_open_return = false
		_return_left = 0.0
	return target

func _tick_feather(delta: float, at: Vector2, moving: bool) -> void:
	var runtime := _skills.runtime_for(FEATHER_DRAUGHT)
	if _feather_left > 0.0:
		_feather_left -= delta
		if _feather_left <= 0.0 and _feather_side == -1 and runtime != null:
			_feather_side = 1
			_feather_left += _feather_pulse_duration
			if _feather_left > 0.0:
				_emit(runtime, "buff_start", at, at, _feather_side, _feather_left, true)
		return
	if runtime == null or not runtime.ready() or not moving:
		_feather_charge = 0.0
		return
	_feather_charge += delta
	if _feather_charge < float(runtime.value("charge_time")):
		return
	_feather_charge = 0.0
	runtime.reset_cooldown()
	_feather_pulse_duration = float(runtime.value("duration"))
	_feather_side = 0
	if _is_split():
		_feather_side = -1
		_feather_pulse_duration *= ABILITIES.SPLIT_DAMAGE_RATIO
	_feather_left = _feather_pulse_duration
	_feather_walk_scale = 1.0 + float(runtime.value("speed_bonus"))
	_emit(runtime, "buff_start", at, at, _feather_side, _feather_left, true)

func _tick_dew(delta: float, at: Vector2, enemies: Array, moving: bool, context: Dictionary) -> void:
	var runtime := _skills.runtime_for(DEW_TONIC)
	var heal: Callable = context.get("heal", Callable())
	if runtime == null or not heal.is_valid():
		_dew_charge = 0.0
		_dew_pulse_left = 0.0
		return
	if _dew_pulse_left > 0.0:
		_dew_pulse_left -= delta
		if _dew_pulse_left <= 0.0:
			_heal_dew(runtime, at, heal, _dew_pulse_amount, 1)
	if not runtime.ready() or not moving or _dew_interrupted or float(context.get("missing_health", 0.0)) <= 0.0:
		_dew_charge = 0.0
		return
	if _skills.nearest_enemy(at, runtime.range_px(), enemies).is_empty():
		_dew_charge = 0.0
		return
	_dew_charge += delta
	if _dew_charge < float(runtime.value("charge_time")):
		return
	_dew_charge = 0.0
	runtime.reset_cooldown()
	var amount := float(runtime.value("heal"))
	if _is_split():
		_dew_pulse_amount = amount * ABILITIES.SPLIT_DAMAGE_RATIO
		_dew_pulse_left = DEW_PULSE_DELAY
		_heal_dew(runtime, at, heal, _dew_pulse_amount, -1)
	else:
		_heal_dew(runtime, at, heal, amount, 0)

func _heal_dew(runtime: SkillRuntime, at: Vector2, heal: Callable, amount: float, side: int) -> void:
	var restored := float(heal.call(amount))
	if restored > 0.0:
		_emit(runtime, "heal", at, at, side, 0.0)

func _play_dodge(runtime: SkillRuntime, from: Vector2, target: Vector2) -> void:
	if _is_split():
		_emit(runtime, "dash", from, target, -1, 0.0)
		_emit(runtime, "dash", from, target, 1, 0.0)
	else:
		_emit(runtime, "dash", from, target, 0, 0.0)

func _emit(runtime: SkillRuntime, event: String, from: Vector2, target: Vector2, side: int, duration: float, follow := false) -> void:
	if _play_fx.is_valid():
		var info := {"skill_id":runtime.skill_id, "event":event, "from":from, "target":target,
			"color":runtime.config.get("color", Color.WHITE), "radius":24.0,
			"duration":duration, "split_side":side}
		if follow:
			info.follow = _player
		_play_fx.call(info)

func _is_split() -> bool:
	return _skills.ability_id == ABILITIES.ABILITY_SPLIT

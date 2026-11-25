extends CharacterBody2D

const SHEET := preload("res://art/lilita_motion/sprite_gen_sheet.png")
const FRAME_WIDTH := 160
const FRAME_HEIGHT := 112
const STANDING_HEIGHT := 103
const FEET_OFFSET := 50  # 图集脚底 y=106，帧中心 y=56。
const BATTLE_BOUNDS := preload("res://levels/preset.gd").DEFAULT_PLAYABLE_BOUNDS
const HURT_SOUND := preload("res://audio/S_PlayerHurt.wav")

const IDLE_ROWS := [0, 1, 2, 3]
const WALK_ROWS := [4, 5, 6, 7]
const ROW_DEAD := 9
# 同一姿态、方向、帧序，仅替换脸部。背面看不到表情。
const HURT_ROWS := {0: 10, 2: 11, 3: 12, 4: 13, 6: 14, 7: 15}
const HURT_RECOVERY_OFFSET := 6
const HURT_EXPRESSION_STEP := 1.0 / 12.0

enum Facing { DOWN, UP, LEFT, RIGHT }
enum Pose { IDLE, WALK, DEAD, DODGE }
@export var clamp_to_battle_bounds := true

var facing := Facing.DOWN
var pose := Pose.IDLE
var elapsed := 0.0
var hurt_time := 0.0
var hurt_expression_time := 0.0
var dead := false
var dodge := 0.0
var cooldown := 0.0
var direction := Vector2.DOWN
var locked := false
var movement_bounds := BATTLE_BOUNDS
var knockback := Vector2.ZERO
var knockback_time := 0.0
var hurt_sound: AudioStreamPlayer
var _hurt_base_modulate := Color.WHITE
@onready var art: Sprite2D = $Art

func _ready() -> void:
	art.texture = SHEET
	art.region_enabled = true
	art.region_filter_clip_enabled = true
	art.position.y = -FEET_OFFSET * art.scale.y
	hurt_sound = AudioStreamPlayer.new()
	hurt_sound.name = "HurtSound"
	hurt_sound.stream = HURT_SOUND
	hurt_sound.volume_db = -10.0
	add_child(hurt_sound)
	update_pose(Pose.IDLE, 0.0)

func _physics_process(delta: float) -> void:
	if hurt_time > 0.0:
		hurt_time = maxf(0.0, hurt_time - delta)
		if hurt_time <= 0.0:
			art.modulate = _hurt_base_modulate
	hurt_expression_time = maxf(0.0, hurt_expression_time - delta)
	if dead:
		update_pose(Pose.DEAD, delta)
		return
	if locked:
		_update_art()
		return
	var move := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	cooldown = maxf(0, cooldown - delta)
	dodge = maxf(0, dodge - delta)
	if move.length_squared() > 0.01 and dodge == 0:
		direction = move
		if absf(move.x) > absf(move.y):
			facing = Facing.RIGHT if move.x > 0 else Facing.LEFT
		else:
			facing = Facing.DOWN if move.y > 0 else Facing.UP
	if Input.is_action_just_pressed("dodge") and cooldown == 0:
		dodge = 0.18
		cooldown = 0.8
	velocity = direction * 490 if dodge > 0 else move * 200
	if knockback_time > 0.0:
		velocity = knockback
		knockback_time -= delta
	move_and_slide()
	if clamp_to_battle_bounds:
		position = position.clamp(movement_bounds.position, movement_bounds.end)
	if dodge > 0.0:
		update_pose(Pose.DODGE, delta)
	else:
		update_pose(Pose.WALK if get_real_velocity().length_squared() > 1 else Pose.IDLE, delta)

func show_hurt() -> void:
	if dead:
		return
	if hurt_time <= 0.0:
		_hurt_base_modulate = art.modulate
	hurt_time = 0.1
	art.modulate = _hurt_base_modulate * Color(1.0, 0.38, 0.34, 1.0)
	hurt_sound.play()
	hurt_expression_time = HURT_EXPRESSION_STEP * 2.0
	_update_art()

func show_death() -> void:
	if hurt_time > 0.0:
		art.modulate = _hurt_base_modulate
		hurt_time = 0.0
	hurt_expression_time = 0.0
	dead = true
	update_pose(Pose.DEAD, 0.0)

func update_pose(next: Pose, delta: float) -> void:
	if pose != next:
		elapsed = 0.0
		pose = next
	elapsed += delta
	_update_art()

func _update_art() -> void:
	var row: int = WALK_ROWS[facing]
	var frame: int
	match pose:
		Pose.WALK:
			frame = int(elapsed * 10.0) % 6
		Pose.DODGE:
			frame = int(elapsed * 16.0) % 6
		Pose.DEAD:
			row = ROW_DEAD
			frame = mini(5, int(elapsed * 10.0))
		Pose.IDLE:
			row = IDLE_ROWS[facing]
			frame = int(elapsed * 4.0) % 4
	if hurt_expression_time > 0.0 and HURT_ROWS.has(row):
		row = HURT_ROWS[row]
		if hurt_expression_time <= HURT_EXPRESSION_STEP:
			row += HURT_RECOVERY_OFFSET
	art.region_rect = Rect2(frame * FRAME_WIDTH, row * FRAME_HEIGHT, FRAME_WIDTH, FRAME_HEIGHT)

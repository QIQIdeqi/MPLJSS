extends CharacterBody2D
# 角色动画：单张规范序列帧 sprite_sheet.png（5行：待机/死亡/左跑/上跑/下跑）
# 左跑右跑通过 flip_h 镜像；待机/死亡不分方向。

const SHEET := preload("res://art/lilita_motion/sprite_sheet.png")
const FRAME_SIZE := 256
const FEET_OFFSET := 107   # 脚底在帧内 y=235，相对帧中心 128 的偏移 = 235 - 128 = 107
const BATTLE_BOUNDS := preload("res://levels/preset.gd").DEFAULT_PLAYABLE_BOUNDS
const HURT_SOUND := preload("res://audio/S_PlayerHurt.wav")

# 行索引（从上到下）
const ROW_IDLE := 0
const ROW_DEAD := 1
const ROW_RUN := 2     # 左跑（右跑镜像）
const ROW_UP := 3
const ROW_DOWN := 4

# 每行帧数
const FRAME_COUNT := {ROW_IDLE: 3, ROW_DEAD: 6, ROW_RUN: 7, ROW_UP: 7, ROW_DOWN: 7}

enum Pose { IDLE, WALK, HURT, DEAD, DODGE }
@export var clamp_to_battle_bounds := true

var facing := 0   # 0=下, 1=上, 2=左右
var pose := Pose.IDLE
var elapsed := 0.0
var hurt_time := 0.0
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
	if dead:
		update_pose(Pose.DEAD, delta)
		return
	if locked:
		return
	var move := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	cooldown = maxf(0, cooldown - delta)
	dodge = maxf(0, dodge - delta)
	if move.length_squared() > 0.01 and dodge == 0:
		direction = move
		if absf(move.x) > absf(move.y):
			facing = 2
			art.flip_h = move.x > 0   # 左跑图为默认，向右移动时镜像
		else:
			facing = 0 if move.y > 0 else 1
			art.flip_h = false
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

func show_death() -> void:
	if hurt_time > 0.0:
		art.modulate = _hurt_base_modulate
		hurt_time = 0.0
	dead = true
	update_pose(Pose.DEAD, 0.0)

# 根据 pose 与 facing 确定行
func _row_for(pose: Pose) -> int:
	match pose:
		Pose.DEAD:
			return ROW_DEAD
		Pose.IDLE, Pose.HURT:
			return ROW_IDLE
		_:
			# WALK / DODGE 按 facing 选方向行
			match facing:
				1: return ROW_UP
				2: return ROW_RUN
				_: return ROW_DOWN

func update_pose(next: Pose, delta: float) -> void:
	if pose != next:
		elapsed = 0.0
		pose = next
	elapsed += delta
	var row := _row_for(pose)
	var count: int = FRAME_COUNT[row]
	var frame := 0
	match pose:
		Pose.WALK:
			frame = int(elapsed * 8.0) % count
		Pose.DODGE:
			frame = int(elapsed * 16.0) % count
		Pose.HURT:
			frame = 0   # 受击复用待机第1帧（配合闪红）
		Pose.DEAD:
			frame = mini(count - 1, int(elapsed * 8.0))
		Pose.IDLE:
			frame = int(elapsed * 4.0) % count
	art.region_rect = Rect2(frame * FRAME_SIZE, row * FRAME_SIZE, FRAME_SIZE, FRAME_SIZE)

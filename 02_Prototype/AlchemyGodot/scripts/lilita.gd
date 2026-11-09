extends CharacterBody2D

# 单张规范序列帧：5 行 × 7 列，每帧 256×256。
# 行顺序（从上到下）：0 待机(3帧) / 1 死亡(6帧) / 2 移动·左走(7帧,右走镜像) / 3 上走(7帧) / 4 下走(7帧)。
const SHEET := preload("res://art/lilita_motion/sprite_sheet.png")
const FRAME_SIZE := 256
const FEET_OFFSET := 107  # 脚底(帧内 y=235)相对帧中心(128)的向下偏移
const FRAME_COUNT := {0: 3, 1: 6, 2: 7, 3: 7, 4: 7}

enum Row { IDLE, DEATH, MOVE, UP, DOWN }
enum Pose { IDLE, WALK, HURT, DEAD, DODGE }
@export var clamp_to_battle_bounds := true

var facing := 0  # 0=下 1=上 2=左右(移动)
var pose := Pose.IDLE
var elapsed := 0.0
var hurt_time := 0.0
var dead := false
var dodge := 0.0
var cooldown := 0.0
var direction := Vector2.DOWN
var locked := false
var knockback := Vector2.ZERO
var knockback_time := 0.0
@onready var art: Sprite2D = $Art

func _ready() -> void:
	art.texture = SHEET
	art.position.y = -FEET_OFFSET * art.scale.y
	art.region_enabled = true
	art.region_filter_clip_enabled = true
	update_pose(Pose.IDLE, 0.0)

func _physics_process(delta: float) -> void:
	if dead:
		update_pose(Pose.DEAD, delta)
		return
	if locked:
		return
	hurt_time = maxf(0.0, hurt_time - delta)
	var move := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	cooldown = maxf(0, cooldown - delta)
	dodge = maxf(0, dodge - delta)
	if move.length_squared() > 0.01 and dodge == 0:
		direction = move
		if absf(move.x) > absf(move.y):
			facing = 2
			art.flip_h = move.x > 0  # 行2为左走，向右移动镜像
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
		position = position.clamp(Vector2(32, 110), Vector2(1248, 652))
	if hurt_time > 0.0:
		update_pose(Pose.HURT, delta)
	elif dodge > 0.0:
		update_pose(Pose.DODGE, delta)
	else:
		update_pose(Pose.WALK if get_real_velocity().length_squared() > 1 else Pose.IDLE, delta)

func show_hurt() -> void:
	hurt_time = 0.4
	update_pose(Pose.HURT, 0.0)

func show_death() -> void:
	dead = true
	update_pose(Pose.DEAD, 0.0)

func _row(pose_value: Pose) -> int:
	match pose_value:
		Pose.DEAD:
			return Row.DEATH
		Pose.IDLE, Pose.HURT:
			return Row.IDLE
		_:
			# WALK / DODGE 按朝向选行
			match facing:
				1: return Row.UP
				2: return Row.MOVE
				_: return Row.DOWN

func update_pose(next: Pose, delta: float) -> void:
	if pose != next:
		elapsed = 0.0
		pose = next
	elapsed += delta
	var row := _row(pose)
	var count: int = FRAME_COUNT[row]
	var frame := 0
	match pose:
		Pose.WALK:
			frame = int(elapsed * 8.0) % count
		Pose.DODGE:
			frame = int(elapsed * 16.0) % count
		Pose.HURT:
			# 受击无专属动画：短暂闪白（modulate 由外部闪红亦可），复用待机帧。
			frame = 0
			art.modulate = Color(1, 0.55, 0.55) if fmod(elapsed * 10.0, 2.0) < 1.0 else Color(1, 1, 1)
		Pose.DEAD:
			frame = mini(count - 1, int(elapsed * 8.0))
		_:
			frame = int(elapsed * 4.0) % count
	if pose != Pose.HURT:
		art.modulate = Color.WHITE
	art.region_rect = Rect2(frame * FRAME_SIZE, row * FRAME_SIZE, FRAME_SIZE, FRAME_SIZE)

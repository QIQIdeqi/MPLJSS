extends CharacterBody2D

const MOTION := [
	preload("res://art/lilita_motion/front.png"),
	preload("res://art/lilita_motion/back.png"),
	preload("res://art/lilita_motion/side.png"),
]
const FRAME_SIZE := 512
const FEET_OFFSET := 232

enum Pose { IDLE, WALK, HURT, DEAD, DODGE }
@export var clamp_to_battle_bounds := true

var facing := 0
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
			art.flip_h = move.x < 0
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

func update_pose(next: Pose, delta: float) -> void:
	if pose != next:
		elapsed = 0.0
		pose = next
	elapsed += delta
	var row := int(pose)
	var frame := 0
	match pose:
		Pose.WALK:
			frame = int(elapsed * 8.0) % 6
		Pose.DODGE:
			row = Pose.WALK
			frame = int(elapsed * 16.0) % 6
		Pose.HURT:
			frame = mini(3, int(elapsed * 10.0))
		Pose.DEAD:
			frame = mini(5, int(elapsed * 8.0))
	art.texture = MOTION[facing]
	art.region_rect = Rect2(frame * FRAME_SIZE, row * FRAME_SIZE, FRAME_SIZE, FRAME_SIZE)

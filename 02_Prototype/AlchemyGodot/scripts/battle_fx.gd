extends Node2D

const HIT := [
	preload("res://art/pixelfx/Hit_FrontColor.png"),
	preload("res://art/pixelfx/Hit_FrontLight.png"),
]
const POISON := [
	preload("res://art/pixelfx/Poison_BackColor.png"),
	preload("res://art/pixelfx/Poison_BackLight.png"),
	preload("res://art/pixelfx/Poison_FrontColor.png"),
	preload("res://art/pixelfx/Poison_FrontLight.png"),
]
const PORTAL := [
	preload("res://art/pixelfx/Portal_BackColor.png"),
	preload("res://art/pixelfx/Portal_FrontColor.png"),
	preload("res://art/pixelfx/Portal_FrontLight.png"),
]
const XP_MOTES := preload("res://scenes/fx/xp_motes.tscn")
const BURST := preload("res://scenes/fx/burst.tscn")
const TRAIL := preload("res://scenes/fx/trail.tscn")
const COIN_SHINE := preload("res://scenes/fx/coin_shine.gdshader")
const FPS := 30.0

static var additive: CanvasItemMaterial
var cards: Array[Sprite2D] = []
var age := 0.0
var frames := 0
var looping := false

static func hit(parent: Node2D, at: Vector2, size_multiplier := 1.0) -> Node2D:
	return _atlas(parent, at, HIT, Vector2(44, 64), Vector2i(4, 4), 15,
		Vector4(1, 1, 0, 0), 0.65 * size_multiplier, false)

static func poison(parent: Node2D, at: Vector2, size_multiplier := 1.0) -> Node2D:
	return _atlas(parent, at, POISON, Vector2(128, 86), Vector2i(8, 15), 120,
		Vector4(-1, -1, 1, 1), 0.78 * size_multiplier, true)

static func portal(parent: Node2D, at: Vector2, size_multiplier := 1.0) -> Node2D:
	return _atlas(parent, at, PORTAL, Vector2(76, 106), Vector2i(8, 9), 72,
		Vector4(-1, 1, 1, 0), 0.80 * size_multiplier, true)

static func burst(parent: Node2D, at: Vector2, tint: Color) -> CPUParticles2D:
	var particles := BURST.instantiate() as CPUParticles2D
	particles.color = tint
	particles.finished.connect(particles.queue_free)
	_fx_parent(parent).add_child(particles)
	particles.global_position = at
	particles.emitting = true
	return particles

static func trail(parent: Node2D, from: Vector2, to: Vector2, tint: Color,
		duration := 0.18) -> CPUParticles2D:
	var particles := TRAIL.instantiate() as CPUParticles2D
	particles.color = tint
	_fx_parent(parent).add_child(particles)
	particles.global_position = from
	particles.emitting = true
	var travel := particles.create_tween()
	travel.tween_property(particles, "global_position", to, maxf(duration, 0.01))
	travel.tween_callback(particles.set_emitting.bind(false))
	travel.tween_interval(particles.lifetime)
	travel.tween_callback(particles.queue_free)
	return particles

static func xp_motes(sprite: Sprite2D) -> CPUParticles2D:
	var particles := XP_MOTES.instantiate() as CPUParticles2D
	sprite.add_child(particles)
	particles.scale = Vector2.ONE / sprite.global_scale.abs()
	particles.position = sprite.offset
	return particles

static func update_xp_motes(sprite: Sprite2D, particles: CPUParticles2D) -> void:
	particles.position = sprite.offset

static func coin_shine(sprite: Sprite2D) -> void:
	var sweep := ShaderMaterial.new()
	sweep.shader = COIN_SHINE
	sweep.set_shader_parameter("offset_phase", fposmod(sprite.position.dot(Vector2(0.007, 0.011)), 1.0))
	sprite.material = sweep

static func _atlas(parent: Node2D, at: Vector2, textures: Array, origin: Vector2,
		grid: Vector2i, count: int, depth: Vector4, pixel_scale: float, loop: bool) -> Node2D:
	var effect = load("res://scripts/battle_fx.gd").new()
	effect.name = "PixelFX"
	effect.frames = count
	effect.looping = loop
	effect.y_sort_enabled = true
	if additive == null:
		additive = CanvasItemMaterial.new()
		additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for i in textures.size():
		var card := Sprite2D.new()
		card.texture = textures[i]
		card.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		card.hframes = grid.x
		card.vframes = grid.y
		card.centered = false
		card.scale = Vector2.ONE * pixel_scale
		var is_light: bool = card.texture.resource_path.ends_with("Light.png")
		var sort_y := 7.0 * depth[i] + (0.1 if is_light else 0.0)
		card.position.y = sort_y
		card.offset = -origin - Vector2(0, sort_y / pixel_scale)
		if is_light:
			card.material = additive
		effect.add_child(card)
		effect.cards.append(card)
	_fx_parent(parent).add_child(effect)
	effect.global_position = at
	return effect

static func _fx_parent(parent: Node2D) -> Node2D:
	var actors := parent.get_node_or_null("Actors") as Node2D
	return actors if actors != null else parent

func _process(delta: float) -> void:
	age += delta
	var frame := floori(age * FPS)
	if not looping and frame >= frames:
		queue_free()
		return
	for card in cards:
		card.frame = frame % frames

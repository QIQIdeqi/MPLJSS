extends Node3D

const BLAST := preload("res://art/vfx/v2/px_blast_flask/grenade_blast_24f.png")
const COLUMNS := 6
const ROWS := 4
const FRAME_COUNT := COLUMNS * ROWS
const LIFETIME := 0.85
const SHOCKWAVE_RADIUS_PIXELS := 70.0
const IMPACT_ANCHOR_OFFSET := Vector2(0.0, 70.0)

var age := 0.0
var blast: Sprite3D
var flash: OmniLight3D

func start(radius: float) -> void:
	var spread := clampf(radius, 0.55, 1.45)
	blast = Sprite3D.new()
	blast.texture = BLAST
	blast.hframes = COLUMNS
	blast.vframes = ROWS
	blast.offset = IMPACT_ANCHOR_OFFSET
	blast.pixel_size = spread / SHOCKWAVE_RADIUS_PIXELS
	blast.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	blast.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	blast.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	blast.position.y = 0.07
	add_child(blast)

	flash = OmniLight3D.new()
	flash.light_color = Color("#ff9e62")
	flash.light_energy = 0.86
	flash.omni_range = spread * 1.55
	flash.omni_attenuation = 1.7
	flash.position.y = 0.33
	add_child(flash)

func _process(delta: float) -> void:
	age += delta
	if age >= LIFETIME:
		queue_free()
		return

	blast.frame = mini(floori(age * FRAME_COUNT / LIFETIME), FRAME_COUNT - 1)
	blast.modulate.a = 1.0 - smoothstep(0.56, LIFETIME, age)
	flash.light_energy = 0.86 * pow(maxf(1.0 - age / 0.17, 0.0), 2.0)

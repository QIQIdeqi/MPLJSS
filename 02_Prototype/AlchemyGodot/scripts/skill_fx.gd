extends RefCounted
# 技能视觉特效库（自制，符合技能描述先用着）
# 由 field 层调用，在 effects 节点生成投射物/爆炸/范围/射线等视觉表现。
# 所有特效都用程序化 Sprite2D/粒子 + 现有 FX 组合，不依赖额外美术资源。

const FX := preload("res://scripts/battle_fx.gd")
const ORBIT_BLADE := preload("res://scripts/fx/orbit_blade.gd")


# ---- 投射物（魔法弹）：飞行的发光弹丸，命中后消失 ----
static func projectile(parent: Node2D, from: Vector2, to: Vector2, color: Color, speed := 620.0, on_hit: Callable = Callable()) -> Node2D:
	var ball := _glow_dot(color, 7.0)
	_fx_root(parent).add_child(ball)
	ball.global_position = from
	var dist: float = from.distance_to(to)
	var dur: float = maxf(0.05, dist / maxf(speed, 1.0))
	var tw := ball.create_tween()
	tw.tween_property(ball, "global_position", to, dur)
	tw.tween_callback(ball.queue_free)
	# 拖尾
	FX.trail(parent, from, to, color, dur)
	if on_hit.is_valid():
		tw.tween_callback(on_hit)
	return ball


# ---- 爆裂（火球）：火球飞行 + 命中爆炸 ----
static func blast(parent: Node2D, from: Vector2, to: Vector2, color: Color, radius_px: float, speed := 520.0) -> void:
	var ball := _glow_dot(color, 10.0)
	_fx_root(parent).add_child(ball)
	ball.global_position = from
	var dur: float = maxf(0.05, from.distance_to(to) / maxf(speed, 1.0))
	var tw := ball.create_tween()
	tw.tween_property(ball, "global_position", to, dur)
	tw.tween_callback(func() -> void:
		ball.queue_free()
		explosion(parent, to, color, radius_px))


# ---- 爆炸（范围冲击波）----
static func explosion(parent: Node2D, at: Vector2, color: Color, radius_px: float) -> void:
	FX.burst(parent, at, color)
	var ring := _ring(color, radius_px)
	_fx_root(parent).add_child(ring)
	ring.global_position = at
	var tw := ring.create_tween()
	tw.tween_property(ring, "scale", Vector2.ONE * 1.4, 0.28)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.28)
	tw.tween_callback(ring.queue_free)


# ---- 直线（冰锥/风刃）：一道拖尾直线 ----
static func line(parent: Node2D, from: Vector2, to: Vector2, color: Color) -> void:
	FX.trail(parent, from, to, color, 0.16)


# ---- 瞬间打击（雷击）：天上劈下闪电 ----
static func lightning(parent: Node2D, at: Vector2, color: Color) -> void:
	var top := at + Vector2(0, -160)
	FX.trail(parent, top, at, color, 0.10)
	var bolt := _line_node(top, at, color, 3.0)
	_fx_root(parent).add_child(bolt)
	var tw := bolt.create_tween()
	tw.tween_interval(0.08)
	tw.tween_callback(bolt.queue_free)
	FX.burst(parent, at, color)


# ---- 环绕（旋风）：围绕玩家的旋转风刃 ----
static func orbit(parent: Node2D, center: Vector2, color: Color, radius_px: float, duration := 0.8) -> void:
	var blade := Sprite2D.new()
	var tex := GradientTexture2D.new()
	tex.gradient = _radial_gradient(color)
	tex.width = 24
	tex.height = 24
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.0, 0.0)
	blade.texture = tex
	blade.scale = Vector2.ONE * 0.5
	blade.set_script(ORBIT_BLADE)
	_fx_root(parent).add_child(blade)
	blade.setup(center, radius_px, duration)


# ---- 区域持续（毒雾）：绿色毒雾团（复用 poison 特效）----
static func zone(parent: Node2D, at: Vector2, color: Color, radius_px: float) -> void:
	FX.poison(parent, at, radius_px / 90.0)


# ---- 指定区域打击（落石）：落石砸下 + 尘土 ----
static func aoe(parent: Node2D, at: Vector2, color: Color, radius_px: float) -> void:
	var rock := _glow_dot(color, 12.0)
	_fx_root(parent).add_child(rock)
	rock.global_position = at + Vector2(0, -120)
	var tw := rock.create_tween()
	tw.tween_property(rock, "global_position", at, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		rock.queue_free()
		explosion(parent, at, color, radius_px))


# ---- 射线（光束）：一道粗光束 ----
static func beam(parent: Node2D, from: Vector2, to: Vector2, color: Color, duration := 0.7) -> void:
	var b := _line_node(from, to, color, 6.0)
	_fx_root(parent).add_child(b)
	var tw := b.create_tween()
	tw.tween_interval(duration)
	tw.tween_callback(b.queue_free)


# ---- 地面突刺（地刺）：地面突起尖刺 ----
static func spike(parent: Node2D, at: Vector2, color: Color) -> void:
	var s := _spike_polygon(color)
	_fx_root(parent).add_child(s)
	s.global_position = at
	var tw := s.create_tween()
	tw.tween_property(s, "scale", Vector2.ONE, 0.12).from(Vector2(0.3, 0.3))
	tw.tween_interval(0.18)
	tw.tween_callback(s.queue_free)


# ---- 内部工具 ----

static func _fx_root(parent: Node2D) -> Node2D:
	var actors := parent.get_node_or_null("Actors") as Node2D
	return actors if actors != null else parent

static func _glow_dot(color: Color, radius: float) -> Sprite2D:
	var s := Sprite2D.new()
	var tex := GradientTexture2D.new()
	tex.gradient = _radial_gradient(color)
	tex.width = 32
	tex.height = 32
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.0, 0.0)
	s.texture = tex
	s.scale = Vector2.ONE * (radius * 2.0 / 32.0)
	return s

static func _radial_gradient(color: Color) -> Gradient:
	var g := Gradient.new()
	g.colors = PackedColorArray([color, Color(color.r, color.g, color.b, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 1.0])
	return g

static func _ring(color: Color, radius: float) -> Node2D:
	var n := Node2D.new()
	var ring := Sprite2D.new()
	var tex := GradientTexture2D.new()
	tex.gradient = _radial_gradient(color)
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.42, 0.5)
	ring.texture = tex
	ring.scale = Vector2.ONE * (radius * 2.0 / 64.0)
	n.add_child(ring)
	return n

static func _line_node(from: Vector2, to: Vector2, color: Color, width: float) -> Node2D:
	var n := Node2D.new()
	var seg := from.distance_to(to)
	n.position = (from + to) * 0.5
	n.rotation = (to - from).angle()
	var rect := ColorRect.new()
	rect.color = color
	rect.size = Vector2(seg, width)
	rect.position = Vector2(-seg * 0.5, -width * 0.5)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.add_child(rect)
	return n

static func _spike_polygon(color: Color) -> Node2D:
	var n := Node2D.new()
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array([
		Vector2(0, 0), Vector2(-14, 0), Vector2(-8, -34), Vector2(0, -46), Vector2(8, -34), Vector2(14, 0),
	])
	p.color = color
	n.add_child(p)
	return n

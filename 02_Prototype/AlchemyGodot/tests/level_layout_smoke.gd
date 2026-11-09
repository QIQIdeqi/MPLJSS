extends SceneTree

const Layout = preload("res://scripts/level_layout.gd")
const NORMAL = preload("res://levels/normal.tres")
const BOSS = preload("res://levels/boss.tres")
const BOUNDS := Rect2(0, 0, 1280, 720)
const SPAWN := Vector2(640, 430)
const BOSS_SPAWN := Vector2(640, 450)
const PORTAL := Vector2(1120, 330)

var failures := 0

func _initialize() -> void:
	for preset in [NORMAL, BOSS]:
		var spawn := BOSS_SPAWN if preset.boss else SPAWN
		for seed_value in [10, 77, 7081, 89042]:
			var layout := Layout.build(preset, seed_value, BOUNDS, spawn)
			expect(layout.error == "", str(layout.error))
			expect(layout.tiles.size() == preset.grid.x * preset.grid.y, "continuous ground")
			expect(not layout.props.is_empty(), "populated objects")
			expect(layout == Layout.build(preset, seed_value, BOUNDS, spawn), "repeatable seed")
			for item: Dictionary in layout.props:
				var foot: Vector2 = item.position
				var half: Vector2 = item.collision * 0.5
				if preset.boss and item.collision != Vector2.ZERO:
					var relative := (foot - BOUNDS.get_center()) / (Vector2(371, 245) + half)
					expect(relative.length_squared() > 1.0, "Boss combat space clear")
				elif not preset.boss:
					var path := Geometry2D.get_closest_point_to_segment(foot, SPAWN, PORTAL)
					expect(path.distance_to(foot) >= preset.protected_half_width, "portal route clear")
		expect(Layout.build(preset, 77, BOUNDS, spawn) != Layout.build(preset, 78, BOUNDS, spawn), "fresh seed changes layout")

	var settings := NORMAL.duplicate_deep()
	var runtime := Layout.build(settings, 77, BOUNDS, SPAWN)
	var original := Layout.build(settings, 77, BOUNDS, SPAWN, Vector2.ZERO, true)
	expect(runtime == original, "unmodified preview matches runtime")
	settings.ground_seed_offset = 1
	var ground := Layout.build(settings, 77, BOUNDS, SPAWN, Vector2.ZERO, true)
	expect(ground.tiles != original.tiles and ground.props == original.props, "ground-only reroll")
	settings.prop_seed_offset = 1
	var objects := Layout.build(settings, 77, BOUNDS, SPAWN, Vector2.ZERO, true)
	expect(objects.tiles == ground.tiles and objects.props != ground.props, "object-only reroll")
	settings.locked_ground[0] = 1
	var first: Dictionary = objects.props[0]
	settings.locked_props[first.cell] = first.brush
	var painted := Layout.build(settings, 77, BOUNDS, SPAWN, Vector2.ZERO, true)
	expect(painted.tiles[0].brush == 1 and painted.props.has(first), "preview locks both layers")
	expect(Layout.build(settings, 77, BOUNDS, SPAWN) == runtime, "runtime ignores editor offsets and locks")

	settings.palette[3].count_range = Vector2i(2, 7)
	settings.palette[3].density_range = Vector2(0.01, 0.014)
	var ranged := Layout.build(settings, 77, BOUNDS, SPAWN)
	expect(ranged.error.is_empty(), "count and density intersect")
	var bushes := 0
	for item: Dictionary in ranged.props:
		bushes += 1 if item.brush == 3 else 0
	expect(bushes >= 5 and bushes <= 6, "count and density enforced")
	settings.palette[3].count_range = Vector2i(0, 0)
	expect(not Layout.build(settings, 77, BOUNDS, SPAWN).error.is_empty(), "impossible ranges rejected")
	if failures == 0:
		print("ALCHEMY_LEVEL_LAYOUT_PASS normal boss routes two-layer reroll locks range")
	quit(failures)

func expect(condition: bool, title: String) -> void:
	if not condition:
		push_error(title)
		failures += 1

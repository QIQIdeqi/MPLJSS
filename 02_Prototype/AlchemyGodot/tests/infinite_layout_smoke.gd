extends SceneTree

const Stream = preload("res://scripts/infinite_field_layout.gd")
const Layout = preload("res://scripts/level_layout.gd")
const Preset = preload("res://levels/preset.gd")
const Brush = preload("res://levels/brush.gd")

var failures := 0
var checks := 0

func _initialize() -> void:
	var settings := make_preset()
	var stream := Stream.new()
	stream.setup(settings, 77, &"greyford_01", Vector2(640, 430))
	var first := stream.update(Vector2(640, 430))
	expect(first.error.is_empty() and first.added.size() == 9, "loads nine initial chunks")
	var original: Dictionary = stream.active_chunks[Vector2i.ZERO].duplicate(true)
	var same := stream.update(Vector2(650, 440))
	expect(same.added.is_empty() and same.removed.is_empty(), "moving inside chunk leaves layout untouched")
	var far := stream.update(Vector2(6400, 3600))
	expect(far.error.is_empty() and far.removed.size() == 9 and stream.active_chunks.size() == 9, "far travel unloads old strip")
	stream.update(Vector2(-2560, -1440))
	expect(stream.coordinate(Vector2(-1, -1)) == Vector2i(-1, -1), "negative coordinates use floor")
	stream.update(Vector2(640, 430))
	expect(stream.active_chunks[Vector2i.ZERO] == original, "returning regenerates exact old chunk")
	var other := Stream.new()
	other.setup(settings, 78, &"greyford_01", Vector2(640, 430))
	expect(other.build_chunk(Vector2i.ZERO) != original, "new seed changes chunk")
	other.setup(settings, 77, &"other_stage", Vector2(640, 430))
	expect(other.build_chunk(Vector2i.ZERO) != original, "stable level ID participates in seed")
	var themes := [&"greyford", &"trade_road", &"manor", &"pilgrimage", &"capital"]
	for theme in themes:
		settings.theme_id = theme
		for seed_value in [77, 908, 12008]:
			stream.setup(settings, seed_value, theme, Vector2(640, 430))
			for coord: Vector2i in [Vector2i.ZERO, Vector2i(4, -3), Vector2i(-7, 2), Vector2i(10, 10)]:
				var data := stream.build_chunk(coord)
				expect(data.error.is_empty(), "%s seed %d chunk %s generates" % [theme, seed_value, coord])
				expect(data.tiles.size() == 432 and data.props.size() >= 6 and data.props.size() <= 8, "per-chunk count/density intersection")
				var clear := true
				for prop: Dictionary in data.props:
					clear = clear and Layout.route_distance(settings, prop.position) >= 58.0 + (prop.collision * 0.5).length()
					clear = clear and prop.position.distance_to(data.bounds.get_center()) >= 112.0
					var occupied := Rect2(prop.position - prop.collision * 0.5, prop.collision)
					clear = clear and data.bounds.grow(-16.0).encloses(occupied)
				expect(clear, "routes, central safe pocket and neighbor collision gap stay clear")
	settings.theme_id = &"greyford"
	stream.setup(settings, 77, &"greyford_01", Vector2(640, 430))
	stream.update(Vector2(640, 430))
	var before := stream.active_chunks.duplicate(true)
	settings.palette[2].count_range = Vector2i(500, 500)
	var impossible := stream.update(Vector2(4000, 4000))
	expect(not impossible.error.is_empty() and stream.active_chunks == before, "invalid next strip fails atomically without reducing authored counts")
	if failures == 0:
		print("ALCHEMY_INFINITE_LAYOUT_PASS checks=%d signed_chunks seed_revisit count_density routes atomic_stream" % checks)
	quit(failures)

func make_preset() -> Preset:
	var settings := Preset.new()
	settings.infinite = true
	settings.object_density = 0.20
	var grass := Brush.new()
	grass.ground = true
	grass.texture = preload("res://art/grass.png")
	grass.weight = 80.0
	var dirt := Brush.new()
	dirt.ground = true
	dirt.texture = preload("res://art/dirt.png")
	dirt.weight = 20.0
	var tree := Brush.new()
	tree.display_name = "测试橡树"
	tree.texture = preload("res://art/oak.png")
	tree.size = Vector2(111, 135)
	tree.collision = Vector2(29, 22)
	tree.count_range = Vector2i(6, 10)
	tree.density_range = Vector2(0.01, 0.02)
	settings.palette.assign([grass, dirt, tree])
	return settings

func expect(condition: bool, title: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(title)

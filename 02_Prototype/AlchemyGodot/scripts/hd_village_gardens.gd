extends RefCounted

const TERRAIN := preload("res://scripts/hd_village_terrain.gd")

const ZONES := {
	"MillAndBridge": [
		["Waterwheel", Vector2(80, 405), 1.20],
		["Crates", Vector2(54, 413), 0.37],
		["Barrel", Vector2(33, 431), 0.34],
		["StoneWall", Vector2(33, 399), 0.32],
		["StoneWall", Vector2(111, 421), 0.30],
		["BankRocks", Vector2(131, 414), 0.28],
		["BankRocks", Vector2(164, 430), 0.31],
		["Bush", Vector2(183, 449), 0.35],
		["BankRocks", Vector2(321, 548), 0.31],
		["RuneStone", Vector2(389, 584), 0.55],
		["Oak", Vector2(480, 662), 1.50],
		["Fence", Vector2(465, 447), 0.36],
		["Bush", Vector2(481, 467), 0.40],
		["BankRocks", Vector2(447, 476), 0.42],
	],
	"WestBankGarden": [
		["TerraceFence", Vector2(0, 580), 0.34, -62.0],
		["TerraceFence", Vector2(16, 618), 0.34, -62.0],
		["TerraceFence", Vector2(32, 652), 0.36, -35.0],
		["TerraceFence", Vector2(85, 691), 0.36, -35.0],
		["TerraceFence", Vector2(144, 723), 0.36, -21.0],
		["TerraceFence", Vector2(207, 730), 0.36, 9.0],
		["TerraceFence", Vector2(252, 708), 0.34, 43.0],
		["TerraceTrough", Vector2(390, 647), 0.53],
		["TerraceRocks", Vector2(421, 625), 0.43],
		["TerraceRocks", Vector2(16, 693), 0.39],
		["TerraceRocks", Vector2(49, 722), 0.40],
	],
}

static func build_terrace_edging(parent: Node3D) -> void:
	var stone := StandardMaterial3D.new()
	stone.albedo_texture = preload("res://art/cobblestone.png")
	stone.albedo_color = Color("#a39478")
	stone.roughness = 0.94
	for bed in TERRAIN.GARDEN_BEDS:
		var center: Vector2 = bed[0]
		var half_size: Vector2 = bed[1]
		var front := center + Vector2(0, half_size.y)
		var front_left := front - Vector2(half_size.x, 0)
		var front_right := front + Vector2(half_size.x, 0)
		var height := TERRAIN.height_at(center)
		add_stone_row(parent, front_left, front_right, height, stone)
		add_stone_row(parent, front_left, center - half_size, height, stone)

static func add_stone_row(parent: Node3D, from: Vector2, to: Vector2, top: float, stone: Material) -> void:
	var pieces := maxi(1, roundi(from.distance_to(to) / 15.0))
	var length := from.distance_to(to) / (pieces * TERRAIN.SCALE)
	for i in pieces:
		var at := from.lerp(to, (i + 0.5) / pieces)
		var bottom := minf(TERRAIN.dry_ground_height(at) - 0.09, top - 0.16)
		var crown := top + 0.016 + 0.008 * sin(float(i) * 2.2)
		var rock := BoxMesh.new()
		rock.material = stone
		rock.size = Vector3(length * 1.01, crown - bottom, 0.16)
		var instance := MeshInstance3D.new()
		instance.mesh = rock
		parent.add_child(instance)
		instance.position = TERRAIN.world_at(at)
		instance.position.y = (crown + bottom) * 0.5
		instance.rotation.y = -from.angle_to_point(to)

static func plant_terraces(parent: Node3D) -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_texture = preload("res://art/village_hd/WoodGrain.png")
	wood.albedo_color = Color("#8e6740")
	wood.roughness = 0.96
	var textures: Array[Texture2D] = []
	for name in ["Cabbage", "Lettuce", "Turnip", "Tomato", "Beans", "BeanSprig"]:
		textures.append(load("res://art/village_hd/generated/GardenPlant" + name + ".png") as Texture2D)
	var cabbage: Vector2 = TERRAIN.GARDEN_BEDS[0][0]
	for row in [-9, 9]:
		for i in 3:
			add_plant(parent, textures[0], cabbage + Vector2((i - 1) * 16, row), 0.18 + 0.02 * (i % 2))
	var trellis: Vector2 = TERRAIN.GARDEN_BEDS[1][0]
	var ridge: Array[Vector3] = []
	for i in 4:
		var at := trellis + Vector2((i - 1.5) * 18, 0)
		var top := TERRAIN.world_at(at) + Vector3.UP * (0.65 + 0.015 * sin(i))
		ridge.append(top)
		for side in [-1, 1]:
			var foot := TERRAIN.world_at(at + Vector2(0, side * 13)) - Vector3.UP * 0.05
			add_timber(parent, foot, top, 0.034, wood)
		add_plant(parent, textures[4 + i % 2], at + Vector2(0, 5), 0.57)
	add_timber(parent, ridge.front() - Vector3(0.07, 0, 0), ridge.back() + Vector3(0.07, 0, 0), 0.045, wood)
	var roots: Vector2 = TERRAIN.GARDEN_BEDS[2][0]
	for i in 4:
		var x := (i - 1.5) * 18
		var at := roots + Vector2(x, -13)
		var foot := TERRAIN.world_at(at)
		add_timber(parent, foot - Vector3.UP * 0.045, foot + Vector3.UP * 0.35, 0.020, wood)
		add_plant(parent, textures[3], at + Vector2(0, 3), 0.31)
		add_plant(parent, textures[2], roots + Vector2(x, 2), 0.16)
		add_plant(parent, textures[1], roots + Vector2(x, 13), 0.14)

static func add_plant(parent: Node3D, texture: Texture2D, at: Vector2, height: float) -> void:
	var plant := Sprite3D.new()
	plant.texture = texture
	plant.pixel_size = height / texture.get_height()
	plant.offset.y = texture.get_height() * 0.5
	plant.shaded = true
	plant.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	plant.alpha_scissor_threshold = 0.46
	plant.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	plant.rotation_degrees.x = -12.0
	parent.add_child(plant)
	plant.position = TERRAIN.world_at(at) - Vector3.UP * 0.024

static func add_timber(parent: Node3D, from: Vector3, to: Vector3, thickness: float, wood: Material) -> void:
	var timber := BoxMesh.new()
	timber.size = Vector3(thickness, thickness, from.distance_to(to))
	timber.material = wood
	var instance := MeshInstance3D.new()
	instance.mesh = timber
	parent.add_child(instance)
	instance.position = (from + to) * 0.5
	var axis := from.direction_to(to)
	instance.look_at(to, Vector3.RIGHT if absf(axis.dot(Vector3.UP)) > 0.95 else Vector3.UP)

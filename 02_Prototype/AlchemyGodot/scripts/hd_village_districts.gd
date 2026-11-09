extends RefCounted

const ZONES := {
	"AlchemyGarden": [
		["Cottage", Vector2(327, 230), 2.12], ["HerbRack", Vector2(159, 233), 0.82],
		["HerbBed", Vector2(179, 274), 0.39], ["HerbBed", Vector2(214, 284), 0.39],
		["HerbBed", Vector2(250, 282), 0.42], ["Planter", Vector2(304, 244), 0.38],
		["Planter", Vector2(281, 248), 0.34], ["Barrel", Vector2(253, 232), 0.41],
		["Fence", Vector2(145, 284), 0.39], ["Fence", Vector2(187, 306), 0.39],
		["Fence", Vector2(232, 302), 0.39], ["Fence", Vector2(409, 230), 0.42],
		["HerbBed", Vector2(449, 221), 0.36], ["Planter", Vector2(455, 238), 0.31],
		["Oak", Vector2(244, 138), 1.58], ["Bush", Vector2(193, 194), 0.43],
	],
	"WarehouseYard": [
		["Warehouse", Vector2(754, 184), 2.4], ["Cart", Vector2(810, 178), 0.47],
		["Crates", Vector2(718, 166), 0.37], ["Crates", Vector2(680, 169), 0.32],
		["Barrel", Vector2(803, 190), 0.33], ["Barrel", Vector2(836, 190), 0.36],
		["Lantern", Vector2(704, 177), 0.78], ["Fence", Vector2(667, 174), 0.39],
		["Fence", Vector2(625, 154), 0.40], ["Oak", Vector2(658, 107), 1.4],
	],
	"WorkshopYard": [
		["Workshop", Vector2(960, 275), 1.8], ["Crates", Vector2(861, 251), 0.38],
		["Barrel", Vector2(885, 264), 0.33], ["Crates", Vector2(1017, 276), 0.34],
		["Fence", Vector2(1013, 305), 0.39], ["Fence", Vector2(1057, 302), 0.38],
		["Lantern", Vector2(1037, 289), 0.96], ["Planter", Vector2(1067, 282), 0.35],
	],
	"WellSquare": [
		["Well", Vector2(576, 328), 0.99], ["Planter", Vector2(656, 280), 0.34],
		["Planter", Vector2(526, 331), 0.35], ["Planter", Vector2(622, 334), 0.31],
	],
	"LanternRest": [
		["Bench", Vector2(746, 365), 0.43], ["Lantern", Vector2(775, 346), 0.95],
		["Planter", Vector2(720, 376), 0.34], ["Planter", Vector2(749, 353), 0.32],
		["Bush", Vector2(783, 344), 0.34],
	],
	"FogGateApproach": [
		["FogGate", Vector2(1162, 309), 1.12], ["Lantern", Vector2(1110, 297), 0.84],
		["RuneStone", Vector2(1231, 354), 1.0], ["Oak", Vector2(1213, 194), 1.7],
		["Oak", Vector2(1282, 260), 1.43], ["Fence", Vector2(1210, 462), 0.42],
		["Fence", Vector2(1257, 480), 0.42], ["Bush", Vector2(1224, 328), 0.4],
	],
	"SouthHomes": [
		["House", Vector2(505, 503), 1.39], ["House", Vector2(1012, 565), 1.58],
		["House", Vector2(1185, 659), 1.4], ["House", Vector2(860, 732), 1.44],
		["Oak", Vector2(883, 476), 1.50], ["Oak", Vector2(818, 629), 1.56],
		["Oak", Vector2(1263, 671), 1.48], ["Bush", Vector2(907, 409), 0.58],
		["Fence", Vector2(609, 436), 0.40], ["Fence", Vector2(565, 449), 0.43],
		["Planter", Vector2(570, 466), 0.31], ["Barrel", Vector2(547, 512), 0.32],
		["HerbBed", Vector2(933, 482), 0.43], ["Fence", Vector2(965, 511), 0.4],
		["Planter", Vector2(983, 537), 0.34], ["Barrel", Vector2(1049, 581), 0.35],
		["Fence", Vector2(1067, 589), 0.39], ["Planter", Vector2(1150, 610), 0.36],
		["Crates", Vector2(1215, 660), 0.41], ["Bush", Vector2(1223, 692), 0.44],
		["HerbBed", Vector2(923, 654), 0.41], ["Barrel", Vector2(864, 671), 0.39],
	],
	"TreeLine": [
		["House", Vector2(478, 59), 1.52], ["Oak", Vector2(421, 89), 1.6],
		["Oak", Vector2(1100, 130), 1.75], ["Oak", Vector2(78, 280), 1.36],
		["Oak", Vector2(61, 120), 1.72], ["Bush", Vector2(1027, 119), 0.47],
	],
}

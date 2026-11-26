extends RefCounted
# V2.0 技能池。魔法弹是独立普通攻击，不在这里、也不进入升级卡池。
# range_units / radius_units 使用设计单位，速度使用世界像素/秒。1 设计单位 = 64 世界像素。

const ATTRIBUTE_STARFIRE := "星火"
const ATTRIBUTE_TIDE := "潮汐"
const ATTRIBUTE_CRYSTAL_CORE := "晶核"
const ATTRIBUTE_AETHER := "以太"

const ELEMENT_NONE := &"none"
# 旧联动脚本尚由场景装配；V2 固定连锁不使用这些标签，保留常量以兼容旧存档与界面。
const ELEMENT_FIRE := &"fire"
const ELEMENT_ICE := &"ice"
const ELEMENT_THUNDER := &"thunder"
const ELEMENT_WIND := &"wind"
const ELEMENT_POISON := &"poison"
const BEHAVIOR_BOTTLE := &"bottle"
const BEHAVIOR_MARK := &"mark"
const BEHAVIOR_BOUNCE := &"bounce"
const BEHAVIOR_PULL := &"pull"
const BEHAVIOR_POOL := &"pool"
const BEHAVIOR_MIST := &"mist"
const BEHAVIOR_CRYSTAL := &"crystal"
const BEHAVIOR_BLADE := &"blade"
const BEHAVIOR_GEL := &"gel"
const BEHAVIOR_NEEDLE := &"needle"
const BEHAVIOR_THUNDER_SALT := &"thunder_salt"
const BEHAVIOR_FIRE_OIL := &"fire_oil"
const BEHAVIOR_MERCURY_RING := &"mercury_ring"
const BEHAVIOR_FROST_POWDER := &"frost_powder"
const BEHAVIOR_WIND_FLASK := &"wind_flask"
const BEHAVIOR_FEATHER_DRAUGHT := &"feather_draught"
const BEHAVIOR_WIND_BOOTS := &"wind_boots"
const BEHAVIOR_RETURN_WIND_POWDER := &"return_wind_powder"
const BEHAVIOR_RENEWAL_FLASK := &"renewal_flask"
const BEHAVIOR_DEW_TONIC := &"dew_tonic"
# 旧 UI/兼容脚本的行为名，不进入 V2 数据池。
const BEHAVIOR_PROJECTILE := &"projectile"
const BEHAVIOR_BLAST := &"blast"
const BEHAVIOR_LINE := &"line"
const BEHAVIOR_INSTANT := &"instant"
const BEHAVIOR_BOOMERANG := &"boomerang"
const BEHAVIOR_ORBIT := &"orbit"
const BEHAVIOR_ZONE := &"zone"
const BEHAVIOR_AOE := &"aoe"
const BEHAVIOR_BEAM := &"beam"
const BEHAVIOR_SPIKE := &"spike"
const UNIT := 64.0

const ROWS := [
	{"id":"sk_blast_flask", "name":"爆裂药瓶", "attribute":ATTRIBUTE_STARFIRE, "behavior":BEHAVIOR_BOTTLE, "color":Color("e65b37"), "base_damage":28.0, "power":[1.0,1.2,1.2,1.5,1.75], "cooldowns":[2.8,2.8,2.8,2.8,2.5], "radius_units":[1.5,1.5,1.75,1.75,1.9], "range_units":[6.0,6.0,6.5,6.5,7.0], "speed":310.0},
	{"id":"sk_brittle_mark", "name":"脆化刻印", "attribute":ATTRIBUTE_STARFIRE, "behavior":BEHAVIOR_MARK, "color":Color("e6a34f"), "base_damage":20.0, "power":[.9,1.05,1.2,1.35,1.5], "cooldowns":[3.4,3.4,3.2,3.2,3.0], "range_units":[6.0,6.0,6.5,6.5,7.0], "duration":2.5},
	{"id":"sk_mithril_drop", "name":"秘银液滴", "attribute":ATTRIBUTE_TIDE, "behavior":BEHAVIOR_BOUNCE, "color":Color("c4d3d8"), "base_damage":24.0, "power":[.55,.64,.74,.84,.95], "cooldowns":[1.9,1.9,1.9,1.8,1.7], "targets":[3,3,4,4,5], "bounce_units":[3.2,3.2,3.5,3.5,3.8], "range_units":[6.0,6.0,6.5,6.5,7.0], "speed":470.0},
	{"id":"sk_gravity_stone", "name":"引力石", "attribute":ATTRIBUTE_TIDE, "behavior":BEHAVIOR_PULL, "color":Color("6d416f"), "base_damage":23.0, "power":[.30,.36,.42,.48,.55], "cooldowns":[5.0,5.0,5.0,5.0,4.6], "radius_units":[2.2,2.2,2.4,2.4,2.6], "duration":[2.4,2.4,2.6,2.6,2.8], "range_units":[6.0,6.0,6.4,6.4,6.8], "speed":360.0},
	{"id":"sk_corrosive_flask", "name":"蚀骨药剂", "attribute":ATTRIBUTE_TIDE, "behavior":BEHAVIOR_POOL, "color":Color("4f9d47"), "base_damage":20.0, "power":[.18,.21,.24,.28,.32], "cooldowns":[3.8,3.8,3.8,3.8,3.5], "radius_units":[1.6,1.6,1.8,1.8,2.0], "duration":[3.0,3.0,3.0,3.5,3.5], "ticks":[6,6,6,7,7], "range_units":[6.0,6.0,6.4,6.4,6.8], "speed":330.0},
	{"id":"sk_mist_flask", "name":"迷雾瓶", "attribute":ATTRIBUTE_TIDE, "behavior":BEHAVIOR_MIST, "color":Color("b797c8"), "base_damage":18.0, "power":[.10,.12,.14,.16,.18], "cooldowns":[5.0,5.0,5.0,5.0,4.8], "radius_units":[2.2,2.2,2.4,2.4,2.6], "duration":[4.0,4.0,4.0,4.5,4.5], "ticks":[8,8,8,9,9], "slow":[.30,.30,.30,.30,.35], "range_units":[6.0,6.0,6.5,6.5,7.0], "speed":310.0},
	{"id":"sk_crystal_growth", "name":"晶簇", "attribute":ATTRIBUTE_CRYSTAL_CORE, "behavior":BEHAVIOR_CRYSTAL, "color":Color("b9eaff"), "base_damage":25.0, "power":[.9,1.05,1.2,1.4,1.6], "cooldowns":[2.5,2.5,2.5,2.3,2.2], "count":[5,5,6,6,7], "range_units":[6.0,6.0,7.1,7.1,8.2], "step_delay":.06},
	{"id":"sk_obsidian_blade", "name":"黑曜飞刃", "attribute":ATTRIBUTE_CRYSTAL_CORE, "behavior":BEHAVIOR_BLADE, "color":Color("5b315f"), "base_damage":24.0, "power":[.72,.84,.96,1.10,1.25], "cooldowns":[2.0,2.0,2.0,1.9,1.8], "targets":[3,3,4,4,5], "range_units":[7.0,7.0,7.5,7.5,8.2], "speed":1024.0},
	{"id":"sk_spirit_gel", "name":"灵胶", "attribute":ATTRIBUTE_AETHER, "behavior":BEHAVIOR_GEL, "color":Color("e4a93f"), "base_damage":24.0, "power":[.5,.6,.7,.8,.9], "cooldowns":[1.9,1.9,1.9,1.9,1.7], "slow":[.30,.30,.30,.30,.35], "slow_duration":[2.0,2.0,2.5,2.5,3.0], "range_units":[6.0,6.0,6.5,6.5,7.0], "speed":430.0},
	{"id":"sk_soul_needle", "name":"魂针", "attribute":ATTRIBUTE_AETHER, "behavior":BEHAVIOR_NEEDLE, "color":Color("9eefff"), "base_damage":22.0, "power":[.22,.26,.26,.31,.34], "cooldowns":[1.3,1.3,1.3,1.3,1.2], "count":[3,3,4,4,4], "interval":.12, "range_units":[7.0,7.0,7.5,7.5,8.2], "speed":1180.0},
	{
		"id": "sk_thunder_salt", "name": "雷盐", "category": "进攻", "attribute": ATTRIBUTE_STARFIRE, "behavior": BEHAVIOR_THUNDER_SALT,
		"description": "抛出雷盐，引下一道雷重击单个敌人。优先攻击精英和首领。",
		"color": Color("ffc965"), "base_damage": 1.0, "power": [42.0, 48.0, 55.0, 63.0, 72.0],
		"cooldowns": [4.0, 4.0, 3.8, 3.8, 3.5], "range_units": 6.0, "flight_time": .32, "flight_height": 42.0,
	},
	{
		"id": "sk_fire_oil", "name": "火油", "category": "进攻", "attribute": ATTRIBUTE_STARFIRE, "behavior": BEHAVIOR_FIRE_OIL,
		"description": "附近有敌人时，移动会在身后留下一段燃烧的油迹。油迹持续灼烧踩入的敌人。",
		"color": Color("ff834a"), "base_damage": 1.0, "power": [8.0, 9.0, 10.0, 11.0, 13.0],
		"cooldowns": [5.0, 5.0, 4.8, 4.8, 4.5], "range_units": 4.0, "radius_units": .75, "lay_time": 1.15,
		"spacing": 28.0, "duration": 1.8, "tick_interval": .45,
	},
	{
		"id": "sk_mercury_ring", "name": "水银环", "category": "进攻", "attribute": ATTRIBUTE_TIDE, "behavior": BEHAVIOR_MERCURY_RING,
		"description": "敌人靠近时，从脚下扩散一道水银环，每道环对每个敌人造成一次伤害。",
		"color": Color("c6e6ec"), "base_damage": 1.0, "power": [26.0, 30.0, 34.0, 39.0, 45.0],
		"cooldowns": [3.4, 3.4, 3.2, 3.2, 3.0], "range_units": 2.4, "radius_units": 2.4, "speed": 448.0,
	},
	{
		"id": "sk_frost_powder", "name": "霜粉", "category": "控制", "attribute": ATTRIBUTE_CRYSTAL_CORE, "behavior": BEHAVIOR_FROST_POWDER,
		"description": "朝最近的普通怪撒出霜粉，短暂冻住落点附近的普通怪。",
		"color": Color("a9e8ff"), "base_damage": 0.0, "power": [0.0, 0.0, 0.0, 0.0, 0.0],
		"cooldowns": [5.4, 5.4, 5.2, 5.2, 4.8], "range_units": 6.0, "radius_units": 1.4, "speed": 720.0,
		"duration": [.85, 1.0, 1.05, 1.15, 1.25], "flight_height": 24.0,
	},
	{
		"id": "sk_wind_flask", "name": "风压瓶", "category": "控制", "attribute": ATTRIBUTE_TIDE, "behavior": BEHAVIOR_WIND_FLASK,
		"description": "朝近处敌人密集的方向放出压缩风，将扇形范围内的敌人推开。对首领无效。",
		"color": Color("b1ead0"), "base_damage": 0.0, "power": [0.0, 0.0, 0.0, 0.0, 0.0],
		"cooldowns": [5.8, 5.8, 5.6, 5.6, 5.2], "range_units": 2.8, "half_angle_degrees": 35.0, "push_units": [.9, 1.0, 1.05, 1.15, 1.25],
	},
	{
		"id": "sk_feather_draught", "name": "轻羽药", "category": "机动", "attribute": ATTRIBUTE_AETHER, "behavior": BEHAVIOR_FEATHER_DRAUGHT,
		"description": "持续移动一段时间后自动生效，短时间提高跑速。",
		"color": Color("f7db86"), "base_damage": 0.0, "power": [0.0, 0.0, 0.0, 0.0, 0.0],
		"cooldowns": [7.0, 7.0, 6.7, 6.7, 6.2], "charge_time": 1.0, "duration": 2.0, "speed_bonus": [.25, .28, .31, .34, .38],
	},
	{
		"id": "sk_wind_boots", "name": "风纹靴", "category": "机动", "attribute": ATTRIBUTE_CRYSTAL_CORE, "behavior": BEHAVIOR_WIND_BOOTS,
		"description": "技能就绪时，下一次普通闪避会移动得更远。",
		"color": Color("bdebef"), "base_damage": 0.0, "power": [0.0, 0.0, 0.0, 0.0, 0.0],
		"cooldowns": [5.5, 5.5, 5.2, 5.2, 4.8], "dodge_bonus": [.30, .34, .38, .42, .48],
	},
	{
		"id": "sk_return_wind_powder", "name": "回风粉", "category": "机动", "attribute": ATTRIBUTE_TIDE, "behavior": BEHAVIOR_RETURN_WIND_POWDER,
		"description": "第一次闪避结束后短时间内再按空格，可朝当前移动方向再闪一次。",
		"color": Color("d1d1ff"), "base_damage": 0.0, "power": [0.0, 0.0, 0.0, 0.0, 0.0],
		"cooldowns": [9.0, 9.0, 8.5, 8.5, 8.0], "window": [.35, .38, .41, .44, .48],
	},
	{
		"id": "sk_renewal_flask", "name": "回春瓶", "category": "回复", "attribute": ATTRIBUTE_AETHER, "behavior": BEHAVIOR_RENEWAL_FLASK,
		"description": "生命未满时在自己脚下生成固定的回复池，留在池内可持续回血。",
		"color": Color("a4eba1"), "base_damage": 0.0, "power": [0.0, 0.0, 0.0, 0.0, 0.0],
		"cooldowns": [12.0, 12.0, 11.5, 11.5, 11.0], "radius_units": 1.25, "duration": 3.0, "tick_interval": .5, "heal": [2.0, 2.5, 3.0, 3.5, 4.0],
	},
	{
		"id": "sk_dew_tonic", "name": "甘露剂", "category": "回复", "attribute": ATTRIBUTE_AETHER, "behavior": BEHAVIOR_DEW_TONIC,
		"description": "缺血且附近有敌人时，持续移动且未受击可回复生命。受击会打断蓄积。",
		"color": Color("f3cd84"), "base_damage": 0.0, "power": [0.0, 0.0, 0.0, 0.0, 0.0],
		"cooldowns": [9.0, 9.0, 8.5, 8.5, 8.0], "charge_time": 2.0, "range_units": 6.0, "heal": [8.0, 9.0, 10.0, 11.0, 12.0],
	},
]

const CHAINS := [
	{"id":"link_blast_mark", "name":"爆裂刻印", "parents":["sk_blast_flask","sk_brittle_mark"], "carrier":"sk_brittle_mark", "cooldown":6.0, "radius":150.0, "targets":3, "damage_ratio":.65, "speed":850.0, "color":Color("ed853e")},
	{"id":"link_mithril_orbit", "name":"秘银星环", "parents":["sk_mithril_drop","sk_gravity_stone"], "carrier":"sk_gravity_stone", "cooldown":8.0, "color":Color("d9edf2")},
	{"id":"link_corrosive_mist", "name":"蚀骨毒雾", "parents":["sk_corrosive_flask","sk_mist_flask"], "carrier":"sk_mist_flask", "cooldown":8.0, "color":Color("a4b450")},
	{"id":"link_crystal_shatter_blade", "name":"晶裂飞刃", "parents":["sk_crystal_growth","sk_obsidian_blade"], "carrier":"sk_obsidian_blade", "cooldown":5.0, "color":Color("b9eaff")},
	{"id":"link_soulbound_needle", "name":"噬魂针", "parents":["sk_spirit_gel","sk_soul_needle"], "carrier":"sk_soul_needle", "cooldown":4.0, "color":Color("91e7ef")},
]

static func by_id(id: StringName) -> Dictionary:
	for row in ROWS:
		if StringName(row.id) == id:
			return row
	return {}

static func ids() -> Array[String]:
	var result: Array[String] = []
	for row in ROWS:
		result.append(row.id)
	return result

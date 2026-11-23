extends SceneTree
# 可用 `godot --headless --path . --script res://tests/v2_skill_data_smoke.gd` 执行。
const SKILLS := preload("res://data/skills/skill_data.gd")

func _init() -> void:
	assert(SKILLS.ROWS.size() == 10, "V2 只应有十个可装备基础技能")
	assert(not SKILLS.ids().has("magic_bolt"), "魔法弹必须留在独立普通攻击")
	assert(SKILLS.CHAINS.size() == 5, "V2 应有五组固定连锁")
	for row in SKILLS.ROWS:
		assert((row.power as Array).size() == 5, "%s 的伤害等级表不完整" % row.id)
		assert((row.cooldowns as Array).size() == 5, "%s 的冷却等级表不完整" % row.id)
	var ids := SKILLS.ids()
	for chain in SKILLS.CHAINS:
		assert(ids.has(chain.parents[0]) and ids.has(chain.parents[1]), "%s 的父技能不存在" % chain.id)
		assert(float(chain.cooldown) > 0.0, "%s 缺少独立冷却" % chain.id)
	print("V2_SKILL_DATA_SMOKE_PASS")
	quit()

extends SceneTree
# 可用 `godot --headless --path . --script res://tests/v2_skill_data_smoke.gd` 执行。
const SKILLS := preload("res://data/skills/skill_data.gd")

func _init() -> void:
	assert(SKILLS.ROWS.size() == 20, "扩展后应有二十个可装备基础技能")
	assert(not SKILLS.ids().has("magic_bolt"), "魔法弹必须留在独立普通攻击")
	assert(SKILLS.CHAINS.size() == 5, "V2 应有五组固定连锁")
	var attribute_counts := {}
	for row in SKILLS.ROWS:
		assert((row.power as Array).size() == 5, "%s 的伤害等级表不完整" % row.id)
		assert((row.cooldowns as Array).size() == 5, "%s 的冷却等级表不完整" % row.id)
		attribute_counts[row.attribute] = int(attribute_counts.get(row.attribute, 0)) + 1
	assert(attribute_counts == {"星火": 4, "潮汐": 7, "晶核": 4, "以太": 5})
	var ids := SKILLS.ids()
	assert(ids.has("sk_brittle_mark") and not ids.has("sk_clay_homunculus"), "脆化刻印应替代炼金魔偶奖励")
	var blast_mark: Array = SKILLS.CHAINS.filter(func(chain: Dictionary) -> bool: return chain.id == "link_blast_mark")
	assert(blast_mark.size() == 1 and blast_mark[0].parents == ["sk_blast_flask", "sk_brittle_mark"],
		"爆裂刻印只由两项新配方父技能激活")
	for chain in SKILLS.CHAINS:
		assert(ids.has(chain.parents[0]) and ids.has(chain.parents[1]), "%s 的父技能不存在" % chain.id)
		assert(SKILLS.by_id(chain.parents[0]).attribute == SKILLS.by_id(chain.parents[1]).attribute,
			"%s 的两项基础技能应有相同属性" % chain.id)
		assert(float(chain.cooldown) > 0.0, "%s 缺少独立冷却" % chain.id)
	_check_upgrade_pool()
	print("V2_SKILL_DATA_SMOKE_PASS")
	quit()

func _check_upgrade_pool() -> void:
	var skills := SkillManager.new()
	skills.setup(&"burst", null)
	var upgrades := UpgradeManager.new()
	upgrades.setup(skills)
	var pool := upgrades._build_pool()
	assert(pool.size() == 20, "开局候选应恰好有二十项，携带炼金能力也一样")
	for pick: Dictionary in pool:
		assert(pick.type == UpgradeManager.CAT_NEW_SKILL and SKILLS.ids().has(pick.skill_id))
		assert(pick.attribute == SKILLS.by_id(pick.skill_id).attribute)
	assert(upgrades.roll_candidates().size() == 3)

	for chain: Dictionary in SKILLS.CHAINS:
		skills.clear()
		skills.max_skill_slots = 2
		upgrades.apply({"type":"new_skill", "skill_id":chain.parents[0]})
		assert(skills.unlocked_chains().is_empty())
		var partner_cards: Array = upgrades._build_pool().filter(
			func(pick: Dictionary) -> bool: return pick.skill_id == chain.parents[1])
		assert(partner_cards.size() == 1 and String(partner_cards[0].desc).contains(chain.name))
		upgrades.apply(partner_cards[0])
		assert(skills.runtimes.size() == 2 and skills.runtime_for(StringName(chain.id)) == null)
		assert(skills.unlocked_chains().size() == 1 and skills.unlocked_chains()[0].id == chain.id)
		assert(not skills.add_skill(StringName(chain.id)))
		for pick: Dictionary in upgrades._build_pool():
			assert(pick.type == UpgradeManager.CAT_SKILL_UPGRADE and chain.parents.has(String(pick.skill_id)))
			assert(pick.attribute == SKILLS.by_id(pick.skill_id).attribute)

		var parent := skills.runtime_for(StringName(chain.parents[0]))
		for i in 6:
			upgrades.apply({"type":"skill_upgrade", "skill_id":chain.parents[0]})
		assert(parent.level == 5 and skills.unlocked_chains().size() == 1)
	skills.clear()
	assert(skills.unlocked_chains().is_empty())
	skills.max_skill_slots = 6
	upgrades.apply({"type":"new_skill", "skill_id":SKILLS.CHAINS[0].id})
	assert(skills.runtimes.is_empty(), "有空槽也不能从奖励直接获得组合技能")

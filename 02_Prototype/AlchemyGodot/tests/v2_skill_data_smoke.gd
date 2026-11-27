extends SceneTree
# 可用 `godot --headless --path . --script res://tests/v2_skill_data_smoke.gd` 执行。
const SKILLS := preload("res://data/skills/skill_data.gd")

func _init() -> void:
	assert(SKILLS.ROWS.size() == 20, "扩展后应有二十个可装备基础技能")
	assert(not SKILLS.ids().has("magic_bolt"), "魔法弹必须留在独立普通攻击")
	assert(SKILLS.CHAINS.size() == 9, "应当有九组新固定配方")
	var expected := ["熔火炉", "雷衣", "回浪镜", "回流锚", "净路剂", "晶门", "寒晶墙", "照影", "收露瓶"]
	assert(SKILLS.CHAINS.map(func(recipe: Dictionary) -> String: return recipe.name) == expected)
	var attribute_counts := {}
	for row in SKILLS.ROWS:
		var values: Array = row.vulnerability if row.behavior == SKILLS.BEHAVIOR_MARK else row.power
		assert(values.size() == 5, "%s 的效果等级表不完整" % row.id)
		assert((row.cooldowns as Array).size() == 5, "%s 的冷却等级表不完整" % row.id)
		attribute_counts[row.attribute] = int(attribute_counts.get(row.attribute, 0)) + 1
	assert(attribute_counts == {"星火": 4, "潮汐": 7, "晶核": 4, "以太": 5})
	var ids := SKILLS.ids()
	assert(ids.has("sk_brittle_mark") and not ids.has("sk_clay_homunculus"), "脆化刻印应替代炼金魔偶奖励")
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

	var paired := {}
	for chain: Dictionary in SKILLS.CHAINS:
		skills.clear()
		var parents: Array = chain.parents
		for parent_id: String in parents:
			assert(not paired.has(parent_id))
			assert(SKILLS.by_id(parent_id).attribute == chain.attribute)
			paired[parent_id] = chain.id
		assert(not skills.add_skill(chain.id))
		assert(skills.add_skill(StringName(parents[0])) and skills.unlocked_chains().is_empty())
		var partner_cards := upgrades._build_pool().filter(
			func(pick: Dictionary) -> bool: return pick.skill_id == parents[1])
		assert(partner_cards.size() == 1 and String(partner_cards[0].desc).contains(chain.name))
		upgrades.apply(partner_cards[0])
		assert(skills.runtimes.size() == 2 and skills.unlocked_chains() == [chain])
		assert(skills.combo_rules.ready(chain.id))
		var first := skills.runtime_for(StringName(parents[0]))
		var second := skills.runtime_for(StringName(parents[1]))
		first.level = 5
		second.level = 3
		assert(is_equal_approx(skills.combo_rules.commit(chain.id), 1.36))
		assert(float(skills.chain_cooldowns.get(chain.id)) == chain.cooldown)
		assert(skills.combo_rules.commit(chain.id) == 0.0)
	assert(paired.size() == 18 and not paired.has("sk_mist_flask") and not paired.has("sk_spirit_gel"))

	var retired := {
		"link_blast_mark": ["sk_blast_flask", "sk_brittle_mark"],
		"link_mithril_orbit": ["sk_mithril_drop", "sk_gravity_stone"],
		"link_corrosive_mist": ["sk_corrosive_flask", "sk_mist_flask"],
		"link_crystal_shatter_blade": ["sk_crystal_growth", "sk_obsidian_blade"],
		"link_soulbound_needle": ["sk_spirit_gel", "sk_soul_needle"],
	}
	for combo_id: String in retired:
		skills.clear()
		skills.max_skill_slots = 2
		var parents: Array = retired[combo_id]
		assert(SKILLS.by_id(parents[0]).attribute == SKILLS.by_id(parents[1]).attribute)
		upgrades.apply({"type":"new_skill", "skill_id":parents[0]})
		var partner_cards := upgrades._build_pool().filter(
			func(pick: Dictionary) -> bool: return pick.skill_id == parents[1])
		assert(partner_cards.size() == 1 and not String(partner_cards[0].desc).contains("自动解锁组合"))
		upgrades.apply(partner_cards[0])
		assert(skills.runtimes.size() == 2 and skills.unlocked_chains().is_empty())
		for pick: Dictionary in upgrades._build_pool():
			assert(pick.type == UpgradeManager.CAT_SKILL_UPGRADE and parents.has(String(pick.skill_id)))
			assert(pick.attribute == SKILLS.by_id(pick.skill_id).attribute)
		var parent := skills.runtime_for(StringName(parents[0]))
		for _index in 6:
			upgrades.apply({"type":"skill_upgrade", "skill_id":parents[0]})
		assert(parent.level == 5)
		skills.clear()
		assert(not skills.add_skill(StringName(combo_id)), "空技能栏也不能直接获得旧组合")

extends SceneTree

const Catalog = preload("res://scripts/levels/level_catalog.gd")
const Entry = preload("res://scripts/levels/level_entry.gd")
const Generator = preload("res://scripts/level_layout.gd")
const CatalogDock = preload("res://addons/level_layout/catalog_dock.gd")
const OUTPUT := "res://Evidence/LevelCatalogShortcuts_20261124/catalog_temp/"
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var catalog := load("res://levels/catalog.tres") as Catalog
	check(catalog != null, "总表可以读取")
	if catalog == null:
		quit(1)
		return
	check(catalog.validation_errors().is_empty(), "现行总表校验通过：%s" % catalog.validation_errors())
	check(catalog.entries.size() == 3, "只登记村庄、首关、Boss 三个实际关卡")
	check(catalog.selectable_levels().size() == 1, "仅首关可从村庄选择")
	check(catalog.selectable_levels()[0].level_id == &"greyford_01", "首关稳定 ID")
	check(catalog.find_level(&"does_not_exist") == null, "未知 ID 不回退成其他关卡")
	for entry in catalog.entries:
		var packed := load(entry.scene_path) as PackedScene
		check(packed != null, "独立场景可加载：" + entry.scene_path)
		if packed == null:
			continue
		var instance := packed.instantiate()
		check(instance.scene_file_path == entry.scene_path, "各关卡具有独立的场景资源路径")
		check(instance.level_id == entry.level_id, "场景与登记 ID 一致：" + String(entry.level_id))
		check(instance.has_node("EntrySpawn"), "独立出生点：" + String(entry.level_id))
		check(instance.get_node("EntrySpawn").position == entry.spawn_position, "出生点默认位置一致")
		check(instance.has_node("Actors/Lilita"), "各场景含实际玩家")
		if entry.kind != Entry.Kind.VILLAGE:
			check(instance.layout_preset == entry.layout, "各战斗场景引用各自的随机配置")
			check(instance.enemy_config == entry.enemy_config, "各战斗场景引用各自的怪物表")
			check(instance.stage_is_boss == (entry.kind == Entry.Kind.BOSS), "Boss 模式只由 Boss 场景启用")
			check(instance.has_node("Interface/CombatHUD"), "独立战斗场景包含 HUD")
			var layout: Dictionary = Generator.build(entry.layout, 77, Rect2(0, 0, 1280, 720), entry.spawn_position)
			check(layout.error.is_empty(), "关卡自身随机配置可生成：" + layout.error)
		instance.free()
	var source := catalog.find_level(&"greyford_01")
	var bad: Catalog = catalog.duplicate(true)
	bad.entries.append(bad.entries[1].duplicate(true))
	check(not bad.validation_errors().is_empty(), "重复 ID 被拒绝")
	bad = catalog.duplicate(true)
	bad.find_level(&"greyford_01_boss").scene_path = bad.find_level(&"greyford_01").scene_path
	check(not bad.validation_errors().is_empty(), "不同关卡必须使用独立场景文件")
	bad = catalog.duplicate(true)
	bad.find_level(&"greyford_01").scene_path = "res://missing_level.tscn"
	check(not bad.validation_errors().is_empty(), "丢失场景被拒绝")
	bad = catalog.duplicate(true)
	bad.find_level(&"greyford_01").boss_level_id = &"village_greyford"
	check(not bad.validation_errors().is_empty(), "错误 Boss 类型链接被拒绝")
	bad = catalog.duplicate(true)
	bad.find_level(&"greyford_01_boss").selectable = true
	check(not bad.validation_errors().is_empty(), "Boss 不直接放进村庄出战列表")
	bad = catalog.duplicate(true)
	bad.find_level(&"greyford_01").spawn_position = Vector2(-500, -500)
	check(not bad.validation_errors().is_empty(), "越界出生点被拒绝")
	bad = catalog.duplicate(true)
	var extra: Entry = source.duplicate(true)
	extra.level_id = &"test_only_second"
	extra.sort_order = source.sort_order - 1
	bad.entries.append(extra)
	check(bad.selectable_levels().size() == 2, "表内新增普通关自动进入选择列表")
	check(bad.selectable_levels()[0].level_id == &"test_only_second", "多关卡按排序值排列")
	extra.enabled = false
	check(bad.selectable_levels().size() == 1, "停用关卡不显示")
	var a := catalog.duplicate_battle_configs(source, false, "配置 A")
	var b := catalog.duplicate_battle_configs(source, true, "配置 B")
	check(a.layout != source.layout and b.layout != a.layout, "新建关卡的随机配置互相独立")
	check(a.waves != source.enemy_config and b.waves != a.waves, "新建关卡的怪物表互相独立")
	check(a.layout.palette[0] != source.layout.palette[0], "地块数量密度素材条目独立复制")
	check(a.waves.rows[0] != source.enemy_config.rows[0], "怪物权重行独立复制")
	check(b.layout.boss and b.waves.opening_count == 0, "新 Boss 不生成首波普通怪")
	check(a.layout.locked_ground.is_empty() and a.layout.locked_props.is_empty(), "预览锁格不复制进新关卡")
	a.layout.preview_seed = 1234
	a.layout.prop_seed_offset = 5
	b.layout.preview_seed = 5678
	b.layout.prop_seed_offset = 9
	a.waves.opening_count = 3
	b.waves.opening_count = 0
	check(source.layout.preview_seed != 1234, "修改新关不改变原关 Seed")
	check(source.enemy_config.opening_count != 3, "修改新关不改变原关首波数量")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for pair in [[a.layout, "a_layout.tres"], [b.layout, "b_layout.tres"], [a.waves, "a_waves.tres"], [b.waves, "b_waves.tres"]]:
		var path: String = OUTPUT + pair[1]
		check(ResourceSaver.save(pair[0], path, ResourceSaver.FLAG_CHANGE_PATH) == OK, "独立配置可保存")
		(pair[0] as Resource).take_over_path(path)
		check(pair[0].resource_path == path, "新资源路径指向独立文件")
	var saved_a = ResourceLoader.load(OUTPUT + "a_layout.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	var saved_b = ResourceLoader.load(OUTPUT + "b_layout.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	var waves_a = ResourceLoader.load(OUTPUT + "a_waves.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	var waves_b = ResourceLoader.load(OUTPUT + "b_waves.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	check(saved_a.preview_seed == 1234 and saved_a.prop_seed_offset == 5, "A 关种子保存后可重读")
	check(saved_b.preview_seed == 5678 and saved_b.prop_seed_offset == 9, "B 关种子保存后可重读")
	check(waves_a.opening_count == 3 and waves_b.opening_count == 0, "不同关首波数量独立持久化")
	var editor := CatalogDock.new()
	editor.catalog = catalog
	editor.current = catalog.find_level(&"greyford_01_boss")
	var normal_template = editor.template_for_kind(Entry.Kind.NORMAL)
	check(normal_template == source, "选中 Boss 新建普通关时使用普通关模板")
	check(normal_template.enemy_config.opening_count > 0, "普通关模板保留非零开局怪物数量")
	editor.current = source
	check(editor.template_for_kind(Entry.Kind.BOSS) == catalog.find_level(&"greyford_01_boss"), "选中普通关新建 Boss 时使用 Boss 模板")
	editor.current = catalog.find_level(&"greyford_01_boss")
	check(editor.template_for_kind(Entry.Kind.BOSS) == editor.current, "同类型新建保留当前选中的模板")
	for is_boss: bool in [false, true]:
		var key := "b" if is_boss else "a"
		var path := OUTPUT + key + "_generated.tscn"
		var generated := FileAccess.open(path, FileAccess.WRITE)
		generated.store_string(editor.build_scene_text("test_" + key, OUTPUT + key + "_layout.tres", OUTPUT + key + "_waves.tres", Vector2(640, 450), is_boss))
		generated.close()
		var packed := load(path) as PackedScene
		check(packed != null, "新建工具产生有效场景文件")
		if packed != null:
			var scene := packed.instantiate()
			check(scene.has_node("Actors/Lilita") and scene.has_node("Interface/CombatHUD"), "新建关卡包含完整玩家和战斗界面")
			check(scene.stage_is_boss == is_boss, "新建普通关和 Boss 场类型一致")
			check(scene.has_node("BossPortal") != is_boss, "普通关才有 Boss 门标记")
			scene.free()
	editor.free()
	var report := {"checks": checks, "failures": failures, "passed": failures.is_empty(), "scope": "catalog, independent scenes, per-level config persistence, generated scene templates; native editor UI verified separately"}
	var output := FileAccess.open(OUTPUT + "../catalog_verification.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
	print("LEVEL_CATALOG_SMOKE %s %d checks" % ["PASS" if failures.is_empty() else "FAIL", checks])
	await process_frame
	quit(0 if failures.is_empty() else 1)

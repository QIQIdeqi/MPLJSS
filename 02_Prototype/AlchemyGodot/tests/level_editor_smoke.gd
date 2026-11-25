@tool
extends SceneTree
## Run only in a separate CLI editor process; never through the user's open editor.

const PluginScript = preload("res://addons/level_layout/plugin.gd")
const OUTPUT := "res://Evidence/FiveRegions_20261124/editor_verification.json"
var checks := 0
var failures: Array[String] = []
var context := {}

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _find_plugin(node: Node) -> Node:
	var script: Script = node.get_script()
	if script != null and script.resource_path == "res://addons/level_layout/plugin.gd":
		return node
	for child in node.get_children():
		var found := _find_plugin(child)
		if found != null:
			return found
	return null

func _write_report(state: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir()))
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	file.store_string(JSON.stringify({"status": state, "checks": checks, "failures": failures, "context": context,
		"scope": "native editor quick-open scenes, visible layout/wave shortcuts, Boss stable-ID selection, cloned live boundary inputs; no production resource saves"}, "\t"))
	file.close()

func _unsupported(reason: String) -> void:
	context.unsupported_reason = reason
	_write_report("unsupported_editor_mainloop")
	print("LEVEL_EDITOR_SMOKE UNSUPPORTED: " + reason)
	quit(2)

func _wait_for_editor_scan() -> bool:
	var filesystem := EditorInterface.get_resource_filesystem()
	var stable := 0
	for attempt in 80:
		await create_timer(0.12).timeout
		stable = 0 if filesystem.is_scanning() else stable + 1
		if stable >= 3:
			return true
	return false

func _wait_for_scene(path: String) -> bool:
	for frame in 60:
		var scene := EditorInterface.get_edited_scene_root()
		if scene != null and scene.scene_file_path == path:
			return true
		await process_frame
	return false

func _run() -> void:
	context.editor_hint = Engine.is_editor_hint()
	context.main_loop = Engine.get_main_loop().get_class()
	if not Engine.is_editor_hint():
		_unsupported("--editor --script did not provide editor context")
		return
	var base := EditorInterface.get_base_control()
	context.editor_base_exists = base != null
	if base == null:
		_unsupported("SceneTree script has no EditorInterface base control")
		return
	var plugin: Node
	for frame in 90:
		plugin = _find_plugin(root)
		if plugin != null and plugin.catalog_dock != null and plugin.catalog_dock.is_node_ready():
			break
		await process_frame
	if plugin == null or plugin.catalog_dock == null or not plugin.catalog_dock.is_node_ready():
		_unsupported("Native EditorNode did not initialize enabled level_layout plugin")
		return
	context.initial_scan_idle = await _wait_for_editor_scan()
	check(context.initial_scan_idle, "编辑器初始文件扫描完成")
	var protected_paths := ["res://levels/catalog.tres", "res://levels/normal.tres", "res://levels/boss.tres", "res://levels/first_level_enemies.tres", "res://levels/greyford_01_boss_enemies.tres"]
	var hashes := {}
	for path: String in protected_paths:
		hashes[path] = FileAccess.get_sha256(path)
	var original_entry: Resource = plugin.current_entry
	var original_scene := EditorInterface.get_edited_scene_root()
	var original_scene_path := original_scene.scene_file_path if original_scene else ""
	var catalog_ui = plugin.catalog_dock
	var catalog: Resource = catalog_ui.catalog
	check(catalog != null and catalog_ui.rows != null, "真实关卡总表已建立原生列表")
	check(catalog_ui.fields.layout is EditorResourcePicker, "随机配置使用原生 EditorResourcePicker")
	check(catalog_ui.fields.enemy_config is EditorResourcePicker, "怪物表使用原生 EditorResourcePicker")
	check(catalog_ui.fields.preview is EditorResourcePicker, "预览图使用原生 EditorResourcePicker")
	for id: StringName in [&"greyford_01", &"greyford_01_boss"]:
		catalog_ui.select_level(id)
		await process_frame
		var entry: Resource = catalog.find_level(id)
		check(catalog_ui.current == entry, "关卡总表选择正确：" + String(id))
		check(plugin.current_entry == entry and plugin.settings == entry.layout, "随机预览跟随当前关卡")
		check(plugin.preview.preset == entry.layout and plugin.preview.spawn == entry.spawn_position, "预览使用当前关卡的范围和出生点")
		check(plugin.enemy_dock.table == entry.enemy_config and plugin.enemy_dock.selected_level_id == String(id), "怪物编辑器跟随当前关卡")
		check(int(plugin.enemy_dock.opening_count.value) == entry.enemy_config.opening_count, "怪物表显示选中关卡的开局数量")
		check(plugin.width_input.editable == not entry.layout.infinite and plugin.height_input.editable == not entry.layout.infinite, "有限场可调宽高，无限场显示标准区块")
		check(catalog_ui.fields.layout.edited_resource == entry.layout, "资源选择器同步选中关卡")
		var expected_index: int = plugin.stage_entries.find(entry)
		check(plugin.stages.selected == expected_index, "Alchemy 关卡下拉选项同步总表")
		check(catalog_ui.rows.get_selected() != null and catalog_ui.rows.get_selected().get_metadata(0) == entry,
			"总表实际高亮行与当前关卡一致")
		check(not catalog_ui.layout_button.disabled and not catalog_ui.waves_button.disabled, "战斗关卡启用两个编辑快捷入口")
		check(catalog_ui.boss_picker.disabled == (entry.kind == 2), "仅普通关可选择关联 Boss")
		if entry.kind == 2:
			check(catalog_ui.boss_button.disabled, "Boss 场自身不提供再打开关联 Boss 的操作")
		plugin.make_bottom_panel_item_visible(catalog_ui)
		await process_frame
		catalog_ui.layout_button.pressed.emit()
		await process_frame
		check(plugin.settings == entry.layout and plugin.current_entry == entry, "地块快捷按钮定位选中关卡的原编辑器")
		check(plugin.dock.is_visible_in_tree() and not catalog_ui.is_visible_in_tree(), "地块快捷按钮切换实际底栏显示")
		plugin.make_bottom_panel_item_visible(catalog_ui)
		await process_frame
		catalog_ui.waves_button.pressed.emit()
		await process_frame
		check(plugin.enemy_dock.table == entry.enemy_config, "怪物快捷按钮定位选中关卡的波次表")
		check(plugin.enemy_dock.is_visible_in_tree() and not catalog_ui.is_visible_in_tree(), "怪物快捷按钮切换实际底栏显示")
	catalog_ui.select_level(&"greyford_01")
	var normal: Resource = catalog.find_level(&"greyford_01")
	check(catalog_ui.boss_picker.get_item_metadata(catalog_ui.boss_picker.selected) == normal.boss_level_id,
		"Boss 下拉显示现有关联的稳定 ID")
	catalog_ui._open_boss_scene()
	check(await _wait_for_scene(catalog.find_level(normal.boss_level_id).scene_path), "打开关联 Boss 进入正确的独立场景")
	var related_boss: Resource = catalog.find_level(normal.boss_level_id)
	check(catalog_ui.current == related_boss and plugin.current_entry == related_boss,
		"打开关联 Boss 同时切换总表和原编辑器当前关卡")
	check(plugin.settings == related_boss.layout and plugin.enemy_dock.table == related_boss.enemy_config,
		"打开关联 Boss 后继续设置会修改 Boss 的独立资源")
	catalog_ui.select_level(normal.level_id)
	catalog_ui._open_scene()
	check(await _wait_for_scene(normal.scene_path), "打开场景进入当前选中普通关")
	catalog_ui.select_level(&"greyford_01_boss")
	catalog_ui.rows.item_activated.emit()
	check(await _wait_for_scene(catalog.find_level(&"greyford_01_boss").scene_path), "总表双击行打开对应 Boss 场景")
	# 库存和关联修改只在总表深拷贝中测试，绝不保存生产配置。
	var fixture: Resource = catalog.duplicate(true)
	var enabled_boss: Resource = fixture.find_level(&"greyford_01_boss").duplicate(true)
	enabled_boss.level_id = &"fixture_enabled_boss"
	fixture.entries.append(enabled_boss)
	var disabled_boss: Resource = enabled_boss.duplicate(true)
	disabled_boss.level_id = &"fixture_disabled_boss"
	disabled_boss.enabled = false
	fixture.entries.append(disabled_boss)
	var fixture_normal: Resource = fixture.find_level(&"greyford_01")
	fixture_normal.boss_level_id = &""
	catalog_ui.catalog = fixture
	catalog_ui.select_level(fixture_normal.level_id)
	var option_ids: Array[StringName] = []
	var enabled_index := -1
	for index in catalog_ui.boss_picker.item_count:
		var id := StringName(catalog_ui.boss_picker.get_item_metadata(index))
		option_ids.append(id)
		if id == enabled_boss.level_id:
			enabled_index = index
		if not id.is_empty():
			var target: Resource = fixture.find_level(id)
			check(target != null and target.enabled and target.kind == 2, "Boss 下拉可选项均为启用的 Boss")
	check(option_ids.has(enabled_boss.level_id) and not option_ids.has(disabled_boss.level_id), "下拉包含启用 Boss 且排除停用 Boss")
	check(not option_ids.has(&"greyford_01") and not option_ids.has(&"village_greyford"), "普通关和村庄不会进入 Boss 下拉")
	if enabled_index >= 0:
		catalog_ui.boss_picker.item_selected.emit(enabled_index)
		check(fixture_normal.boss_level_id == enabled_boss.level_id, "选择 Boss 写入稳定 ID 而非显示文字")
		check(not catalog_ui.boss_button.disabled, "关联有效 Boss 后可快速打开")
	catalog_ui.boss_picker.item_selected.emit(0)
	check(fixture_normal.boss_level_id.is_empty() and catalog_ui.boss_button.disabled, "清除关联后禁用 Boss 快捷入口")
	check(normal.boss_level_id == &"greyford_01_boss", "选择测试未修改实际第一关关联")
	catalog_ui.catalog = catalog
	catalog_ui.select_level(&"village_greyford")
	await process_frame
	check(plugin.settings == null and plugin.preview.preset == null, "村庄清空随机预览")
	check(plugin.enemy_dock.table == null and plugin.enemy_dock.save_button.disabled, "村庄清空怪物表并禁用保存")
	check(not plugin.width_input.editable and not plugin.height_input.editable, "村庄不误改上一战斗关卡范围")
	check(catalog_ui.layout_button.disabled and catalog_ui.waves_button.disabled, "村庄禁用地块和怪物快捷入口")
	check(catalog_ui.boss_picker.disabled and catalog_ui.boss_button.disabled, "村庄禁用 Boss 关联操作")
	var clone: Resource = catalog.find_level(&"greyford_01").duplicate(true)
	clone.layout = catalog.find_level(&"greyford_01").layout.duplicate(true)
	clone.layout.infinite = false
	clone.enemy_config = catalog.find_level(&"greyford_01").enemy_config.duplicate(true)
	plugin._apply_entry(clone)
	var before: Rect2 = clone.layout.playable_bounds()
	var target_width := 1100 if int(before.size.x) != 1100 else 1050
	var target_height := 500 if int(before.size.y) != 500 else 480
	plugin.width_input.value = target_width
	plugin.height_input.value = target_height
	await process_frame
	await process_frame
	check(clone.layout.playable_size == Vector2i(target_width, target_height), "原生宽高输入实时修改独立测试配置")
	check(plugin.preview.preset.playable_bounds().size == Vector2(target_width, target_height), "红线绘制使用的矩形实时更新")
	check(plugin.preview.layout.get("error", "missing").is_empty(), "改范围后重新生成预览成功")
	check(catalog.find_level(&"greyford_01").layout.playable_bounds() == before, "测试宽高未修改实际首关配置")
	if original_entry != null:
		catalog_ui.select_level(original_entry.level_id)
	else:
		catalog_ui.select_level(&"greyford_01")
	if not original_scene_path.is_empty():
		EditorInterface.open_scene_from_path(original_scene_path)
		check(await _wait_for_scene(original_scene_path), "恢复隔离编辑器原先场景")
	plugin.make_bottom_panel_item_visible(catalog_ui)
	for path: String in protected_paths:
		check(FileAccess.get_sha256(path) == hashes[path], "未写入生产资源：" + path)
	context.final_scan_idle = await _wait_for_editor_scan()
	check(context.final_scan_idle, "退出前编辑器文件扫描完成")
	_write_report("passed" if failures.is_empty() else "failed")
	print("LEVEL_EDITOR_SMOKE %s %d checks" % ["PASS" if failures.is_empty() else "FAIL", checks])
	# Waiting for scans avoids aborting a filesystem worker. This CLI --editor -s
	# harness still reports native editor shutdown RIDs; check logs separately.
	await process_frame
	await process_frame
	call_deferred("quit", 0 if failures.is_empty() else 1)

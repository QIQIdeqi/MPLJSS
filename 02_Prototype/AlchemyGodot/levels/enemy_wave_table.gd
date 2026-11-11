@tool
extends Resource
## Wave indices are shared by the time, interval, cap and monster weight columns.

const ENEMY_ROW := preload("res://levels/enemy_spawn_row.gd")

@export var level_name := "第一关"
@export_range(0, 48, 1) var opening_count := 8
@export var start_seconds: PackedFloat32Array
@export var spawn_intervals: PackedFloat32Array
@export var alive_caps: PackedInt32Array
@export var rows: Array[ENEMY_ROW]

func wave_index(seconds: float) -> int:
	var wave := 0
	for i in range(1, start_seconds.size()):
		if seconds >= start_seconds[i]:
			wave = i
	return wave

func interval(wave: int) -> float:
	return maxf(0.25, spawn_intervals[wave]) if wave < spawn_intervals.size() else 2.0

func alive_cap(wave: int) -> int:
	return clampi(alive_caps[wave], 0, 48) if wave < alive_caps.size() else 12

func pick_row(wave: int, roll: float) -> ENEMY_ROW:
	var total := 0.0
	for row in rows:
		total += weight(row, wave)
	if total <= 0.0:
		return null
	var remaining := clampf(roll, 0.0, 0.999999) * total
	for row in rows:
		var chance := weight(row, wave)
		if remaining < chance:
			return row
		remaining -= chance
	return null

func row_for_kind(kind: int) -> ENEMY_ROW:
	for row in rows:
		if row and row.kind == kind and row.atlas:
			return row
	return null

func weight(row: ENEMY_ROW, wave: int) -> float:
	if not row or not row.atlas or wave < 0 or wave >= row.wave_weights.size():
		return 0.0
	return maxf(0.0, row.wave_weights[wave])

func validation_error() -> String:
	var count := start_seconds.size()
	if count == 0 or not is_zero_approx(start_seconds[0]):
		return "第 1 波必须从 0 秒开始"
	if spawn_intervals.size() != count or alive_caps.size() != count:
		return "波次时间、间隔和同屏上限的列数必须一致"
	for i in count:
		if not is_finite(start_seconds[i]) or (i > 0 and start_seconds[i] <= start_seconds[i - 1]):
			return "波次开始时间必须递增"
		if not is_finite(spawn_intervals[i]) or spawn_intervals[i] < 0.25 or alive_caps[i] < 0 or alive_caps[i] > 48:
			return "出怪间隔至少 0.25 秒，同屏上限为 0–48"
	for row in rows:
		if not row or row.display_name.strip_edges().is_empty() or row.kind < 0 or row.kind > 6:
			return "每行都需要有效的怪物名称和行为类型"
		if row.wave_weights.size() != count:
			return "%s 的权重列数与波次不一致" % row.display_name
		for chance in row.wave_weights:
			if not is_finite(chance) or chance < 0.0:
				return "%s 的权重必须是非负数" % row.display_name
			if chance > 0.0 and not row.atlas:
				return "%s 有出场权重，需要指定素材" % row.display_name
		if row.atlas and (row.atlas.get_width() % 4 != 0 or row.atlas.get_height() % 4 != 0):
			return "%s 的素材尺寸需要能切成 4×4 格" % row.display_name
	return ""

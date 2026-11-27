@tool
extends Control
## One shared ruler for independent image/text entrance clips and page exit.
signal edit_started
signal timing_changed(channel: String, start: float, duration: float, final: bool)
signal seek_requested(seconds: float)
var page: Resource
var image_active := true
var text_active := true
var cursor := 0.0
var span := 10.0
var drag_kind := ""
var drag_channel := ""
var drag_x := 0.0
var drag_start := 0.0
var drag_end := 0.0
const LEFT := 92.0
const RIGHT := 22.0
const COLORS := {"image": Color("60cdb4"), "text": Color("9da9ff")}

func _ready() -> void:
	custom_minimum_size.y = 174
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "拖动轨道移动出现时间；拖左右边缘调整起点 / 终点；拖标尺或空白处定位预览。"

func display(value: Resource, seconds: float = 0.0) -> void:
	page = value
	cursor = seconds
	if drag_kind.is_empty():
		span = maxf(5.0, ceilf(entrance_end() + page.hold_seconds + page.exit_duration + 0.5))
	queue_redraw()

func entrance_end() -> float:
	return maxf(page.image_delay + page.image_duration if image_active else 0.0, page.text_delay + page.text_duration if text_active else 0.0) if page != null else 0.0

func time_x(value: float) -> float:
	return LEFT + value / span * maxf(1.0, size.x - LEFT - RIGHT)

func x_time(value: float) -> float:
	return clampf((value - LEFT) / maxf(1.0, size.x - LEFT - RIGHT) * span, 0.0, span)

func clip_rect(channel: String) -> Rect2:
	var start: float = page.get(channel + "_delay")
	var duration: float = page.get(channel + "_duration")
	return Rect2(time_x(start), 44 if channel == "image" else 83, maxf(14, time_x(start + duration) - time_x(start)), 29)

func _draw() -> void:
	draw_style_box(_background(), Rect2(Vector2.ZERO, size))
	if page == null:
		return
	var font := ThemeDB.fallback_font
	var step := maxf(0.5, ceilf(span / maxf(2, (size.x - LEFT) / 75.0) * 2.0) / 2.0)
	var tick := 0.0
	while tick <= span:
		var x := time_x(tick)
		draw_line(Vector2(x, 30), Vector2(x, 119), Color("344252"))
		draw_string(font, Vector2(x - 8, 22), str(tick), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("aab9cc"))
		tick += step
	for channel: String in ["image", "text"]:
		var rect := clip_rect(channel)
		var color: Color = COLORS[channel]
		draw_string(font, Vector2(12, rect.position.y + 20), "图片" if channel == "image" else "文字", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)
		draw_rect(rect, Color(color, 0.22))
		draw_rect(rect, color, false, 1.5)
		draw_rect(Rect2(rect.position, Vector2(5, rect.size.y)), color)
		draw_rect(Rect2(rect.end - Vector2(5, rect.size.y), Vector2(5, rect.size.y)), color)
		var start: float = page.get(channel + "_delay")
		var end: float = start + page.get(channel + "_duration")
		draw_string(font, Vector2(rect.end.x + 8, rect.position.y + 19), "%.2f → %.2f s" % [start, end], HORIZONTAL_ALIGNMENT_LEFT, maxf(0, size.x - rect.end.x - 12), 12, color)
	var entry := entrance_end()
	var exit_start: float = entry + page.hold_seconds
	for part: Array in [[0.0, entry, Color("3b786f"), "入场"], [entry, exit_start, Color("655b39"), "阅读停留"], [exit_start, exit_start + page.exit_duration, Color("6d506c"), "淡出"]]:
		var rect := Rect2(time_x(part[0]), 126, maxf(2, time_x(part[1]) - time_x(part[0])), 22)
		draw_rect(rect, part[2])
		if rect.size.x > 42:
			draw_string(font, rect.position + Vector2(4, 16), part[3], HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 4, 11, Color.WHITE)
	var x := time_x(cursor)
	draw_line(Vector2(x, 27), Vector2(x, 151), Color("ffd48a"), 2)
	draw_colored_polygon(PackedVector2Array([Vector2(x - 6, 27), Vector2(x + 6, 27), Vector2(x, 35)]), Color("ffd48a"))
	draw_string(font, Vector2(12, 166), "拖条移动 · 拖边缘调时长 · 拖标尺预览    |    %.2f s" % cursor, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("aab9cc"))

func _background() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("111923")
	style.set_corner_radius_all(5)
	return style

func _gui_input(event: InputEvent) -> void:
	if page == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			drag_kind = "seek"
			for channel: String in ["image", "text"]:
				var rect := clip_rect(channel)
				if rect.grow(4).has_point(event.position):
					drag_channel = channel
					drag_x = event.position.x
					drag_start = page.get(channel + "_delay")
					drag_end = drag_start + page.get(channel + "_duration")
					drag_kind = "start" if absf(event.position.x - rect.position.x) <= 7 else ("end" if absf(event.position.x - rect.end.x) <= 7 else "move")
					edit_started.emit()
					break
			_update_drag(event.position.x, false)
		else:
			if not drag_kind.is_empty():
				_update_drag(event.position.x, true)
			drag_kind = ""
			display(page, cursor)
		accept_event()
	elif event is InputEventMouseMotion and not drag_kind.is_empty():
		_update_drag(event.position.x, false)
		accept_event()

func _update_drag(x: float, final: bool) -> void:
	if drag_kind == "seek":
		cursor = snappedf(x_time(x), 0.01)
		seek_requested.emit(cursor)
	else:
		var delta := (x - drag_x) / maxf(1.0, size.x - LEFT - RIGHT) * span
		var start := drag_start
		var end := drag_end
		match drag_kind:
			"move":
				start = clampf(snappedf(drag_start + delta, 0.05), 0, 30)
				end = start + drag_end - drag_start
			"start": start = clampf(snappedf(drag_start + delta, 0.05), maxf(0, end - 30), minf(30, end))
			"end": end = clampf(snappedf(drag_end + delta, 0.05), start, start + 30)
		timing_changed.emit(drag_channel, start, end - start, final)
	queue_redraw()

@tool
extends Resource

const Page = preload("res://scripts/picture_book/page.gd")

@export var title: String = "未命名绘本"
@export var background_texture: Texture2D
@export var background_color: Color = Color("18212b")
@export var text_shadow_color: Color = Color(0, 0, 0, 0.85)
@export var text_shadow_offset: Vector2 = Vector2(2, 2)
@export var text_shadow_outline_size: int = 0
@export var pages: Array[Resource] = []

## Resolve from the beginning every time: selection and reorder cannot leave
## stale inherited content behind. The first page inherits an empty layer.
func resolve(page_index: int) -> Dictionary:
	var result: Dictionary = {
		"image": null, "text": "", "image_rect": Rect2(0, 0, 1280, 720),
		"text_rect": Rect2(96, 540, 1088, 130), "font_size": 32,
		"text_color": Color.WHITE, "image_fit": Page.ImageFit.COVER,
		"text_shadow_color": text_shadow_color,
		"text_shadow_offset": text_shadow_offset, "text_shadow_outline_size": text_shadow_outline_size,
	}
	if page_index < 0 or page_index >= pages.size():
		return result
	for i in range(page_index + 1):
		var page: Resource = pages[i]
		if not page is Page:
			continue
		match page.image_action:
			Page.Action.REPLACE:
				result.image = page.image
			Page.Action.CLEAR:
				result.image = null
		match page.text_action:
			Page.Action.REPLACE:
				result.text = page.text
			Page.Action.CLEAR:
				result.text = ""
	var current: Resource = pages[page_index]
	if current is Page:
		result.image_rect = current.image_rect
		result.image_fit = current.image_fit
		result.text_rect = current.text_rect
		result.text_backdrop_color = current.text_backdrop_color
		result.text_backdrop_padding = current.text_backdrop_padding
		result.font_size = current.font_size
		result.text_color = current.text_color
	return result

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if pages.is_empty():
		errors.append("绘本至少需要一页。")
	for i in pages.size():
		var page: Resource = pages[i]
		var prefix: String = "第 %d 页：" % (i + 1)
		if not page is Page:
			errors.append(prefix + "不是有效的绘本页面资源。")
			continue
		if page.image_action not in [Page.Action.KEEP, Page.Action.REPLACE, Page.Action.CLEAR] or page.text_action not in [Page.Action.KEEP, Page.Action.REPLACE, Page.Action.CLEAR]:
			errors.append(prefix + "内容操作无效。")
		if page.image != null and (not page.image.resource_path.begins_with("res://") or page.image.resource_path.contains("::")):
			errors.append(prefix + "图片必须引用项目内的独立资源（res://）。")
		for field in ["image_rect", "text_rect"]:
			var rect: Rect2 = page.get(field)
			if not rect.position.is_finite() or not rect.size.is_finite() or rect.size.x <= 0 or rect.size.y <= 0:
				errors.append(prefix + "图片和文本框必须具有有效的正宽高。")
		if page.image_fit not in [Page.ImageFit.COVER, Page.ImageFit.CONTAIN]:
			errors.append(prefix + "图片适配模式无效。")
		if page.font_size < 8 or page.font_size > 144:
			errors.append(prefix + "字号须为 8–144。")
		for field in ["image_delay", "image_duration", "text_delay", "text_duration", "hold_seconds", "exit_duration", "text_backdrop_padding"]:
			var value: float = page.get(field)
			if not is_finite(value) or value < 0:
				errors.append(prefix + "过渡和停留时间不能为负数或非有限数。")
	return errors

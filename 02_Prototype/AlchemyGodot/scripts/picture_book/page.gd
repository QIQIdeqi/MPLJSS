@tool
extends Resource
## A single picture-book slide. KEEP inherits content, not the local layout.

enum Action { KEEP, REPLACE, CLEAR }
enum ImageFit { COVER, CONTAIN }

@export var title: String = "新页面"
@export_enum("保留上一页", "换成新内容", "清空") var image_action: int = Action.REPLACE
@export var image: Texture2D
@export_enum("保留上一页", "换成新内容", "清空") var text_action: int = Action.REPLACE
@export_multiline var text: String = ""
@export var image_rect: Rect2 = Rect2(0, 0, 1280, 720)
@export var text_rect: Rect2 = Rect2(96, 540, 1088, 130)
@export_range(8, 144, 1) var font_size: int = 32
@export var text_color: Color = Color.WHITE
@export_range(0, 30, 0.05) var image_delay: float = 0.0
@export_range(0, 30, 0.05) var image_duration: float = 0.5
@export_range(0, 30, 0.05) var text_delay: float = 0.0
@export_range(0, 30, 0.05) var text_duration: float = 0.5
@export var auto_advance: bool = false
@export_range(0, 300, 0.1) var hold_seconds: float = 3.0

@export_enum("覆盖裁切", "完整显示") var image_fit: int = ImageFit.COVER
@export_range(0, 30, 0.05) var exit_duration: float = 0.5

@export var text_backdrop_color: Color = Color.TRANSPARENT
@export_range(0, 120, 1) var text_backdrop_padding: float = 20.0

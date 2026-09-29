extends CanvasLayer

var stack: ItemStack = null

var _icon := TextureRect.new()
var _count := Label.new()

func _ready() -> void:
	layer = 100
	_icon.custom_minimum_size = Vector2(48, 48)
	_icon.size = Vector2(64, 64)
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.visible = false
	add_child(_icon)
	
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_count.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_icon.add_child(_count)
	
	set_process(true)

func _process(_delta: float) -> void:
	if stack != null:
		_icon.global_position = get_viewport().get_mouse_position() + Vector2(6, 6)

func set_stack(s: ItemStack) -> void:
	stack = s
	_icon.visible =s != null
	if s != null:
		_icon.texture = s.item.icon
		_count.text = str(s.count) if s.count > 1 else ""

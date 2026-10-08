extends Node
## Keeps the game phone-shaped on desktop, autoloaded as /root/PhoneFrame. The project stretches
## with aspect "expand", which on a wide desktop window would widen the table across the whole
## screen. Off phones, once the window is wider than [constant MAX_ASPECT], the viewport is held
## at that shape instead and Godot centres it with black bars either side. Phones keep "expand"
## so the layout still fills their whole screen.

## Widest width:height the game grows to off phones (9:16, a typical phone screen).
const MAX_ASPECT := 9.0 / 16.0

var _base_size: Vector2i


func _ready() -> void:
	if OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios"):
		return
	var window := get_tree().root
	_base_size = window.content_scale_size
	window.size_changed.connect(_fit)
	_fit()


func _fit() -> void:
	var window := get_tree().root
	var size := Vector2(window.size)
	if size.y <= 0 or size.x / size.y <= MAX_ASPECT:
		# Phone-shaped or taller: let the height grow, as on a phone.
		window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		window.content_scale_size = _base_size
	else:
		# Wider than a phone: a fixed phone-shaped screen, centred between black bars.
		window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
		window.content_scale_size = Vector2i(roundi(_base_size.y * MAX_ASPECT), _base_size.y)

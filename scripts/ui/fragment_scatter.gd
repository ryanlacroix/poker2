class_name FragmentScatter
extends Control
## Fragments of a blown-up seat lying where they landed, for the rest of the table. Full-screen
## and click-through; meant to sit on the table, under the seats, cards and buttons.

# Each fragment: Rect2 where it lies, and its colour.
var _rects: Array[Rect2] = []
var _colors: Array[Color] = []


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


## A fragment of [param shape] (whole pixels) comes to rest at [param at] (local coordinates).
func add(at: Vector2, shape: Vector2, color: Color) -> void:
	_rects.append(Rect2(at.floor(), shape))
	_colors.append(color)
	queue_redraw()


func _draw() -> void:
	for i in _rects.size():
		draw_rect(_rects[i], _colors[i])

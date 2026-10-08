class_name NoticeBanner
extends Control
## Caption-style notices: a translucent black strip across the full width of the screen with
## white text on it. Queued messages play one at a time, each shown for [constant HOLD_TIME]
## and then faded out. The node's rect is the strip.

## Emitted when the last queued notice has faded out (not when cut short by [method clear]).
signal finished

const HOLD_TIME := 1.0
const FADE_TIME := 0.4
const STRIP_HEIGHT := 30.0

var _queue: Array[String] = []
var _text := ""
var _tween: Tween


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	visible = false


func enqueue(text: String) -> void:
	_queue.push_back(text)
	if not visible:
		_show_next()


func clear() -> void:
	_queue.clear()
	if _tween:
		_tween.kill()
	visible = false


func _show_next() -> void:
	if _queue.is_empty():
		visible = false
		finished.emit()
		return
	_text = _queue.pop_front()
	modulate = Color.WHITE
	visible = true
	queue_redraw()
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(HOLD_TIME)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	_tween.tween_callback(_show_next)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.6))
	var font := get_theme_default_font()
	var font_size := UiTheme.FONT_SIZE
	var baseline := floorf((size.y + font.get_ascent(font_size) - font.get_descent(font_size)) / 2)
	draw_string(font, Vector2(0, baseline), _text, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, Color.WHITE)

class_name ShotTracer
extends Control
## A gunshot tracer: a glowing red line flashed between shooter and target that quickly fades.
## Full-screen and click-through; [method fire] draws one.

const FADE_SECONDS := 0.35

var _from: Vector2
var _to: Vector2
var _tween: Tween


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	visible = false


## Flashes the tracer from [param from] to [param to] (local coordinates).
func fire(from: Vector2, to: Vector2) -> void:
	_from = from.floor()
	_to = to.floor()
	if _tween:
		_tween.kill()
	modulate = Color.WHITE
	visible = true
	queue_redraw()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, FADE_SECONDS) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(hide)


func _draw() -> void:
	# Wide faint glow, a brighter band, then a hot near-white core.
	draw_line(_from, _to, Color(PixelArt.HEART_RED, 0.35), 11)
	draw_line(_from, _to, Color(PixelArt.HEART_RED, 0.6), 7)
	draw_line(_from, _to, Color(PixelArt.HEART_RED, 0.9), 5)
	draw_line(_from, _to, Color("ff6a6a"), 3)
	draw_line(_from, _to, Color("ffe0e0"), 1)

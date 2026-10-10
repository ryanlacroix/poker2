class_name ShotTracer
extends Control
## Gunshot tracers: glowing lines flashed between shooter and target that quickly fade.
## Full-screen and click-through; [method fire] draws one, joining any still fading out.

const FADE_SECONDS := 0.35

# Each line: [from, to, color].
var _lines: Array[Array] = []
var _tween: Tween


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	visible = false


## Flashes a tracer from [param from] to [param to] (local coordinates), red unless
## [param color] says otherwise.
func fire(from: Vector2, to: Vector2, color := PixelArt.HEART_RED) -> void:
	if not visible:
		_lines.clear()
	_lines.append([from.floor(), to.floor(), color])
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
	for line in _lines:
		var from: Vector2 = line[0]
		var to: Vector2 = line[1]
		var color: Color = line[2]
		# Wide faint glow, a brighter band, then a hot near-white core.
		draw_line(from, to, Color(color, 0.35), 11)
		draw_line(from, to, Color(color, 0.6), 7)
		draw_line(from, to, Color(color, 0.9), 5)
		draw_line(from, to, color.lerp(Color.WHITE, 0.35), 3)
		draw_line(from, to, color.lerp(Color.WHITE, 0.85), 1)

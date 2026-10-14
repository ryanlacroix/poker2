class_name LightningBolt
extends Control
## A lightning strike: a jagged bolt from the top of the screen down onto a portrait that
## flickers, fades and frees itself. Full-screen and click-through; set [member to] before adding it.

const COLOR := Color("b8d4ff")
## How long the bolt flickers at full strength, then fades.
const FLICKER_SECONDS := 0.25
const FADE_SECONDS := 0.35
## Rough length of each straight segment of the bolt.
const SEGMENT := 18.0
## How far each bend can swing off the straight line.
const JAG := 9.0
## How far the bolt's top is pulled toward the middle of the screen, so it comes down in front
## of the other portraits in its column rather than through them.
const LEAN := 0.5

## Where the bolt strikes (local coordinates): the struck player's portrait.
var to: Vector2

var _points := PackedVector2Array()
var _fork := PackedVector2Array()
var _age := 0.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	var from := Vector2(lerpf(to.x, get_viewport_rect().size.x / 2, LEAN), 0)
	_points = jagged(from, to)
	# A short fork off the bolt, partway down.
	@warning_ignore("integer_division")
	var split := _points[_points.size() / 2]
	_fork = jagged(split, split + Vector2(signf(randf() - 0.5) * 24, 30))
	var tween := create_tween()
	tween.tween_interval(FLICKER_SECONDS)
	tween.tween_property(self, "modulate:a", 0.0, FADE_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(queue_free)


func _process(delta: float) -> void:
	_age += delta
	# Flickers off for a moment early on, like a real strike.
	visible = not (_age > 0.06 and _age < 0.1)
	queue_redraw()


## A zigzag from [param from] to [param end], on whole pixels: a bend every [param segment] or so,
## each swinging up to [param jag] off the straight line.
static func jagged(from: Vector2, end: Vector2, segment := SEGMENT, jag := JAG) -> PackedVector2Array:
	var points := PackedVector2Array([from.floor()])
	var steps := maxi(2, ceili(from.distance_to(end) / segment))
	var across := (end - from).orthogonal().normalized()
	for i in range(1, steps):
		var at := from.lerp(end, float(i) / steps) + across * randf_range(-jag, jag)
		points.append(at.floor())
	points.append(end.floor())
	return points


func _draw() -> void:
	for line in [_points, _fork]:
		# Wide faint glow, a brighter band, then a white-hot core.
		draw_polyline(line, Color(COLOR, 0.3), 9)
		draw_polyline(line, Color(COLOR, 0.7), 5)
		draw_polyline(line, COLOR.lerp(Color.WHITE, 0.5), 3)
		draw_polyline(line, Color.WHITE, 1)

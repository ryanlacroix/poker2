class_name OverloadSparks
extends Control
## A shield overload charging: electricity shoots violently out of a portrait, jagged arcs that
## lash out from its edges in all directions, more and longer as it builds, around a crackling
## outline and a flickering blue-white glow that turns white-hot just before it blows; then it
## frees itself. Full-screen and click-through; set [member seat] before adding it.

const SECONDS := 1.0
## How often the arcs are thrown out afresh.
const RESTRIKE_SECONDS := 0.04
## Arcs out of the portrait at the start and by the end.
const ARCS := Vector2i(3, 12)
## How far an arc reaches out from the portrait's edge at the start, and by the end.
const REACH := Vector2(14, 60)
## Rough length of each straight stretch of an arc, and how far each bend swings.
const SEGMENT := 7.0
const JAG := 5.0
## Chance an arc throws off a short fork.
const FORK_CHANCE := 0.35
## The last stretch, when the portrait glows white-hot.
const WHITE_HOT_SECONDS := 0.15

## Whose portrait is overloading; followed every frame, so the arcs stay on it as it shakes.
var seat: SeatView

var _age := 0.0
var _since_strike := 0.0
var _arcs: Array[PackedVector2Array] = []
var _outline := PackedVector2Array()


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_strike()
	get_tree().create_timer(SECONDS, false).timeout.connect(queue_free)


func _process(delta: float) -> void:
	_age += delta
	_since_strike += delta
	if _since_strike >= RESTRIKE_SECONDS:
		_since_strike = 0.0
		_strike()
	queue_redraw()


## How far it has built up, 0 to 1 (eased in, so it ends far wilder than it starts).
func _charge() -> float:
	return pow(clampf(_age / SECONDS, 0.0, 1.0), 1.5)


func _frame() -> Rect2:
	var size := SeatView.PORTRAIT_SIZE
	return Rect2(seat.portrait_center() - size / 2, size)


## Throws out a fresh set of arcs, and a fresh crackle round the portrait's outline.
func _strike() -> void:
	var k := _charge()
	var frame := _frame()
	var middle := frame.get_center()
	_arcs.clear()
	for i in roundi(lerpf(ARCS.x, ARCS.y, k)):
		# From a random point on the portrait's edge, out and away from its middle.
		var from := _point_on_edge(frame)
		var out := (from - middle).normalized().rotated(randf_range(-0.6, 0.6))
		var reach := randf_range(0.5, 1.0) * lerpf(REACH.x, REACH.y, k)
		var arc := LightningBolt.jagged(from, from + out * reach, SEGMENT, JAG)
		_arcs.append(arc)
		if randf() < FORK_CHANCE and arc.size() > 2:
			var split := arc[randi_range(1, arc.size() - 2)]
			var fork_out := out.rotated(randf_range(0.5, 1.0) * signf(randf() - 0.5))
			_arcs.append(LightningBolt.jagged(split, split + fork_out * reach * 0.4, SEGMENT, JAG))
	var corners := [frame.position, Vector2(frame.end.x, frame.position.y), frame.end, Vector2(frame.position.x, frame.end.y)]
	_outline = PackedVector2Array()
	for i in 4:
		var side := LightningBolt.jagged(corners[i], corners[(i + 1) % 4], SEGMENT, 2.0)
		side.remove_at(side.size() - 1) # the next side starts there
		_outline.append_array(side)
	_outline.append(_outline[0])


static func _point_on_edge(frame: Rect2) -> Vector2:
	var along := randf() * 2 * (frame.size.x + frame.size.y)
	if along < frame.size.x:
		return frame.position + Vector2(along, 0)
	along -= frame.size.x
	if along < frame.size.y:
		return Vector2(frame.end.x, frame.position.y + along)
	along -= frame.size.y
	if along < frame.size.x:
		return frame.end - Vector2(along, 0)
	return Vector2(frame.position.x, frame.end.y - (along - frame.size.x))


func _draw() -> void:
	var k := _charge()
	var frame := _frame()
	# A glow over the portrait that flickers harder as it builds, and goes white-hot at the end.
	var white_hot := clampf((_age - (SECONDS - WHITE_HOT_SECONDS)) / WHITE_HOT_SECONDS, 0.0, 1.0)
	var glow := lerpf(0.15, 0.55, k) * randf_range(0.6, 1.0)
	draw_rect(frame.grow(2), Color(LightningBolt.COLOR.lerp(Color.WHITE, white_hot), lerpf(glow, 0.95, white_hot)))
	# Each arc: a faint glow, a brighter band, then a white-hot core, like a lightning bolt.
	for line in _arcs + [_outline]:
		draw_polyline(line, Color(LightningBolt.COLOR, 0.3), 5)
		draw_polyline(line, Color(LightningBolt.COLOR, 0.8), 3)
		draw_polyline(line, Color.WHITE, 1)

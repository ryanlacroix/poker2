class_name BurnMark
extends Control
## The scorch left where a seat was blown up: a ragged charred blotch, blackest in the middle,
## with streaks of soot blasted out around it. Click-through; size it over the seat it replaces
## (with room to spare for the streaks) and it draws once, on the table, under everything else.

## The blotch and streaks are drawn in cells this many pixels across, to match the pixel art.
const CELL := 2
## How far past the seat the soot streaks reach, as a share of its half-size.
const STREAK_REACH := 1.35
const STREAKS := 14
## How much of the box the blotch itself fills; the rest is for the streaks.
const BLOTCH := 0.75
const CHAR := Color(0.07, 0.05, 0.04, 0.92)
const SCORCH := Color(0.17, 0.11, 0.08, 0.78)
const SINGE := Color(0.29, 0.19, 0.13, 0.45)

var _noise := FastNoiseLite.new()
# Each soot streak: [angle, length as a share of the full reach].
var _streaks: Array[Array] = []


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_noise.seed = randi()
	_noise.frequency = 0.15
	for i in STREAKS:
		_streaks.append([TAU * (i + randf_range(-0.3, 0.3)) / STREAKS, randf_range(0.8, 1.1)])


func _draw() -> void:
	var half := size / 2 * BLOTCH
	var middle := size / 2
	# Soot streaks first, so the blotch covers where they start.
	for streak in _streaks:
		var direction := Vector2.from_angle(streak[0])
		var reach: float = (half * STREAK_REACH * Vector2(absf(direction.x), absf(direction.y))).length() * streak[1]
		var steps := int(reach / CELL)
		for s in steps:
			var k := float(s) / steps
			var at := middle + direction * s * CELL
			draw_rect(Rect2(at.floor(), Vector2.ONE * CELL), Color(SCORCH, SCORCH.a * (1.0 - k)))
	for cy in int(size.y / CELL):
		for cx in int(size.x / CELL):
			var at := Vector2(cx, cy) * CELL
			var d := ((at - middle) / half).length() + _noise.get_noise_2d(cx, cy) * 0.3
			var color: Color
			if d < 0.55:
				color = CHAR
			elif d < 0.8:
				color = SCORCH
			elif d < 1.0:
				color = SINGE
			else:
				continue
			draw_rect(Rect2(at, Vector2.ONE * CELL), color)

class_name ArmyView
extends Control
## A player's army: tiny black stick men standing in rows on the felt beside their seat, filling
## the node's rect from the top. New men [method march_in] from
## [member enter_from] (off-screen), running in one after another to their places. Once the rect
## is full, newcomers crowd in among the others and the army's size shows in digits.

## Stick men are drawn at this many screen pixels per cell.
const PX := 2
const STAND: Array[String] = [".X.", "XXX", ".X.", ".X.", "X.X"]
## Running: legs apart, then together, bobbing up a pixel on the stride.
const RUN: Array = [
	[".X.", "XXX", ".X.", "X.X", "X.X"],
	[".X.", "XXX", ".X.", ".X.", ".X."],
]
const MAN_SIZE := Vector2(3, 5) * PX
## Distance between neighbouring men's top-left corners.
const PITCH := Vector2(MAN_SIZE.x + 2, MAN_SIZE.y + 3)
## Width the layout gives a formation: seven men across.
const FORMATION_WIDTH := PITCH.x * 7 - 2
const COLOR := Color.BLACK
## How fast a man runs (pixels per second), how long each running frame lasts, and the gap
## between men setting off.
const RUN_SPEED := 130.0
const RUN_FRAME_SECONDS := 0.08
const STAGGER_SECONDS := 0.12
## How far above or below [member enter_from] each man sets off.
const ENTER_SPREAD := 12.0

## Where new men come from (local coordinates): off-screen, on the side they run in from.
var enter_from: Vector2
## Men standing in formation (runners join it as they arrive).
var count := 0

## Places in the formation taken, by men standing in them or running to them.
var _places := 0
var _runners: Array[Runner] = []
var _age := 0.0


## One man on his way in.
class Runner:
	var start: Vector2
	var place: int
	var depart: float # [member ArmyView._age] when he sets off
	var seconds: float # how long his run takes


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_process(false)


## Sends [param n] men running in, the first after [param delay] seconds.
func march_in(n: int, delay := 0.0) -> void:
	var set_off := _age + delay
	for runner in _runners:
		set_off = maxf(set_off, runner.depart + STAGGER_SECONDS)
	for i in n:
		var runner := Runner.new()
		runner.start = enter_from + Vector2(0, randf_range(-ENTER_SPREAD, ENTER_SPREAD))
		runner.place = _places
		_places += 1
		runner.depart = set_off + STAGGER_SECONDS * i
		runner.seconds = runner.start.distance_to(_place_position(runner.place)) / RUN_SPEED
		_runners.append(runner)
	set_process(true)


## Most men the formation shows.
func capacity() -> int:
	return _columns() * maxi(1, floori((size.y + PITCH.y - MAN_SIZE.y) / PITCH.y))


func _columns() -> int:
	return maxi(1, floori((size.x + PITCH.x - MAN_SIZE.x) / PITCH.x))


## Top-left of the man in [param place] (counting from 0): rows fill from the top, each from the
## side the men run in from. Past [method capacity], places repeat.
func _place_position(place: int) -> Vector2:
	place %= capacity()
	var columns := _columns()
	var column := place % columns
	if enter_from.x > size.x / 2:
		column = columns - 1 - column
	var grid_width := PITCH.x * columns - (PITCH.x - MAN_SIZE.x)
	@warning_ignore("integer_division")
	return Vector2((size.x - grid_width) / 2 + PITCH.x * column, PITCH.y * (place / columns)).floor()


func _process(delta: float) -> void:
	_age += delta
	var running := _runners.filter(func(runner: Runner) -> bool: return _age < runner.depart + runner.seconds)
	count += _runners.size() - running.size()
	_runners.assign(running)
	if _runners.is_empty():
		set_process(false)
	queue_redraw()


func _draw() -> void:
	# Places whose men are still on their way.
	var awaited := {}
	for runner in _runners:
		awaited[runner.place] = true
	# Past capacity, places repeat: a spot is filled if any man meant for it has arrived.
	var cap := capacity()
	for spot in mini(_places, cap):
		for place in range(spot, _places, cap):
			if not awaited.has(place):
				PixelArt.draw(self, STAND, _place_position(spot), PX, COLOR)
				break
	for runner in _runners:
		var t := (_age - runner.depart) / runner.seconds
		if t < 0:
			continue
		var frame := int((_age - runner.depart) / RUN_FRAME_SECONDS) % RUN.size()
		var at := runner.start.lerp(_place_position(runner.place), t).floor() + Vector2(0, -PX if frame == 0 else 0)
		PixelArt.draw(self, RUN[frame], at, PX, COLOR)
	if count > capacity():
		_draw_count()


## The army's size in gold digits, centred over the bottom row.
func _draw_count() -> void:
	var text := str(count)
	var width := (text.length() * 4 - 1) * PX
	var rows := ceili(float(capacity()) / _columns())
	var origin := Vector2((size.x - width) / 2, PITCH.y * (rows - 1)).floor()
	draw_rect(Rect2(origin - Vector2.ONE * 2, Vector2(width + 4, 5 * PX + 4)), Color(0, 0, 0, 0.6))
	PixelArt.draw_text(self, text, origin, PX, PixelArt.GOLD)

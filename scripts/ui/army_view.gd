class_name ArmyView
extends Control
## A player's army: tiny black stick men milling about on the felt beside their seat, within the
## node's rect. New men [method march_in] from [member enter_from] (off-screen), running in one
## after another; once there, each one dawdles, then ambles to some spot nearby, and so on. Past
## [constant MAX_SHOWN], newcomers melt into the crowd and the army's size shows in digits.
## For a battle, the men are handed over ([method disband]) and survivors come back ([method rejoin]).
## Meanwhile other armies keep out of the way of the men on the move (see [member avoid]).

## Every man on his way in has arrived.
signal settled

## Stick men are drawn at this many screen pixels per cell.
const PX := 2
const STAND: Array[String] = [".X.", "XXX", ".X.", ".X.", "X.X"]
## Running or walking: legs apart, then together, bobbing up a pixel on the stride.
const STRIDE: Array = [
	[".X.", "XXX", ".X.", "X.X", "X.X"],
	[".X.", "XXX", ".X.", ".X.", ".X."],
]
const MAN_SIZE := Vector2(3, 5) * PX
## Width the layout gives an army's patch of felt.
const FORMATION_WIDTH := 54.0
const COLOR := Color.BLACK
## Most men shown at once.
const MAX_SHOWN := 28
## Running in: speed (pixels per second), how long each stride frame lasts, and the gap between
## men setting off.
const RUN_SPEED := 130.0
const RUN_FRAME_SECONDS := 0.08
const STAGGER_SECONDS := 0.12
## How far above or below [member enter_from] each man sets off.
const ENTER_SPREAD := 12.0
## Milling about: walking speed and stride, how far each stroll goes at most, and how long a man
## dawdles between strolls.
const WALK_SPEED := 8.0
const WALK_FRAME_SECONDS := 0.3
const STROLL_DISTANCE := 16.0
const REST_MIN := 1.0
const REST_MAX := 4.0
## Getting out of the way (see [member avoid]): men step aside when someone comes within
## [constant DODGE_RADIUS] (centre to centre), trotting at [constant DODGE_SPEED] to the best of
## [constant DODGE_CHOICES] spots up to [constant DODGE_DISTANCE] away, still inside the rect.
const DODGE_RADIUS := 14.0
const DODGE_SPEED := 60.0
const DODGE_DISTANCE := 16.0
const DODGE_CHOICES := 8
## A [method glow]: a soft pool of gold light under each man's feet, and a fainter halo behind him,
## fading away over [constant GLOW_SECONDS].
const GLOW_SECONDS := 0.6
const GLOW_COLOR := PixelArt.GOLD
const GLOW_POOL_RADIUS := 7.0
const GLOW_HALO_RADIUS := 8.0

## Where new men come from (local coordinates): off-screen, on the side they run in from.
var enter_from: Vector2
## Men who've arrived (counting any melted into the crowd).
var count := 0
## Men from elsewhere to keep out of the way of: returns their top-left corners in the parent's
## coordinates. Left empty (the default), no one dodges.
var avoid := Callable()

var _men: Array[Man] = []
## Seconds into the current [method glow]; -1 when not glowing.
var _glow_age := -1.0


## One man: running in, then milling about.
class Man:
	var at: Vector2 # top-left
	var target: Vector2
	var arrived := false
	var wait := 0.0 # seconds before he sets off, or rests, before moving on
	var stride_age := 0.0 # seconds spent moving, for the stride frames
	var dodging := false # trotting out of someone's way


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_process(false)


## Every man in the crowd glows gold from underneath for a moment.
func glow() -> void:
	_glow_age = 0.0
	set_process(true)


## No one's on his way in.
func is_settled() -> bool:
	return _men.all(func(man: Man) -> bool: return man.arrived)


## The army leaves to fight: [param n] men's top-left corners in the parent's coordinates, those
## in the crowd where they stand and the rest somewhere on the army's patch. The patch is left empty.
func disband(n: int) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for man in _men:
		if points.size() < n:
			points.append(position + man.at)
	while points.size() < n:
		points.append(position + _random_spot())
	_men.clear()
	count = 0
	queue_redraw()
	return points


## Men at [param points] (top-left corners, in the parent's coordinates) run back to the
## army's patch, counted in as they arrive.
func rejoin(points: Array[Vector2]) -> void:
	for point in points:
		var man := Man.new()
		man.at = point - position
		man.target = _random_spot()
		_men.append(man)
	set_process(true)
	if points.is_empty():
		settled.emit()


## Sends [param n] men running in, the first after [param delay] seconds.
func march_in(n: int, delay := 0.0) -> void:
	var set_off := delay
	for man in _men:
		if not man.arrived:
			set_off = maxf(set_off, man.wait + STAGGER_SECONDS)
	for i in n:
		var man := Man.new()
		man.at = enter_from + Vector2(0, randf_range(-ENTER_SPREAD, ENTER_SPREAD))
		man.target = _random_spot()
		man.wait = set_off + STAGGER_SECONDS * i
		_men.append(man)
	set_process(true)


## Anywhere a man fits in the rect.
func _random_spot() -> Vector2:
	return Vector2(randf() * maxf(0, size.x - MAN_SIZE.x), randf() * maxf(0, size.y - MAN_SIZE.y))


func _process(delta: float) -> void:
	if _glow_age >= 0:
		_glow_age += delta
		if _glow_age >= GLOW_SECONDS:
			_glow_age = -1.0
	var hazards := _hazards()
	for man in _men.duplicate():
		if man.arrived and not hazards.is_empty():
			_dodge(man, hazards)
		if man.wait > 0:
			man.wait -= delta
			continue
		var speed := DODGE_SPEED if man.dodging else WALK_SPEED if man.arrived else RUN_SPEED
		man.at = man.at.move_toward(man.target, speed * delta)
		man.stride_age += delta
		if man.at != man.target:
			continue
		man.stride_age = 0
		man.dodging = false
		man.wait = randf_range(REST_MIN, REST_MAX)
		man.target = _stroll_from(man.at)
		if not man.arrived:
			man.arrived = true
			count += 1
			# The crowd's full: he melts into it.
			if _shown() > MAX_SHOWN:
				_men.erase(man)
			if is_settled():
				settled.emit()
	queue_redraw()


## The centres of the men in [member avoid], in local coordinates.
func _hazards() -> Array[Vector2]:
	var centers: Array[Vector2] = []
	if avoid.is_valid():
		for point: Vector2 in avoid.call():
			centers.append(point - position + MAN_SIZE / 2)
	return centers


## If someone's close to [param man], or to where he's heading, he trots off to whichever nearby
## spot is furthest from everyone in [param hazards].
func _dodge(man: Man, hazards: Array[Vector2]) -> void:
	if _clearance(man.at, hazards) >= DODGE_RADIUS and _clearance(man.target, hazards) >= DODGE_RADIUS:
		return
	if man.dodging and _clearance(man.target, hazards) >= DODGE_RADIUS:
		return
	var best := man.at
	var best_clearance := _clearance(man.at, hazards)
	var bounds := (size - MAN_SIZE).max(Vector2.ZERO)
	for i in DODGE_CHOICES:
		var spot := (man.at + Vector2.from_angle(TAU * (i + randf()) / DODGE_CHOICES) * DODGE_DISTANCE).clamp(Vector2.ZERO, bounds)
		var clearance := _clearance(spot, hazards)
		if clearance > best_clearance:
			best = spot
			best_clearance = clearance
	man.target = best
	man.dodging = true
	man.wait = 0


## How far a man at [param at] (top-left) would stand from the nearest of [param hazards].
func _clearance(at: Vector2, hazards: Array[Vector2]) -> float:
	var nearest := INF
	for hazard in hazards:
		nearest = minf(nearest, (at + MAN_SIZE / 2).distance_to(hazard))
	return nearest


## Somewhere a short stroll from [param from], inside the rect.
func _stroll_from(from: Vector2) -> Vector2:
	var to := from + Vector2.from_angle(randf() * TAU) * randf_range(STROLL_DISTANCE / 3, STROLL_DISTANCE)
	return to.clamp(Vector2.ZERO, (size - MAN_SIZE).max(Vector2.ZERO))


## Where the men still running in or home are: top-left corners in the parent's coordinates.
func running_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for man in _men:
		if not man.arrived and man.wait <= 0:
			points.append(position + man.at)
	return points


## Men in the crowd, not counting those still running in.
func _shown() -> int:
	return _men.filter(func(man: Man) -> bool: return man.arrived).size()


func _draw() -> void:
	# Further back (higher up) first, so nearer men stand in front.
	var men := _men.duplicate()
	men.sort_custom(func(a: Man, b: Man) -> bool: return a.at.y < b.at.y)
	if _glow_age >= 0:
		_draw_glow(men)
	for man: Man in men:
		if not man.arrived and man.wait > 0:
			continue
		var moving := man.wait <= 0
		if not moving:
			PixelArt.draw(self, STAND, man.at.floor(), PX, COLOR)
			continue
		var frame_seconds := WALK_FRAME_SECONDS if man.arrived and not man.dodging else RUN_FRAME_SECONDS
		var frame := int(man.stride_age / frame_seconds) % STRIDE.size()
		PixelArt.draw(self, STRIDE[frame], man.at.floor() + Vector2(0, -PX if frame == 0 else 0), PX, COLOR)
	if count > MAX_SHOWN:
		_draw_count()


## The [method glow] under [param men], under all of them so it never covers anyone. Each light
## is a few stacked faint circles, brightest at the middle; the pool under the feet is flattened.
func _draw_glow(men: Array) -> void:
	# Quick at first, then lingering faintly.
	var strength := pow(1.0 - _glow_age / GLOW_SECONDS, 2)
	for man: Man in men:
		if not man.arrived:
			continue
		var body := man.at + MAN_SIZE / 2
		var feet := man.at + Vector2(MAN_SIZE.x / 2, MAN_SIZE.y)
		for i in 3:
			var k := 1.0 - i / 3.0
			draw_circle(body, GLOW_HALO_RADIUS * k, Color(GLOW_COLOR, 0.12 * strength))
			draw_set_transform(feet, 0, Vector2(1, 0.45))
			draw_circle(Vector2.ZERO, GLOW_POOL_RADIUS * k, Color(GLOW_COLOR, 0.3 * strength))
			draw_set_transform(Vector2.ZERO)


## The army's size in gold digits, centred at the bottom of the rect.
func _draw_count() -> void:
	var text := str(count)
	var width := (text.length() * 4 - 1) * PX
	var origin := Vector2((size.x - width) / 2, size.y - 5 * PX - 2).floor()
	draw_rect(Rect2(origin - Vector2.ONE * 2, Vector2(width + 4, 5 * PX + 4)), Color(0, 0, 0, 0.6))
	PixelArt.draw_text(self, text, origin, PX, PixelArt.GOLD)

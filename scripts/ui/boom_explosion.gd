class_name BoomExplosion
extends Control
## A boom trap going off: a white flash over the whole screen, a shockwave ring, a churning
## fireball in chunky pixels that swells, cools through yellow, orange and red and rolls up into
## smoke, burning debris flung out under gravity, and black fragments of the seat blasted out
## across the table, left lying where they land in [member scatter]; then it frees itself.
## Full-screen and click-through; set [member center] and [member scatter] before adding it.

## Emitted once the fireball has swallowed the seat, so it can be swapped for a burn mark unseen.
signal engulfed

const SECONDS := 2.0
const ENGULF_SECONDS := 0.1
const FLASH_SECONDS := 0.3
## The fireball swells to [constant FIREBALL_RADIUS] over this long, then burns down until
## [constant BURN_SECONDS] in, as the smoke it leaves fades by [constant SECONDS].
const GROW_SECONDS := 0.3
const BURN_SECONDS := 1.3
const FIREBALL_RADIUS := 70.0
## How far the fireball and its smoke billow out and rise as they burn down.
const BILLOW := 0.35
const RISE := 30.0
const SHOCKWAVE_SECONDS := 0.45
const SHOCKWAVE_RADIUS := 170.0
const DEBRIS := 80
const GRAVITY := 450.0
## Fragments of the seat: blasted out and up, they arc through the air tumbling, hit the table,
## bounce once and skid to a stop.
const FRAGMENTS := 60
## How fast (pixels a second) they fly out across the table, and up off it.
const FRAGMENT_SPEED := Vector2(160, 440)
const FRAGMENT_LIFT := Vector2(120, 320)
## Pull back down to the table, and how quickly they slow in the air and skidding on the table.
const FRAGMENT_FALL := 900.0
const AIR_DRAG := 1.5
const SKID_DRAG := 9.0
## Share of its fall speed a fragment bounces back up with, and of its speed it keeps doing so.
const BOUNCE := 0.3
const BOUNCE_SKID := 0.55
## How often an airborne fragment turns over, and the slowest it can skid before it stops.
const TUMBLE_SECONDS := 0.05
const STOP_SPEED := 8.0
const FRAGMENT_SHAPES: Array[Vector2] = [
	Vector2(2, 2), Vector2(3, 2), Vector2(2, 3), Vector2(3, 3), Vector2(4, 2), Vector2(4, 3),
]
const FRAGMENT_COLORS: Array[Color] = [Color("0b0b10"), Color("0b0b10"), Color("1c1a20"), Color("2a2a30")]
## The fireball is drawn in cells this many pixels across, to match the chunky pixel art.
const CELL := 3
## Fire from hottest to coolest, by how far into the fireball a cell is and how hot it still burns.
const WHITE_HOT := Color("fff6d0")
const YELLOW := Color("ffd040")
const ORANGE := Color("ff8a20")
const RED := Color("d83018")
const SMOKE := Color("3a3238")

## Where it goes off (local coordinates): the middle of the victim's seat.
var center: Vector2
## Where the fragments are left lying once they land, in the same coordinates; none are kept if null.
var scatter: FragmentScatter

var _age := 0.0
var _noise := FastNoiseLite.new()
# Each piece of debris: [position, velocity, lifetime, size].
var _debris: Array[Array] = []
var _fragments: Array[Fragment] = []


## A fragment of the seat in flight: where it is on the table and how high above it, and how fast
## it's moving across and up.
class Fragment:
	var at: Vector2
	var velocity: Vector2
	var height := 0.0
	var lift: float
	var shape: Vector2
	var color: Color
	var bounced := false
	var skidding := false


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_noise.seed = randi()
	_noise.frequency = 0.12
	for i in DEBRIS:
		var direction := Vector2.from_angle(randf() * TAU)
		_debris.append([center, direction * randf_range(120, 340) + Vector2(0, -80),
			randf_range(0.5, 1.2), 3 if randf() < 0.4 else 2])
	for i in FRAGMENTS:
		var fragment := Fragment.new()
		var direction := Vector2.from_angle(randf() * TAU)
		fragment.at = center + direction * randf_range(0, 10)
		fragment.velocity = direction * randf_range(FRAGMENT_SPEED.x, FRAGMENT_SPEED.y)
		fragment.lift = randf_range(FRAGMENT_LIFT.x, FRAGMENT_LIFT.y)
		fragment.shape = FRAGMENT_SHAPES.pick_random()
		fragment.color = FRAGMENT_COLORS.pick_random()
		_fragments.append(fragment)
	get_tree().create_timer(ENGULF_SECONDS, false).timeout.connect(engulfed.emit)
	get_tree().create_timer(SECONDS, false).timeout.connect(func() -> void:
		# Anything still moving stops where it is.
		for fragment in _fragments:
			_land(fragment)
		_fragments.clear()
		queue_free())


func _process(delta: float) -> void:
	_age += delta
	for piece in _debris:
		piece[1] += Vector2(0, GRAVITY * delta)
		piece[0] += piece[1] * delta
	for fragment in _fragments.duplicate():
		_move_fragment(fragment, delta)
	queue_redraw()


func _move_fragment(fragment: Fragment, delta: float) -> void:
	fragment.at += fragment.velocity * delta
	if fragment.skidding:
		fragment.velocity *= exp(-SKID_DRAG * delta)
		if fragment.velocity.length() < STOP_SPEED:
			_land(fragment)
			_fragments.erase(fragment)
		return
	fragment.velocity *= exp(-AIR_DRAG * delta)
	fragment.lift -= FRAGMENT_FALL * delta
	fragment.height += fragment.lift * delta
	if fragment.height > 0:
		return
	fragment.height = 0
	fragment.velocity *= BOUNCE_SKID
	if fragment.bounced:
		fragment.skidding = true
	else:
		fragment.bounced = true
		fragment.lift = -fragment.lift * BOUNCE


## [param fragment] comes to rest where it is, left on the table for good.
func _land(fragment: Fragment) -> void:
	if scatter:
		scatter.add(fragment.at, fragment.shape, fragment.color)


func _draw() -> void:
	_draw_fireball()
	_draw_debris()
	_draw_fragments()
	_draw_shockwave()
	if _age < FLASH_SECONDS:
		var view := get_viewport_rect().size
		# Oversized, so no unflashed edge shows while the screen shakes.
		draw_rect(Rect2(-Vector2.ONE * 40, view + Vector2.ONE * 80), Color(1, 0.97, 0.88, 0.9 * (1 - _age / FLASH_SECONDS)))


## The fireball, cell by cell: churning noise roughens its edge and its bands of colour, which
## cool to smoke from the outside in as it burns down.
func _draw_fireball() -> void:
	var grow := minf(_age / GROW_SECONDS, 1.0)
	var heat := clampf(1.0 - (_age - GROW_SECONDS) / (BURN_SECONDS - GROW_SECONDS), 0.0, 1.0)
	var smoke := clampf((SECONDS - _age) / (SECONDS - BURN_SECONDS * 0.6), 0.0, 1.0)
	var after := maxf(_age - GROW_SECONDS, 0.0)
	var radius := FIREBALL_RADIUS * (1.0 - pow(1.0 - grow, 3)) * (1.0 + BILLOW * after)
	if radius < 1 or smoke <= 0:
		return
	var middle := center + Vector2(0, -RISE * after)
	var cells := ceili(radius * 1.3 / CELL)
	for cy in range(-cells, cells + 1):
		for cx in range(-cells, cells + 1):
			var offset := Vector2(cx, cy) * CELL
			if offset.length() > radius * 1.35:
				continue # beyond anything the noise can push out to
			var d := offset.length() / radius + _noise.get_noise_3d(cx + middle.x / CELL, cy + middle.y / CELL, _age * 25) * 0.35
			if d >= 1.0:
				continue
			var fire := (1.0 - d) * 1.7 * heat
			var color: Color
			if fire > 1.0:
				color = WHITE_HOT
			elif fire > 0.7:
				color = YELLOW
			elif fire > 0.45:
				color = ORANGE
			elif fire > 0.2:
				color = RED
			else:
				color = Color(SMOKE, 0.85 * smoke)
			draw_rect(Rect2((middle + offset).floor() - Vector2.ONE * CELL / 2.0, Vector2.ONE * CELL), color)


## Burning chunks flung out of the blast, cooling from white to red to soot as they fall.
func _draw_debris() -> void:
	for piece in _debris:
		var life: float = piece[2]
		var k := _age / life
		if k >= 1.0:
			continue
		var color := WHITE_HOT.lerp(YELLOW, k * 3) if k < 0.33 else YELLOW.lerp(ORANGE, (k - 0.33) * 3) \
			if k < 0.66 else Color(RED.lerp(SMOKE, (k - 0.66) * 3), 1.0 - (k - 0.66) * 3)
		var size: int = piece[3]
		var at: Vector2 = piece[0]
		draw_rect(Rect2(at.floor(), Vector2.ONE * size), color)


## Fragments still on the move: tumbling end over end in the air, high above a faint shadow on the
## table, then skidding flat.
func _draw_fragments() -> void:
	var tumbled := int(_age / TUMBLE_SECONDS) % 2 == 1
	for fragment in _fragments:
		var shape := fragment.shape
		if not fragment.skidding:
			draw_rect(Rect2(fragment.at.floor(), shape), Color(0, 0, 0, 0.3)) # shadow
			if tumbled:
				shape = Vector2(shape.y, shape.x)
		draw_rect(Rect2((fragment.at - Vector2(0, fragment.height)).floor(), shape), fragment.color)


## A pale ring racing out from the blast and fading.
func _draw_shockwave() -> void:
	var k := _age / SHOCKWAVE_SECONDS
	if k >= 1.0:
		return
	var radius := SHOCKWAVE_RADIUS * (1.0 - pow(1.0 - k, 2))
	draw_arc(center, radius, 0, TAU, 72, Color(WHITE_HOT, 0.8 * (1.0 - k)), 4)
	draw_arc(center, radius - 4, 0, TAU, 72, Color(ORANGE, 0.5 * (1.0 - k)), 3)

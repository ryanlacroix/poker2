class_name BoomExplosion
extends Control
## A boom trap going off: a white flash over the whole screen, a shockwave ring, a churning
## fireball in chunky pixels that swells, cools through yellow, orange and red and rolls up into
## smoke, and burning debris flung out under gravity; then it frees itself. Full-screen and
## click-through; set [member center] before adding it.

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
const DEBRIS := 40
const GRAVITY := 450.0
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

var _age := 0.0
var _noise := FastNoiseLite.new()
# Each piece of debris: [position, velocity, lifetime, size].
var _debris: Array[Array] = []


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_noise.seed = randi()
	_noise.frequency = 0.12
	for i in DEBRIS:
		var direction := Vector2.from_angle(randf() * TAU)
		_debris.append([center, direction * randf_range(120, 340) + Vector2(0, -80),
			randf_range(0.5, 1.2), 3 if randf() < 0.4 else 2])
	get_tree().create_timer(ENGULF_SECONDS, false).timeout.connect(engulfed.emit)
	get_tree().create_timer(SECONDS, false).timeout.connect(queue_free)


func _process(delta: float) -> void:
	_age += delta
	for piece in _debris:
		piece[1] += Vector2(0, GRAVITY * delta)
		piece[0] += piece[1] * delta
	queue_redraw()


func _draw() -> void:
	_draw_fireball()
	_draw_debris()
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


## A pale ring racing out from the blast and fading.
func _draw_shockwave() -> void:
	var k := _age / SHOCKWAVE_SECONDS
	if k >= 1.0:
		return
	var radius := SHOCKWAVE_RADIUS * (1.0 - pow(1.0 - k, 2))
	draw_arc(center, radius, 0, TAU, 72, Color(WHITE_HOT, 0.8 * (1.0 - k)), 4)
	draw_arc(center, radius - 4, 0, TAU, 72, Color(ORANGE, 0.5 * (1.0 - k)), 3)

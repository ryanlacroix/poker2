class_name CoinShower
extends Control
## A pot being paid out: [member count] gold coins fly from the pot of gold to the winner, launched
## in a quick staggered burst, each spinning as it arcs over and vanishing as it lands (behind the
## winner's portrait, which is drawn over it); then it
## frees itself. Full-screen and click-through; set [member from], [member to] and [member count]
## before adding it.

## How long each coin takes to fly over, and how spread out their launches are.
const FLIGHT_SECONDS := 1.0
const STAGGER_SECONDS := 0.5
const SECONDS := FLIGHT_SECONDS + STAGGER_SECONDS
## How high the coins arc above the straight line, give or take [constant ARC_JITTER].
const ARC_HEIGHT := 50.0
const ARC_JITTER := 25.0
## How far apart the coins start (round the pot) and land (round the portrait).
const LAUNCH_SPREAD := 8.0
const LAND_SPREAD := 10.0
## How long each frame of a coin's spin lasts.
const SPIN_FRAME_SECONDS := 0.06
## Coin art is drawn at this many screen pixels per cell.
const PX := 3

## A coin turning over: face on, edge on, and back (each centred on the coin).
const SPIN: Array = [
	[".ooo.", "oWYYo", "oYYYo", "oYyyo", ".ooo."],
	[".o.", "oWo", "oYo", "oyo", ".o."],
	["o", "Y", "Y", "y", "o"],
	[".o.", "oYo", "oYo", "oyo", ".o."],
]
const COLORS := {
	"Y": PixelArt.GOLD,
	"y": Color("c08a20"),
	"W": Color("fff6d0"),
	"o": Color("7a4e10"),
}

## Where the coins come from and go to (local coordinates): the pot of gold and the winner's portrait.
var from: Vector2
var to: Vector2
var count := 1

var _age := 0.0
var _coins: Array[Coin] = []


## One coin's flight.
class Coin:
	var delay: float
	var start: Vector2
	var end: Vector2
	var lift: float # how high its arc goes
	var spin_offset: int


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	for i in count:
		var coin := Coin.new()
		coin.delay = STAGGER_SECONDS * i / maxi(count - 1, 1)
		coin.start = from + Vector2.from_angle(randf() * TAU) * randf() * LAUNCH_SPREAD
		coin.end = to + Vector2.from_angle(randf() * TAU) * randf() * LAND_SPREAD
		coin.lift = ARC_HEIGHT + randf_range(-ARC_JITTER, ARC_JITTER)
		coin.spin_offset = randi_range(0, SPIN.size() - 1)
		_coins.append(coin)


func _process(delta: float) -> void:
	_age += delta
	if _age >= SECONDS:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	for coin in _coins:
		var t := (_age - coin.delay) / FLIGHT_SECONDS
		if t < 0 or t >= 1:
			continue
		# Eased in and out, along a curve bowing up over the straight line.
		var k := smoothstep(0.0, 1.0, t)
		var control := (coin.start + coin.end) / 2 + Vector2(0, -coin.lift * 2)
		var at := coin.start.lerp(control, k).lerp(control.lerp(coin.end, k), k)
		var frame: Array = SPIN[(int(_age / SPIN_FRAME_SECONDS) + coin.spin_offset) % SPIN.size()]
		var art_size := Vector2(frame[0].length(), frame.size()) * PX
		PixelArt.draw_colored(self, frame, COLORS, (at - art_size / 2).floor(), PX)

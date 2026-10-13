class_name MagpieBird
extends Control
## A magpie hex's bird: swoops down from the top of the screen onto [member grab_at], snatches
## the item there in its feet, carries it over to [member drop_at], lets go and flies off the
## top of the screen, then frees itself. Click-through; set its fields before adding it.

## Emitted as it lets go of the item over [member drop_at].
signal delivered

const SWOOP_SECONDS := 0.6
const CARRY_SECONDS := 0.8
const LEAVE_SECONDS := 0.55
## How high the bird arcs while carrying the item across.
const CARRY_ARC := 40.0
## How often the wings beat between up and down.
const FLAP_SECONDS := 0.06
const PX := 2

# Facing right; flipped to fly left: a long blue-sheened tail, white belly and shoulder, and
# white-tipped wings. Its feet (the F cells) carry the item.
const WINGS_UP: Array[String] = [
	"......WW............",
	"......KWW...........",
	".......KWW..........",
	"........KBB.........",
	".........KBB....KK..",
	".........KBBK..KKEKY",
	"...BBKKKKWWWKKKKKKK.",
	"BBBKK...KKWWWWKKK...",
	".........KWWWWWK....",
	"..........KWWWK.....",
	"...........K.K......",
	"...........F.F......",
]
const WINGS_DOWN: Array[String] = [
	"....................",
	"....................",
	"....................",
	"....................",
	"................KK..",
	"...............KKEKY",
	"...BBKKKKWWWKKKKKKK.",
	"BBBKK...KBBKWWKKK...",
	"........KBBKWWWWK...",
	".......KWWK.WWK.....",
	"......WWK..K.K......",
	"...........F.F......",
]
const COLORS := {
	"K": Color("16161e"),
	"W": Color("f4f4f4"),
	"B": Color("3a5cc0"),
	"E": Color("8a8a99"),
	"Y": Color("4a4a55"),
	"F": Color("6a6a72"),
}
## Column the feet are centred on, facing right.
const FEET_X := 12.5

## Where the item is snatched from, and dropped on (the parent's coordinates): the centres of
## the target's and the caster's item plates.
var grab_at: Vector2
var drop_at: Vector2
## What it's stealing, drawn in its feet once grabbed.
var item: Item.Kind

var _carrying := false
var _facing := 1.0
var _age := 0.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	var start := Vector2(lerpf(grab_at.x, get_viewport_rect().size.x / 2, 0.3), -20)
	position = start
	_face(grab_at.x - start.x)
	var tween := create_tween()
	tween.tween_property(self, "position", grab_at, SWOOP_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void:
		_carrying = true
		_face(drop_at.x - grab_at.x))
	tween.tween_method(func(t: float) -> void:
		position = grab_at.lerp(drop_at, t) + Vector2(0, -sin(PI * t) * CARRY_ARC),
		0.0, 1.0, CARRY_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func() -> void:
		_carrying = false
		delivered.emit())
	# Flies on the way it was heading, up off the top of the screen.
	tween.tween_method(func(t: float) -> void:
		position = drop_at.lerp(Vector2(drop_at.x + _facing * 60, -30), t),
		0.0, 1.0, LEAVE_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()


## Turns to fly the way [param dx] points (keeping its heading when it's straight up or down).
func _face(dx: float) -> void:
	if dx != 0:
		_facing = signf(dx)


func _draw() -> void:
	var art := WINGS_UP if int(_age / FLAP_SECONDS) % 2 == 0 else WINGS_DOWN
	var width := art[0].length()
	if _facing < 0:
		var flipped: Array[String] = []
		for row in art:
			flipped.append(row.reverse())
		art = flipped
	var feet_x := FEET_X if _facing > 0 else width - FEET_X
	# The item hangs from its feet, centred on this node's position.
	var icon: Array = SeatView.item_art(item)[0]
	var icon_size := Vector2(icon[0].length(), icon.size())
	PixelArt.draw_colored(self, art, COLORS, Vector2(-feet_x * PX, -icon_size.y / 2 - art.size() * PX).floor(), PX)
	if _carrying:
		var art_colors: Dictionary = SeatView.item_art(item)[1]
		PixelArt.draw_colored(self, icon, art_colors, (-icon_size / 2).floor(), 1)

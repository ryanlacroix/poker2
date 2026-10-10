class_name LeechBeam
extends Control
## A leech draining its victim: a soft gold beam from victim to caster that slowly fades in, with
## motes of gold drifting along it toward the caster, then slowly fades out and frees itself.
## Full-screen and click-through; set [member from] and [member to] before adding it.

const FADE_IN_SECONDS := 0.6
const HOLD_SECONDS := 0.5
const FADE_OUT_SECONDS := 0.8
## The whole beam, start to finish.
const SECONDS := FADE_IN_SECONDS + HOLD_SECONDS + FADE_OUT_SECONDS
const MOTES := 7
## How long a mote takes to drift from one end of the beam to the other.
const MOTE_SECONDS := 1.1
## How far motes weave either side of the beam.
const MOTE_WEAVE := 3.0

## Ends of the beam (local coordinates): the victim's portrait, then the caster's.
var from: Vector2
var to: Vector2

var _age := 0.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	modulate.a = 0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, FADE_IN_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(HOLD_SECONDS)
	tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(queue_free)


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()


func _draw() -> void:
	# A wide, faint glow round a thin pale core, breathing gently: no hot centre, unlike a shot.
	var breath := 0.8 + 0.2 * sin(_age * 5.0)
	draw_line(from, to, Color(PixelArt.GOLD, 0.1 * breath), 13)
	draw_line(from, to, Color(PixelArt.GOLD, 0.2 * breath), 7)
	draw_line(from, to, Color(PixelArt.GOLD, 0.4 * breath), 3)
	draw_line(from, to, Color("fff2c0", 0.55 * breath), 1)

	# Motes drift from victim to caster, weaving about the beam, brightest midway.
	var across := (to - from).orthogonal().normalized()
	for i in MOTES:
		var k := fmod(_age / MOTE_SECONDS + float(i) / MOTES, 1.0)
		var p := (from.lerp(to, k) + across * sin((k * 2.0 + float(i) / MOTES) * TAU) * MOTE_WEAVE).floor()
		var alpha := sin(k * PI)
		draw_rect(Rect2(p - Vector2(1, 1), Vector2(3, 3)), Color(PixelArt.GOLD, 0.6 * alpha))
		draw_rect(Rect2(p, Vector2.ONE), Color(Color.WHITE, 0.9 * alpha))

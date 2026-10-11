class_name HexMist
extends Control
## A hex being cast: the table suddenly dims and a blood-red mist drifts across it, then the mist
## fades away and the table brightens again, and this frees itself. Full-screen and click-through;
## meant to sit just over the table's own drawing, under the seats, cards and buttons.

const DARKEN_SECONDS := 0.2
## How long the mist drifts across the dimmed table before fading.
const DRIFT_SECONDS := 1.0
const FADE_OUT_SECONDS := 0.6
## How dark the table gets (alpha of the black over it).
const DARKNESS := 0.6
const MIST_COLOR := Color("8a0c18")
## Strongest alpha of the mist's thickest wisps.
const MIST_ALPHA := 0.5
## How far each layer of mist drifts, start to finish (the far layer drifts slower).
const DRIFT_DISTANCE := 90.0
const FAR_DRIFT_DISTANCE := 45.0
## The mist is drawn this many screen pixels per texel, to match the chunky pixel art.
const PIXEL_SCALE := 2
## Shades the mist's alpha is stepped into, rather than a smooth gradient.
const ALPHA_STEPS := 5

static var _mist_texture: Texture2D

var _darkness := 0.0
var _mist := 0.0
var _age := 0.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	if _mist_texture == null:
		_mist_texture = _build_mist(get_viewport_rect().size)
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		_darkness = t * DARKNESS
		_mist = t, 0.0, 1.0, DARKEN_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_interval(DRIFT_SECONDS)
	tween.tween_method(func(t: float) -> void:
		_darkness = t * DARKNESS
		_mist = t, 1.0, 0.0, FADE_OUT_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(queue_free)


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, _darkness))
	# Two layers drifting left to right at different speeds; the far one flipped so they don't line
	# up, and fainter.
	var k := _age / (DARKEN_SECONDS + DRIFT_SECONDS + FADE_OUT_SECONDS)
	var tex_size := _mist_texture.get_size() * PIXEL_SCALE
	var far_x := -FAR_DRIFT_DISTANCE + k * FAR_DRIFT_DISTANCE
	draw_texture_rect(_mist_texture, Rect2(Vector2(far_x + tex_size.x, 0).floor(), Vector2(-tex_size.x, tex_size.y)),
		false, Color(MIST_COLOR, 0.6 * _mist))
	var near_x := -DRIFT_DISTANCE + k * DRIFT_DISTANCE
	draw_texture_rect(_mist_texture, Rect2(Vector2(near_x, 0).floor(), tex_size), false, Color(MIST_COLOR, _mist))


## Wisps of mist as a white texture whose alpha is the mist's thickness, wide enough to cover
## [param screen] however far it drifts.
static func _build_mist(screen: Vector2) -> Texture2D:
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.025
	noise.fractal_octaves = 3
	var w := ceili((screen.x + DRIFT_DISTANCE) / PIXEL_SCALE)
	var h := ceili(screen.y / PIXEL_SCALE)
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			# Stretched sideways, so the wisps lie along the way they drift.
			var n := noise.get_noise_2d(x * 0.5, y)
			var thick := clampf((n + 0.15) / 0.6, 0.0, 1.0)
			var alpha := floorf(thick * thick * ALPHA_STEPS) / ALPHA_STEPS
			image.set_pixel(x, y, Color(1, 1, 1, alpha * MIST_ALPHA))
	return ImageTexture.create_from_image(image)

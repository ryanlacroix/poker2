class_name PotView
extends Control
## The pot display under the board: a pixel-art pot of gold followed by the amount ("$70"),
## centred as a unit. [member font_size] drives the pop animation. As the pot grows (see
## [method grow_to]) the amount slowly swells and warms from gold through orange to red; the pot
## of gold itself always stays the same size. When the pot empties (it's been won), the display
## fades out quickly, sinking a little as it goes, as it last looked.

const GAP := 4
## The pot of gold is drawn this many times its size, always.
const ICON_SCALE := 2
## At full growth the amount is this many times its resting size...
const MAX_GROWTH_SCALE := 2.0
## ...and this colour, having gone through ORANGE halfway there.
const ORANGE := Color("ff8a30")
const HOT := PixelArt.HEART_RED
## How quickly [member growth] closes on its target: the share of the gap closed each second.
const GROWTH_RATE := 1.5
## Once the pot empties, how long the display takes to fade out, and how far it sinks meanwhile.
const FADE_SECONDS := 0.35
const FADE_FALL := 10.0
## The amount's hard-edged shadow, down and to the right: 1 pixel at the resting size, plus a pixel
## for every this many points the text has grown.
const SHADOW_COLOR := Color.BLACK
const SHADOW_STEP := 16.0

var amount := 0:
	set(value):
		if value <= 0 and amount > 0:
			# Keep showing the pot as it was while it fades out.
			_faded_amount = amount
			_faded_growth = growth
			_faded_font_size = font_size
			_fade_age = 0.0
			set_process(true)
		elif value > 0:
			_fade_age = -1.0
		amount = value
		queue_redraw()

var font_size := UiTheme.FONT_SIZE:
	set(value):
		font_size = value
		queue_redraw()

## How grown the amount is, 0 (resting) to 1 (full size, red); eases toward [method grow_to]'s target.
var growth := 0.0
var _target_growth := 0.0
# The pot as it was when it emptied, and how long ago that was (-1 = not fading).
var _faded_amount := 0
var _faded_growth := 0.0
var _faded_font_size := 0
var _fade_age := -1.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_process(false)


## Eases [member growth] toward [param target] (0 to 1). Shrinking (a new hand's pot) is instant.
func grow_to(target: float) -> void:
	_target_growth = clampf(target, 0.0, 1.0)
	if _target_growth < growth:
		growth = _target_growth
		queue_redraw()
	set_process(not is_equal_approx(growth, _target_growth) or _fade_age >= 0)


func _process(delta: float) -> void:
	growth = lerpf(growth, _target_growth, 1.0 - exp(-GROWTH_RATE * delta))
	if absf(_target_growth - growth) < 0.002:
		growth = _target_growth
	if _fade_age >= 0:
		_fade_age += delta
		if _fade_age >= FADE_SECONDS:
			_fade_age = -1.0
	set_process(growth != _target_growth or _fade_age >= 0)
	queue_redraw()


## The amount's colour at [param k] growth: gold, through orange, to red.
static func growth_color(k: float) -> Color:
	return PixelArt.GOLD.lerp(ORANGE, k * 2) if k < 0.5 else ORANGE.lerp(HOT, (k - 0.5) * 2)


func _draw() -> void:
	if amount > 0:
		_draw_pot(amount, growth, font_size, Color.WHITE)
	elif _fade_age >= 0:
		# Eased out, so it drops away quickly and settles as it vanishes.
		var k := 1.0 - pow(1.0 - _fade_age / FADE_SECONDS, 2)
		draw_set_transform(Vector2(0, roundf(FADE_FALL * k)))
		_draw_pot(_faded_amount, _faded_growth, _faded_font_size, Color(1, 1, 1, 1.0 - k))
		draw_set_transform(Vector2.ZERO)


## The pot of gold and [param pot_amount], at [param k] growth and [param base_size] before
## growing, tinted by [param tint] (for fading).
func _draw_pot(pot_amount: int, k: float, base_size: int, tint: Color) -> void:
	var font := get_theme_default_font()
	var text := "$%d" % pot_amount
	var text_size := roundi(base_size * lerpf(1.0, MAX_GROWTH_SCALE, k))
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
	var icon := Vector2(PixelArt.POT_OF_GOLD[0].length(), PixelArt.POT_OF_GOLD.size()) * ICON_SCALE

	var left := floorf((size.x - (icon.x + GAP + text_width)) / 2)
	var mid_y := size.y / 2
	var icon_colors := {}
	for key: String in PixelArt.POT_OF_GOLD_COLORS:
		icon_colors[key] = PixelArt.POT_OF_GOLD_COLORS[key] * tint
	PixelArt.draw_colored(self, PixelArt.POT_OF_GOLD, icon_colors, Vector2(left, floorf(mid_y - icon.y / 2)), ICON_SCALE)

	# Baseline that vertically centres the text's cap height on the icon.
	var baseline := floorf(mid_y + (font.get_ascent(text_size) - font.get_descent(text_size)) / 2)
	var at := Vector2(left + icon.x + GAP, baseline)
	var shadow := float(maxi(1, roundi(text_size / SHADOW_STEP)))
	draw_string(font, at + Vector2(shadow, shadow), text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, SHADOW_COLOR * tint)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, growth_color(k) * tint)

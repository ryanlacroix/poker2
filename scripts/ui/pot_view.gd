class_name PotView
extends Control
## The pot display under the board: a pixel-art pot of gold followed by the amount ("$70"),
## centred as a unit. [member font_size] drives the pop animation; the icon steps up
## in whole-pixel scales alongside the text so it stays crisp.

const GAP := 4

var amount := 0:
	set(value):
		amount = value
		queue_redraw()

var font_size := UiTheme.FONT_SIZE:
	set(value):
		font_size = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func _draw() -> void:
	if amount <= 0:
		return

	var font := get_theme_default_font()
	var text := "$%d" % amount
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

	# Icon roughly as tall as the text: 2x at the resting size, 3x at the peak of a pop.
	var px := maxi(1, roundi(font_size / 9.0))
	var icon := Vector2(PixelArt.POT_OF_GOLD[0].length(), PixelArt.POT_OF_GOLD.size()) * px

	var left := floorf((size.x - (icon.x + GAP + text_width)) / 2)
	var mid_y := size.y / 2
	PixelArt.draw_colored(self, PixelArt.POT_OF_GOLD, PixelArt.POT_OF_GOLD_COLORS,
		Vector2(left, floorf(mid_y - icon.y / 2)), px)

	# Baseline that vertically centres the text's cap height on the icon.
	var baseline := floorf(mid_y + (font.get_ascent(font_size) - font.get_descent(font_size)) / 2)
	draw_string(font, Vector2(left + icon.x + GAP, baseline), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, PixelArt.GOLD)

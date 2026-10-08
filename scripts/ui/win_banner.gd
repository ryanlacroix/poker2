class_name WinBanner
extends Control
## Big centred announcement of the winning hand ("FULL HOUSE") with the winner's name under it.
## Text is drawn at the normal font size and blown up by a whole-number scale, so each font
## pixel becomes a crisp block. Shown for [constant HOLD_TIME], then fades out.

## Emitted once the banner has faded out (not when it's cut short by [method hide_banner]).
signal finished

const HOLD_TIME := 2.0
const FADE_TIME := 0.4
const MAX_TITLE_SCALE := 3
const OUTLINE_SIZE := 4 # in unscaled font pixels: 2 on each side
const SIDE_MARGIN := 8
const LINE_GAP := 4

## Lowest y the text may reach; the banner rises above it (e.g. to clear the board).
var max_bottom := INF

var _title := ""
var _subtitle := ""
var _tween: Tween


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	visible = false


func show_banner(title: String, subtitle: String) -> void:
	_title = title
	_subtitle = subtitle
	if _tween:
		_tween.kill()
	modulate = Color.WHITE
	visible = true
	queue_redraw()
	_tween = create_tween()
	_tween.tween_interval(HOLD_TIME)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	_tween.tween_callback(func() -> void:
		visible = false
		finished.emit())


func hide_banner() -> void:
	if _tween:
		_tween.kill()
	visible = false


func _draw() -> void:
	var font := get_theme_default_font()
	var font_size := UiTheme.FONT_SIZE

	# Largest whole-number scale that keeps the title on screen; the name goes one step smaller.
	var title_width := font.get_string_size(_title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + OUTLINE_SIZE
	var title_scale := MAX_TITLE_SCALE
	while title_scale > 1 and title_width * title_scale > size.x - SIDE_MARGIN * 2:
		title_scale -= 1
	var subtitle_scale := maxi(1, title_scale - 1)

	var line_height := font.get_height(font_size)
	var total_height := line_height * title_scale + LINE_GAP + line_height * subtitle_scale
	var top := floorf(minf(size.y / 2 - total_height / 2, max_bottom - total_height))
	_draw_line(font, font_size, _title, title_scale, top)
	_draw_line(font, font_size, _subtitle, subtitle_scale, top + line_height * title_scale + LINE_GAP)
	draw_set_transform(Vector2.ZERO)


## White text with a black outline, centred horizontally, its top at [param top].
func _draw_line(font: Font, font_size: int, text: String, text_scale: int, top: float) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x * text_scale
	var origin := Vector2(floorf((size.x - width) / 2), top)
	draw_set_transform(origin, 0, Vector2.ONE * text_scale)
	var baseline := Vector2(0, font.get_ascent(font_size))
	draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, OUTLINE_SIZE, Color.BLACK)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

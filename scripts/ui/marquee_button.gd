class_name MarqueeButton
extends Button
## A button that keeps the size it's given however long its text: text that fits sits still and
## centred, as on any button, but text too long to fit scrolls sideways within it, smoothly. It
## holds at the start for [constant HOLD_SECONDS], scrolls to the end, holds there, then starts
## again from the beginning. Set [member text] as usual; set [member text_color] (not a theme
## override) to recolour it. A [member side_icon] sits just right of the text, and stays put at
## the right while the text scrolls beside it.

## How fast too-long text scrolls, in pixels a second.
const SCROLL_SPEED := 30.0
## How long too-long text holds still at each end.
const HOLD_SECONDS := 1.0
## Room kept clear between the text and the inside of the button's frame, at each side.
const PADDING := 3.0
## [member side_icon] is drawn this many times its size (1 = as on the seats), this far from the text.
const ICON_SCALE := 1
const ICON_GAP := 8.0
const FONT_COLORS: Array[StringName] = [
	&"font_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color",
	&"font_focus_color", &"font_disabled_color",
]

## Replaces the theme's font colour in every state while its alpha is above 0.
var text_color := Color.TRANSPARENT
## A picture shown just right of the text (null = none). The button is made tall enough for it.
var side_icon: Texture2D:
	set(value):
		side_icon = value
		_icon.texture = value
		_icon.visible = value != null
		if value:
			var box := get_theme_stylebox("normal") if is_inside_tree() else null
			var frame := box.get_margin(SIDE_TOP) + box.get_margin(SIDE_BOTTOM) if box else 8.0
			custom_minimum_size.y = maxf(custom_minimum_size.y, value.get_height() * ICON_SCALE + frame + 4)

# The button draws its own text invisibly (for its height and focus); this label shows it instead,
# clipped to the space inside the button's frame.
var _clip := Control.new()
var _label := Label.new()
var _icon := TextureRect.new()
# The theme's font colour for each state, from before they were hidden.
var _theme_colors := {}
var _scroll_time := 0.0


func _ready() -> void:
	clip_text = true # the text no longer widens the button
	for state in FONT_COLORS:
		_theme_colors[state] = get_theme_color(state)
		add_theme_color_override(state, Color.TRANSPARENT)
	# The button's own text outline would still show through, so the label wears it instead.
	_label.add_theme_color_override("font_outline_color", get_theme_color("font_outline_color"))
	_label.add_theme_constant_override("outline_size", get_theme_constant("outline_size"))
	add_theme_constant_override("outline_size", 0)
	_clip.clip_contents = true
	_clip.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_clip, false, INTERNAL_MODE_FRONT)
	_label.mouse_filter = MOUSE_FILTER_IGNORE
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_copy_font()
	_clip.add_child(_label)
	_icon.mouse_filter = MOUSE_FILTER_IGNORE
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.visible = side_icon != null
	add_child(_icon, false, INTERNAL_MODE_FRONT)


## A drop shadow behind the text, [param offset] down and right of it.
func set_text_shadow(color: Color, offset: Vector2i) -> void:
	_label.add_theme_color_override("font_shadow_color", color)
	_label.add_theme_constant_override("shadow_offset_x", offset.x)
	_label.add_theme_constant_override("shadow_offset_y", offset.y)


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_copy_font()


## The label wears the button's font, kept up to date if the theme's font changes.
func _copy_font() -> void:
	_label.add_theme_font_override("font", get_theme_font("font"))
	_label.add_theme_font_size_override("font_size", get_theme_font_size("font_size"))


func _process(delta: float) -> void:
	if _label.text != text:
		_label.text = text
		_scroll_time = 0.0
	var box := get_theme_stylebox("normal")
	var inset := Vector2(box.get_margin(SIDE_LEFT) + PADDING, box.get_margin(SIDE_TOP))
	var area := Rect2(inset, size - inset - Vector2(box.get_margin(SIDE_RIGHT) + PADDING, box.get_margin(SIDE_BOTTOM)))
	# Room the icon (and the gap before it) takes from the text.
	var icon_size := side_icon.get_size() * ICON_SCALE if side_icon else Vector2.ZERO
	var reserved := icon_size.x + ICON_GAP if side_icon else 0.0
	_clip.position = area.position
	_clip.size = Vector2(area.size.x - reserved, area.size.y)
	var text_width := _label.get_minimum_size().x
	var overflow := text_width - _clip.size.x
	_label.size = Vector2(text_width, _clip.size.y)
	if overflow <= 0:
		# The text and icon, centred together.
		_scroll_time = 0.0
		_label.position = Vector2(roundf((area.size.x - text_width - reserved) / 2), 0)
	else:
		_scroll_time += delta
		_label.position = Vector2(-roundf(_scroll_offset(overflow)), 0)
	if side_icon:
		var icon_x := area.position.x + _label.position.x + text_width + ICON_GAP if overflow <= 0 \
			else area.end.x - icon_size.x
		_icon.position = Vector2(roundf(icon_x), roundf(area.get_center().y - icon_size.y / 2))
		_icon.size = icon_size
	_label.add_theme_color_override("font_color", _font_color())


## How far along too-long text has scrolled, [param overflow] being how much doesn't fit: held at
## the start, scrolling to the end, held there, then round again.
func _scroll_offset(overflow: float) -> float:
	var scroll_seconds := overflow / SCROLL_SPEED
	var t := fmod(_scroll_time, HOLD_SECONDS * 2 + scroll_seconds)
	return clampf((t - HOLD_SECONDS) * SCROLL_SPEED, 0.0, overflow)


## The text's colour for the button's state right now.
func _font_color() -> Color:
	if text_color.a > 0:
		return text_color
	if disabled:
		return _theme_colors[&"font_disabled_color"]
	if is_pressed() or get_draw_mode() == DRAW_PRESSED:
		return _theme_colors[&"font_hover_pressed_color" if is_hovered() else &"font_pressed_color"]
	if is_hovered():
		return _theme_colors[&"font_hover_color"]
	if has_focus():
		return _theme_colors[&"font_focus_color"]
	return _theme_colors[&"font_color"]

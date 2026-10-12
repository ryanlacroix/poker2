class_name UiTheme
extends RefCounted
## Builds the theme used by every Control: gilded pixel frames (see [Ornament]) in the colours of
## [member InterfaceStyle.current].

## Drop a pixel font here (e.g. m5x7, Pixel Operator) and it is picked up automatically.
const FONT_PATH := "res://assets/fonts/pixel_font.ttf"

## UI text size, and the height of one line of it (measured for the default font).
const FONT_SIZE := 14
const LINE_HEIGHT := 20


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = FONT_SIZE
	if ResourceLoader.exists(FONT_PATH):
		theme.default_font = load(FONT_PATH)

	var style := InterfaceStyle.current
	theme.set_stylebox("normal", "Button", Ornament.frame_box(style.button_normal, style.trim, style.trim_dark))
	theme.set_stylebox("hover", "Button", Ornament.frame_box(style.button_hover, style.trim_light, style.trim))
	theme.set_stylebox("pressed", "Button", Ornament.frame_box(style.button_pressed, style.trim_dark, style.trim_dark))
	theme.set_stylebox("disabled", "Button", Ornament.frame_box(style.button_disabled, Color("555a6a"), Color("3a3e4c")))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_color("font_color", "Button", PixelArt.PAPER)
	theme.set_color("font_hover_color", "Button", PixelArt.GOLD)
	theme.set_color("font_pressed_color", "Button", PixelArt.GOLD)
	theme.set_color("font_focus_color", "Button", PixelArt.PAPER)
	theme.set_color("font_disabled_color", "Button", Color("6a6f80"))
	theme.set_color("font_outline_color", "Button", PixelArt.INK)
	theme.set_constant("outline_size", "Button", 2)
	theme.set_stylebox("panel", "Panel", Ornament.frame_box(Color(style.panel, 0.91), style.brass, style.brass_dark))
	theme.set_stylebox("panel", "PanelContainer", Ornament.frame_box(Color(style.panel, 0.94), style.trim, style.trim_dark, 10, 10))
	theme.set_color("font_color", "Label", PixelArt.PAPER)

	# Raise slider: a sunken groove filled with gold up to a gem grabber.
	var groove := _box(style.groove, style.brass_dark)
	groove.content_margin_top = 2
	groove.content_margin_bottom = 2
	theme.set_stylebox("slider", "HSlider", groove)
	var filled := _box(style.trim_dark, style.brass_dark)
	filled.border_color = style.trim
	filled.set_border_width_all(0)
	filled.border_width_top = 1
	theme.set_stylebox("grabber_area", "HSlider", filled)
	theme.set_stylebox("grabber_area_highlight", "HSlider", filled)
	theme.set_icon("grabber", "HSlider", Ornament.gem_texture(6))
	theme.set_icon("grabber_highlight", "HSlider", Ornament.gem_texture(6, true))
	return theme


## Adds [param control] to [param parent], then sets its rect, and returns it.
## Sizing must happen after add_child: outside the tree a Control measures itself with
## the engine's default 16px font, and the inflated size never shrinks back.
static func add_at(parent: Node, control: Control, position: Vector2, size: Vector2) -> Control:
	parent.add_child(control)
	control.position = position
	control.size = size
	return control


static func _box(bg: Color, border: Color, margin := 3) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.anti_aliasing = false
	box.set_border_width_all(1)
	box.set_content_margin_all(margin)
	return box

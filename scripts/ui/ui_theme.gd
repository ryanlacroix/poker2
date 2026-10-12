class_name UiTheme
extends RefCounted
## Builds the global theme used by every Control: gilded pixel frames (see [Ornament]).

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

	theme.set_stylebox("normal", "Button", Ornament.frame_box(Color("2d3a5a"), PixelArt.GOLD, Ornament.GOLD_DARK))
	theme.set_stylebox("hover", "Button", Ornament.frame_box(Color("3d4f7a"), Ornament.GOLD_LIGHT, PixelArt.GOLD))
	theme.set_stylebox("pressed", "Button", Ornament.frame_box(Color("1f2840"), Ornament.GOLD_DARK, Ornament.GOLD_DARK))
	theme.set_stylebox("disabled", "Button", Ornament.frame_box(Color("23283a"), Color("555a6a"), Color("3a3e4c")))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_color("font_color", "Button", PixelArt.PAPER)
	theme.set_color("font_hover_color", "Button", PixelArt.GOLD)
	theme.set_color("font_pressed_color", "Button", PixelArt.GOLD)
	theme.set_color("font_focus_color", "Button", PixelArt.PAPER)
	theme.set_color("font_disabled_color", "Button", Color("6a6f80"))
	theme.set_color("font_outline_color", "Button", PixelArt.INK)
	theme.set_constant("outline_size", "Button", 2)
	theme.set_stylebox("panel", "Panel", Ornament.frame_box(Color("141826e8"), Ornament.BRASS, Ornament.BRASS_DARK))
	theme.set_stylebox("panel", "PanelContainer", Ornament.frame_box(Color("141826f0"), PixelArt.GOLD, Ornament.GOLD_DARK, 10, 10))
	theme.set_color("font_color", "Label", PixelArt.PAPER)

	# Raise slider: a sunken groove filled with gold up to a gem grabber.
	var groove := _box(Color("0c0f1a"), Ornament.BRASS_DARK)
	groove.content_margin_top = 2
	groove.content_margin_bottom = 2
	theme.set_stylebox("slider", "HSlider", groove)
	var filled := _box(Ornament.GOLD_DARK, Ornament.BRASS_DARK)
	filled.border_color = PixelArt.GOLD
	filled.set_border_width_all(0)
	filled.border_width_top = 1
	theme.set_stylebox("grabber_area", "HSlider", filled)
	theme.set_stylebox("grabber_area_highlight", "HSlider", filled)
	theme.set_icon("grabber", "HSlider", Ornament.gem_texture(6))
	theme.set_icon("grabber_highlight", "HSlider", Ornament.gem_texture(6, Ornament.GOLD_LIGHT))
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

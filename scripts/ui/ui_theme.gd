class_name UiTheme
extends RefCounted
## Builds the global flat, square-cornered theme used by every Control.

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

	theme.set_stylebox("normal", "Button", _box(Color("2d3a5a"), PixelArt.PAPER))
	theme.set_stylebox("hover", "Button", _box(Color("3d4f7a"), PixelArt.GOLD))
	theme.set_stylebox("pressed", "Button", _box(Color("1f2840"), PixelArt.GOLD))
	theme.set_stylebox("disabled", "Button", _box(Color("23283a"), Color("555a6a")))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_color("font_color", "Button", PixelArt.PAPER)
	theme.set_color("font_hover_color", "Button", PixelArt.GOLD)
	theme.set_color("font_disabled_color", "Button", Color("6a6f80"))
	theme.set_stylebox("panel", "Panel", _box(Color("141826e0"), Color("4a5270")))
	theme.set_stylebox("panel", "PanelContainer", _box(Color("141826f0"), PixelArt.GOLD, 8))
	theme.set_color("font_color", "Label", PixelArt.PAPER)
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

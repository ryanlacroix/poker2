extends Control
## Title screen: the title, the gambler (see tools/generate_menu_art.py) under a spotlight,
## and JOIN TABLE.

const GAMBLER_PATH := "res://assets/sprites/menu_gambler.png"
const BACKDROP := Color("0d0f1a")
## Spotlight rings behind the gambler, outermost first: (radius as a share of his width, colour).
const SPOTLIGHT := [[0.78, Color("121626")], [0.6, Color("171c30")], [0.42, Color("1d2440")]]
## Room kept for the title, the JOIN TABLE button and the gaps around the gambler.
const RESERVED_HEIGHT := 150.0
const SIDE_MARGIN := 12.0

var _gambler := TextureRect.new()


func _ready() -> void:
	resized.connect(_fit_gambler)

	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)

	var title := Label.new()
	title.text = "poker2"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", PixelArt.GOLD)
	box.add_child(title)

	_gambler.texture = load(GAMBLER_PATH)
	_gambler.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_gambler.stretch_mode = TextureRect.STRETCH_SCALE
	_gambler.size_flags_horizontal = SIZE_SHRINK_CENTER
	_gambler.item_rect_changed.connect(queue_redraw)
	box.add_child(_gambler)
	_fit_gambler()

	var play := _button("JOIN TABLE")
	play.size_flags_horizontal = SIZE_SHRINK_CENTER
	play.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/table.tscn"))
	box.add_child(play)
	play.grab_focus.call_deferred()


## Shows the gambler at the largest whole-number scale that fits, so his pixels stay crisp.
func _fit_gambler() -> void:
	var art := _gambler.texture.get_size()
	var fit := minf((size.x - SIDE_MARGIN * 2) / art.x, (size.y - RESERVED_HEIGHT) / art.y)
	_gambler.custom_minimum_size = art * maxf(1, floorf(fit))
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKDROP)
	# Stepped rings of light, centred a little above the middle of the gambler.
	var rect := Rect2(_gambler.global_position - global_position, _gambler.size)
	var center := (rect.get_center() - Vector2(0, rect.size.y * 0.08)).round()
	for ring: Array in SPOTLIGHT:
		draw_circle(center, roundf(rect.size.x * ring[0]), ring[1])


static func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(160, 36)
	return button

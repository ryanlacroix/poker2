extends Control
## Title screen: the splash art filling the screen and slowly drifting inside a gilt border, with
## the title and a gilded rule sitting just above JOIN TABLE near the bottom.

const SPLASH_PATH := "res://assets/sprites/poker-splash.png"
## Furthest the splash drifts from centre, in pixels, and how long one full sway takes.
const DRIFT := Vector2(8, 5)
const DRIFT_PERIOD := 16.0
## Gap below the button.
const EDGE_MARGIN := 80.0
## Gap between the title, the gilded rule under it and the button.
const TITLE_GAP := 12.0
const RULE_WIDTH := 220.0
const RULE_HEIGHT := 9.0
## How far the gilt border round the screen sits in from its edges.
const BORDER_INSET := 6.0
## Where the vignette starts darkening, as a share of the centre-to-corner distance.
const VIGNETTE_START := 0.45
## On load the splash fades in from black, then the title and button fade in together.
const SPLASH_FADE := 0.7
const UI_FADE := 1.0

var _splash: Texture2D = load(SPLASH_PATH)
var _splash_alpha := 0.0
var _time := 0.0


func _ready() -> void:
	resized.connect(queue_redraw)
	add_child(_vignette())
	add_child(_gilt_border())

	var box := VBoxContainer.new()
	box.set_anchors_preset(PRESET_FULL_RECT)
	box.offset_bottom = -EDGE_MARGIN
	box.alignment = BoxContainer.ALIGNMENT_END
	box.add_theme_constant_override("separation", TITLE_GAP)
	add_child(box)

	var title := Label.new()
	title.text = "poker2"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", PixelArt.GOLD)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	box.add_child(title)

	# A gilded rule under the title, about as wide as it.
	var rule := Control.new()
	rule.custom_minimum_size = Vector2(RULE_WIDTH, RULE_HEIGHT)
	rule.size_flags_horizontal = SIZE_SHRINK_CENTER
	rule.draw.connect(func() -> void:
		Ornament.draw_rule(rule, 0, rule.size.x, floorf(rule.size.y / 2), true))
	box.add_child(rule)

	var play := _button("JOIN TABLE")
	play.size_flags_horizontal = SIZE_SHRINK_CENTER
	play.pressed.connect(func() -> void:
		GameConfig.table_number = 1
		get_tree().change_scene_to_file("res://scenes/table.tscn"))
	box.add_child(play)
	play.grab_focus.call_deferred()

	box.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "_splash_alpha", 1.0, SPLASH_FADE)
	tween.tween_property(box, "modulate:a", 1.0, UI_FADE)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	# Cover the screen with room to spare for the drift, so no edge ever shows.
	var art := _splash.get_size()
	var zoom := maxf((size.x + DRIFT.x * 2) / art.x, (size.y + DRIFT.y * 2) / art.y)
	var drawn := art * zoom
	# A slow figure-eight sway around centre.
	var phase := _time / DRIFT_PERIOD * TAU
	var offset := Vector2(sin(phase), sin(phase * 2)) * DRIFT
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	draw_texture_rect(_splash, Rect2(((size - drawn) / 2 + offset).round(), drawn), false,
			Color(1, 1, 1, _splash_alpha))


## A black fade around the screen edges, stretched to the screen so it follows its shape.
static func _vignette() -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0, 0, 0, 0))
	gradient.set_offset(0, VIGNETTE_START)
	gradient.set_color(1, Color.BLACK)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	# Reach full black exactly at the corners.
	texture.fill_to = Vector2(0.5 + sqrt(0.5), 0.5)
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_preset(PRESET_FULL_RECT)
	# Smooth, not pixelated, so the fade has no visible steps.
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	rect.mouse_filter = MOUSE_FILTER_IGNORE
	return rect


## A gilt frame inset round the screen, with a gem at the middle of each side.
static func _gilt_border() -> Control:
	var border := Control.new()
	border.set_anchors_preset(PRESET_FULL_RECT)
	border.mouse_filter = MOUSE_FILTER_IGNORE
	var box := Ornament.frame_box(Color(0, 0, 0, 0), PixelArt.GOLD, Ornament.GOLD_DARK)
	border.draw.connect(func() -> void:
		var rect := Rect2(Vector2.ZERO, border.size).grow(-BORDER_INSET)
		box.draw(border.get_canvas_item(), rect)
		var mid := (rect.get_center() - Vector2.ONE * 0.5).floor()
		for gem: Vector2 in [Vector2(mid.x, rect.position.y + 1), Vector2(mid.x, rect.end.y - 2),
				Vector2(rect.position.x + 1, mid.y), Vector2(rect.end.x - 2, mid.y)]:
			Ornament.draw_gem(border, gem, 3))
	border.resized.connect(border.queue_redraw)
	return border


static func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(160, 36)
	return button

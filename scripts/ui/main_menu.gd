extends Control
## Title screen.

var _world_map: Texture2D = load(UiTheme.WORLD_MAP_PATH)


func _ready() -> void:
	resized.connect(queue_redraw)

	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)

	var title := Label.new()
	title.text = "PIXEL POKER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", PixelArt.GOLD)
	box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "No-limit Texas Hold'em"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	box.add_child(spacer)

	var play := _button("PLAY")
	play.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/table.tscn"))
	box.add_child(play)
	var quit := _button("QUIT")
	quit.pressed.connect(func() -> void: get_tree().quit())
	box.add_child(quit)
	play.grab_focus.call_deferred()


func _draw() -> void:
	UiTheme.draw_world_map(self, _world_map, size)


static func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(160, 36)
	return button

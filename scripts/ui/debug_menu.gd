class_name DebugMenu
extends Control
## Modal popup of debug / testing actions, opened from the table's DEBUG button. Dims the
## screen and blocks input to the table; clicking outside the panel (or CLOSE) dismisses it.

## Emitted when a "give" action is picked; the menu closes itself.
signal give_item(item: Item.Kind)

## Draws over everything on the table, including portraits and the gun.
const MODAL_Z := 10


func _ready() -> void:
	visible = false
	z_index = MODAL_Z
	mouse_filter = MOUSE_FILTER_IGNORE

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			hide())
	add_child(dim)

	var center := CenterContainer.new()
	center.mouse_filter = MOUSE_FILTER_IGNORE
	center.set_anchors_preset(PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var title := Label.new()
	title.text = "DEBUG"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", PixelArt.GOLD)
	box.add_child(title)
	_add_button(box, "GIVE GUN", _give.bind(Item.Kind.GUN))
	_add_button(box, "GIVE SHIELD", _give.bind(Item.Kind.SHIELD))
	_add_button(box, "CLOSE", hide)


static func _add_button(box: Container, text: String, on_pressed: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(160, 36)
	button.pressed.connect(on_pressed)
	box.add_child(button)


func _give(item: Item.Kind) -> void:
	hide()
	give_item.emit(item)

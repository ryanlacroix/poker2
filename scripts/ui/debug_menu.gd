class_name DebugMenu
extends Control
## Modal popup of debug / testing actions, opened from the table's DEBUG button. Dims the
## screen and blocks input to the table; clicking outside the panel (or CLOSE) dismisses it.

## Emitted when a "give" action is picked; the menu closes itself.
signal give_item(item: Item.Kind)
## Emitted when a "give" action for a particular hex is picked; the menu closes itself.
signal give_hex(effect: Hex.Effect)
## Emitted when GIVE NPCS STIMPAKS is picked; the menu closes itself.
signal give_npcs_stimpaks
## Emitted when GIVE NPC SHIELD is picked; the menu closes itself.
signal give_npc_shield
## Emitted when GIVE $1000 is picked; the menu closes itself.
signal give_chips(amount: int)
## Emitted when LOSE A HEART is picked; the menu closes itself.
signal lose_heart
## Emitted when SET NPC $50 is picked (the table then has the human pick which); the menu
## closes itself.
signal set_npc_chips(amount: int)
## Emitted when EXPLODE NPC is picked; the menu closes itself.
signal explode_npc
## Emitted when WIN TABLE is picked (shows the win screen, to reach the next table); the
## menu closes itself.
signal win_table

## Draws over everything on the table, including portraits and the gun.
const MODAL_Z := 10
## Chips handed over by GIVE $.
const GIVE_CHIPS := 1000
## What SET NPC $ sets the picked NPC's stack to.
const SET_NPC_CHIPS := 50
## Size of each action button; they're laid out in two columns, with CLOSE under them.
const BUTTON_SIZE := Vector2(150, 36)
const GAP := 8


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
	box.add_theme_constant_override("separation", GAP)
	panel.add_child(box)

	var title := Label.new()
	title.text = "DEBUG"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", PixelArt.GOLD)
	box.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", GAP)
	grid.add_theme_constant_override("v_separation", GAP)
	box.add_child(grid)
	_add_button(grid, "GIVE GUN", _give.bind(Item.Kind.GUN))
	_add_button(grid, "GIVE SHIELD", _give.bind(Item.Kind.SHIELD))
	_add_button(grid, "GIVE STIMPAK", _give.bind(Item.Kind.STIMPAK))
	_add_button(grid, "GIVE NPCS STIMPAKS", _picked(give_npcs_stimpaks.emit))
	_add_button(grid, "GIVE NPC SHIELD", _picked(give_npc_shield.emit))
	for effect: Hex.Effect in Hex.Effect.values():
		_add_button(grid, "GIVE %s HEX" % Hex.display_name(effect), _picked(give_hex.emit.bind(effect)))
	_add_button(grid, "GIVE $%d" % GIVE_CHIPS, _picked(give_chips.emit.bind(GIVE_CHIPS)))
	_add_button(grid, "LOSE A HEART", _picked(lose_heart.emit))
	_add_button(grid, "EXPLODE NPC", _picked(explode_npc.emit))
	_add_button(grid, "SET NPC $%d" % SET_NPC_CHIPS, _picked(set_npc_chips.emit.bind(SET_NPC_CHIPS)))
	_add_button(grid, "WIN TABLE", _picked(win_table.emit))
	# Across both columns.
	_add_button(box, "CLOSE", hide)


static func _add_button(container: Container, text: String, on_pressed: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = BUTTON_SIZE
	button.pressed.connect(on_pressed)
	container.add_child(button)


## Closes the menu, then does [param action].
func _picked(action: Callable) -> Callable:
	return func() -> void:
		hide()
		action.call()


func _give(item: Item.Kind) -> void:
	hide()
	give_item.emit(item)

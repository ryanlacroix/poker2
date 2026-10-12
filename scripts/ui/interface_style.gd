class_name InterfaceStyle
extends RefCounted
## How one table's interface is dressed: the wallpaper, the table's rail, the gilt trim, gems,
## buttons, panels and card backs. Table 1's look is the [constant BASELINE]; each later table
## lists only what it changes in [constant VARIATIONS]. Colours that carry meaning in play
## (gold money, the winner's glow, red damage) are not part of a style and stay the same everywhere.
##
## The table scene makes its level's style [member current] before building its UI; [Ornament],
## [UiTheme] and the views read it from there.

## The little motif in each cell of the wallpaper's trellis.
enum Motif { FLEURON, FLEUR_DE_LIS }

## Table 1. Keys: [code]backdrop[/code] the wallpaper behind the table; [code]rail[/code] the
## table's rail from the outside in (dark edge, lit wood, wood, shadow, inlay) with
## [code]rail_socket[/code] round its studs; [code]trim_*[/code] the gilt of frames and rules,
## [code]brass*[/code] quieter trim; [code]gem*[/code] the gems, studs and slider grabber;
## [code]pinstripe[/code] the line round the inner felt; [code]button_*[/code], [code]panel[/code],
## [code]groove[/code] (the raise slider) and [code]seat_backing[/code] fills; [code]card_back*[/code]
## the backs of the cards and the gem in the middle of the large ones.
const BASELINE := {
	backdrop = Color("16203a"),
	motif = Motif.FLEURON,
	rail = [Color("2a1608"), Color("9a6a3a"), Color("6e4626"), Color("4a2c16"), Color("c8a050")],
	rail_socket = Color("3a2210"),
	trim_light = Color("f8dc78"),
	trim = Color("f0c040"),
	trim_dark = Color("a0701c"),
	brass = Color("b0904a"),
	brass_dark = Color("6a5228"),
	gem_light = Color("f8dc78"),
	gem = Color("f0c040"),
	gem_dark = Color("a0701c"),
	pinstripe = Color(Color("f0c040"), 0.35),
	button_normal = Color("2d3a5a"),
	button_hover = Color("3d4f7a"),
	button_pressed = Color("1f2840"),
	button_disabled = Color("23283a"),
	panel = Color("141826"),
	groove = Color("0c0f1a"),
	seat_backing = Color(0.05, 0.06, 0.11, 0.78),
	card_back = Color("3050a0"),
	card_back_light = Color("5078c8"),
	card_back_gem = Color("c0303a"),
}

## What each table after the first changes from [constant BASELINE] (index 0 is table 2).
## Tables past the last one reuse its style.
const VARIATIONS := [
	# Table 2, THE KING'S COURT: royal purple damask strewn with fleurs-de-lis, an ebony rail,
	# rubies for gems and purple card backs set with gold.
	{
		backdrop = Color("24122e"),
		motif = Motif.FLEUR_DE_LIS,
		rail = [Color("0e080c"), Color("5a3c50"), Color("3a2434"), Color("22121c"), Color("d8b050")],
		rail_socket = Color("0e080c"),
		gem_light = Color("ffa0a8"),
		gem = Color("e0304a"),
		gem_dark = Color("8a1424"),
		button_normal = Color("4a2a5e"),
		button_hover = Color("62397a"),
		button_pressed = Color("2e1a3c"),
		button_disabled = Color("2a2232"),
		panel = Color("1c1024"),
		groove = Color("0e0812"),
		seat_backing = Color(0.08, 0.04, 0.1, 0.8),
		card_back = Color("4a2a7a"),
		card_back_light = Color("7a58b0"),
		card_back_gem = Color("f0c040"),
	},
]

## The style in use: table 1's until a table scene picks its own.
static var current := InterfaceStyle.for_table(1)

var backdrop: Color
var motif: Motif
var rail: Array[Color] = []
var rail_socket: Color
var trim_light: Color
var trim: Color
var trim_dark: Color
var brass: Color
var brass_dark: Color
var gem_light: Color
var gem: Color
var gem_dark: Color
var pinstripe: Color
var button_normal: Color
var button_hover: Color
var button_pressed: Color
var button_disabled: Color
var panel: Color
var groove: Color
var seat_backing: Color
var card_back: Color
var card_back_light: Color
var card_back_gem: Color


## The style of table [param number] (1 = the first): the baseline with that table's changes.
static func for_table(number: int) -> InterfaceStyle:
	var spec := BASELINE.duplicate()
	if number > 1 and not VARIATIONS.is_empty():
		spec.merge(VARIATIONS[mini(number - 2, VARIATIONS.size() - 1)], true)
	return InterfaceStyle.new(spec)


func _init(spec: Dictionary) -> void:
	assert(spec.size() == BASELINE.size(), "a style variation has a key the baseline doesn't")
	for key: String in spec:
		if key == "rail":
			rail.assign(spec.rail)
		else:
			set(key, spec[key])

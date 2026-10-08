class_name TableLevel
extends RefCounted
## One table of the climb: its stakes and how its felt looks. Winning a table (every other
## player out) ascends the player to the next. Tables past the last one in [constant TABLES]
## reuse its setup.

## Table 1 first. Felt colours: [code]felt[/code] is the band inside the wooden rail,
## [code]felt_inner[/code] the lighter felt inside it; [code]textured[/code] adds a faint grain.
const TABLES := [
	{
		starting_chips = 1000, small_blind = 10, big_blind = 20,
		felt = Color("1f6b3a"), felt_inner = Color("247a43"), textured = false,
	},
	{
		starting_chips = 2000, small_blind = 20, big_blind = 40,
		felt = Color("561820"), felt_inner = Color("651d26"), textured = true,
	},
]

var number: int
var starting_chips: int
var small_blind: int
var big_blind: int
var felt: Color
var felt_inner: Color
var textured: bool


## Table [param p_number] (1 = the first).
func _init(p_number: int) -> void:
	number = p_number
	var spec: Dictionary = TABLES[clampi(p_number, 1, TABLES.size()) - 1]
	starting_chips = spec.starting_chips
	small_blind = spec.small_blind
	big_blind = spec.big_blind
	felt = spec.felt
	felt_inner = spec.felt_inner
	textured = spec.textured

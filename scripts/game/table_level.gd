class_name TableLevel
extends RefCounted
## One table of the climb: its stakes and how its felt looks. Winning a table (every other
## player out) ascends the player to the next. Tables past the last one in [constant TABLES]
## reuse its setup.

## Table 1 first. [code]name[/code] is shown at the top of the screen. [code]opponents[/code]
## are the NPC personalities seated there, in seat order (clockwise from the human: up the left
## column, then down the right); the table has room for up to
## [constant PortraitLayout.MAX_OPPONENTS]. Felt colours: [code]felt[/code] is the band inside the wooden rail,
## [code]felt_inner[/code] the lighter felt inside it; [code]textured[/code] adds a faint grain.
const TABLES := [
	{
		name = "AMATEUR HOUR",
		opponents = [
			"res://data/npcs/rocky.tres",    # tight-passive
			"res://data/npcs/lucky.tres",    # calling station
			"res://data/npcs/maverick.tres", # loose-aggressive
			"res://data/npcs/shark.tres",    # tight-aggressive, strongest reader
			"res://data/npcs/doc.tres",      # balanced
			"res://data/npcs/duke.tres",     # maniac
		],
		starting_chips = 1000, small_blind = 10, big_blind = 20,
		felt = Color("1f6b3a"), felt_inner = Color("247a43"), textured = false,
	},
	{
		name = "THE KING'S COURT",
		opponents = [
			"res://data/npcs/peasant.tres",  # timid calling station
			"res://data/npcs/jester.tres",   # maniac
			"res://data/npcs/king.tres",     # loose-aggressive bully
			"res://data/npcs/queen.tres",    # tight-aggressive, strongest reader
			"res://data/npcs/nobleman.tres", # balanced and calculating
			"res://data/npcs/knight.tres",   # tight and honest: never bluffs
		],
		starting_chips = 2000, small_blind = 20, big_blind = 40,
		felt = Color("561820"), felt_inner = Color("651d26"), textured = true,
	},
]

var number: int
var name: String
var opponents: Array[String] = []
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
	name = spec.name
	opponents.assign(spec.opponents)
	starting_chips = spec.starting_chips
	small_blind = spec.small_blind
	big_blind = spec.big_blind
	felt = spec.felt
	felt_inner = spec.felt_inner
	textured = spec.textured

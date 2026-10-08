extends Node
## Global game settings, autoloaded as /root/GameConfig.

## NPC personalities seated at the table, in seat order (clockwise from the human).
## The portrait table has room for up to [constant PortraitLayout.MAX_OPPONENTS].
const OPPONENT_PATHS: Array[String] = [
	"res://data/npcs/rocky.tres",    # tight-passive
	"res://data/npcs/lucky.tres",    # calling station
	"res://data/npcs/maverick.tres", # loose-aggressive
	"res://data/npcs/shark.tres",    # tight-aggressive, strongest reader
	"res://data/npcs/doc.tres",      # balanced
	"res://data/npcs/duke.tres",     # maniac
]

var player_name := "YOU"
var player_portrait_path := "res://assets/portraits/you.png"
var player_injured_portrait_path := "res://assets/portraits/you_injured.png"
var starting_chips := 1000
## Hearts each player starts with (shown under their name).
var starting_hearts := 3
var small_blind := 10
var big_blind := 20
var npc_think_time := 0.8
var deal_delay := 0.4
var showdown_delay := 2.5
var between_hands_delay := 1.5


func _enter_tree() -> void:
	get_tree().root.theme = UiTheme.build()


func create_players() -> Array[PokerPlayer]:
	var players: Array[PokerPlayer] = [PokerPlayer.new(player_name, starting_chips, null, starting_hearts)]
	for path in OPPONENT_PATHS:
		var brain: NpcBrain = load(path)
		players.append(PokerPlayer.new(brain.display_name, starting_chips, brain, starting_hearts))
	return players

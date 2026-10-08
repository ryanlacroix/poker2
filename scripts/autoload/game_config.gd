extends Node
## Global game settings, autoloaded as /root/GameConfig.

var player_name := "YOU"
var player_portrait_path := "res://assets/portraits/you.png"
var player_injured_portrait_path := "res://assets/portraits/you_injured.png"
## The table the player is at (1 = the first); see [TableLevel]. Winning it ascends them.
var table_number := 1
## Hearts each player starts with (shown under their name).
var starting_hearts := 3
var npc_think_time := 0.8
var deal_delay := 0.4
var showdown_delay := 2.5
var between_hands_delay := 1.5


func _enter_tree() -> void:
	get_tree().root.theme = UiTheme.build()


func table_level() -> TableLevel:
	return TableLevel.new(table_number)


func create_players() -> Array[PokerPlayer]:
	var level := table_level()
	var starting_chips := level.starting_chips
	var players: Array[PokerPlayer] = [PokerPlayer.new(player_name, starting_chips, null, starting_hearts)]
	for path in level.opponents:
		var brain: NpcBrain = load(path)
		players.append(PokerPlayer.new(brain.display_name, starting_chips, brain, starting_hearts))
	return players

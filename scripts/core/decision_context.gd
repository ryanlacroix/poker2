class_name DecisionContext
extends RefCounted
## Everything an NPC is allowed to know when deciding.

var hole: Array[Card]
var community: Array[Card]
var street: Poker.Street
var to_call: int
var pot: int
var current_bet: int
var min_raise_to: int
var max_raise_to: int
var chips: int
var big_blind: int
var num_opponents: int


func _init(p_hole: Array[Card], p_community: Array[Card], p_street: Poker.Street, p_to_call: int,
		p_pot: int, p_current_bet: int, p_min_raise_to: int, p_max_raise_to: int, p_chips: int,
		p_big_blind: int, p_num_opponents: int) -> void:
	hole = p_hole
	community = p_community
	street = p_street
	to_call = p_to_call
	pot = p_pot
	current_bet = p_current_bet
	min_raise_to = p_min_raise_to
	max_raise_to = p_max_raise_to
	chips = p_chips
	big_blind = p_big_blind
	num_opponents = p_num_opponents

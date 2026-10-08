class_name Decision
extends RefCounted
## What a player chose to do. Amount is the total "raise to" for RAISE.

var action: Poker.Action
var amount: int


func _init(p_action: Poker.Action, p_amount := 0) -> void:
	action = p_action
	amount = p_amount

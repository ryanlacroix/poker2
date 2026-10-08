class_name ItemDecision
extends RefCounted
## An item-phase choice. [member target] is who to shoot, for [constant Item.Action.USE] with a gun.

var action: Item.Action
var target: PokerPlayer


func _init(p_action: Item.Action, p_target: PokerPlayer = null) -> void:
	action = p_action
	target = p_target

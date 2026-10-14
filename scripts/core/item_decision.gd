class_name ItemDecision
extends RefCounted
## An item-phase choice: [member item] is which of the player's items to use or drop, and
## [member target] who to shoot or hex. For a magpie, [member steal] is which of the target's items
## it takes.

var action: Item.Action
var item: HeldItem
var target: PokerPlayer
var steal: HeldItem


func _init(p_action: Item.Action, p_item: HeldItem = null, p_target: PokerPlayer = null, p_steal: HeldItem = null) -> void:
	action = p_action
	item = p_item
	target = p_target
	steal = p_steal

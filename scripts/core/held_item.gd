class_name HeldItem
extends RefCounted
## One item a player is carrying (they can carry up to [constant Item.MAX_HELD]).

var kind: Item.Kind
## Number of the hand at whose end it was picked up.
var gained_on_hand: int
## What it casts when it's a hex: rolled on pickup, secret until it's used.
var hex := Hex.Effect.SHIMMER


func _init(p_kind: Item.Kind, p_gained_on_hand: int, p_hex := Hex.Effect.SHIMMER) -> void:
	kind = p_kind
	gained_on_hand = p_gained_on_hand
	hex = p_hex


## Items can't be used straight away: only at the end of a later hand than the one they were
## picked up in, and only if they have a use (a shield doesn't).
func is_ready(hand_number: int) -> bool:
	return Item.can_be_used(kind) and hand_number > gained_on_hand

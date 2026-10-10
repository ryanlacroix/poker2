class_name PokerPlayer
extends RefCounted
## Per-seat state: stack, hole cards, and betting status for the current hand.

var display_name: String
var brain: NpcBrain
var seat := 0
var chips := 0
## Hearts shown under the player's name.
var hearts := 3
## Hearts they started with: a stimpak can't heal them past this.
var max_hearts := 3
## The one item this player carries ([enum Item.Kind]), or [constant Item.NONE].
var item: int = Item.NONE
## Number of the hand at whose end [member item] was picked up.
var item_gained_on_hand := 0
## What [member item] casts when it's a hex: rolled on pickup, secret until it's used.
var hex := Hex.Effect.SHIMMER
## Whoever put a shimmer on this player, or null if none is on them (see [constant Hex.Effect.SHIMMER]).
var shimmered_by: PokerPlayer

var hole_cards: Array[Card] = []
## Chips put in during the current betting round.
var street_bet := 0
## Chips put in during the whole hand (used for side pots).
var total_bet := 0
var folded := false
var all_in := false
var has_acted := false
## Busted; no longer dealt in.
var is_out := false


func _init(p_name: String, p_chips: int, p_brain: NpcBrain = null, p_hearts := 3) -> void:
	display_name = p_name
	chips = p_chips
	brain = p_brain
	hearts = p_hearts
	max_hearts = p_hearts


func is_human() -> bool:
	return brain == null


## Has lost at least one heart (so a stimpak would help).
func is_hurt() -> bool:
	return hearts < max_hearts


func is_shimmering() -> bool:
	return shimmered_by != null


func has_item() -> bool:
	return item != Item.NONE


## Items can't be used straight away: only at the end of a later hand than the one they
## were picked up in.
func can_use_item(hand_number: int) -> bool:
	return has_item() and hand_number > item_gained_on_hand


func reset_for_hand() -> void:
	hole_cards.clear()
	street_bet = 0
	total_bet = 0
	folded = false
	all_in = false
	has_acted = false
	is_out = chips <= 0


func in_hand() -> bool:
	return not is_out and not folded


func can_act() -> bool:
	return in_hand() and not all_in


## Move up to [param amount] chips into the pot. Returns what was actually paid.
func commit(amount: int) -> int:
	var paid := mini(amount, chips)
	chips -= paid
	street_bet += paid
	total_bet += paid
	if chips == 0:
		all_in = true
	return paid

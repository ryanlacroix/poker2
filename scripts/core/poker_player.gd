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
## The items this player carries, in the order they were picked up: up to [constant Item.MAX_HELD].
var items: Array[HeldItem] = []
## Whoever put a shimmer on this player, or null if none is on them (see [constant Hex.Effect.SHIMMER]).
var shimmered_by: PokerPlayer
## Whoever put a leech on this player, or null if none is on them (see [constant Hex.Effect.LEECH]).
var leeched_by: PokerPlayer
## How many more times the leech on this player will drain them.
var leech_drains_left := 0
## Whoever strapped a bomb to this player, or null if none is on them (see [constant Hex.Effect.BOOM_TRAP]).
var trapped_by: PokerPlayer
## Blown out of the game by a boom trap or shield overload: their seat is gone from the table.
var blown_up := false

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


func is_leeched() -> bool:
	return leeched_by != null


func is_trapped() -> bool:
	return trapped_by != null


func has_item() -> bool:
	return not items.is_empty()


## Has room to pick up another item.
func has_free_hand() -> bool:
	return items.size() < Item.MAX_HELD


## Carries at least one [param kind].
func has(kind: Item.Kind) -> bool:
	return first(kind) != null


## The first [param kind] they carry, or null.
func first(kind: Item.Kind) -> HeldItem:
	for held in items:
		if held.kind == kind:
			return held
	return null


## Takes [param held] out of their hands (if they have it).
func remove_item(held: HeldItem) -> void:
	items.erase(held)


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

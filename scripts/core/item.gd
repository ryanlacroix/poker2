class_name Item
extends RefCounted
## Something a player can carry, one at a time. Shown as a small icon on their seat.

enum Kind {
	## Used between hands to shoot an NPC, taking one of their hearts.
	GUN,
	## Protects from the moment it's picked up: the next shot breaks it instead of taking a heart.
	## Has no use action; it can only be dropped.
	SHIELD,
}

## A player's item slot when they carry nothing.
const NONE := -1

## What a player does with their item on their turn in the item phase.
enum Action { KEEP, USE, DROP }

## What happened when someone was shot.
enum ShotResult { SHIELD_BROKE, HIT, ELIMINATED }


## Whether [param item] has an action besides being dropped.
static func can_be_used(item: int) -> bool:
	return item == Kind.GUN


## How likely each item is, relative to the others, when a player picks one up: 3 guns to 1 shield.
static func weight(item: Kind) -> int:
	match item:
		Kind.GUN: return 3
		Kind.SHIELD: return 1
	assert(false, "unknown item %d" % item)
	return 0


## A random item, chosen by [method weight].
static func random(rng: RandomNumberGenerator = null) -> Kind:
	var all: Array = Kind.values()
	var total := 0
	for item: Kind in all:
		total += weight(item)
	var roll := rng.randi_range(0, total - 1) if rng else randi_range(0, total - 1)
	for item: Kind in all:
		roll -= weight(item)
		if roll < 0:
			return item
	return all[-1]


## Short upper-case name, as on the "USE ..." and "DROP ..." buttons.
static func display_name(item: Kind) -> String:
	match item:
		Kind.GUN: return "GUN"
		Kind.SHIELD: return "SHIELD"
	assert(false, "unknown item %d" % item)
	return ""


## The notification shown when [param who] picks up [param item].
static func gained_text(item: Kind, who: String) -> String:
	match item:
		Kind.GUN: return "%s got a gun" % who
		Kind.SHIELD: return "%s GOT THE SHIELD" % who
	assert(false, "unknown item %d" % item)
	return ""

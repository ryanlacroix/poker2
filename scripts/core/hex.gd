class_name Hex
extends RefCounted
## What a hex does when cast. Each hex gets one of these at random when it's picked up, kept
## secret until its holder uses it.

enum Effect {
	## The caster picks another player, who shimmers until they're next shot: that shot also hits
	## up to [constant SHIMMER_SPREAD] other random players, never the caster or the shooter.
	SHIMMER,
	## The caster picks another player and, for [constant LEECH_HANDS] hands, takes
	## [constant LEECH_PERCENT]% of that player's chips after each one.
	LEECH,
	## Every other player still in the game has a [constant LIGHTNING_PERCENT]% chance of being
	## struck, one at a time; a strike lands like the caster's gunshot.
	LIGHTNING,
	## The caster picks another player carrying an item; a magpie steals it and brings it to the
	## caster, who can use it or drop it straight away.
	MAGPIE,
	## The caster picks another player and straps a bomb to them. If they fold in the next hand,
	## or end it with no chips left, it blows them out of the game (their chips go to the
	## caster); if they see the hand through, it falls off.
	BOOM_TRAP,
	## The caster picks another player carrying a shield, which overloads: their avatar crackles
	## with electricity until it explodes, blowing them out of the game (their chips go to the caster).
	SHIELD_OVERLOAD,
	## The caster picks another player and infects them for the next hand. On their first betting
	## turn the fungus takes over and they go all in, whatever their cards. It wears off when that
	## hand ends (even if they never got a turn).
	CORDYCEPS,
}

## How many hands a leech drains its victim for.
const LEECH_HANDS := 3
## Share of the victim's chips a leech takes each time, rounded down.
const LEECH_PERCENT := 10

## Chance each other player has of being struck by lightning.
const LIGHTNING_PERCENT := 50

## Extra players hit by the shot at a shimmering player.
const SHIMMER_SPREAD := 3


## A random effect for a newly picked-up hex.
static func random(rng: RandomNumberGenerator = null) -> Effect:
	var all: Array = Effect.values()
	return all[rng.randi_range(0, all.size() - 1) if rng else randi_range(0, all.size() - 1)]


## Whether casting [param effect] needs another player picked.
static func needs_target(effect: Effect) -> bool:
	match effect:
		Effect.SHIMMER, Effect.LEECH, Effect.MAGPIE, Effect.BOOM_TRAP, Effect.SHIELD_OVERLOAD, Effect.CORDYCEPS: return true
		Effect.LIGHTNING: return false
	assert(false, "unknown hex %d" % effect)
	return false


## Upper-case name, as the cast modal's title.
static func display_name(effect: Effect) -> String:
	match effect:
		Effect.SHIMMER: return "SHIMMER"
		Effect.LEECH: return "LEECH"
		Effect.LIGHTNING: return "LIGHTNING"
		Effect.MAGPIE: return "MAGPIE"
		Effect.BOOM_TRAP: return "BOOM TRAP"
		Effect.SHIELD_OVERLOAD: return "SHIELD OVERLOAD"
		Effect.CORDYCEPS: return "CORDYCEPS"
	assert(false, "unknown hex %d" % effect)
	return ""


## Picture of [param effect] (70x37), shown in the cast modal; null if it has none yet.
static func image(effect: Effect) -> Texture2D:
	var path := ""
	match effect:
		Effect.SHIMMER: path = "res://assets/hexes/shimmer.png"
		Effect.LEECH: path = "res://assets/hexes/leech.png"
		Effect.LIGHTNING: path = "res://assets/hexes/lightning.png"
		Effect.MAGPIE: path = "res://assets/hexes/magpie.png"
		Effect.BOOM_TRAP: path = "res://assets/hexes/boom_trap.png"
		Effect.SHIELD_OVERLOAD: path = "res://assets/hexes/shield_overload.png"
		Effect.CORDYCEPS: path = "res://assets/hexes/cordyceps.png"
		_: assert(false, "unknown hex %d" % effect)
	return load(path) if ResourceLoader.exists(path) else null


## What [param effect] does, shown in the cast modal.
static func description(effect: Effect) -> String:
	match effect:
		Effect.SHIMMER:
			return "Pick another player to shimmer. The next shot fired at them also hits %d other random players, but never you or the shooter. Then the shimmer fades." \
				% SHIMMER_SPREAD
		Effect.LEECH:
			return "Pick another player to leech. After each of the next %d hands, you steal %d%% of their money." \
				% [LEECH_HANDS, LEECH_PERCENT]
		Effect.LIGHTNING:
			return "Call down a storm. Every other player has a %d%% chance of being struck by lightning, which hits like a bullet." \
				% LIGHTNING_PERCENT
		Effect.MAGPIE:
			return "Pick another player who's carrying an item. A magpie swoops down, steals it and brings it to you, to use or drop straight away."
		Effect.BOOM_TRAP:
			return "Strap a bomb to another player. If they fold next hand, or end it broke, they blow up and you get whatever chips they had left. If they see the hand through, the bomb falls off."
		Effect.SHIELD_OVERLOAD:
			return "Pick another player who's carrying a shield. It overloads with electricity and explodes, blowing them out of the game, and you get their chips."
		Effect.CORDYCEPS:
			return "Infect another player with cordyceps. On their next turn to bet, the fungus takes over and they go all in, whatever their cards. It wears off at the end of the round."
	assert(false, "unknown hex %d" % effect)
	return ""

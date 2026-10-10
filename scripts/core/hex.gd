class_name Hex
extends RefCounted
## What a hex does when cast. Each hex gets one of these at random when it's picked up, kept
## secret until its holder uses it.

enum Effect {
	## The caster picks another player, who shimmers until they're next shot: that shot also hits
	## up to [constant SHIMMER_SPREAD] other random players, never the caster or the shooter.
	SHIMMER,
}

## Extra players hit by the shot at a shimmering player.
const SHIMMER_SPREAD := 3


## A random effect for a newly picked-up hex.
static func random(rng: RandomNumberGenerator = null) -> Effect:
	var all: Array = Effect.values()
	return all[rng.randi_range(0, all.size() - 1) if rng else randi_range(0, all.size() - 1)]


## Whether casting [param effect] needs another player picked.
static func needs_target(effect: Effect) -> bool:
	match effect:
		Effect.SHIMMER: return true
	assert(false, "unknown hex %d" % effect)
	return false


## Upper-case name, as the cast modal's title.
static func display_name(effect: Effect) -> String:
	match effect:
		Effect.SHIMMER: return "SHIMMER"
	assert(false, "unknown hex %d" % effect)
	return ""


## What [param effect] does, shown in the cast modal.
static func description(effect: Effect) -> String:
	match effect:
		Effect.SHIMMER:
			return "Pick another player to shimmer. The next shot fired at them also hits %d other random players, but never you or the shooter. Then the shimmer fades." \
				% SHIMMER_SPREAD
	assert(false, "unknown hex %d" % effect)
	return ""

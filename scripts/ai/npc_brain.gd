class_name NpcBrain
extends Resource
## Decision-making for an NPC opponent. Each .tres in data/npcs/ is one personality.
## Hand strength comes from a Monte Carlo equity estimate; the personality knobs shift
## how that strength turns into folds, calls, raises and bluffs.

@export var display_name := "NPC"
## 16x16 pixel portrait shown at the seat (see tools/generate_portraits.py).
@export var portrait: Texture2D
## The same face beaten up, shown once they're down to their last heart.
@export var injured_portrait: Texture2D
## 0 = plays almost anything, 1 = only premium hands.
@export_range(0, 1, 0.01) var tightness := 0.5
## 0 = calls and checks, 1 = bets and raises constantly.
@export_range(0, 1, 0.01) var aggression := 0.5
## Chance to bet with a weak hand.
@export_range(0, 1, 0.01) var bluff_rate := 0.1
## Monte Carlo samples per decision: more = smarter but slower.
@export_range(20, 5000) var simulations := 500
## Noise added to equity so NPCs aren't perfectly predictable.
@export_range(0, 0.3, 0.01) var randomness := 0.05


func decide(ctx: DecisionContext) -> Decision:
	var equity := estimate_equity(ctx.hole, ctx.community, ctx.num_opponents)
	equity = clampf(equity + randf_range(-randomness, randomness), 0.0, 1.0)

	# Equity needed to raise, scaled from "fair share" (1 / players) toward 1.
	var fair_share := 1.0 / (ctx.num_opponents + 1)
	var raise_bar := fair_share + (1.0 - fair_share) * (lerpf(0.25, 0.5, tightness) - 0.15 * aggression)

	if equity >= raise_bar and randf() < 0.4 + aggression * 0.6:
		return _raise(ctx, equity)

	if ctx.to_call == 0:
		if randf() < bluff_rate * (0.5 + aggression):
			return _raise(ctx, equity)
		return Decision.new(Poker.Action.CHECK)

	var pot_odds := float(ctx.to_call) / (ctx.pot + ctx.to_call)
	# Loose players over-call (implied odds, curiosity); tight ones demand a margin.
	var call_bar := pot_odds * lerpf(0.6, 1.1, tightness)
	if equity >= call_bar:
		return Decision.new(Poker.Action.CALL)

	if randf() < bluff_rate * 0.5:
		return _raise(ctx, equity)
	return Decision.new(Poker.Action.FOLD)


func _raise(ctx: DecisionContext, equity: float) -> Decision:
	if ctx.max_raise_to <= ctx.current_bet:
		return Decision.new(Poker.Action.CALL)

	var size_frac := lerpf(0.4, 1.0, aggression) * randf_range(0.7, 1.3)
	var target := ctx.current_bet + int(ctx.pot * size_frac)
	if equity > 0.85 and randf() < aggression:
		target = ctx.max_raise_to
	target = _round_half_even(float(target) / ctx.big_blind) * ctx.big_blind
	target = mini(maxi(target, ctx.min_raise_to), ctx.max_raise_to)
	return Decision.new(Poker.Action.RAISE, target)


## Item phase: fire a ready gun (more likely the more aggressive), and timid players who
## won't fire it drop it to try for a shield instead. A shield is always worth keeping, and a
## stimpak is saved until it would win back a heart. A ready hex is cast about as readily as a
## gun is fired. [param targets] are who the gun or hex could be used on.
func decide_item(me: PokerPlayer, can_use: bool, targets: Array[PokerPlayer]) -> ItemDecision:
	if me.item == Item.Kind.STIMPAK:
		return ItemDecision.new(Item.Action.USE if can_use and me.is_hurt() else Item.Action.KEEP)
	if me.item == Item.Kind.HEX:
		if not can_use or randf() >= 0.5 + 0.5 * aggression:
			return ItemDecision.new(Item.Action.KEEP)
		return ItemDecision.new(Item.Action.USE, _pick_hex_target(me.hex, targets))
	if me.item != Item.Kind.GUN or not can_use or targets.is_empty():
		return ItemDecision.new(Item.Action.KEEP)
	if randf() < 0.5 + 0.5 * aggression:
		return ItemDecision.new(Item.Action.USE, _pick_target(me, targets))
	return ItemDecision.new(Item.Action.DROP if aggression < 0.3 else Item.Action.KEEP)


## The most rewarding shot: finishing someone off takes their whole stack, so favour big stacks
## with few hearts left; a shield only breaks, so shielded players are a poor target. A shot at
## a shimmering player spreads to others and never back to the shooter, so it's worth more.
static func _pick_target(me: PokerPlayer, targets: Array[PokerPlayer]) -> PokerPlayer:
	var best: PokerPlayer = null
	var best_value := -INF
	for t in targets:
		var value := float(t.chips) / t.hearts * (0.25 if t.item == Item.Kind.SHIELD else 1.0) * randf_range(0.8, 1.2)
		if t.is_shimmering():
			value *= 2.0
		if value > best_value:
			best = t
			best_value = value
	return best


## Who to cast [param effect] on, or null if it needs nobody. Both hexes go on the biggest stack
## that doesn't already have one: a shimmer draws everyone's fire and its spread never hits the
## caster, so it marks the player the caster most wants shot; a leech takes a share of the
## victim's chips, so the richer the better.
static func _pick_hex_target(effect: Hex.Effect, targets: Array[PokerPlayer]) -> PokerPlayer:
	if not Hex.needs_target(effect):
		return null
	var has_it := func(t: PokerPlayer) -> bool:
		return t.is_shimmering() if effect == Hex.Effect.SHIMMER else t.is_leeched()
	var best: PokerPlayer = null
	for t in targets:
		if best == null or (has_it.call(best) and not has_it.call(t)) \
				or (has_it.call(best) == has_it.call(t) and t.chips > best.chips):
			best = t
	return best


## Probability of winning at showdown against [param opponents] random hands.
func estimate_equity(hole: Array[Card], community: Array[Card], opponents: int) -> float:
	if opponents <= 0:
		return 1.0

	var known := {}
	for c in hole + community:
		known[c.rank * 4 + c.suit] = true
	var deck: Array[Card] = []
	for suit: Card.Suit in Card.Suit.values():
		for rank in range(2, 15):
			if not known.has(rank * 4 + suit):
				deck.append(Card.new(rank, suit))

	var mine: Array[Card] = []
	mine.resize(7)
	var theirs: Array[Card] = []
	theirs.resize(7)
	var board_needed := 5 - community.size()
	var wins := 0.0
	for sim in simulations:
		deck.shuffle()
		var idx := 0
		# Slots 0-4: board, 5-6: hole cards.
		for i in community.size():
			mine[i] = community[i]
		for i in board_needed:
			mine[community.size() + i] = deck[idx]
			idx += 1
		for i in 5:
			theirs[i] = mine[i]
		mine[5] = hole[0]
		mine[6] = hole[1]
		var my_score := HandEvaluator.evaluate(mine)

		var tied := 1
		var lost := false
		for o in opponents:
			theirs[5] = deck[idx]
			theirs[6] = deck[idx + 1]
			idx += 2
			var cmp := HandEvaluator.compare(my_score, HandEvaluator.evaluate(theirs))
			if cmp < 0:
				lost = true
				break
			elif cmp == 0:
				tied += 1
		if not lost:
			wins += 1.0 / tied
	return wins / simulations


## Rounds to the nearest whole number, halves to the even one (like C#'s Math.Round).
static func _round_half_even(x: float) -> int:
	var f := floorf(x)
	var diff := x - f
	if diff > 0.5 or (diff == 0.5 and int(f) % 2 != 0):
		return int(f) + 1
	return int(f)

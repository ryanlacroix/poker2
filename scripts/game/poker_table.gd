class_name PokerTable
extends Node
## Texas Hold'em rules engine. Has no visuals: it runs the game as a coroutine and
## reports everything through signals so any view (or a test) can follow along.

signal hand_started(hand_number: int, dealer_seat: int)
signal street_started(street: Poker.Street)
signal hole_cards_dealt
signal community_changed(cards: Array[Card])
signal turn_started(player: PokerPlayer, to_call: int, min_raise_to: int, max_raise_to: int)
signal player_acted(player: PokerPlayer, action: Poker.Action, amount: int)
signal chips_changed
## Contenders, and each one's score (a Dictionary of PokerPlayer -> Array[int]).
signal showdown(contenders: Array[PokerPlayer], scores: Dictionary)
## Hand name is "" if the pot was uncontested.
signal pot_awarded(winner: PokerPlayer, amount: int, hand_name: String)
## A player picked up an item at the end of a hand.
signal item_gained(player: PokerPlayer, item: Item.Kind)
signal hand_finished
## Emitted after a hand (when [member wait_for_next_hand] is on) so the view can finish showing
## it first; call [method begin_item_phase] to start the item turns.
signal waiting_for_item_phase
## It's this player's item turn, for the items in [param offered] (see [method can_use_item] for
## which can be used now). For the human, answer with [method submit_item_decision]; NPCs only
## emit it when they'll use or drop something. After a drop it's emitted again for what's left.
signal item_turn_started(player: PokerPlayer, offered: Array[HeldItem])
## A gun was fired.
signal shot(shooter: PokerPlayer, target: PokerPlayer, result: Item.ShotResult)
## A stimpak was used up, and whether it won back a heart (it does nothing at full health).
signal stimpak_used(player: PokerPlayer, healed: bool)
## A hex was cast (and used up) from [param slot] of the caster's hands (its index in their
## items, before it went); [param target] is null for a hex that doesn't need one.
signal hex_cast(caster: PokerPlayer, effect: Hex.Effect, target: PokerPlayer, slot: int)
## A shot at a shimmering player ([param source]) also hit [param target].
signal shot_spread(source: PokerPlayer, target: PokerPlayer, result: Item.ShotResult)
## The shimmer on [param player] wore off, as they were shot.
signal shimmer_ended(player: PokerPlayer)
## The leech [param caster] put on [param victim] took [param amount] of their chips.
signal leech_drained(caster: PokerPlayer, victim: PokerPlayer, amount: int)
## The leech on [param victim] dropped off: its hands are up, or one of the pair is out.
signal leech_ended(victim: PokerPlayer)
## Lightning [param caster] called down struck [param target].
signal lightning_struck(caster: PokerPlayer, target: PokerPlayer, result: Item.ShotResult)
## The magpie [param caster] sent is swooping down on [param target]'s [param item]; it's taken
## [member magpie_swoop_delay] later, with [signal item_stolen].
signal magpie_swooped(caster: PokerPlayer, target: PokerPlayer, item: HeldItem)
## The magpie took [param item] from [param target] for [param caster]; it's carried over for
## [member magpie_carry_delay], then [param caster] gets another item turn, for it alone.
signal item_stolen(caster: PokerPlayer, target: PokerPlayer, item: HeldItem)
## The bomb [param caster] strapped to [param victim] went off, blowing them out of the game.
signal bomb_exploded(victim: PokerPlayer, caster: PokerPlayer)
## [param victim] saw the hand through, so the bomb on them fell off.
signal bomb_dropped(victim: PokerPlayer)
## Once the cast has played out, electricity starts shooting out of [param target]'s avatar; it
## explodes [member overload_charge_delay] later, with [signal overload_exploded].
signal overload_charging(caster: PokerPlayer, target: PokerPlayer)
## The shield overload [param caster] cast blew up [param target], taking all their hearts.
signal overload_exploded(caster: PokerPlayer, target: PokerPlayer)
## [param caster] tried to cast the hex in [param slot] of their hands (as for [signal hex_cast]),
## but it turned out to be [param effect] and nobody could be picked for it (see
## [method hex_fizzles]), so it's lost.
signal hex_fizzled(caster: PokerPlayer, effect: Hex.Effect, slot: int)
signal item_dropped(player: PokerPlayer, item: Item.Kind)
signal item_phase_finished
## Emitted between hands when [member wait_for_next_hand] is on; call [method continue_to_next_hand].
signal waiting_for_next_hand
signal game_over(leader: PokerPlayer)
signal message(text: String)
## Never emitted: a coroutine that awaits it is parked until the table is freed.
signal _never

var small_blind := 10
var big_blind := 20
var deal_delay := 0.4
## Extra pause per hole card dealt after the first, so the view can lay them down one by one.
var hole_card_stagger := 0.0
var npc_think_time := 0.8
var showdown_delay := 2.0
var between_hands_delay := 1.5
## Pause after a gunshot, a stimpak or a hex in the item phase, so it can be seen before the next turn.
var shot_delay := 0.9
## Pause between a shot at a shimmering player and the shots it spreads to.
var spread_delay := 0.35
## Pause after each leech drains its victim, so the transfer can be seen before the next.
var leech_delay := 0.9
## Pause before each lightning strike, so they land one by one.
var lightning_delay := 1.0
## Pause after a magpie is cast, while the cast plays out, before the bird swoops.
var magpie_delay := 1.0
## How long the magpie takes to swoop down to its target's item, then to carry it to the caster.
var magpie_swoop_delay := 0.45
var magpie_carry_delay := 0.6
## Pause while a bomb goes off, and while one falls off.
var explosion_delay := 2.0
var bomb_drop_delay := 0.6
## Pause after a shield overload is cast, while the cast plays out, before the target crackles;
## then how long it crackles before exploding (the explosion then takes [member explosion_delay]).
var overload_delay := 1.0
var overload_charge_delay := 1.0
## Pause while a hex that fizzled sputters out.
var hex_fizzle_delay := 0.9
## 0 = unlimited.
var max_hands := 0
## Pause after each hand for the view: before the item phase (until [method begin_item_phase])
## and before the next hand (until [method continue_to_next_hand]), instead of waiting
## showdown_delay + between_hands_delay.
var wait_for_next_hand := false
## Chance, at the end of each hand, that each empty-handed player still in the game gets a random item.
## TESTING: raised to 1 in 2 from the intended 1 in 6.
var item_chance := 1.0 / 2

var players: Array[PokerPlayer] = []
var community: Array[Card] = []
var street := Poker.Street.PREFLOP
var dealer_index := -1
var hand_number := 0
## Highest street_bet this betting round.
var current_bet := 0

var _min_raise := 0
var _deck := Deck.new()
var _human_decision: Completion
var _next_hand: Completion
var _item_phase: Completion
var _human_item_decision: Completion
## The view has finished showing this hand's end (see [method _wait_for_view]).
var _view_caught_up := false
var _cancelled := false


func pot() -> int:
	var total := 0
	for p in players:
		total += p.total_bet
	return total


func setup(p_players: Array[PokerPlayer]) -> void:
	players.clear()
	players.append_array(p_players)
	for i in players.size():
		players[i].seat = i


## Called by the UI when the human picks an action.
func submit_human_action(decision: Decision) -> void:
	if _human_decision:
		_human_decision.set_result(decision)


## Called by the UI to deal the next hand while paused (see [member wait_for_next_hand]).
func continue_to_next_hand() -> void:
	if _next_hand:
		_next_hand.set_result()


## Called by the UI to start the item turns once it has finished showing the hand.
func begin_item_phase() -> void:
	if _item_phase:
		_item_phase.set_result()


## Called by the UI with the human's choice on their item turn.
func submit_item_decision(decision: ItemDecision) -> void:
	if _human_item_decision:
		_human_item_decision.set_result(decision)


## Puts [param item] in [param p]'s free hand, picked up at the end of this hand. A hex gets its
## secret effect now. Returns it.
func give_item(p: PokerPlayer, item: Item.Kind) -> HeldItem:
	assert(p.has_free_hand(), "%s's hands are full" % p.display_name)
	var held := HeldItem.new(item, hand_number, Hex.random() if item == Item.Kind.HEX else Hex.Effect.SHIMMER)
	p.items.append(held)
	return held


## [param shooter] fires [param gun] (used up; their first gun if not given) at [param target]
## (call between hands). A shield breaks and absorbs the shot; otherwise it takes a heart. If
## [param target] is shimmering, follow up with [method spread_shimmer].
func shoot(shooter: PokerPlayer, target: PokerPlayer, gun: HeldItem = null) -> Item.ShotResult:
	shooter.remove_item(gun if gun else shooter.first(Item.Kind.GUN))
	return _hit(target, shooter)


## The shot at shimmering [param target] also hits up to [constant Hex.SHIMMER_SPREAD] other random
## players still in the game, never whoever cast the shimmer or [param shooter]. That uses the
## shimmer up. Returns each one hit and their [enum Item.ShotResult].
func spread_shimmer(shooter: PokerPlayer, target: PokerPlayer) -> Dictionary:
	var hits := {}
	if not target.is_shimmering():
		return hits
	var caster := target.shimmered_by
	target.shimmered_by = null
	var others := players.filter(func(p: PokerPlayer) -> bool:
		return p != target and p != caster and p != shooter and in_game(p))
	others.shuffle()
	for p: PokerPlayer in others.slice(0, Hex.SHIMMER_SPREAD):
		hits[p] = _hit(p, shooter)
	return hits


## A shot at [param target] by [param shooter]: breaks a shield they carry (in either hand), or
## takes a heart.
func _hit(target: PokerPlayer, shooter: PokerPlayer) -> Item.ShotResult:
	if target.has(Item.Kind.SHIELD):
		target.remove_item(target.first(Item.Kind.SHIELD))
		chips_changed.emit()
		return Item.ShotResult.SHIELD_BROKE
	return Item.ShotResult.ELIMINATED if remove_heart(target, shooter) else Item.ShotResult.HIT


## Takes one heart from [param target] (call between hands). At zero hearts the target is
## eliminated and their chips go to [param taker]. Returns true if eliminated.
func remove_heart(target: PokerPlayer, taker: PokerPlayer) -> bool:
	if target.hearts <= 0:
		return false
	target.hearts -= 1
	var eliminated := target.hearts == 0
	if eliminated and target != taker:
		taker.chips += target.chips
		target.chips = 0
	chips_changed.emit()
	return eliminated


## [param p] uses up [param stimpak] (their first stimpak if not given; call between hands),
## winning back a heart if they've lost any. Returns true if it healed them.
func use_stimpak(p: PokerPlayer, stimpak: HeldItem = null) -> bool:
	p.remove_item(stimpak if stimpak else p.first(Item.Kind.STIMPAK))
	var healed := p.is_hurt()
	if healed:
		p.hearts += 1
	chips_changed.emit()
	return healed


## [param caster] uses up their [param hex] (call between hands), casting its effect on
## [param target] if it needs one. Returns false, keeping the hex, if [param target] can't be picked.
func cast_hex(caster: PokerPlayer, hex: HeldItem, target: PokerPlayer) -> bool:
	if hex == null or hex.kind != Item.Kind.HEX or hex not in caster.items:
		return false
	if Hex.needs_target(hex.hex) and target not in hex_targets(caster, hex.hex):
		return false
	caster.remove_item(hex)
	match hex.hex:
		Hex.Effect.SHIMMER:
			target.shimmered_by = caster
		Hex.Effect.LEECH:
			target.leeched_by = caster
			target.leech_drains_left = Hex.LEECH_HANDS
		Hex.Effect.BOOM_TRAP:
			target.trapped_by = caster
	chips_changed.emit()
	return true


## Who the lightning [param caster] calls down will strike: each other player still in the game,
## with a [constant Hex.LIGHTNING_PERCENT]% chance each, in seat order. Hit each with
## [method strike_lightning].
func roll_lightning(caster: PokerPlayer) -> Array[PokerPlayer]:
	return hex_targets(caster, Hex.Effect.LIGHTNING).filter(func(_p: PokerPlayer) -> bool:
		return randi_range(0, 99) < Hex.LIGHTNING_PERCENT)


## Lightning [param caster] called down strikes [param target]: breaks their shield, or takes a
## heart (their chips go to [param caster] if it's their last).
func strike_lightning(caster: PokerPlayer, target: PokerPlayer) -> Item.ShotResult:
	return _hit(target, caster)


## The magpie [param thief] cast takes [param item] from [param victim] (a hex's secret effect
## and all) and gives it to [param thief], ready to use straight away. Returns it, or null if
## [param victim] doesn't have it.
func steal_item(thief: PokerPlayer, victim: PokerPlayer, item: HeldItem) -> HeldItem:
	if item not in victim.items:
		return null
	victim.remove_item(item)
	item.gained_on_hand = hand_number - 1 # as if held since an earlier hand
	thief.items.append(item)
	chips_changed.emit()
	return item


## The bomb on [param victim] goes off: they're out of the game for good, and whatever chips they
## have left go to whoever trapped them (if that player is still in). Returns that player.
func detonate(victim: PokerPlayer) -> PokerPlayer:
	var caster := victim.trapped_by
	victim.trapped_by = null
	victim.blown_up = true
	victim.hearts = 0
	if caster != victim and not caster.is_out and caster.hearts > 0:
		caster.chips += victim.chips
	victim.chips = 0
	chips_changed.emit()
	return caster


## The shield overload [param caster] cast on [param target] goes off: like a boom trap, it blows
## them out of the game, and their chips go to [param caster].
func overload(caster: PokerPlayer, target: PokerPlayer) -> void:
	target.blown_up = true
	target.hearts = 0
	if target != caster:
		caster.chips += target.chips
		target.chips = 0
	chips_changed.emit()


## Still playing: has chips and hearts left.
static func in_game(p: PokerPlayer) -> bool:
	return p.chips > 0 and p.hearts > 0


## Everyone [param shooter] could shoot.
func gun_targets(shooter: PokerPlayer) -> Array[PokerPlayer]:
	return players.filter(func(t: PokerPlayer) -> bool: return t != shooter and in_game(t))


## The leech on [param victim] moves [constant Hex.LEECH_PERCENT]% of their chips (rounded down)
## to whoever cast it, and drops off after its last drain. Returns the chips taken.
func drain_leech(victim: PokerPlayer) -> int:
	if not victim.is_leeched():
		return 0
	@warning_ignore("integer_division")
	var amount := victim.chips * Hex.LEECH_PERCENT / 100
	victim.chips -= amount
	victim.leeched_by.chips += amount
	victim.leech_drains_left -= 1
	if victim.leech_drains_left <= 0:
		victim.leeched_by = null
	chips_changed.emit()
	return amount


## Everyone [param caster] could cast a hex with [param effect] on: anyone else still in the game,
## but for a magpie only those carrying an item, for a boom trap only those without a bomb on
## already, and for a shield overload only those carrying a shield.
func hex_targets(caster: PokerPlayer, effect: Hex.Effect) -> Array[PokerPlayer]:
	var targets := gun_targets(caster)
	match effect:
		Hex.Effect.MAGPIE:
			return targets.filter(func(t: PokerPlayer) -> bool: return t.has_item())
		Hex.Effect.BOOM_TRAP:
			return targets.filter(func(t: PokerPlayer) -> bool: return not t.is_trapped())
		Hex.Effect.SHIELD_OVERLOAD:
			return targets.filter(func(t: PokerPlayer) -> bool: return t.has(Item.Kind.SHIELD))
	return targets


## Whether [param p] may use [param item] now (between hands): they carry it, it has a use, they've
## held it since an earlier hand, and (for a gun) there's someone to shoot. A hex's effect is secret
## until it's tried, so a ready hex can always be tried, even if it then fizzles ([method hex_fizzles]).
func can_use_item(p: PokerPlayer, item: HeldItem) -> bool:
	if item == null or item not in p.items or not item.is_ready(hand_number):
		return false
	if item.kind == Item.Kind.GUN:
		return not gun_targets(p).is_empty()
	return true


## Whether [param caster]'s [param hex], once tried, turns out to need someone picked and nobody
## can be (e.g. a shield overload with no shields about): it's lost without effect.
func hex_fizzles(caster: PokerPlayer, hex: HeldItem) -> bool:
	return hex.kind == Item.Kind.HEX and Hex.needs_target(hex.hex) and hex_targets(caster, hex.hex).is_empty()


func _exit_tree() -> void:
	# Stops the game loop cleanly if the scene is left mid-hand: it parks at its next wait.
	_cancelled = true


func _game_continues() -> bool:
	var with_chips := 0
	for p in players:
		if p.chips > 0:
			with_chips += 1
		if p.is_human() and p.chips <= 0:
			return false
	return with_chips > 1 and (max_hands == 0 or hand_number < max_hands)


## Runs the whole game. Not awaited: it plays out over many frames and ends with [signal game_over].
func start_game() -> void:
	while _game_continues():
		await _play_hand()
		if players.any(func(p: PokerPlayer) -> bool: return p.is_trapped()):
			await _wait_for_view()
			await _settle_bombs()
		if not _game_continues():
			break
		await _item_phase_turns()
		if not _game_continues():
			break
		if wait_for_next_hand:
			_next_hand = Completion.new()
			waiting_for_next_hand.emit()
			await _next_hand.wait()
			_next_hand = null
		else:
			await _wait(between_hands_delay)
	var leader := players[0]
	for p in players:
		if p.chips > leader.chips:
			leader = p
	game_over.emit(leader)


# --- Hand flow ---------------------------------------------------------

func _play_hand() -> void:
	hand_number += 1
	_view_caught_up = false
	for p in players:
		p.reset_for_hand()
	community.clear()
	_deck.reset()

	var seated := func(p: PokerPlayer) -> bool: return not p.is_out
	dealer_index = _next_seat(dealer_index, seated)
	# Heads-up: the dealer posts the small blind.
	var sb_index := dealer_index if _count(seated) == 2 else _next_seat(dealer_index, seated)
	var bb_index := _next_seat(sb_index, seated)

	hand_started.emit(hand_number, dealer_index)
	_start_street(Poker.Street.PREFLOP)
	_post_blind(players[sb_index], small_blind, "small")
	_post_blind(players[bb_index], big_blind, "big")
	current_bet = big_blind

	var dealt := 0
	for _round in 2:
		for step in range(1, players.size() + 1):
			var p := players[(dealer_index + step) % players.size()]
			if not p.is_out:
				p.hole_cards.append(_deck.draw())
				dealt += 1
	hole_cards_dealt.emit()
	chips_changed.emit()
	await _wait(deal_delay + hole_card_stagger * maxi(dealt - 1, 0))

	await _betting_round(_next_seat(bb_index, _can_act))

	for next: Poker.Street in [Poker.Street.FLOP, Poker.Street.TURN, Poker.Street.RIVER]:
		if _count(_in_hand) <= 1:
			break
		_start_street(next)
		var n := 3 if next == Poker.Street.FLOP else 1
		for i in n:
			community.append(_deck.draw())
		community_changed.emit(community)
		await _wait(deal_delay)
		if _count(_can_act) >= 2:
			await _betting_round(_next_seat(dealer_index, _can_act))

	await _resolve_hand()
	_hand_out_items()
	hand_finished.emit()


func _start_street(s: Poker.Street) -> void:
	street = s
	current_bet = 0
	_min_raise = big_blind
	for p in players:
		p.street_bet = 0
		p.has_acted = false
	street_started.emit(s)


func _post_blind(p: PokerPlayer, amount: int, kind: String) -> void:
	var paid := p.commit(amount)
	message.emit("%s posts %s blind %d" % [p.display_name, kind, paid])


func _needs_to_act(p: PokerPlayer) -> bool:
	return p.can_act() and (not p.has_acted or p.street_bet < current_bet)


func _betting_round(start: int) -> void:
	if start < 0:
		return
	var idx := start
	while true:
		if _count(_in_hand) <= 1:
			return
		if not players.any(_needs_to_act):
			return
		var actors := players.filter(_can_act)
		if actors.size() == 1 and actors[0].street_bet >= current_bet:
			return

		var player := players[idx]
		if _needs_to_act(player):
			var to_call := current_bet - player.street_bet
			var max_to := player.street_bet + player.chips
			var min_to := mini(current_bet + _min_raise, max_to)

			var decision: Decision
			if player.is_human():
				_human_decision = Completion.new()
				turn_started.emit(player, to_call, min_to, max_to)
				decision = await _human_decision.wait()
				_human_decision = null
			else:
				turn_started.emit(player, to_call, min_to, max_to)
				await _wait(npc_think_time)
				decision = player.brain.decide(DecisionContext.new(
					player.hole_cards, community, street, to_call, pot(), current_bet,
					min_to, max_to, player.chips, big_blind, _count(_in_hand) - 1))
				# With a bomb strapped on, folding is death: an NPC calls instead.
				if decision.action == Poker.Action.FOLD and player.is_trapped():
					decision = Decision.new(Poker.Action.CALL)
			_apply_action(player, decision)
			if player.folded and player.is_trapped():
				bomb_exploded.emit(player, detonate(player))
				await _wait(explosion_delay)
		idx = (idx + 1) % players.size()


## Validates and applies a decision. Illegal choices are coerced to the nearest legal one.
func _apply_action(p: PokerPlayer, decision: Decision) -> void:
	var to_call := current_bet - p.street_bet
	var action := decision.action
	var amount := decision.amount

	if action == Poker.Action.RAISE:
		amount = mini(maxi(amount, current_bet + _min_raise), p.street_bet + p.chips)
		if amount <= current_bet:
			action = Poker.Action.CALL
	if action == Poker.Action.CHECK and to_call > 0:
		action = Poker.Action.CALL
	if action == Poker.Action.CALL and to_call == 0:
		action = Poker.Action.CHECK

	match action:
		Poker.Action.FOLD:
			p.folded = true
			amount = 0
		Poker.Action.CHECK:
			amount = 0
		Poker.Action.CALL:
			amount = p.commit(to_call)
		Poker.Action.RAISE:
			var raise_size := amount - current_bet
			p.commit(amount - p.street_bet)
			if raise_size >= _min_raise:
				_min_raise = raise_size
				# A full raise re-opens the action for everyone else.
				for other in players:
					if other != p:
						other.has_acted = false
			current_bet = amount
	p.has_acted = true
	player_acted.emit(p, action, amount)
	chips_changed.emit()


func _resolve_hand() -> void:
	var contenders: Array[PokerPlayer] = players.filter(_in_hand)
	if contenders.size() == 1:
		var amount := pot()
		contenders[0].chips += amount
		pot_awarded.emit(contenders[0], amount, "")
		_clear_bets()
		return

	street = Poker.Street.SHOWDOWN
	var scores := {}
	for p in contenders:
		var cards := p.hole_cards.duplicate()
		cards.append_array(community)
		scores[p] = HandEvaluator.evaluate(cards)
	showdown.emit(contenders, scores)

	# Main pot + one side pot per distinct all-in level.
	var levels: Array[int] = []
	for p in contenders:
		if p.total_bet not in levels:
			levels.append(p.total_bet)
	levels.sort()
	var prev := 0
	for i in levels.size():
		var level := levels[i]
		var is_last := i == levels.size() - 1
		var amount := 0
		for p in players:
			var over := p.total_bet - prev
			# The last pot also sweeps up chips folded players put in above every all-in level.
			if over > 0:
				amount += over if is_last else mini(over, level - prev)
		prev = level
		if amount == 0:
			continue

		var winners: Array[PokerPlayer] = []
		for p in contenders:
			if p.total_bet < level:
				continue
			var cmp := 1 if winners.is_empty() else HandEvaluator.compare(scores[p], scores[winners[0]])
			if cmp > 0:
				winners = [p]
			elif cmp == 0:
				winners.append(p)
		@warning_ignore("integer_division")
		var share := amount / winners.size()
		var remainder := amount % winners.size()
		for w in winners:
			var won := share + remainder
			remainder = 0
			w.chips += won
			pot_awarded.emit(w, won, HandEvaluator.describe(scores[w]))

	_clear_bets()
	if not wait_for_next_hand:
		await _wait(showdown_delay)


## Between hands, after items are handed out: everyone still in the game who holds an item and
## didn't fold this hand gets a turn to use one, drop either or keep them, starting with this
## hand's dealer and going round in play order. NPCs that keep their items pass without a pause.
func _item_phase_turns() -> void:
	await _wait_for_view()
	await _drain_leeches()

	var n := players.size()
	for step in n:
		var p := players[(dealer_index + step) % n]
		if not p.has_item() or not in_game(p) or p.folded:
			continue
		await _item_turn(p)
	item_phase_finished.emit()


## [param p]'s turn to use one of their items, drop them or keep them; just for [param only] if
## given (a magpie's catch). Using an item ends the turn, as does keeping what's left; dropping
## one doesn't, so they carry on with whatever they still hold.
func _item_turn(p: PokerPlayer, only: HeldItem = null) -> void:
	while true:
		var offered: Array[HeldItem] = []
		for held in p.items:
			if only == null or held == only:
				offered.append(held)
		if offered.is_empty() or not in_game(p):
			return

		var decision: ItemDecision
		if p.is_human():
			_human_item_decision = Completion.new()
			item_turn_started.emit(p, offered)
			decision = await _human_item_decision.wait()
			_human_item_decision = null
		else:
			var usable: Array[HeldItem] = []
			usable.assign(offered.filter(func(held: HeldItem) -> bool: return can_use_item(p, held)))
			decision = p.brain.decide_item(p, offered, usable, gun_targets(p),
				func(effect: Hex.Effect) -> Array[PokerPlayer]: return hex_targets(p, effect))
			if decision.action == Item.Action.KEEP:
				return
			item_turn_started.emit(p, offered)
			await _wait(npc_think_time)

		# Anything they no longer carry (or, on a magpie's turn, anything but its catch) is a keep.
		if decision.action == Item.Action.KEEP or decision.item not in p.items or (only and decision.item != only):
			return
		if decision.action == Item.Action.USE:
			await _apply_item_use(p, decision)
			return
		p.remove_item(decision.item)
		item_dropped.emit(p, decision.item.kind)


## When [member wait_for_next_hand] is on, waits (once a hand) for the view to finish showing the
## hand's end: see [signal waiting_for_item_phase].
func _wait_for_view() -> void:
	if not wait_for_next_hand or _view_caught_up:
		return
	_item_phase = Completion.new()
	waiting_for_item_phase.emit()
	await _item_phase.wait()
	_item_phase = null
	_view_caught_up = true


## After a hand: each bomb on a player who ended it with no chips goes off; each on a player who
## saw it through falls off. (A bomb on someone who folded went off then and there.) A bomb on
## someone who wasn't dealt in (shot out, or broke, since it was strapped on) just goes away.
func _settle_bombs() -> void:
	for p in players:
		if not p.is_trapped():
			continue
		if p.is_out or p.hearts == 0:
			p.trapped_by = null
		elif p.chips == 0:
			bomb_exploded.emit(p, detonate(p))
			await _wait(explosion_delay)
		else:
			p.trapped_by = null
			bomb_dropped.emit(p)
			await _wait(bomb_drop_delay)


## Start of the item phase: each leech takes its share from its victim. A leech whose victim or
## caster is out of the game drops off instead.
func _drain_leeches() -> void:
	for victim in players:
		if not victim.is_leeched():
			continue
		var caster := victim.leeched_by
		if not in_game(victim) or not in_game(caster):
			victim.leeched_by = null
			leech_ended.emit(victim)
			continue
		leech_drained.emit(caster, victim, drain_leech(victim))
		if not victim.is_leeched():
			leech_ended.emit(victim)
		await _wait(leech_delay)


## Uses the item [param decision] picked; anything not allowed right now does nothing, keeping it.
func _apply_item_use(p: PokerPlayer, decision: ItemDecision) -> void:
	var item := decision.item
	var target := decision.target
	if not can_use_item(p, item):
		return
	match item.kind:
		Item.Kind.GUN:
			if target == null or target == p or not in_game(target):
				return
			var result := shoot(p, target, item)
			shot.emit(p, target, result)
			if target.is_shimmering():
				await _wait(spread_delay)
				var hits := spread_shimmer(p, target)
				for hit: PokerPlayer in hits:
					shot_spread.emit(target, hit, hits[hit])
				shimmer_ended.emit(target)
			await _wait(shot_delay)
		Item.Kind.STIMPAK:
			stimpak_used.emit(p, use_stimpak(p, item))
			await _wait(shot_delay)
		Item.Kind.HEX:
			var effect := item.hex
			var slot := p.items.find(item)
			if hex_fizzles(p, item):
				p.remove_item(item)
				hex_fizzled.emit(p, effect, slot)
				await _wait(hex_fizzle_delay)
				return
			if not cast_hex(p, item, target):
				return
			hex_cast.emit(p, effect, target if Hex.needs_target(effect) else null, slot)
			match effect:
				Hex.Effect.MAGPIE:
					# Whichever item was picked, if [param target] still has it; otherwise their only one.
					var steal := decision.steal if decision.steal in target.items else target.items[0]
					await _send_magpie(p, target, steal)
					return
				Hex.Effect.SHIELD_OVERLOAD:
					await _overload_target(p, target)
					return
				Hex.Effect.LIGHTNING:
					for struck in roll_lightning(p):
						await _wait(lightning_delay)
						lightning_struck.emit(p, struck, strike_lightning(p, struck))
			await _wait(shot_delay)


## After the cast, [param caster]'s magpie swoops on [param target]'s [param item] and carries it
## back; then [param caster] gets another item turn, to use or drop it.
func _send_magpie(caster: PokerPlayer, target: PokerPlayer, item: HeldItem) -> void:
	await _wait(magpie_delay)
	magpie_swooped.emit(caster, target, item)
	await _wait(magpie_swoop_delay)
	if steal_item(caster, target, item) == null:
		return
	item_stolen.emit(caster, target, item)
	await _wait(magpie_carry_delay)
	await _item_turn(caster, item)


## After the cast, [param target]'s avatar crackles with electricity, then explodes.
func _overload_target(caster: PokerPlayer, target: PokerPlayer) -> void:
	await _wait(overload_delay)
	overload_charging.emit(caster, target)
	await _wait(overload_charge_delay)
	overload(caster, target)
	overload_exploded.emit(caster, target)
	await _wait(explosion_delay)


## End of hand: each player still in the game with a free hand may pick up a random item.
## Players whose hands are full don't roll.
func _hand_out_items() -> void:
	for p in players:
		if p.chips <= 0 or not p.has_free_hand() or randf() >= item_chance:
			continue
		item_gained.emit(p, give_item(p, Item.random()).kind)


func _clear_bets() -> void:
	for p in players:
		p.total_bet = 0
		p.street_bet = 0
	chips_changed.emit()


# --- Helpers -----------------------------------------------------------

static func _in_hand(p: PokerPlayer) -> bool:
	return p.in_hand()


static func _can_act(p: PokerPlayer) -> bool:
	return p.can_act()


func _count(pred: Callable) -> int:
	var n := 0
	for p in players:
		if pred.call(p):
			n += 1
	return n


## First seat after [param from] (wrapping, [param from] itself last) matching pred, or -1.
func _next_seat(from: int, pred: Callable) -> int:
	var n := players.size()
	for step in range(1, n + 1):
		var i := ((from + step) % n + n) % n
		if pred.call(players[i]):
			return i
	return -1


func _wait(seconds: float) -> void:
	if _cancelled:
		await _never
	await get_tree().create_timer(seconds).timeout
	if _cancelled:
		await _never

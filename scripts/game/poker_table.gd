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
## It's this player's item turn (and whether they can use their item now). For the human,
## answer with [method submit_item_decision]; NPCs only emit it when they'll use or drop.
signal item_turn_started(player: PokerPlayer, can_use: bool)
## A gun was fired.
signal shot(shooter: PokerPlayer, target: PokerPlayer, result: Item.ShotResult)
## A stimpak was used up, and whether it won back a heart (it does nothing at full health).
signal stimpak_used(player: PokerPlayer, healed: bool)
## A hex was cast (and used up); [param target] is null for a hex that doesn't need one.
signal hex_cast(caster: PokerPlayer, effect: Hex.Effect, target: PokerPlayer)
## A shot at a shimmering player ([param source]) also hit [param target].
signal shot_spread(source: PokerPlayer, target: PokerPlayer, result: Item.ShotResult)
## The shimmer on [param player] wore off, as they were shot.
signal shimmer_ended(player: PokerPlayer)
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


## Puts [param item] in [param p]'s hands, picked up at the end of this hand. A hex gets its
## secret effect now.
func give_item(p: PokerPlayer, item: Item.Kind) -> void:
	p.item = item
	p.item_gained_on_hand = hand_number
	if item == Item.Kind.HEX:
		p.hex = Hex.random()


## [param shooter] fires their gun (used up) at [param target] (call between hands).
## A shield breaks and absorbs the shot; otherwise it takes a heart. If [param target] is
## shimmering, follow up with [method spread_shimmer].
func shoot(shooter: PokerPlayer, target: PokerPlayer) -> Item.ShotResult:
	if shooter.item == Item.Kind.GUN:
		shooter.item = Item.NONE
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


## A shot at [param target] by [param shooter]: breaks their shield, or takes a heart.
func _hit(target: PokerPlayer, shooter: PokerPlayer) -> Item.ShotResult:
	if target.item == Item.Kind.SHIELD:
		target.item = Item.NONE
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


## [param p] uses up their stimpak (call between hands), winning back a heart if they've lost
## any. Returns true if it healed them.
func use_stimpak(p: PokerPlayer) -> bool:
	if p.item == Item.Kind.STIMPAK:
		p.item = Item.NONE
	var healed := p.is_hurt()
	if healed:
		p.hearts += 1
	chips_changed.emit()
	return healed


## [param caster] uses up their hex (call between hands), casting its effect on [param target]
## if it needs one. Returns false, keeping the hex, if [param target] can't be picked.
func cast_hex(caster: PokerPlayer, target: PokerPlayer) -> bool:
	if caster.item != Item.Kind.HEX:
		return false
	if Hex.needs_target(caster.hex) and target not in hex_targets(caster):
		return false
	caster.item = Item.NONE
	match caster.hex:
		Hex.Effect.SHIMMER:
			target.shimmered_by = caster
	chips_changed.emit()
	return true


## Still playing: has chips and hearts left.
static func in_game(p: PokerPlayer) -> bool:
	return p.chips > 0 and p.hearts > 0


## Everyone [param shooter] could shoot.
func gun_targets(shooter: PokerPlayer) -> Array[PokerPlayer]:
	return players.filter(func(t: PokerPlayer) -> bool: return t != shooter and in_game(t))


## Everyone [param caster] could cast their hex on.
func hex_targets(caster: PokerPlayer) -> Array[PokerPlayer]:
	return gun_targets(caster)


## Whether [param p] may use their item now (between hands): it has a use, they've held it
## since an earlier hand, and (for a gun, or a hex cast on someone) there's someone to pick.
func can_use_item(p: PokerPlayer) -> bool:
	if not (p.has_item() and Item.can_be_used(p.item) and p.can_use_item(hand_number)):
		return false
	match p.item:
		Item.Kind.GUN: return not gun_targets(p).is_empty()
		Item.Kind.HEX: return not Hex.needs_target(p.hex) or not hex_targets(p).is_empty()
	return true


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
			_apply_action(player, decision)
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
## didn't fold this hand gets a turn to use it, drop it or keep it, starting with this hand's
## dealer and going round in play order. NPCs that keep their item pass without a pause.
func _item_phase_turns() -> void:
	if wait_for_next_hand:
		_item_phase = Completion.new()
		waiting_for_item_phase.emit()
		await _item_phase.wait()
		_item_phase = null

	var n := players.size()
	for step in n:
		var p := players[(dealer_index + step) % n]
		if not p.has_item() or not in_game(p) or p.folded:
			continue
		var item := p.item as Item.Kind
		var can_use := can_use_item(p)

		var decision: ItemDecision
		if p.is_human():
			_human_item_decision = Completion.new()
			item_turn_started.emit(p, can_use)
			decision = await _human_item_decision.wait()
			_human_item_decision = null
		else:
			decision = p.brain.decide_item(p, can_use, gun_targets(p) if item == Item.Kind.GUN else hex_targets(p))
			if decision.action == Item.Action.KEEP:
				continue
			item_turn_started.emit(p, can_use)
			await _wait(npc_think_time)
		await _apply_item_decision(p, item, can_use, decision)
	item_phase_finished.emit()


## Carries out an item-phase choice; anything not allowed right now counts as keeping the item.
func _apply_item_decision(p: PokerPlayer, item: Item.Kind, can_use: bool, decision: ItemDecision) -> void:
	match decision.action:
		Item.Action.USE:
			var target := decision.target
			if can_use and item == Item.Kind.GUN and target != null and target != p and in_game(target):
				var result := shoot(p, target)
				shot.emit(p, target, result)
				if target.is_shimmering():
					await _wait(spread_delay)
					var hits := spread_shimmer(p, target)
					for hit: PokerPlayer in hits:
						shot_spread.emit(target, hit, hits[hit])
					shimmer_ended.emit(target)
				await _wait(shot_delay)
			elif can_use and item == Item.Kind.STIMPAK:
				stimpak_used.emit(p, use_stimpak(p))
				await _wait(shot_delay)
			elif can_use and item == Item.Kind.HEX:
				var effect := p.hex
				if cast_hex(p, target):
					hex_cast.emit(p, effect, target if Hex.needs_target(effect) else null)
					await _wait(shot_delay)
		Item.Action.DROP:
			p.item = Item.NONE
			item_dropped.emit(p, item)


## End of hand: each player still in the game with free hands may pick up a random item.
## Players already carrying one don't roll.
func _hand_out_items() -> void:
	for p in players:
		if p.chips <= 0 or p.has_item() or randf() >= item_chance:
			continue
		give_item(p, Item.random())
		item_gained.emit(p, p.item)


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

extends Node
## Headless smoke test. Run with:
##   godot --headless res://tests/sim_test.tscn
## Checks the hand evaluator, then plays an all-NPC game with no delays and verifies
## that chips are conserved after every hand. Exit code = number of failures.

var _failures := 0


func _ready() -> void:
	_test_evaluator()
	_run_simulation()


func _test_evaluator() -> void:
	_expect("As Ks Qs Js Ts 2d 3c", HandEvaluator.Category.STRAIGHT_FLUSH, [14])
	_expect("Ah 2d 3c 4s 5h Kd Kc", HandEvaluator.Category.STRAIGHT, [5])
	_expect("Ah Ad Ac Kh Kd Kc 2s", HandEvaluator.Category.FULL_HOUSE, [14, 13])
	_expect("Ah Ad Kh Kd Qh Qd 2c", HandEvaluator.Category.TWO_PAIR, [14, 13, 12])
	_expect("9h 9d 9c 9s 2h 3d Kc", HandEvaluator.Category.FOUR_OF_A_KIND, [9, 13])
	_expect("2h 7h 9h Jh Kh Ad Qd", HandEvaluator.Category.FLUSH, [13, 11, 9, 7, 2])
	_expect("2h 3h 4h 5h 7h 6d 8c", HandEvaluator.Category.FLUSH, [7, 5, 4, 3, 2])
	_expect("2c 5d 9h Jh Kh Ad 3s", HandEvaluator.Category.HIGH_CARD, [14, 13, 11, 9, 5])
	_check(HandEvaluator.compare(_score("Ah Kd 2c 3c 4d 8h 9s"), _score("Ac Kh 2d 3s 4h 8d 9c")) == 0, "split pot tie")
	_check(HandEvaluator.compare(_score("Ah Ad Kc 7s 2d 3h 4s"), _score("Ah Ad Qc 7s 2d 3h 4s")) > 0, "pair kicker")
	_test_remove_heart()
	_test_shield()
	_test_stimpak()
	_test_stimpak_phase()
	_test_items()
	_test_item_phase()
	_test_item_odds()
	_expect_best_five("Ah Kd 7c 7s 2d 3h Ac", "Ah Ac 7c 7s Kd")
	_expect_best_five("2h 3h 4h 5h 7h 6d 8c", "7h 5h 4h 3h 2h")
	_expect_best_five("Ah 2d 3c 4s 5h Kd Kc", "Ah 2d 3c 4s 5h")


func _test_shield() -> void:
	var table := PokerTable.new()
	var you := PokerPlayer.new("YOU", 1000)
	you.item = Item.Kind.GUN
	var npc := PokerPlayer.new("NPC", 400, NpcBrain.new())
	npc.item = Item.Kind.SHIELD
	table.setup([you, npc])
	_check(table.shoot(you, npc) == Item.ShotResult.SHIELD_BROKE and npc.hearts == 3 and not npc.has_item(), "a shield breaks instead of losing a heart")
	_check(not you.has_item(), "shooting uses up the gun")
	_check(table.shoot(you, npc) == Item.ShotResult.HIT and npc.hearts == 2, "once broken, the next shot takes a heart")
	table.free()


func _test_remove_heart() -> void:
	var table := PokerTable.new()
	var you := PokerPlayer.new("YOU", 1000)
	var npc := PokerPlayer.new("NPC", 400, NpcBrain.new())
	table.setup([you, npc])
	_check(not table.remove_heart(npc, you) and npc.hearts == 2 and npc.chips == 400, "first shot only takes a heart")
	_check(not table.remove_heart(npc, you) and npc.hearts == 1, "second shot only takes a heart")
	_check(table.remove_heart(npc, you) and npc.hearts == 0, "third shot eliminates")
	_check(npc.chips == 0 and you.chips == 1400, "eliminated player's chips go to the shooter")
	_check(not table.remove_heart(npc, you) and npc.hearts == 0, "no hearts below zero")
	table.free()


## Plays one all-NPC hand at a forced item chance, then calls [param done] with the table.
func _play_one_hand(item_chance: float, players: Array[PokerPlayer], done: Callable) -> void:
	_play_hands(1, item_chance, players, done)


## Plays up to [param hands] all-NPC hands (with no pauses, so every hand but the last is
## followed by an item phase), then calls [param done] with the table.
func _play_hands(hands: int, item_chance: float, players: Array[PokerPlayer], done: Callable,
		setup := Callable()) -> void:
	var table := PokerTable.new()
	table.deal_delay = 0
	table.npc_think_time = 0
	table.showdown_delay = 0
	table.between_hands_delay = 0
	table.shot_delay = 0
	table.max_hands = hands
	table.item_chance = item_chance
	add_child(table)
	table.setup(players)
	table.game_over.connect(func(_leader: PokerPlayer) -> void:
		done.call(table)
		table.queue_free())
	if setup.is_valid():
		setup.call(table)
	table.start_game()


func _test_item_odds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var counts := {}
	for i in 40_000:
		var item := Item.random(rng)
		counts[item] = counts.get(item, 0) + 1
	# Weights 3 : 1 : 1, so 24000 : 8000 : 8000 expected.
	for item: Item.Kind in [Item.Kind.GUN, Item.Kind.SHIELD, Item.Kind.STIMPAK]:
		var want := 40_000 * Item.weight(item) / 5
		var got: int = counts.get(item, 0)
		_check(absi(got - want) < 1_000, "%s pickups match their weight (got %d of 40000, want ~%d)" % [Item.display_name(item), got, want])


func _test_stimpak() -> void:
	var table := PokerTable.new()
	var hurt := PokerPlayer.new("HURT", 1000, NpcBrain.new())
	var healthy := PokerPlayer.new("HEALTHY", 1000, NpcBrain.new())
	table.setup([hurt, healthy])
	_check(Item.can_be_used(Item.Kind.STIMPAK), "a stimpak can be used")

	hurt.hearts = 1
	hurt.item = Item.Kind.STIMPAK
	_check(table.use_stimpak(hurt) and hurt.hearts == 2, "a stimpak wins back one heart")
	_check(not hurt.has_item(), "using a stimpak uses it up")
	hurt.item = Item.Kind.STIMPAK
	_check(table.use_stimpak(hurt) and hurt.hearts == 3 and not hurt.has_item(), "a second stimpak heals back to full")

	healthy.item = Item.Kind.STIMPAK
	_check(not table.use_stimpak(healthy) and healthy.hearts == 3, "a stimpak does nothing at full health")
	_check(not healthy.has_item(), "a stimpak is used up even at full health")

	# Like a gun, it's only ready from the end of the hand after it was picked up.
	healthy.item = Item.Kind.STIMPAK
	healthy.item_gained_on_hand = 4
	table.hand_number = 4
	_check(not table.can_use_item(healthy), "a new stimpak can't be used at the end of the hand it was picked up")
	table.hand_number = 5
	_check(table.can_use_item(healthy), "a stimpak can be used at the end of the next hand")

	# NPCs save a stimpak until they're hurt.
	var brain := NpcBrain.new()
	var no_targets: Array[PokerPlayer] = []
	healthy.hearts = 3
	_check(brain.decide_item(healthy, true, no_targets).action == Item.Action.KEEP, "an NPC at full health keeps their stimpak")
	healthy.hearts = 2
	_check(brain.decide_item(healthy, true, no_targets).action == Item.Action.USE, "a hurt NPC uses a ready stimpak")
	_check(brain.decide_item(healthy, false, no_targets).action == Item.Action.KEEP, "an NPC can't use a stimpak before it's ready")
	table.free()


func _test_stimpak_phase() -> void:
	# A hurt NPC with a ready stimpak uses it in the item phase after a hand (unless they folded).
	var brain := NpcBrain.new()
	brain.simulations = 20
	var players: Array[PokerPlayer] = [
		PokerPlayer.new("A", 100_000, brain), PokerPlayer.new("B", 1000, brain), PokerPlayer.new("C", 1000, brain),
	]
	players[0].hearts = 2
	players[0].item = Item.Kind.STIMPAK
	players[0].item_gained_on_hand = -1
	var seen := {"healed": null, "folded": null}
	_play_hands(2, 0, players, func(_table: PokerTable) -> void:
		if seen.folded == false:
			_check(seen.healed == true and players[0].hearts == 3, "a hurt NPC heals with their stimpak in the item phase")
			_check(not players[0].has_item(), "the NPC's stimpak is used up")
		elif seen.folded == true:
			_check(seen.healed == null and players[0].item == Item.Kind.STIMPAK, "a player who folded doesn't use their stimpak"),
		func(table: PokerTable) -> void:
			table.stimpak_used.connect(func(_p: PokerPlayer, healed: bool) -> void: seen.healed = healed)
			table.item_phase_finished.connect(func() -> void:
				if seen.folded == null:
					seen.folded = players[0].folded))


func _test_item_phase() -> void:
	# A ready gun in the hands of a maximally aggressive NPC always gets fired after the hand,
	# unless they folded it (then they get no item turn). A's huge stack keeps them in the game.
	var gunman := NpcBrain.new()
	gunman.simulations = 20
	gunman.aggression = 1
	var brain := NpcBrain.new()
	brain.simulations = 20
	var players: Array[PokerPlayer] = [
		PokerPlayer.new("A", 100_000, gunman), PokerPlayer.new("B", 1000, brain), PokerPlayer.new("C", 1000, brain),
	]
	players[0].item = Item.Kind.GUN
	players[0].item_gained_on_hand = -1
	# Lambdas capture locals by value, so the results they record go in here.
	# gunman_folded is as of the (only) item phase, after hand 1.
	var seen := {"shooter": null, "victim": null, "gunman_folded": null}
	_play_hands(2, 0, players, func(_table: PokerTable) -> void:
		if seen.gunman_folded == false:
			_check(seen.shooter == players[0] and seen.victim != null and seen.victim != players[0], "an aggressive NPC fires a ready gun at someone else")
			_check(not players[0].has_item(), "firing uses up the NPC's gun")
			_check(players[1].hearts + players[2].hearts == 5, "the shot takes exactly one heart")
		elif seen.gunman_folded == true:
			_check(seen.shooter == null and players[0].item == Item.Kind.GUN, "a player who folded gets no item turn"),
		func(table: PokerTable) -> void:
			table.shot.connect(func(s: PokerPlayer, t: PokerPlayer, _result: Item.ShotResult) -> void:
				seen.shooter = s
				seen.victim = t)
			table.item_phase_finished.connect(func() -> void:
				if seen.gunman_folded == null:
					seen.gunman_folded = players[0].folded))


func _test_items() -> void:
	var brain := NpcBrain.new()
	brain.simulations = 20
	var never: Array[PokerPlayer] = [PokerPlayer.new("A", 1000, brain), PokerPlayer.new("B", 1000, brain)]
	_play_one_hand(0, never, func(_table: PokerTable) -> void:
		_check(never.all(func(p: PokerPlayer) -> bool: return not p.has_item()), "no items at 0% chance"))

	var always: Array[PokerPlayer] = [PokerPlayer.new("A", 1000, brain), PokerPlayer.new("B", 1000, brain), PokerPlayer.new("C", 0, brain)]
	_play_one_hand(1, always, func(table: PokerTable) -> void:
		_check(always.all(func(p: PokerPlayer) -> bool: return p.chips <= 0 or p.has_item()), "everyone still in gets an item at 100%")
		_check(not always[2].has_item(), "busted players get no item")
		# A or B, whoever didn't bust (and so picked up an item).
		var holder: PokerPlayer = always.filter(func(p: PokerPlayer) -> bool: return p.has_item())[0]
		_check(not table.can_use_item(holder), "a new item can't be used at the end of the hand it was picked up")
		_check(holder.can_use_item(table.hand_number + 1), "an item can be used at the end of the next hand"))

	# Someone already carrying an item doesn't roll for another.
	var holding: Array[PokerPlayer] = [PokerPlayer.new("A", 1000, brain), PokerPlayer.new("B", 1000, brain)]
	holding[0].item = Item.Kind.GUN
	holding[0].item_gained_on_hand = -1
	_play_one_hand(1, holding, func(_table: PokerTable) -> void:
		_check(holding[0].chips == 0 or holding[0].item_gained_on_hand == -1, "no new item while already carrying one"))


func _run_simulation() -> void:
	var brains: Array[NpcBrain] = []
	for path in GameConfig.OPPONENT_PATHS:
		brains.append(load(path))
	for brain in brains:
		_check(brain.portrait != null, "%s has a portrait" % brain.display_name)
		_check(brain.injured_portrait != null, "%s has an injured portrait" % brain.display_name)
	var table := PokerTable.new()
	table.deal_delay = 0
	table.npc_think_time = 0
	table.showdown_delay = 0
	table.between_hands_delay = 0
	table.max_hands = 300
	table.wait_for_next_hand = true
	add_child(table)
	# One NPC per opponent slot plus one in the human's seat, so the game runs unattended.
	var seated := brains.duplicate()
	seated.append(brains[0])
	var players: Array[PokerPlayer] = []
	for i in seated.size():
		players.append(PokerPlayer.new("%s%d" % [seated[i].display_name, i], 1000, seated[i]))
	table.setup(players)
	var expected := _total_chips(table)

	table.hand_finished.connect(func() -> void:
		var total := _total_chips(table)
		_check(total == expected, "chips conserved after hand %d (%d != %d)" % [table.hand_number, total, expected])
		_check(table.players.all(func(p: PokerPlayer) -> bool: return p.chips >= 0), "no negative stacks"))
	# Lambdas capture locals by value, so the counters live in here.
	var counts := {"shots": 0, "stimpaks": 0, "pauses": 0}
	# Stand in for the view: start item turns straight away, and count the shots fired.
	table.waiting_for_item_phase.connect(table.begin_item_phase)
	table.shot.connect(func(_s: PokerPlayer, _t: PokerPlayer, _result: Item.ShotResult) -> void:
		counts.shots += 1)
	table.stimpak_used.connect(func(_p: PokerPlayer, _healed: bool) -> void:
		counts.stimpaks += 1)
	# Stand in for the "next hand" button.
	table.waiting_for_next_hand.connect(func() -> void:
		counts.pauses += 1
		table.continue_to_next_hand())
	table.game_over.connect(func(winner: PokerPlayer) -> void:
		# Every hand but the game-ending one should pause for the button.
		_check(counts.pauses == table.hand_number - 1, "paused %d times over %d hands" % [counts.pauses, table.hand_number])
		print("Simulated %d hands (%d gunshots, %d stimpaks), leader %s with %d" % [table.hand_number, counts.shots, counts.stimpaks, winner.display_name, winner.chips])
		print("ALL TESTS PASSED" if _failures == 0 else "%d FAILURE(S)" % _failures)
		get_tree().quit(_failures))
	table.start_game()


static func _total_chips(table: PokerTable) -> int:
	var total := 0
	for p in table.players:
		total += p.chips
	return total


func _expect(hand: String, category: HandEvaluator.Category, tiebreaks: Array[int]) -> void:
	var score := _score(hand)
	var expected: Array[int] = [category]
	expected.append_array(tiebreaks)
	_check(score == expected, "%s: got %s, want %s" % [hand, score, expected])


func _expect_best_five(hand: String, expected: String) -> void:
	var best: Array[String] = []
	for c in HandEvaluator.best_five(_parse_hand(hand)):
		best.append(str(c))
	best.sort()
	var want: Array[String] = []
	for c in _parse_hand(expected):
		want.append(str(c))
	want.sort()
	_check(best == want, "best five of %s: got %s, want %s" % [hand, " ".join(best), " ".join(want)])


static func _score(hand: String) -> Array[int]:
	return HandEvaluator.evaluate(_parse_hand(hand))


static func _parse_hand(hand: String) -> Array[Card]:
	var cards: Array[Card] = []
	for s in hand.split(" "):
		cards.append(_parse(s))
	return cards


static func _parse(s: String) -> Card:
	var rank := "23456789TJQKA".find(s[0]) + 2
	return Card.new(rank, "cdhs".find(s[1]) as Card.Suit)


func _check(ok: bool, what: String) -> void:
	if ok:
		return
	_failures += 1
	printerr("FAIL: " + what)

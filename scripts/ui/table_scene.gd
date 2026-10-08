class_name TableScene
extends Control
## Visual layer for a poker table. Builds the UI, owns a [PokerTable], and
## translates its signals into on-screen updates and human input back into decisions.

# Stack pile (no label) and bet pile (with label) offsets from a pair's centre.
const STACK_PILE_OFFSET := Vector2(-22, 0)
const BET_PILE_OFFSET := Vector2(22, 0)
const STACK_PILE_OFFSET_VERTICAL := Vector2(0, -19)
const BET_PILE_OFFSET_VERTICAL := Vector2(0, 19)

const CHIP_CHANGE_HOLD := 0.6
const CHIP_CHANGE_FADE := 0.4
const CHIP_CHANGE_RISE := 10.0
const CHIP_CHANGE_FONT_SIZE := UiTheme.FONT_SIZE + 4
const POT_FONT_SIZE := UiTheme.FONT_SIZE + 4
const POT_POP_SIZE := POT_FONT_SIZE + 6
## Z index of the winning-hand banner and item notices: above the portraits, the gun and the
## chip-change labels (all at SeatView.DARKEN_Z + 1), below the DEBUG popup.
const BANNER_Z := SeatView.DARKEN_Z + 2
## The "TABLE N" label: a little bigger than the players' names, to fill the header strip.
const TABLE_LABEL_FONT_SIZE := 18
## Dark blue felt behind the table, filling the screen.
const BACKDROP := Color("16203a")
## Share of the felt's pixels drawn a shade darker / lighter on a textured felt.
const FELT_DARK_SHARE := 0.12
const FELT_LIGHT_SHARE := 0.08

var _level: TableLevel = GameConfig.table_level()
var _table: PokerTable
var _layout: PortraitLayout
var _backdrop_texture: Texture2D
# Grained felt, covering the whole table rect (null on a plain felt).
var _felt_texture: Texture2D
var _felt_inner_texture: Texture2D
var _seats: Array[SeatView] = []
var _stack_piles: Array[ChipPileView] = []
var _bet_piles: Array[ChipPileView] = []
var _community: Array[CardView] = []
var _winners := {} # PokerPlayer -> true
var _winning_cards := {} # Card -> true: winners' best five, kickers included
var _scoring_cards := {} # Card -> true: just the cards that made each winning hand
var _pot: PotView
var _shown_pot := 0
var _shown_chips: Array[int] = [] # each player's stack as last shown
var _chip_change_labels := {} # SeatView -> the "+100" Label currently over its portrait
var _pot_tween: Tween
var _action_bar: Panel
var _fold_button: Button
var _call_button: Button
var _raise_button: Button
var _raise_slider: HSlider
var _raise_label: Label
var _next_hand_button: Button
var _use_item_button: Button
var _drop_item_button: Button
var _human_item_turn := false # the item phase is waiting on the human's choice
var _continue_after_items := false # NEXT HAND was pressed on the human's item turn
var _debug_menu: DebugMenu
var _gun: GunView
var _shot_darken: ColorRect
var _shot_tracer: ShotTracer
var _shot_darken_tween: Tween
var _target_hint: Label
var _win_banner: WinBanner
var _notices: NoticeBanner
var _item_news: Array[String] = [] # this hand's item pickups, announced once it's settled
var _targeting := false
var _to_call := 0


## Area a stack-over-bet pile pair can cover, relative to its centre.
static func vertical_pile_unit_bounds() -> Rect2:
	return _pair_bounds(STACK_PILE_OFFSET_VERTICAL, BET_PILE_OFFSET_VERTICAL)


## Area a stack-beside-bet pile pair can cover, relative to its centre.
static func horizontal_pile_unit_bounds() -> Rect2:
	return _pair_bounds(STACK_PILE_OFFSET, BET_PILE_OFFSET)


static func _pair_bounds(stack_offset: Vector2, bet_offset: Vector2) -> Rect2:
	var stack := ChipPileView.bounds_for(false)
	var bet := ChipPileView.bounds_for(true)
	return Rect2(stack.position + stack_offset, stack.size).merge(Rect2(bet.position + bet_offset, bet.size))


func _ready() -> void:
	_table = PokerTable.new()
	_table.small_blind = _level.small_blind
	_table.big_blind = _level.big_blind
	_table.npc_think_time = GameConfig.npc_think_time
	_table.deal_delay = GameConfig.deal_delay
	_table.showdown_delay = GameConfig.showdown_delay
	_table.between_hands_delay = GameConfig.between_hands_delay
	_table.wait_for_next_hand = true
	add_child(_table)
	_table.setup(GameConfig.create_players())

	_build_ui()
	_connect_table()
	_table.start_game()


func _draw() -> void:
	draw_texture(_backdrop_texture, Vector2.ZERO)
	# A long table between the two NPC columns: wooden rail, felt, lighter inner felt.
	var table := _layout.table
	draw_colored_polygon(_chamfered(table, 6), Color("5a3a22"))
	_draw_felt(_chamfered(table.grow(-3), 5), _level.felt, _felt_texture)
	_draw_felt(_chamfered(table.grow(-9), 4), _level.felt_inner, _felt_inner_texture)


func _draw_felt(points: PackedVector2Array, color: Color, texture: Texture2D) -> void:
	if texture == null:
		draw_colored_polygon(points, color)
		return
	var table := _layout.table
	var uvs := PackedVector2Array()
	for p in points:
		uvs.append((p - table.position) / table.size)
	draw_colored_polygon(points, Color.WHITE, uvs, texture)


## Faint grain (the backdrop, and some tables' felt): [param color] with scattered pixels a shade darker or lighter, as a texture of
## [param size]. A random tile, repeated, so it's quick to build.
static func _grained_felt(color: Color, size: Vector2i) -> Texture2D:
	const TILE := 48
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var tile := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	tile.fill(color)
	var dark := color.darkened(0.12)
	var light := color.lightened(0.05)
	for y in TILE:
		for x in TILE:
			var roll := rng.randf()
			if roll < FELT_DARK_SHARE:
				tile.set_pixel(x, y, dark)
			elif roll < FELT_DARK_SHARE + FELT_LIGHT_SHARE:
				tile.set_pixel(x, y, light)
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in range(0, size.y, TILE):
		for x in range(0, size.x, TILE):
			image.blit_rect(tile, Rect2i(0, 0, TILE, TILE), Vector2i(x, y))
	return ImageTexture.create_from_image(image)


## Rectangle with its corners cut at 45 degrees: reads as "rounded" at pixel scale.
static func _chamfered(r: Rect2, c: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(r.position.x + c, r.position.y), Vector2(r.end.x - c, r.position.y),
		Vector2(r.end.x, r.position.y + c), Vector2(r.end.x, r.end.y - c),
		Vector2(r.end.x - c, r.end.y), Vector2(r.position.x + c, r.end.y),
		Vector2(r.position.x, r.end.y - c), Vector2(r.position.x, r.position.y + c),
	])


# --- UI construction ---------------------------------------------------

func _build_ui() -> void:
	var insets := PortraitLayout.safe_insets(get_viewport())
	var viewport_size := get_viewport_rect().size
	_layout = PortraitLayout.new(viewport_size, _table.players.size() - 1, insets.x, insets.y)
	var pot_center := _layout.pot_center
	_backdrop_texture = _grained_felt(BACKDROP, Vector2i(viewport_size.ceil()))
	if _level.textured:
		var felt_size := Vector2i(_layout.table.size.ceil())
		_felt_texture = _grained_felt(_level.felt, felt_size)
		_felt_inner_texture = _grained_felt(_level.felt_inner, felt_size)

	# Which table this is, in the header strip above the felt, on the left; lettered like the
	# players' names.
	var table_label := Label.new()
	table_label.text = "TABLE %d" % _level.number
	table_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiTheme.add_at(self, table_label,
		Vector2(_layout.header.position.x, _layout.header.get_center().y - UiTheme.LINE_HEIGHT / 2.0),
		Vector2(_layout.header.size.x / 2, UiTheme.LINE_HEIGHT))
	table_label.add_theme_color_override("font_color", PixelArt.GOLD)
	table_label.add_theme_font_size_override("font_size", TABLE_LABEL_FONT_SIZE)

	# players[0] is the human (bottom right); opponents fill the edge columns clockwise.
	var human_portrait: Texture2D = load(GameConfig.player_portrait_path)
	var human_injured_portrait: Texture2D = load(GameConfig.player_injured_portrait_path)
	for i in _table.players.size():
		var player := _table.players[i]
		var slot := _layout.human if i == 0 else _layout.opponents[i - 1]
		var seat := SeatView.new()
		seat.player = player
		var npc_portrait: Texture2D = player.brain.portrait if player.brain else null
		var npc_injured_portrait: Texture2D = player.brain.injured_portrait if player.brain else null
		seat.portrait = npc_portrait if npc_portrait else human_portrait
		seat.injured_portrait = npc_injured_portrait if npc_injured_portrait else human_injured_portrait
		seat.style = slot.style
		seat.max_hearts = GameConfig.starting_hearts
		seat.position = slot.seat_position.round()
		add_child(seat)
		seat.targeted.connect(_on_seat_targeted)
		_seats.append(seat)
		_shown_chips.append(player.chips)

		# Stack (whole bankroll) left/above, this hand's bet right/below.
		var stack := ChipPileView.new()
		stack.position = slot.pile_center + (STACK_PILE_OFFSET_VERTICAL if slot.vertical_piles else STACK_PILE_OFFSET)
		stack.show_label = false
		add_child(stack)
		_stack_piles.append(stack)
		var bet := ChipPileView.new()
		bet.position = slot.pile_center + (BET_PILE_OFFSET_VERTICAL if slot.vertical_piles else BET_PILE_OFFSET)
		add_child(bet)
		_bet_piles.append(bet)

	# The board, drawn large in the space under the NPCs.
	var step := CardView.CARD_SIZE.x * PortraitLayout.BOARD_CARD_SCALE + PortraitLayout.BOARD_CARD_GAP
	for i in 5:
		var view := CardView.new()
		view.show_empty_slot = true
		view.pixel_scale = PortraitLayout.BOARD_CARD_SCALE
		view.position = _layout.board_origin + Vector2(i * step, 0)
		add_child(view)
		_community.append(view)

	# Pot of gold + amount; the box is tall and centred so it grows from its middle when it pops.
	_pot = PotView.new()
	_pot.font_size = POT_FONT_SIZE
	UiTheme.add_at(self, _pot, pot_center - Vector2(80, 20), Vector2(160, 40))

	var debug_button := _new_button("DEBUG")
	UiTheme.add_at(self, debug_button, _layout.debug_button.position, _layout.debug_button.size)
	debug_button.pressed.connect(func() -> void: _debug_menu.show())

	# Shown under the board, in the (then empty) pot label's spot, once a hand is over, and on
	# the human's item turn, where it means "keep my item": the rest of the table takes its
	# item turns, then the next hand is dealt straight away.
	_next_hand_button = _new_button("NEXT HAND", false)
	UiTheme.add_at(self, _next_hand_button, pot_center - PortraitLayout.NEXT_HAND_SIZE / 2, PortraitLayout.NEXT_HAND_SIZE)
	_next_hand_button.pressed.connect(func() -> void:
		_next_hand_button.visible = false
		if _human_item_turn:
			_continue_after_items = true
			_submit_item_decision(ItemDecision.new(Item.Action.KEEP))
		else:
			_clear_table_then_continue())

	# A gunshot in the item phase: gun in the screen centre (and, while the human aims, a hint
	# under the board).
	_gun = GunView.new()
	_gun.visible = false
	# Floats in the centre of the screen.
	_gun.position = (viewport_size / 2 - GunView.art_size / 2).round()
	add_child(_gun)
	# Gunshot flash-to-dark over the table; the gun and portraits sit above it.
	_shot_darken = ColorRect.new()
	_shot_darken.color = Color(0, 0, 0, 0)
	_shot_darken.mouse_filter = MOUSE_FILTER_IGNORE
	_shot_darken.z_index = SeatView.DARKEN_Z
	UiTheme.add_at(self, _shot_darken, Vector2.ZERO, viewport_size)
	_gun.z_index = SeatView.DARKEN_Z + 1
	# Same layer as the darkening, drawn after it: over the dimmed table, under the portraits.
	_shot_tracer = ShotTracer.new()
	_shot_tracer.z_index = SeatView.DARKEN_Z
	UiTheme.add_at(self, _shot_tracer, Vector2.ZERO, viewport_size)
	_target_hint = Label.new()
	_target_hint.text = "PICK A TARGET"
	_target_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_target_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_target_hint.visible = false
	UiTheme.add_at(self, _target_hint, pot_center - PortraitLayout.NEXT_HAND_SIZE / 2, PortraitLayout.NEXT_HAND_SIZE)
	_target_hint.add_theme_color_override("font_color", PixelArt.HEART_RED)

	_build_action_bar()

	# The human's item turn, in the action panel's area: DROP in its bottom slot, and USE just
	# above it once the item is ready. (Keeping it is NEXT HAND.)
	var bar := _layout.action_bar
	var item_button_size := Vector2(bar.size.x - PortraitLayout.ACTION_PADDING * 2, PortraitLayout.ACTION_BUTTON_HEIGHT)
	var drop_at := Vector2(bar.position.x + PortraitLayout.ACTION_PADDING,
		bar.end.y - PortraitLayout.ACTION_PADDING - PortraitLayout.ACTION_BUTTON_HEIGHT)
	_drop_item_button = _new_button("", false)
	UiTheme.add_at(self, _drop_item_button, drop_at, item_button_size)
	_drop_item_button.pressed.connect(func() -> void: _submit_item_decision(ItemDecision.new(Item.Action.DROP)))
	_use_item_button = _new_button("", false)
	UiTheme.add_at(self, _use_item_button,
		drop_at - Vector2(0, PortraitLayout.ACTION_BUTTON_HEIGHT + PortraitLayout.ACTION_GAP), item_button_size)
	_use_item_button.pressed.connect(_use_item)

	# Added last so it draws over everything else.
	_win_banner = WinBanner.new()
	_win_banner.z_index = BANNER_Z
	_win_banner.max_bottom = _layout.board_origin.y - 4
	UiTheme.add_at(self, _win_banner, Vector2.ZERO, viewport_size)
	# Item notices run across the screen over the middle of the board.
	var board_mid := _layout.board_origin.y + CardView.CARD_SIZE.y * PortraitLayout.BOARD_CARD_SCALE / 2
	_notices = NoticeBanner.new()
	_notices.z_index = BANNER_Z
	UiTheme.add_at(self, _notices,
		Vector2(0, floorf(board_mid - NoticeBanner.STRIP_HEIGHT / 2)),
		Vector2(viewport_size.x, NoticeBanner.STRIP_HEIGHT))

	# Added last so it takes input before anything else.
	_debug_menu = DebugMenu.new()
	UiTheme.add_at(self, _debug_menu, Vector2.ZERO, viewport_size)
	_debug_menu.give_item.connect(_debug_give_item)
	_debug_menu.lose_heart.connect(_debug_lose_heart)
	_debug_menu.win_table.connect(func() -> void: _show_game_over(_table.players[0]))


func _build_action_bar() -> void:
	# A column of big, well-spaced touch targets beside the human's seat:
	# FOLD, CALL, raise amount, RAISE.
	var bar := _layout.action_bar
	_action_bar = Panel.new()
	_action_bar.visible = false
	UiTheme.add_at(self, _action_bar, bar.position, bar.size)
	var pad := PortraitLayout.ACTION_PADDING
	var gap := PortraitLayout.ACTION_GAP
	var button_h := PortraitLayout.ACTION_BUTTON_HEIGHT
	var slider_h := PortraitLayout.ACTION_SLIDER_HEIGHT
	var inner := bar.size.x - pad * 2

	var y := pad
	_fold_button = _action_button("FOLD", y, func() -> void: _submit(Decision.new(Poker.Action.FOLD)))
	y += button_h + gap
	_call_button = _action_button("CALL", y, func() -> void:
		_submit(Decision.new(Poker.Action.CHECK if _to_call == 0 else Poker.Action.CALL)))
	y += button_h + gap

	_raise_slider = HSlider.new()
	_raise_slider.step = 1
	UiTheme.add_at(_action_bar, _raise_slider, Vector2(pad, y), Vector2(inner - 78, slider_h))
	_raise_slider.value_changed.connect(func(_value: float) -> void: _update_raise_label())
	_raise_label = Label.new()
	_raise_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_raise_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiTheme.add_at(_action_bar, _raise_label, Vector2(pad + inner - 74, y), Vector2(74, slider_h))
	y += slider_h + gap

	_raise_button = _action_button("RAISE", y, func() -> void:
		_submit(Decision.new(Poker.Action.RAISE, int(_raise_slider.value))))


func _action_button(text: String, y: float, on_pressed: Callable) -> Button:
	var pad := PortraitLayout.ACTION_PADDING
	var button := _new_button(text)
	UiTheme.add_at(_action_bar, button,
		Vector2(pad, y), Vector2(_layout.action_bar.size.x - pad * 2, PortraitLayout.ACTION_BUTTON_HEIGHT))
	button.pressed.connect(on_pressed)
	return button


static func _new_button(text: String, shown := true) -> Button:
	var button := Button.new()
	button.text = text
	button.visible = shown
	return button


func _submit(decision: Decision) -> void:
	_action_bar.visible = false
	_table.submit_human_action(decision)


func _update_raise_label() -> void:
	var all_in := int(_raise_slider.value) >= int(_raise_slider.max_value)
	_raise_label.text = "ALL IN" if all_in else "TO $%d" % int(_raise_slider.value)


# --- Human input -------------------------------------------------------

func _show_actions(p: PokerPlayer, to_call: int, min_to: int, max_to: int) -> void:
	_to_call = to_call
	_call_button.text = "CHECK" if to_call == 0 else "ALL IN" if to_call >= p.chips else "CALL $%d" % to_call

	var can_raise := p.chips > to_call
	_raise_button.disabled = not can_raise
	_raise_slider.editable = can_raise and max_to > min_to
	_raise_slider.min_value = min_to
	_raise_slider.max_value = max_to
	_raise_slider.value = min_to
	_raise_button.text = "BET" if _table.current_bet == 0 else "RAISE"
	_update_raise_label()
	_action_bar.visible = true


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not _action_bar.visible or key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_F:
			_fold_button.pressed.emit()
		KEY_C:
			_call_button.pressed.emit()
		KEY_R:
			if not _raise_button.disabled:
				_raise_button.pressed.emit()


# --- Table signals -----------------------------------------------------

func _connect_table() -> void:
	_table.hand_started.connect(func(_number: int, dealer: int) -> void:
		for seat in _seats:
			seat.set_dealer(seat.player.seat == dealer)
			seat.set_reveal(false)
			seat.set_status("")
		for view in _community:
			view.set_card(null, false)
		_winners.clear()
		_winning_cards.clear()
		_scoring_cards.clear()
		_win_banner.hide_banner()
		_item_news.clear()
		_notices.clear()
		_apply_win_highlights())
	_table.street_started.connect(func(street: Poker.Street) -> void:
		if street == Poker.Street.PREFLOP:
			return
		for seat in _seats:
			if seat.player.in_hand() and not seat.player.all_in:
				seat.set_status(""))
	_table.hole_cards_dealt.connect(_refresh_seats)
	_table.community_changed.connect(func(cards: Array[Card]) -> void:
		for i in _community.size():
			_community[i].set_card(cards[i] if i < cards.size() else null, true))
	_table.turn_started.connect(func(player: PokerPlayer, to_call: int, min_to: int, max_to: int) -> void:
		for seat in _seats:
			seat.set_active(seat.player == player)
		if player.is_human():
			_show_actions(player, to_call, min_to, max_to))
	_table.player_acted.connect(func(player: PokerPlayer, action: Poker.Action, amount: int) -> void:
		var text: String
		match action:
			Poker.Action.FOLD: text = "FOLD"
			Poker.Action.CHECK: text = "CHECK"
			Poker.Action.CALL: text = "CALL %d" % amount
			_: text = "RAISE TO %d" % amount
		if player.all_in and action != Poker.Action.FOLD:
			text = "ALL IN"
		_seats[player.seat].set_status(text)
		_seats[player.seat].set_active(false))
	_table.chips_changed.connect(_refresh_seats)
	_table.item_gained.connect(func(player: PokerPlayer, item: Item.Kind) -> void:
		_seats[player.seat].refresh()
		_item_news.append(Item.gained_text(item, player.display_name)))
	_table.showdown.connect(func(contenders: Array[PokerPlayer], scores: Dictionary) -> void:
		for p in contenders:
			_seats[p.seat].set_reveal(true)
			_seats[p.seat].set_status(_seat_hand_name(scores[p]), PixelArt.PAPER)
		# Announce the best hand at the table (it takes the main pot) and whoever holds it.
		var best: Array[int] = scores[contenders[0]]
		for p in contenders:
			if HandEvaluator.compare(scores[p], best) > 0:
				best = scores[p]
		var names: PackedStringArray = []
		for p in contenders:
			if HandEvaluator.compare(scores[p], best) == 0:
				names.append(p.display_name.to_upper())
		_win_banner.show_banner(HandEvaluator.describe(best).to_upper(), " & ".join(names)))
	_table.pot_awarded.connect(func(player: PokerPlayer, amount: int, hand_name: String) -> void:
		_seats[player.seat].set_status("WINS $%d" % amount, PixelArt.GOLD)
		_winners[player] = true
		# Uncontested pots have no shown hand; only showdown winners light up cards.
		if hand_name != "":
			var cards := player.hole_cards.duplicate()
			cards.append_array(_table.community)
			var five := HandEvaluator.best_five(cards)
			for c in five:
				_winning_cards[c] = true
			for c in HandEvaluator.scoring_cards(five):
				_scoring_cards[c] = true
		_apply_win_highlights())
	_table.waiting_for_item_phase.connect(func() -> void:
		for seat in _seats:
			seat.set_active(false)
		# Let the winning-hand banner finish, then announce any items, before the item turns.
		if _win_banner.visible:
			if not _win_banner.finished.is_connected(_announce_items):
				_win_banner.finished.connect(_announce_items, CONNECT_ONE_SHOT)
		else:
			_announce_items())
	_table.item_turn_started.connect(func(player: PokerPlayer, can_use: bool) -> void:
		for seat in _seats:
			seat.set_active(seat.player == player)
		if player.is_human():
			_human_item_turn = true
			_show_item_buttons(can_use))
	_table.shot.connect(_on_shot)
	_table.stimpak_used.connect(func(player: PokerPlayer, healed: bool) -> void:
		var seat := _seats[player.seat]
		if healed:
			seat.set_status("+1 HEART", PixelArt.HEAL_GREEN)
			seat.flash_heal()
		else:
			seat.set_status("WASTED", PixelArt.PAPER)
		seat.refresh())
	_table.item_dropped.connect(func(player: PokerPlayer, item: Item.Kind) -> void:
		_seats[player.seat].set_status("DROPPED %s" % Item.display_name(item), PixelArt.PAPER)
		_seats[player.seat].refresh())
	_table.item_phase_finished.connect(func() -> void:
		for seat in _seats:
			seat.set_active(false))
	_table.waiting_for_next_hand.connect(func() -> void:
		if _continue_after_items:
			_continue_after_items = false
			_clear_table_then_continue()
			return
		_next_hand_button.visible = true
		_next_hand_button.grab_focus()) # Enter / Space also continue
	_table.game_over.connect(_show_game_over)


## One notice per item picked up this hand, in turn; then the item turns begin.
func _announce_items() -> void:
	if _item_news.is_empty():
		_table.begin_item_phase()
		return
	if not _notices.finished.is_connected(_table.begin_item_phase):
		_notices.finished.connect(_table.begin_item_phase, CONNECT_ONE_SHOT)
	for text in _item_news:
		_notices.enqueue(text)
	_item_news.clear()


## The human's item turn: NEXT HAND (keep it) and DROP always, USE as well when the item is ready.
func _show_item_buttons(can_use: bool) -> void:
	_hide_item_buttons()
	var human := _table.players[0]
	if not human.has_item():
		return
	var item_name := Item.display_name(human.item as Item.Kind)
	_next_hand_button.visible = true
	_drop_item_button.text = "DROP %s" % item_name
	_drop_item_button.visible = true
	if can_use:
		_use_item_button.text = "USE %s" % item_name
		_use_item_button.visible = true
	_next_hand_button.grab_focus() # Enter / Space keep it and move on


func _hide_item_buttons() -> void:
	_use_item_button.visible = false
	_drop_item_button.visible = false
	_next_hand_button.visible = false


## Ends the human's item turn with [param decision].
func _submit_item_decision(decision: ItemDecision) -> void:
	if not _human_item_turn:
		return
	_human_item_turn = false
	_hide_item_buttons()
	_table.submit_item_decision(decision)


## Debug: hands the human [param item], replacing whatever they carry. It counts as
## picked up a hand ago, so it can be used at the end of this hand (or right now, on their item turn).
func _debug_give_item(item: Item.Kind) -> void:
	var human := _table.players[0]
	human.item = item
	human.item_gained_on_hand = _table.hand_number - 1
	_seats[0].refresh()
	if _human_item_turn and not _targeting:
		_show_item_buttons(_table.can_use_item(human))


## Debug: takes one of the human's hearts (so a stimpak has something to heal), but never the
## last one.
func _debug_lose_heart() -> void:
	var human := _table.players[0]
	if human.hearts <= 1:
		return
	human.hearts -= 1
	_seats[0].flash_hit()
	_seats[0].refresh()


func _use_item() -> void:
	match _table.players[0].item:
		Item.Kind.GUN:
			_hide_item_buttons()
			var targets := _table.gun_targets(_table.players[0])
			_enter_target_mode(_seats.filter(func(s: SeatView) -> bool: return s.player in targets))
		Item.Kind.STIMPAK:
			_submit_item_decision(ItemDecision.new(Item.Action.USE))


func _enter_target_mode(targets: Array[SeatView]) -> void:
	_targeting = true
	_gun.visible = true
	_gun.set_process(true)
	_target_hint.visible = true
	for seat in targets:
		seat.set_targetable(true)


## The human picked who to shoot; the table fires (see [method _on_shot]).
func _on_seat_targeted(target: SeatView) -> void:
	if not _targeting:
		return
	_targeting = false
	for seat in _seats:
		seat.set_targetable(false)
	_target_hint.visible = false
	_submit_item_decision(ItemDecision.new(Item.Action.USE, target.player))


## Someone fired a gun: the screen darkens, a tracer joins the two portraits and the target
## flashes. When it's the human's shot, the big gun they aimed with fires too, and goes away
## as the table moves on; NPC shots don't show it.
func _on_shot(shooter: PokerPlayer, target_player: PokerPlayer, result: Item.ShotResult) -> void:
	var target := _seats[target_player.seat]
	_darken_for_shot()
	_shot_tracer.fire(_seats[shooter.seat].portrait_center(), target.portrait_center())
	target.flash_hit()
	_seats[shooter.seat].refresh() # the gun is used up
	match result:
		Item.ShotResult.SHIELD_BROKE: target.set_status("SHIELD BROKE", PixelArt.HEART_RED)
		Item.ShotResult.ELIMINATED: target.set_status("ELIMINATED", PixelArt.HEART_RED)
		_: target.set_status("DIRECT HIT", PixelArt.HEART_RED)
	target.refresh()

	if not shooter.is_human():
		return
	_gun.fire()
	# Bound to this scene, so it's dropped if the scene is left meanwhile.
	get_tree().create_timer(_table.shot_delay).timeout.connect(func() -> void:
		if _targeting:
			return # the human is aiming again
		_gun.visible = false
		_gun.set_process(false))


## End of the hand: every card on the table fades out, then the next hand is dealt.
func _clear_table_then_continue() -> void:
	for seat in _seats:
		seat.fade_out_cards()
	for view in _community:
		view.fade_out()
	# Bound to this scene, so it's dropped if the scene is left meanwhile.
	get_tree().create_timer(CardView.FADE_SECONDS).timeout.connect(_table.continue_to_next_hand)


## The table drops to near-black on the shot, then quickly fades back.
func _darken_for_shot() -> void:
	if _shot_darken_tween:
		_shot_darken_tween.kill()
	_shot_darken.color = Color(0, 0, 0, 0.8)
	_shot_darken_tween = create_tween()
	_shot_darken_tween.tween_property(_shot_darken, "color:a", 0.0, 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## Hand name short enough for a seat's status line (poker shorthand for the long ones).
static func _seat_hand_name(score: Array[int]) -> String:
	match score[0]:
		HandEvaluator.Category.THREE_OF_A_KIND: return "TRIPS"
		HandEvaluator.Category.FOUR_OF_A_KIND: return "QUADS"
		_: return HandEvaluator.describe(score).to_upper()


## Gold glow on winners' portraits; lift the cards that made the winning hand, faintly outline
## its kickers, and dim the rest.
func _apply_win_highlights() -> void:
	for seat in _seats:
		seat.set_winner(_winners.has(seat.player))
		seat.highlight_cards(_win_highlight_for)
	for view in _community:
		view.set_highlight(_win_highlight_for(view.card))


func _win_highlight_for(card: Card) -> CardView.Highlight:
	if _winning_cards.is_empty() or card == null:
		return CardView.Highlight.NONE
	if _scoring_cards.has(card):
		return CardView.Highlight.WINNING
	if _winning_cards.has(card):
		return CardView.Highlight.KICKER
	return CardView.Highlight.DIMMED


func _refresh_seats() -> void:
	for seat in _seats:
		seat.refresh()
	for i in _table.players.size():
		var chips := _table.players[i].chips
		if chips != _shown_chips[i]:
			_show_chip_change(_seats[i], chips - _shown_chips[i])
		_shown_chips[i] = chips
		_stack_piles[i].amount = _table.players[i].chips
		_bet_piles[i].amount = _table.players[i].total_bet
	var pot := _table.pot()
	_pot.amount = pot
	if pot > _shown_pot:
		_pop_pot_label()
	_shown_pot = pot


## Floats "+100" (gold, like the seat's stack label) or "-20" (red) over a seat's portrait, then
## drifts up and fades. A newer change on the same seat replaces the old one.
func _show_chip_change(seat: SeatView, delta: int) -> void:
	var old: Variant = _chip_change_labels.get(seat)
	_chip_change_labels.erase(seat)
	if is_instance_valid(old):
		old.queue_free()

	var label_size := Vector2(96, UiTheme.LINE_HEIGHT + 8)
	var label := Label.new()
	label.text = "+%d" % delta if delta > 0 else str(delta)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.z_index = SeatView.DARKEN_Z + 1 # with the portraits, above the shot darkening
	UiTheme.add_at(self, label, (seat.portrait_center() - label_size / 2).round(), label_size)
	label.add_theme_color_override("font_color", PixelArt.GOLD if delta > 0 else PixelArt.HEART_RED)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_font_size_override("font_size", CHIP_CHANGE_FONT_SIZE)
	_chip_change_labels[seat] = label

	var tween := label.create_tween()
	tween.tween_property(label, "position:y", label.position.y - CHIP_CHANGE_RISE, CHIP_CHANGE_HOLD + CHIP_CHANGE_FADE) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, CHIP_CHANGE_FADE).set_delay(CHIP_CHANGE_HOLD)
	tween.tween_callback(func() -> void:
		if _chip_change_labels.get(seat) == label:
			_chip_change_labels.erase(seat)
		label.queue_free())


## Money went into the pot: the pot display swells briefly, then settles back.
func _pop_pot_label() -> void:
	if _pot_tween:
		_pot_tween.kill()
	var set_size := func(value: float) -> void: _pot.font_size = roundi(value)
	_pot_tween = create_tween()
	_pot_tween.tween_method(set_size, float(POT_FONT_SIZE), float(POT_POP_SIZE), 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pot_tween.tween_method(set_size, float(POT_POP_SIZE), float(POT_FONT_SIZE), 0.2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## End of the game: a modal over the table. Winning it offers the next table; going bust
## offers this table again.
func _show_game_over(winner: PokerPlayer) -> void:
	_action_bar.visible = false
	var modal := Control.new()
	modal.z_index = DebugMenu.MODAL_Z
	UiTheme.add_at(self, modal, Vector2.ZERO, get_viewport_rect().size)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(PRESET_FULL_RECT)
	modal.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	modal.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var title := Label.new()
	title.text = "YOU WIN!" if winner.is_human() else "BUSTED!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", PixelArt.GOLD)
	box.add_child(title)
	var detail := Label.new()
	detail.text = "You took every chip at the table." if winner.is_human() \
		else "%s leads with $%d." % [winner.display_name, winner.chips]
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(detail)
	var next := _new_button("ASCEND TO TABLE %d" % (_level.number + 1) if winner.is_human() else "PLAY AGAIN")
	next.pressed.connect(func() -> void:
		if winner.is_human():
			GameConfig.table_number = _level.number + 1
		get_tree().reload_current_scene())
	box.add_child(next)
	next.grab_focus()
	var menu := _new_button("MAIN MENU")
	menu.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	box.add_child(menu)

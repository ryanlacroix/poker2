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
## Gap between board cards dealt together (the flop) going down.
const BOARD_DEAL_STAGGER := 0.07
## Gap between hole cards going down as they're dealt round the table.
const HOLE_DEAL_STAGGER := 0.15
## Longest gap between the taps of a triple tap on the hidden debug spot.
const DEBUG_TAP_GAP_MSEC := 400
## How long the action bar takes to fade in or out.
const ACTION_BAR_FADE_SECONDS := 0.1
# The table's intro before the first deal: a pause, the "Table N" title fading in, held, fading
# out, then a pause.
const INTRO_DELAY := 0.5
const INTRO_FADE_IN_SECONDS := 0.15
const INTRO_TITLE_SECONDS := 1.5
const INTRO_FADE_SECONDS := 0.4
const INTRO_AFTER_DELAY := 0.5
## The title is drawn this small, then scaled up by [constant INTRO_PIXEL_SCALE] into chunky pixels.
const INTRO_FONT_SIZE := 16
const INTRO_PIXEL_SCALE := 3
## Width of the text in the hex modal, which wraps to fit.
const HEX_MODAL_TEXT_WIDTH := 240
## Whole-pixel scale of the hex's picture in the hex modal.
const HEX_MODAL_IMAGE_SCALE := 2
## Whole-pixel scale of the next table's splash on the TABLE CLEARED modal.
const SPLASH_IMAGE_SCALE := 2
## Tracers from a shimmering player to the others their shot spread to.
const SHIMMER_TRACER_COLOR := Color("c8d8ff")
## Z index of the winning-hand banner and item notices: above the portraits, the gun and the
## chip-change labels (all at SeatView.DARKEN_Z + 1), below the DEBUG popup.
const BANNER_Z := SeatView.DARKEN_Z + 2
## Z index of a lightning strike's darkening and its bolt: over everything on the table, cards
## and banners included, below the DEBUG popup and modals.
const LIGHTNING_Z := DebugMenu.MODAL_Z - 1
## The "TABLE N" label: a little bigger than the players' names, to fill the header strip.
const TABLE_LABEL_FONT_SIZE := 18
## Offset (down and right) of the hard black shadow under the table's name.
const TABLE_NAME_SHADOW_OFFSET := 2
## How much thicker the table's name is drawn (the UI font has no bold of its own).
const TABLE_NAME_EMBOLDEN := 0.8
## Share of the felt's pixels drawn a shade darker / lighter on a textured felt.
const FELT_DARK_SHARE := 0.12
const FELT_LIGHT_SHARE := 0.08
## A shot shakes everything but the wallpaper: how far, in whole pixels, and for how long.
const SHAKE_PIXELS := 10
const SHAKE_SECONDS := 0.2
## A boom trap's blast shakes the screen twice as hard, for this long.
const BOOM_SHAKE_SECONDS := 0.7
## How far, in whole pixels, a shield-overloading seat judders as the electricity builds.
const OVERLOAD_JUDDER_PIXELS := 3
## Gap between the brass studs along the rail.
const RAIL_STUD_SPACING := 20.0

var _level: TableLevel = GameConfig.table_level()
var _style := InterfaceStyle.for_table(_level.number)
var _table: PokerTable
var _layout: PortraitLayout
var _backdrop_texture: Texture2D
var _table_name_label: Label # the gilded rule in the header runs on from its end
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
## Whether the human can act: false as soon as the action bar starts fading out.
var _actions_open := false
var _action_bar_tween: Tween
var _call_button: Button
var _raise_button: Button
var _raise_slider: HSlider
var _raise_label: Label
var _next_hand_button: Button
## Fades NEXT HAND out once it's pressed (see [method _fade_out_next_hand]).
var _next_hand_tween: Tween
var _use_item_button: Button
var _drop_item_button: Button
var _human_item_turn := false # the item phase is waiting on the human's choice
var _continue_after_items := false # NEXT HAND was pressed on the human's item turn
var _debug_menu: DebugMenu
# Taps on the hidden debug spot: how many in a row, and when the last one was.
var _debug_taps := 0
var _debug_last_tap_msec := 0
var _gun: GunView
var _shot_darken: ColorRect
var _shot_tracer: ShotTracer
var _shot_darken_tween: Tween
var _lightning_darken: ColorRect
var _lightning_darken_tween: Tween
var _shake_tween: Tween
## The screen's current shake; the wallpaper is drawn this much the other way so it stays put.
var _shake := Vector2.ZERO
var _target_hint: Label
var _win_banner: WinBanner
var _notices: NoticeBanner
var _item_news: Array[String] = [] # this hand's item pickups, announced once it's settled
var _targeting := false
## While picking a seat for a debug action: what to do with the player picked (instead of an item turn's use).
var _debug_pick: Callable
var _hex_modal: Control # the hex being cast, open until CAST is pressed
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
	_table.hole_card_stagger = HOLE_DEAL_STAGGER
	_table.showdown_delay = GameConfig.showdown_delay
	_table.between_hands_delay = GameConfig.between_hands_delay
	_table.leech_delay = LeechBeam.SECONDS
	_table.magpie_swoop_delay = MagpieBird.SWOOP_SECONDS
	_table.magpie_carry_delay = MagpieBird.CARRY_SECONDS
	_table.explosion_delay = BoomExplosion.SECONDS
	_table.bomb_drop_delay = SeatView.BOMB_DROP_SECONDS
	_table.overload_delay = HexMist.DARKEN_SECONDS + HexMist.DRIFT_SECONDS
	_table.overload_charge_delay = OverloadSparks.SECONDS
	_table.hex_fizzle_delay = SeatView.HEX_FIZZLE_SECONDS
	_table.wait_for_next_hand = true
	add_child(_table)
	_table.setup(GameConfig.create_players())

	# Dress the whole table in its level's style before anything is built.
	InterfaceStyle.current = _style
	theme = UiTheme.build()
	_build_ui()
	_connect_table()
	_play_intro()


func _draw() -> void:
	# The wallpaper holds still while everything else shakes, so no screen edge ever shows.
	draw_set_transform(-_shake)
	draw_texture(_backdrop_texture, Vector2.ZERO)
	draw_set_transform(Vector2.ZERO)
	_draw_header_rule()
	# A long table between the two NPC columns: a bevelled rail (in the style's wood) with an
	# inlay and studs, felt, then a lighter inner felt edged with a pinstripe.
	var table := _layout.table
	for i in _style.rail.size():
		draw_colored_polygon(_chamfered(table.grow(-i), 6 - i * 0.5), _style.rail[i])
	_draw_rail_studs(table)
	_draw_felt(_chamfered(table.grow(-_style.rail.size()), 4), _level.felt, _felt_texture)
	var inner := table.grow(-9)
	draw_colored_polygon(_chamfered(inner.grow(1), 4), _style.pinstripe)
	_draw_felt(_chamfered(inner, 4), _level.felt_inner, _felt_inner_texture)
	draw_colored_polygon(_chamfered(inner.grow(-3), 3), Color(_style.pinstripe, _style.pinstripe.a * 0.35))
	_draw_felt(_chamfered(inner.grow(-4), 3), _level.felt_inner, _felt_inner_texture)


## Studs (in the style's gem colours) along the rail's long straight top and bottom runs, each with a glint.
func _draw_rail_studs(table: Rect2) -> void:
	var y_top := table.position.y + 2
	var y_bottom := table.end.y - 3
	var x := table.position.x + RAIL_STUD_SPACING
	while x < table.end.x - RAIL_STUD_SPACING / 2.0:
		for y in [y_top, y_bottom]:
			draw_rect(Rect2(x - 1, y - 1, 3, 3), _style.rail_socket)
			draw_rect(Rect2(x, y, 1, 1), _style.gem_light)
			draw_rect(Rect2(x - 1, y, 1, 1), _style.gem)
			draw_rect(Rect2(x, y - 1, 1, 1), _style.gem)
			draw_rect(Rect2(x + 1, y, 1, 1), _style.gem_dark)
			draw_rect(Rect2(x, y + 1, 1, 1), _style.gem_dark)
		x += RAIL_STUD_SPACING


## A gilded rule running from just after the table's name to the right edge of the header.
func _draw_header_rule() -> void:
	if _table_name_label == null:
		return
	var font := _table_name_label.get_theme_font("font")
	var text_end := _table_name_label.position.x + font.get_string_size(
		_table_name_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, TABLE_LABEL_FONT_SIZE).x
	var from := _layout.header.position.x + text_end + TABLE_NAME_SHADOW_OFFSET + 6
	Ornament.draw_rule(self, from, _layout.header.end.x, _layout.header.get_center().y + 1)


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
## [param size]. A random tile, repeated, so it's quick to build. [param strength] scales how far
## those pixels are shaded (1 = full).
static func _grained_felt(color: Color, size: Vector2i, strength := 1.0) -> Texture2D:
	const TILE := 48
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var tile := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	tile.fill(color)
	var dark := color.lerp(color.darkened(0.12), strength)
	var light := color.lerp(color.lightened(0.05), strength)
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
	_backdrop_texture = Ornament.wallpaper(_style.backdrop, _style.motif, Vector2i(viewport_size.ceil()))
	if _level.grain > 0:
		var felt_size := Vector2i(_layout.table.size.ceil())
		_felt_texture = _grained_felt(_level.felt, felt_size, _level.grain)
		_felt_inner_texture = _grained_felt(_level.felt_inner, felt_size, _level.grain)

	# Which table this is, in the header strip above the felt, on the left; lettered like the
	# players' names, with the table's name bold over a hard black shadow.
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 0)
	UiTheme.add_at(self, header_row,
		Vector2(_layout.header.position.x, _layout.header.get_center().y - UiTheme.LINE_HEIGHT / 2.0),
		Vector2(_layout.header.size.x, UiTheme.LINE_HEIGHT))
	_add_header_text(header_row, "TABLE %d: " % _level.number, PixelArt.GOLD)
	var table_name := _add_header_text(header_row, _level.name, PixelArt.GOLD)
	table_name.size_flags_horizontal = SIZE_EXPAND_FILL
	table_name.clip_text = true
	var bold := FontVariation.new()
	bold.base_font = table_name.get_theme_default_font()
	bold.variation_embolden = TABLE_NAME_EMBOLDEN
	table_name.add_theme_font_override("font", bold)
	table_name.add_theme_color_override("font_shadow_color", Color.BLACK)
	table_name.add_theme_constant_override("shadow_offset_x", TABLE_NAME_SHADOW_OFFSET)
	table_name.add_theme_constant_override("shadow_offset_y", TABLE_NAME_SHADOW_OFFSET)
	table_name.add_theme_constant_override("shadow_outline_size", 0)
	_table_name_label = table_name
	header_row.sort_children.connect(queue_redraw)

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
		stack.amount = player.chips # on the table from the start, before the intro
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

	# An invisible spot where the DEBUG button was: three quick taps open the debug menu.
	var debug_spot := Control.new()
	UiTheme.add_at(self, debug_spot, _layout.debug_button.position, _layout.debug_button.size)
	debug_spot.gui_input.connect(_on_debug_spot_input)

	# Shown under the board, in the (then empty) pot label's spot, once a hand is over, and on
	# the human's item turn, where it means "keep my item": the rest of the table takes its
	# item turns, then the next hand is dealt straight away.
	_next_hand_button = _new_button("NEXT HAND", false)
	UiTheme.add_at(self, _next_hand_button, pot_center - PortraitLayout.NEXT_HAND_SIZE / 2, PortraitLayout.NEXT_HAND_SIZE)
	_next_hand_button.pressed.connect(func() -> void:
		_fade_out_next_hand()
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
	# Oversized, so no undarkened edge shows while the screen shakes.
	UiTheme.add_at(self, _shot_darken, -Vector2.ONE * SHAKE_PIXELS, viewport_size + Vector2.ONE * SHAKE_PIXELS * 2)
	_gun.z_index = SeatView.DARKEN_Z + 1
	# Same layer as the darkening, drawn after it: over the dimmed table, under the portraits.
	_shot_tracer = ShotTracer.new()
	_shot_tracer.z_index = SeatView.DARKEN_Z
	UiTheme.add_at(self, _shot_tracer, Vector2.ZERO, viewport_size)
	# A lightning strike's flash-to-dark over the whole screen; each bolt is added after it, on top.
	_lightning_darken = ColorRect.new()
	_lightning_darken.color = Color(0, 0, 0, 0)
	_lightning_darken.mouse_filter = MOUSE_FILTER_IGNORE
	_lightning_darken.z_index = LIGHTNING_Z
	UiTheme.add_at(self, _lightning_darken, -Vector2.ONE * SHAKE_PIXELS, viewport_size + Vector2.ONE * SHAKE_PIXELS * 2)
	_target_hint = Label.new()
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
	_debug_menu.give_hex.connect(_debug_give_hex)
	_debug_menu.give_npcs_stimpaks.connect(_debug_give_npcs_stimpaks)
	_debug_menu.give_npc_shield.connect(_debug_give_npc_shield)
	_debug_menu.give_chips.connect(_debug_give_chips)
	_debug_menu.fizzle_hexes.connect(_debug_fizzle_hexes)
	_debug_menu.explode_npc.connect(_debug_explode_npc)
	_debug_menu.set_npc_chips.connect(_debug_set_npc_chips)
	_debug_menu.lose_heart.connect(_debug_lose_heart)
	_debug_menu.win_table.connect(func() -> void: _show_game_over(_table.players[0]))


func _on_debug_spot_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	var now := Time.get_ticks_msec()
	_debug_taps = _debug_taps + 1 if now - _debug_last_tap_msec <= DEBUG_TAP_GAP_MSEC else 1
	_debug_last_tap_msec = now
	if _debug_taps >= 3:
		_debug_taps = 0
		_debug_menu.show()


## Before the first deal: a pause, then a big "Table N" title that fades in and away, then a short pause
## and the game starts. Run by a tween on this scene, so it stops if the scene is left.
func _play_intro() -> void:
	var title := Label.new()
	title.text = "Table %d" % _level.number
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", INTRO_FONT_SIZE)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_color_override("font_shadow_color", Color.BLACK)
	title.add_theme_constant_override("shadow_offset_x", 1)
	title.add_theme_constant_override("shadow_offset_y", 1)
	title.mouse_filter = MOUSE_FILTER_IGNORE
	title.z_index = BANNER_Z
	title.modulate.a = 0
	# Covers the screen once scaled up, so the title sits in its centre.
	UiTheme.add_at(self, title, Vector2.ZERO, get_viewport_rect().size / INTRO_PIXEL_SCALE)
	title.scale = Vector2.ONE * INTRO_PIXEL_SCALE

	var tween := create_tween()
	tween.tween_interval(INTRO_DELAY)
	tween.tween_property(title, "modulate:a", 1.0, INTRO_FADE_IN_SECONDS)
	tween.tween_interval(INTRO_TITLE_SECONDS)
	tween.tween_property(title, "modulate:a", 0.0, INTRO_FADE_SECONDS)
	tween.tween_callback(title.queue_free)
	tween.tween_interval(INTRO_AFTER_DELAY)
	tween.tween_callback(_table.start_game)


func _add_header_text(row: HBoxContainer, text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", TABLE_LABEL_FONT_SIZE)
	row.add_child(label)
	return label


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

	# The raise amount on the left, its slider on the right.
	_raise_label = Label.new()
	_raise_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_raise_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiTheme.add_at(_action_bar, _raise_label, Vector2(pad, y), Vector2(74, slider_h))
	_raise_slider = HSlider.new()
	_raise_slider.step = 1
	UiTheme.add_at(_action_bar, _raise_slider, Vector2(pad + 78, y), Vector2(inner - 78, slider_h))
	_raise_slider.value_changed.connect(func(_value: float) -> void: _update_raise_label())
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
	if not _actions_open:
		return # already chosen; the bar is fading out
	_set_actions_open(false)
	_table.submit_human_action(decision)


## Quickly fades the action bar in or out. Its buttons and keys stop working as soon as it
## starts fading out.
func _set_actions_open(open: bool) -> void:
	_actions_open = open
	if _action_bar_tween:
		_action_bar_tween.kill()
	if open and not _action_bar.visible:
		_action_bar.modulate.a = 0
		_action_bar.visible = true
	_action_bar_tween = create_tween()
	_action_bar_tween.tween_property(_action_bar, "modulate:a", 1.0 if open else 0.0, ACTION_BAR_FADE_SECONDS)
	if not open:
		_action_bar_tween.tween_callback(_action_bar.hide)


func _update_raise_label() -> void:
	var all_in := int(_raise_slider.value) >= int(_raise_slider.max_value)
	_raise_label.text = "ALL IN" if all_in else "TO $%d" % int(_raise_slider.value)


# --- Human input -------------------------------------------------------

func _show_actions(p: PokerPlayer, to_call: int, min_to: int, max_to: int) -> void:
	_to_call = to_call
	# With a bomb strapped on, folding sets it off.
	_fold_button.text = "FOLD = BOOM!" if p.is_trapped() else "FOLD"
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		if p.is_trapped():
			_fold_button.add_theme_color_override(state, PixelArt.HEART_RED)
		else:
			_fold_button.remove_theme_color_override(state)
	_call_button.text = "CHECK" if to_call == 0 else "ALL IN" if to_call >= p.chips else "CALL $%d" % to_call

	var can_raise := p.chips > to_call
	_raise_button.disabled = not can_raise
	_raise_slider.editable = can_raise and max_to > min_to
	# Exponential, so the low end moves in small steps and the high end in big ones.
	# It needs a minimum above zero.
	_raise_slider.exp_edit = min_to > 0
	_raise_slider.min_value = min_to
	_raise_slider.max_value = max_to
	_raise_slider.value = min_to
	_raise_button.text = "BET" if _table.current_bet == 0 else "RAISE"
	_update_raise_label()
	_set_actions_open(true)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not _actions_open or key == null or not key.pressed or key.echo:
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
	_table.hole_cards_dealt.connect(_deal_hole_cards)
	_table.community_changed.connect(func(cards: Array[Card]) -> void:
		# Cards dealt together (the flop) go down one after another.
		var delay := 0.0
		for i in _community.size():
			var card: Card = cards[i] if i < cards.size() else null
			if card != null and card != _community[i].card:
				_community[i].set_card(card, true, delay)
				delay += BOARD_DEAL_STAGGER
			else:
				_community[i].set_card(card, true))
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
	_table.hex_cast.connect(_on_hex_cast)
	_table.hex_fizzled.connect(func(caster: PokerPlayer, effect: Hex.Effect) -> void:
		_seats[caster.seat].fizzle_hex()
		_seats[caster.seat].set_status("HEX FIZZLED", PixelArt.PAPER)
		_seats[caster.seat].refresh() # the hex is lost
		if not caster.is_human():
			_notices.enqueue("%s's %s fizzled: %s" % [caster.display_name,
				Hex.display_name(effect).to_lower(), _no_target_reason(effect).to_lower()]))
	_table.shot_spread.connect(_on_shot_spread)
	_table.shimmer_ended.connect(func(player: PokerPlayer) -> void:
		_seats[player.seat].refresh())
	_table.leech_drained.connect(_on_leech_drained)
	_table.lightning_struck.connect(_on_lightning_struck)
	_table.magpie_swooped.connect(_on_magpie_swooped)
	_table.item_stolen.connect(_on_item_stolen)
	_table.bomb_exploded.connect(_on_bomb_exploded)
	_table.overload_charging.connect(_on_overload_charging)
	_table.overload_exploded.connect(_on_overload_exploded)
	_table.bomb_dropped.connect(func(player: PokerPlayer) -> void:
		_seats[player.seat].drop_bomb()
		_seats[player.seat].set_status("BOMB FELL OFF", PixelArt.HEAL_GREEN)
		_seats[player.seat].refresh())
	_table.leech_ended.connect(func(player: PokerPlayer) -> void:
		_seats[player.seat].refresh())
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
		_show_next_hand()) # Enter / Space also continue
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
	_show_next_hand()
	_drop_item_button.text = "DROP %s" % item_name
	_drop_item_button.visible = true
	if can_use:
		_use_item_button.text = "USE %s" % item_name
		_use_item_button.visible = true
	# NEXT HAND has focus, so Enter / Space keep it and move on.


func _hide_item_buttons() -> void:
	_use_item_button.visible = false
	_drop_item_button.visible = false
	# Once pressed, NEXT HAND is left to finish fading out.
	if not (_next_hand_tween and _next_hand_tween.is_running()):
		_next_hand_button.visible = false


## Shows NEXT HAND at full opacity, focused so Enter / Space press it.
func _show_next_hand() -> void:
	if _next_hand_tween:
		_next_hand_tween.kill()
	_next_hand_button.modulate.a = 1
	_next_hand_button.mouse_filter = MOUSE_FILTER_STOP
	_next_hand_button.visible = true
	_next_hand_button.grab_focus()


## Fades NEXT HAND out like the action panel, taking no more presses meanwhile.
func _fade_out_next_hand() -> void:
	if _next_hand_tween:
		_next_hand_tween.kill()
	_next_hand_button.mouse_filter = MOUSE_FILTER_IGNORE
	_next_hand_button.release_focus()
	_next_hand_tween = create_tween()
	_next_hand_tween.tween_property(_next_hand_button, "modulate:a", 0.0, ACTION_BAR_FADE_SECONDS)
	_next_hand_tween.tween_callback(_next_hand_button.hide)


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
	if _hex_modal:
		return # the hex being cast is already revealed
	var human := _table.players[0]
	_table.give_item(human, item)
	human.item_gained_on_hand = _table.hand_number - 1
	_seats[0].refresh()
	if _human_item_turn and not _targeting:
		_show_item_buttons(_table.can_use_item(human))


## Debug: hands the human a hex with [param effect] (see [method _debug_give_item]).
func _debug_give_hex(effect: Hex.Effect) -> void:
	_debug_give_item(Item.Kind.HEX)
	if _hex_modal == null:
		_table.players[0].hex = effect


## Debug: hands every NPC still in the game a stimpak, replacing whatever they carry. Like
## [method _debug_give_item], each counts as picked up a hand ago, so it's ready to use.
func _debug_give_npcs_stimpaks() -> void:
	for p in _table.players:
		if p.is_human() or not PokerTable.in_game(p):
			continue
		_table.give_item(p, Item.Kind.STIMPAK)
		p.item_gained_on_hand = _table.hand_number - 1
		_seats[p.seat].refresh()


## Debug: hands a random NPC still in the game, and not already carrying a shield, a shield,
## replacing whatever they carry.
func _debug_give_npc_shield() -> void:
	var npcs := _table.players.filter(func(p: PokerPlayer) -> bool:
		return not p.is_human() and PokerTable.in_game(p) and p.item != Item.Kind.SHIELD)
	if npcs.is_empty():
		return
	var npc: PokerPlayer = npcs.pick_random()
	_table.give_item(npc, Item.Kind.SHIELD)
	npc.item_gained_on_hand = _table.hand_number - 1
	_seats[npc.seat].refresh()


## Debug: every hex anyone's carrying fizzles, as if they'd tried it with nobody to pick. Not the
## human's while its modal is open.
func _debug_fizzle_hexes() -> void:
	for p in _table.players:
		if p.item != Item.Kind.HEX or (p.is_human() and _hex_modal):
			continue
		p.item = Item.NONE
		_table.hex_fizzled.emit(p, p.hex)
	if _human_item_turn and not _targeting:
		_show_item_buttons(_table.can_use_item(_table.players[0]))


## Debug: blows up a random NPC still in the game, as if a boom trap went off on them. Their
## chips go to nobody, and they sit out the rest of this hand.
func _debug_explode_npc() -> void:
	var npcs := _table.players.filter(func(p: PokerPlayer) -> bool:
		return not p.is_human() and PokerTable.in_game(p))
	if npcs.is_empty():
		return
	var victim: PokerPlayer = npcs.pick_random()
	victim.folded = true
	victim.trapped_by = victim # so nobody collects their chips
	_table.bomb_exploded.emit(victim, _table.detonate(victim))


## Debug: the human picks an NPC still in the game, whose stack is set to [param amount]. Not
## while already picking a target.
func _debug_set_npc_chips(amount: int) -> void:
	if _targeting:
		return
	var npcs: Array[PokerPlayer] = []
	npcs.assign(_table.players.filter(func(p: PokerPlayer) -> bool:
		return not p.is_human() and PokerTable.in_game(p)))
	if npcs.is_empty():
		return
	_debug_pick = func(p: PokerPlayer) -> void:
		p.chips = amount
		_refresh_seats()
	_enter_target_mode(npcs, false, "PICK AN NPC")


## Debug: adds [param amount] to the human's stack.
func _debug_give_chips(amount: int) -> void:
	_table.players[0].chips += amount
	_refresh_seats()


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
	var human := _table.players[0]
	match human.item:
		Item.Kind.GUN:
			_hide_item_buttons()
			_enter_target_mode(_table.gun_targets(human), true, "PICK A TARGET")
		Item.Kind.STIMPAK:
			_submit_item_decision(ItemDecision.new(Item.Action.USE))
		Item.Kind.HEX:
			_hide_item_buttons()
			_show_hex_modal(human.hex)


## Seats of [param players] pulse and take a tap; the gun floats in the middle while aiming one.
func _enter_target_mode(players: Array[PokerPlayer], with_gun: bool, hint: String) -> void:
	_targeting = true
	if with_gun:
		_gun.visible = true
		_gun.set_process(true)
	_target_hint.text = hint
	_target_hint.visible = true
	for seat in _seats:
		if seat.player in players:
			seat.set_targetable(true)


## The hex is revealed: its name, what it does, and CAST (there's no backing out). Casting one
## that needs a target then has the human pick who. One with nobody to pick (see
## [method PokerTable.hex_fizzles]) only offers to let it go, losing it.
func _show_hex_modal(effect: Hex.Effect) -> void:
	var box := VBoxContainer.new()
	var title := Label.new()
	title.text = Hex.display_name(effect)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", PixelArt.HEART_RED)
	box.add_child(title)
	if Hex.image(effect):
		var picture := TextureRect.new()
		picture.texture = Hex.image(effect)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.custom_minimum_size = picture.texture.get_size() * HEX_MODAL_IMAGE_SCALE
		box.add_child(picture)
	var detail := Label.new()
	detail.text = Hex.description(effect)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size.x = HEX_MODAL_TEXT_WIDTH
	box.add_child(detail)
	var fizzles := _table.hex_fizzles(_table.players[0])
	var cast := _new_button("%s - DROP HEX" % _no_target_reason(effect) if fizzles else "CAST")
	cast.pressed.connect(func() -> void:
		_hex_modal.queue_free()
		_hex_modal = null
		if Hex.needs_target(effect) and not fizzles:
			_enter_target_mode(_table.hex_targets(_table.players[0]), false, "PICK A PLAYER")
		else:
			_submit_item_decision(ItemDecision.new(Item.Action.USE)))
	box.add_child(cast)
	_hex_modal = _show_modal(box)
	cast.grab_focus()


## Why nobody can be picked for [param effect], on the hex modal's button when it fizzles.
static func _no_target_reason(effect: Hex.Effect) -> String:
	match effect:
		Hex.Effect.SHIELD_OVERLOAD: return "NO SHIELDED PLAYERS"
		Hex.Effect.MAGPIE: return "NO ITEMS TO STEAL"
		Hex.Effect.BOOM_TRAP: return "NO ONE LEFT TO TRAP"
	return "NO ONE TO HEX"


## The human picked who to shoot or hex; the table carries it out.
func _on_seat_targeted(target: SeatView) -> void:
	if not _targeting:
		return
	_targeting = false
	for seat in _seats:
		seat.set_targetable(false)
	_target_hint.visible = false
	if _debug_pick.is_valid():
		var pick := _debug_pick
		_debug_pick = Callable()
		pick.call(target.player)
		return
	_submit_item_decision(ItemDecision.new(Item.Action.USE, target.player))


## Someone fired a gun: the screen darkens, a tracer joins the two portraits and the target
## flashes. When it's the human's shot, the big gun they aimed with fires too, and goes away
## as the table moves on; NPC shots don't show it.
func _on_shot(shooter: PokerPlayer, target_player: PokerPlayer, result: Item.ShotResult) -> void:
	var target := _seats[target_player.seat]
	_darken_for_shot()
	_shot_tracer.fire(_seats[shooter.seat].portrait_center(), target.portrait_center())
	_seats[shooter.seat].refresh() # the gun is used up
	_show_hit(target, result)
	_shake_screen()

	if not shooter.is_human():
		return
	_gun.fire()
	# Bound to this scene, so it's dropped if the scene is left meanwhile.
	get_tree().create_timer(_table.shot_delay).timeout.connect(func() -> void:
		if _targeting:
			return # the human is aiming again
		_gun.visible = false
		_gun.set_process(false))


## A hex was cast: the table dims under a blood-red mist while its target glows the same red (and
## its caster, from the side facing the table), the caster's status names it, the used-up hex
## sputters out on the caster's portrait, and a shimmer lights up its target.
func _on_hex_cast(caster: PokerPlayer, effect: Hex.Effect, target: PokerPlayer) -> void:
	# First child: over the table's own drawing, under the seats, cards and buttons.
	var mist := HexMist.new()
	UiTheme.add_at(self, mist, Vector2.ZERO, get_viewport_rect().size)
	move_child(mist, 0)
	if target:
		_seats[target.seat].hex_glow(HexMist.DRIFT_SECONDS)
	_seats[caster.seat].hex_glow(HexMist.DRIFT_SECONDS, true)
	_seats[caster.seat].set_status("CAST %s" % Hex.display_name(effect), PixelArt.HEART_RED)
	_seats[caster.seat].fizzle_hex() # the hex is used up
	_seats[caster.seat].refresh()
	match effect:
		Hex.Effect.SHIMMER:
			_seats[target.seat].set_status("SHIMMERING", Color.WHITE)
			_seats[target.seat].refresh()
		Hex.Effect.LEECH:
			_seats[target.seat].set_status("LEECHED", PixelArt.GOLD)
			_seats[target.seat].refresh()
		Hex.Effect.BOOM_TRAP:
			_seats[target.seat].set_status("TRAPPED", PixelArt.HEART_RED)
			_seats[target.seat].refresh()
	if not caster.is_human():
		_notices.enqueue("%s cast %s on %s" % [caster.display_name, Hex.display_name(effect).to_lower(),
			target.display_name if target else "the table"])


## A shot at a shimmering player spread to [param target_player]: a pale tracer from them, and
## the hit lands as if shot.
func _on_shot_spread(source: PokerPlayer, target_player: PokerPlayer, result: Item.ShotResult) -> void:
	var target := _seats[target_player.seat]
	_darken_for_shot()
	_shot_tracer.fire(_seats[source.seat].portrait_center(), target.portrait_center(), SHIMMER_TRACER_COLOR)
	_show_hit(target, result)
	_shake_screen()


## Lightning struck [param target_player]: the whole screen goes dark but for a bolt coming down
## on them, then fades back in, and the hit lands as if shot.
func _on_lightning_struck(_caster: PokerPlayer, target_player: PokerPlayer, result: Item.ShotResult) -> void:
	var target := _seats[target_player.seat]
	_darken_for_lightning()
	var bolt := LightningBolt.new()
	bolt.to = target.portrait_center()
	# Over the darkening, so only the bolt shows through.
	bolt.z_index = LIGHTNING_Z
	UiTheme.add_at(self, bolt, Vector2.ZERO, get_viewport_rect().size)
	_show_hit(target, result)
	_shake_screen()


## A magpie swoops down on [param target_player]'s item, to carry it to [param caster]. It's
## taken from the target's seat as the bird grabs it ([method _on_item_stolen]), and shows up on
## the caster's as the bird lets go.
func _on_magpie_swooped(caster: PokerPlayer, target_player: PokerPlayer) -> void:
	var item := target_player.item as Item.Kind
	var bird := MagpieBird.new()
	bird.item = item
	bird.grab_at = _seats[target_player.seat].item_center(item)
	bird.drop_at = _seats[caster.seat].item_center(item)
	# Over everything on the table, like a lightning bolt.
	bird.z_index = LIGHTNING_Z
	var caster_seat := _seats[caster.seat]
	bird.delivered.connect(func() -> void:
		caster_seat.item_hidden = false
		caster_seat.refresh())
	add_child(bird) # it places itself


## The magpie snatched [param item] from [param target]: gone from their seat, and kept off the
## caster's until the bird drops it there.
func _on_item_stolen(caster: PokerPlayer, target: PokerPlayer, item: Item.Kind) -> void:
	_seats[target.seat].set_status("LOST %s" % Item.display_name(item), PixelArt.HEART_RED)
	_seats[target.seat].refresh()
	_seats[caster.seat].item_hidden = true
	_seats[caster.seat].set_status("STOLE %s" % Item.display_name(item), PixelArt.GOLD)
	_seats[caster.seat].refresh()


## A boom trap went off on [param victim]: see [method _blow_up_seat].
func _on_bomb_exploded(victim: PokerPlayer, _caster: PokerPlayer) -> void:
	_blow_up_seat(victim)
	_notices.enqueue("%s blew up!" % victim.display_name)


## A huge blast over [param victim]'s seat that shakes the whole screen. Once the fireball has
## swallowed it, the seat is gone for good, leaving a burn mark.
func _blow_up_seat(victim: PokerPlayer) -> void:
	var seat := _seats[victim.seat]
	var boom := BoomExplosion.new()
	boom.center = seat.position + seat.size / 2
	var scatter := FragmentScatter.new()
	UiTheme.add_at(self, scatter, Vector2.ZERO, get_viewport_rect().size)
	# First child: over the table's own drawing, under the seats, cards and buttons.
	move_child(scatter, 0)
	boom.scatter = scatter
	# Over everything on the table, like a lightning bolt.
	boom.z_index = LIGHTNING_Z
	boom.engulfed.connect(func() -> void:
		seat.visible = false
		var mark := BurnMark.new()
		var mark_size := (seat.size / BurnMark.BLOTCH).round()
		UiTheme.add_at(self, mark, (seat.position - (mark_size - seat.size) / 2).round(), mark_size)
		# First child: over the table's own drawing, under the seats, cards and buttons.
		move_child(mark, 0))
	UiTheme.add_at(self, boom, Vector2.ZERO, get_viewport_rect().size)
	_shake_screen(SHAKE_PIXELS * 2, BOOM_SHAKE_SECONDS)


## A shield overload starts on [param target_player]: electricity shoots out of their portrait
## and their seat judders harder and harder, until it explodes ([method _on_overload_exploded]).
func _on_overload_charging(_caster: PokerPlayer, target_player: PokerPlayer) -> void:
	var seat := _seats[target_player.seat]
	var sparks := OverloadSparks.new()
	sparks.seat = seat
	# Over everything on the table, like a lightning bolt.
	sparks.z_index = LIGHTNING_Z
	UiTheme.add_at(self, sparks, Vector2.ZERO, get_viewport_rect().size)
	seat.set_status("OVERLOADING", LightningBolt.COLOR)
	seat.refresh()
	var rest := seat.position
	var judder := create_tween()
	judder.tween_method(func(strength: float) -> void:
		var reach := roundi(OVERLOAD_JUDDER_PIXELS * strength)
		seat.position = rest + Vector2(randi_range(-reach, reach), randi_range(-reach, reach)), 0.3, 1.0, OverloadSparks.SECONDS)
	judder.tween_callback(func() -> void: seat.position = rest)


## A shield overload blew up [param target_player], just like a boom trap: see [method _blow_up_seat].
func _on_overload_exploded(_caster: PokerPlayer, target_player: PokerPlayer) -> void:
	_blow_up_seat(target_player)
	_notices.enqueue("%s overloaded!" % target_player.display_name)


## A leech took its share: a gold beam drifts from the victim to the caster as the chips move over.
func _on_leech_drained(caster: PokerPlayer, victim: PokerPlayer, amount: int) -> void:
	var beam := LeechBeam.new()
	beam.from = _seats[victim.seat].portrait_center()
	beam.to = _seats[caster.seat].portrait_center()
	# With the shot tracer: over the table, under the portraits.
	beam.z_index = SeatView.DARKEN_Z
	UiTheme.add_at(self, beam, Vector2.ZERO, get_viewport_rect().size)
	_seats[victim.seat].set_status("LEECHED $%d" % amount, PixelArt.GOLD)
	_seats[caster.seat].set_status("LEECH +$%d" % amount, PixelArt.GOLD)
	_seats[victim.seat].refresh()
	_seats[caster.seat].refresh()


## End of the hand: every card on the table fades out, then the next hand is dealt.
func _clear_table_then_continue() -> void:
	# NEXT HAND finishes fading out before the cards start to.
	if _next_hand_tween and _next_hand_tween.is_running():
		await _next_hand_tween.finished
	for seat in _seats:
		seat.fade_out_cards()
	for view in _community:
		view.fade_out()
	# Bound to this scene, so it's dropped if the scene is left meanwhile.
	get_tree().create_timer(CardView.FADE_SECONDS).timeout.connect(_table.continue_to_next_hand)


## [param target] was shot: a flash, and what the shot did.
static func _show_hit(target: SeatView, result: Item.ShotResult) -> void:
	target.flash_hit()
	match result:
		Item.ShotResult.SHIELD_BROKE: target.set_status("SHIELD BROKE", PixelArt.HEART_RED)
		Item.ShotResult.ELIMINATED: target.set_status("ELIMINATED", PixelArt.HEART_RED)
		_: target.set_status("DIRECT HIT", PixelArt.HEART_RED)
	target.refresh()


## A brief, dying-away jolt of everything on screen but the wallpaper: the whole canvas is
## offset by a random whole-pixel amount each frame, and the wallpaper drawn back the other way.
func _shake_screen(pixels := SHAKE_PIXELS, seconds := SHAKE_SECONDS) -> void:
	if _shake_tween:
		_shake_tween.kill()
	_shake_tween = create_tween()
	_shake_tween.tween_method(func(strength: float) -> void:
		var reach := roundi(pixels * strength)
		_set_shake(Vector2(randi_range(-reach, reach), randi_range(-reach, reach))), 1.0, 0.0, seconds)
	_shake_tween.tween_callback(_set_shake.bind(Vector2.ZERO))


func _set_shake(offset: Vector2) -> void:
	_shake = offset
	get_viewport().canvas_transform = Transform2D(0, offset)
	queue_redraw()


func _exit_tree() -> void:
	# Leaving mid-shake mustn't leave the next scene offset.
	get_viewport().canvas_transform = Transform2D.IDENTITY


## The table drops to near-black on the shot, then quickly fades back.
func _darken_for_shot() -> void:
	if _shot_darken_tween:
		_shot_darken_tween.kill()
	_shot_darken.color = Color(0, 0, 0, 0.8)
	_shot_darken_tween = create_tween()
	_shot_darken_tween.tween_property(_shot_darken, "color:a", 0.0, 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## Everything on screen drops to near-black on a lightning strike, then quickly fades back.
func _darken_for_lightning() -> void:
	if _lightning_darken_tween:
		_lightning_darken_tween.kill()
	_lightning_darken.color = Color(0, 0, 0, 0.85)
	_lightning_darken_tween = create_tween()
	_lightning_darken_tween.tween_property(_lightning_darken, "color:a", 0.0, 0.5) \
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


## Hole cards fly out from the dealer's portrait one at a time in dealing order: round the table
## from the dealer's left, everyone's first card, then everyone's second.
func _deal_hole_cards() -> void:
	var players := _table.players
	var delay := 0.0
	var delays := {} # PokerPlayer -> Array[float]
	for _round in 2:
		for step in range(1, players.size() + 1):
			var player := players[(_table.dealer_index + step) % players.size()]
			if player.hole_cards.is_empty():
				continue
			if not delays.has(player):
				delays[player] = [] as Array[float]
			delays[player].append(delay)
			delay += HOLE_DEAL_STAGGER
	var dealer := _seats[players[_table.dealer_index].seat]
	for player: PokerPlayer in delays:
		_seats[player.seat].deal_cards(delays[player], dealer.portrait_global_center())
	_refresh_seats()


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


## End of the game: a modal over the table. Winning it shows the next table's splash and blurb
## and offers that table; going bust offers this table again.
func _show_game_over(winner: PokerPlayer) -> void:
	if _actions_open:
		_set_actions_open(false)
	var box := VBoxContainer.new()
	var title := Label.new()
	title.text = "TABLE CLEARED" if winner.is_human() else "BUSTED!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", PixelArt.GOLD)
	box.add_child(title)
	if winner.is_human():
		var next_level := TableLevel.new(_level.number + 1)
		if next_level.splash:
			var picture := TextureRect.new()
			picture.texture = next_level.splash
			picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			picture.custom_minimum_size = next_level.splash.get_size() * SPLASH_IMAGE_SCALE
			box.add_child(picture)
		if next_level.blurb:
			var blurb := Label.new()
			blurb.text = next_level.blurb
			blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			blurb.custom_minimum_size.x = HEX_MODAL_TEXT_WIDTH
			blurb.add_theme_color_override("font_color", Color.WHITE)
			box.add_child(blurb)
	else:
		var detail := Label.new()
		detail.text = "%s leads with $%d." % [winner.display_name, winner.chips]
		detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(detail)
	var next := _new_button("ASCEND TO TABLE %d" % (_level.number + 1) if winner.is_human() else "PLAY AGAIN")
	next.pressed.connect(func() -> void:
		if winner.is_human():
			GameConfig.table_number = _level.number + 1
		get_tree().reload_current_scene())
	box.add_child(next)
	if not winner.is_human():
		var menu := _new_button("MAIN MENU")
		menu.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
		box.add_child(menu)
	_show_modal(box)
	next.grab_focus()


## Shows [param box] in a panel in the middle of the screen, over the dimmed table, taking all
## input. Returns the modal, to free when done.
func _show_modal(box: VBoxContainer) -> Control:
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
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	return modal

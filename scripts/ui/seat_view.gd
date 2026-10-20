class_name SeatView
extends Control
## One player's spot at the table: portrait, hole cards, name, stack and last action.

## Wide: the human's seat, with 2x cards beside the portrait. Compact: the NPC columns, 1x cards
## beside the portrait (mirrored on the right); text aligns toward the middle of the screen so
## long labels never run off it.
enum Style { WIDE, COMPACT_LEFT, COMPACT_RIGHT }

## Emitted when the human taps this seat while it is targetable.
signal targeted(seat: SeatView)

const WIDE_SIZE := Vector2(160, 74 + UiTheme.LINE_HEIGHT * 2)
const COMPACT_SIZE := Vector2(106, 52 + UiTheme.LINE_HEIGHT * 3)
## Portraits: the 16px art at a crisp 3x.
const PORTRAIT_SIZE := Vector2(48, 48)
const WIDE_CARD_SCALE := 2
const STATUS_COLOR := Color("9fe0a0")
## The dealer button: a square "D" in the inner bottom corner of the dealer's seat.
const DEALER_SIZE := 9
const HIT_SECONDS := 0.6
## How long a bomb that falls off takes to drop away and vanish.
const BOMB_DROP_SECONDS := 0.6
## A hex that fizzles: its icon sputters out over [constant HEX_SPUTTER_SECONDS], its pentagram's
## pixels guttering out one by one before the plate fades, while a wisp of smoke curls up off it
## and drifts away, gone by [constant HEX_FIZZLE_SECONDS].
const HEX_FIZZLE_SECONDS := 2.5
const HEX_SPUTTER_SECONDS := 1.4
## Of the sputter, how long the bare plate takes to fade at the end.
const HEX_PLATE_FADE_SECONDS := 0.3
## Smoke puffs: how many curl up off the icon while it sputters, how long each lasts, how fast it
## rises (pixels a second), how far it sways side to side, and how big a puff starts and ends.
const SMOKE_PUFFS := 26
const SMOKE_PUFF_SECONDS := 1.1
const SMOKE_RISE := 34.0
const SMOKE_SWAY := 9.0
const SMOKE_PUFF_SIZE := Vector2(2, 6)
const SMOKE_COLOR := Color("d4d0d8")
const SMOKE_SHADE := Color("7c7884")
## A dying ember's colour, between the hex's red and going out.
const EMBER_COLOR := Color("6a1414")
## How long the gold your-turn outline takes to fade in or out.
const ACTIVE_FADE_SECONDS := 0.1
## Tint for the text and hearts of a seat whose player is OUT or RIP.
const KNOCKED_OUT_TINT := Color(0.55, 0.55, 0.6)

## Z index of the shot's screen-darkening overlay. Portraits (and the gun) draw above it;
## everything else stays below.
const DARKEN_Z := 1
## Z index of the gold your-turn outline: above everything on the table (the banners and notices
## are at TableScene.BANNER_Z, just below), except the human's hole cards.
const OUTLINE_Z := DARKEN_Z + 3
## Z index of the human's hole cards, the only thing over the outline.
const HUMAN_CARDS_Z := OUTLINE_Z + 1
## The hex caster's magical fire, from its white-hot base out to its tips.
const FIRE_CORE := Color("fde8ff")
const FIRE_FLAME := Color("f65ad2")
const FIRE_BODY := Color("b82496")
const FIRE_TIPS := Color("6a1490")
## Colours the odd spark of the hex caster's fire flickers to.
const FIRE_SPARKS: Array[Color] = [Color("60f0ff"), Color("70ff9a"), Color("ffd860"), Color("b080ff")]

# Set these before adding the seat to the tree.
var player: PokerPlayer
var portrait: Texture2D
## Shown instead of [member portrait] once the player is down to their last heart (or out of hearts).
var injured_portrait: Texture2D
var style := Style.WIDE
## Heart slots to draw; lost hearts show as empty.
var max_hearts := 3

var _cards: Array[CardView] = []
var _name_label := Label.new()
var _chips_label := Label.new()
var _status_label := Label.new()
var _portrait_layer := Control.new()
## The gold your-turn outline, on top of every seat and everything in them.
var _outline_layer := Control.new()
var _is_dealer := false
var _is_active := false
## The your-turn outline's opacity, faded toward 1 or 0 as the turn comes and goes.
var _active_alpha := 0.0
var _battling := false
var _active_tween: Tween
var _reveal := false
var _is_winner := false
var _is_target := false
var _hit_at := -1.0
var _flash_color := PixelArt.HEART_RED
# When the hex glow started, and how long it lasts (-1 = not glowing).
var _hex_glow_at := -1.0
var _hex_glow_seconds := 0.0
var _hex_glow_one_sided := false # the caster's glow: only on the side facing the table
# When the bomb fell off (-1 = it hasn't).
var _bomb_dropped_at := -1.0
# When the hex fizzled (-1 = it hasn't), and which slot it was in.
var _hex_fizzled_at := -1.0
var _hex_fizzle_slot := 0
## A carried item left off the portrait, while a magpie is still bringing it over (null = none).
var hidden_item: HeldItem:
	set(value):
		hidden_item = value
		_portrait_layer.queue_redraw()

# Scrolled through to make the caster's hex fire lick and flicker.
static var _fire_noise: FastNoiseLite
# Scrolled through, slowly, for the cordyceps fuzz on an infected seat.
static var _fuzz_noise: FastNoiseLite


static func size_for(p_style: Style) -> Vector2:
	return WIDE_SIZE if p_style == Style.WIDE else COMPACT_SIZE


func seat_size() -> Vector2:
	return size_for(style)


func _is_compact() -> bool:
	return style != Style.WIDE


## Just under the 2x cards.
static func _wide_labels_y() -> float:
	return CardView.CARD_SIZE.y * WIDE_CARD_SCALE + 2


# Compact seats mirror: left column is [portrait][cards], right column is [cards][portrait].
## Centre of the portrait, in the parent's coordinates.
func portrait_center() -> Vector2:
	return position + _portrait_frame().get_center()


## Centre of the portrait, in canvas coordinates.
func portrait_global_center() -> Vector2:
	return get_global_transform() * _portrait_frame().get_center()


## The portrait to draw right now: injured at 1 heart or fewer, if there is one.
func _face() -> Texture2D:
	return injured_portrait if player.hearts <= 1 and injured_portrait != null else portrait


func _portrait_frame() -> Rect2:
	match style:
		Style.COMPACT_LEFT:
			return Rect2(Vector2(1, 1), PORTRAIT_SIZE)
		Style.COMPACT_RIGHT:
			return Rect2(Vector2(COMPACT_SIZE.x - 1 - PORTRAIT_SIZE.x, 1), PORTRAIT_SIZE)
		_:
			return Rect2(Vector2(1, 12), PORTRAIT_SIZE)


func _ready() -> void:
	size = seat_size()
	mouse_filter = MOUSE_FILTER_IGNORE
	set_process(false) # only runs while a glow or flash animates
	# Cards sit beside the portrait (on the inner side for compact seats).
	var card_scale := 1 if _is_compact() else WIDE_CARD_SCALE
	var cards_origin: Vector2
	match style:
		Style.COMPACT_LEFT: cards_origin = Vector2(PORTRAIT_SIZE.x + 4, 7)
		Style.COMPACT_RIGHT: cards_origin = Vector2(0, 7)
		_: cards_origin = Vector2(PORTRAIT_SIZE.x + 4, 0)
	for i in 2:
		var view := CardView.new()
		view.pixel_scale = card_scale
		view.position = cards_origin + Vector2(i * (CardView.CARD_SIZE.x * card_scale + 2), 0)
		if player.is_human():
			view.resting_z = HUMAN_CARDS_Z
			view.z_index = HUMAN_CARDS_Z
		add_child(view)
		_cards.append(view)
	var labels_y := 52.0 if _is_compact() else _wide_labels_y()
	if _is_compact():
		# Name; then hearts under it with the chips at the far end of that line; then status.
		var chips_align := HORIZONTAL_ALIGNMENT_RIGHT if style == Style.COMPACT_LEFT else HORIZONTAL_ALIGNMENT_LEFT
		_add_label(_name_label, labels_y, PixelArt.PAPER)
		_add_label(_chips_label, labels_y + UiTheme.LINE_HEIGHT, PixelArt.GOLD, chips_align)
		_add_label(_status_label, labels_y + UiTheme.LINE_HEIGHT * 2, STATUS_COLOR)
	else:
		# Name left and chips right; hearts under the name with the status at the right.
		_add_label(_name_label, labels_y, PixelArt.PAPER, HORIZONTAL_ALIGNMENT_LEFT)
		_add_label(_chips_label, labels_y, PixelArt.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
		_add_label(_status_label, labels_y + UiTheme.LINE_HEIGHT, STATUS_COLOR, HORIZONTAL_ALIGNMENT_RIGHT)
	_name_label.text = player.display_name
	_portrait_layer.mouse_filter = MOUSE_FILTER_IGNORE
	_portrait_layer.z_index = DARKEN_Z + 1
	_portrait_layer.draw.connect(func() -> void: _draw_portrait(_portrait_layer))
	add_child(_portrait_layer)
	_outline_layer.mouse_filter = MOUSE_FILTER_IGNORE
	_outline_layer.z_index = OUTLINE_Z
	_outline_layer.draw.connect(_draw_active_outline)
	add_child(_outline_layer)
	refresh()


## [param align] defaults to aligning toward the middle of the screen.
func _add_label(label: Label, y: float, color: Color, align := -1) -> void:
	if align < 0:
		match style:
			Style.COMPACT_LEFT: align = HORIZONTAL_ALIGNMENT_LEFT
			Style.COMPACT_RIGHT: align = HORIZONTAL_ALIGNMENT_RIGHT
			_: align = HORIZONTAL_ALIGNMENT_CENTER
	label.horizontal_alignment = align as HorizontalAlignment
	label.add_theme_color_override("font_color", color)
	UiTheme.add_at(self, label, Vector2(0, y), Vector2(seat_size().x, UiTheme.LINE_HEIGHT))


## Newly dealt hole cards fly in from [param from] (canvas coordinates), each after its delay in
## [param delays].
func deal_cards(delays: Array[float], from: Vector2) -> void:
	var face_up := player.is_human() or _reveal
	for i in mini(player.hole_cards.size(), delays.size()):
		_cards[i].deal_card(player.hole_cards[i], face_up, delays[i], from)
	refresh()


func refresh() -> void:
	# RIP once shot out of hearts (straight away, not just from the next hand); OUT if they went broke.
	_chips_label.text = "RIP" if player.hearts == 0 else "OUT" if player.is_out else "$%d" % player.chips
	var text_tint := KNOCKED_OUT_TINT if _knocked_out() else Color.WHITE
	for label: Label in [_name_label, _chips_label, _status_label]:
		label.modulate = text_tint
	var face_up := player.is_human() or _reveal
	for i in 2:
		var hole_card: Card = player.hole_cards[i] if i < player.hole_cards.size() else null
		_cards[i].set_card(hole_card, face_up)
		_cards[i].modulate = Color(1, 1, 1, 0.35) if player.folded else Color.WHITE
	_update_processing()
	queue_redraw()


## Shot out of hearts or gone broke: the seat shows RIP or OUT.
func _knocked_out() -> bool:
	return player.hearts == 0 or player.is_out


func set_status(text: String, color := STATUS_COLOR) -> void:
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", color)


func set_dealer(value: bool) -> void:
	_is_dealer = value
	queue_redraw()


func set_active(value: bool) -> void:
	if value == _is_active:
		return
	_is_active = value
	if _active_tween:
		_active_tween.kill()
	_active_tween = create_tween()
	_active_tween.tween_method(func(alpha: float) -> void:
		_active_alpha = alpha
		_outline_layer.queue_redraw(), _active_alpha, 1.0 if value else 0.0, ACTIVE_FADE_SECONDS)


## A battle: a red outline round the seat, over any gold one.
func set_battling(value: bool) -> void:
	_battling = value
	_outline_layer.queue_redraw()


func set_reveal(value: bool) -> void:
	_reveal = value
	refresh()


## Make the portrait pulse gold.
func set_winner(value: bool) -> void:
	_is_winner = value
	_update_processing()
	queue_redraw()


## Target mode: the portrait pulses red and the seat accepts a tap.
func set_targetable(value: bool) -> void:
	_is_target = value
	mouse_filter = MOUSE_FILTER_STOP if value else MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = CURSOR_POINTING_HAND
	_update_processing()
	queue_redraw()


## Brief red flash on the portrait after being shot.
func flash_hit() -> void:
	_flash(PixelArt.HEART_RED)


## Brief green flash on the portrait after a stimpak wins back a heart.
func flash_heal() -> void:
	_flash(PixelArt.HEAL_GREEN)


func _flash(color: Color) -> void:
	_flash_color = color
	_hit_at = Time.get_ticks_msec() / 1000.0
	_update_processing()


## A hex is being cast: magical fire that swells and dies down over [param seconds], all round the
## target's portrait, or, if [param one_sided] (the caster's), just from the side facing the middle
## of the table.
func hex_glow(seconds: float, one_sided := false) -> void:
	_hex_glow_at = Time.get_ticks_msec() / 1000.0
	_hex_glow_seconds = seconds
	_hex_glow_one_sided = one_sided
	_update_processing()


## How far through the hex glow this is (0 to 1), or -1 if it isn't glowing.
func _hex_glow_progress() -> float:
	if _hex_glow_at < 0:
		return -1.0
	var k := (Time.get_ticks_msec() / 1000.0 - _hex_glow_at) / _hex_glow_seconds
	return k if k < 1.0 else -1.0


## The bomb on this player fell off: it drops away and vanishes over [constant BOMB_DROP_SECONDS].
func drop_bomb() -> void:
	_bomb_dropped_at = Time.get_ticks_msec() / 1000.0
	_update_processing()


## Seconds since the bomb fell off, or -1 once it's gone (or if it hasn't fallen).
func _bomb_drop_time() -> float:
	if _bomb_dropped_at < 0:
		return -1.0
	var t := Time.get_ticks_msec() / 1000.0 - _bomb_dropped_at
	return t if t < BOMB_DROP_SECONDS else -1.0


## The hex this player carried in [param slot] (its index in their items) is gone, cast or
## fizzled: its icon sputters out and smokes over [constant HEX_FIZZLE_SECONDS], keeping its place
## until its plate has faded.
func fizzle_hex(slot: int) -> void:
	_hex_fizzled_at = Time.get_ticks_msec() / 1000.0
	_hex_fizzle_slot = slot
	_update_processing()


## Seconds since the hex fizzled, or -1 once its smoke is gone (or if it hasn't fizzled).
func _hex_fizzle_time() -> float:
	if _hex_fizzled_at < 0:
		return -1.0
	var t := Time.get_ticks_msec() / 1000.0 - _hex_fizzled_at
	return t if t < HEX_FIZZLE_SECONDS else -1.0


func _hit_active() -> bool:
	return _hit_at >= 0 and Time.get_ticks_msec() / 1000.0 - _hit_at < HIT_SECONDS


func _animating() -> bool:
	return _is_winner or _is_target or _hit_active() or _hex_glow_progress() >= 0 or _shimmering() or _leeched() \
		or _trapped() or _bomb_drop_time() >= 0 or _hex_fizzle_time() >= 0 or _infected()


## Under a shimmer and still in the game (a shimmer on someone knocked out stops showing).
func _shimmering() -> bool:
	return player.is_shimmering() and _still_playing()


## Under a leech and still in the game.
func _leeched() -> bool:
	return player.is_leeched() and _still_playing()


## Still in the game, counting being all in: no chips in front of them, but some in the pot this
## hand. (Once the hand is paid out, a player who lost it all is out.)
func _still_playing() -> bool:
	return player.hearts > 0 and (player.chips > 0 or player.total_bet > 0)


## Has a bomb strapped on and was dealt in. All in counts: the bomb stays on until the hand is
## settled, even with no chips left in front of them.
func _trapped() -> bool:
	return player.is_trapped() and not player.is_out and player.hearts > 0


## Infected with cordyceps and still in the game.
func _infected() -> bool:
	return player.is_infected() and _still_playing()


# Only redraw every frame while something is animating.
func _update_processing() -> void:
	set_process(_animating())


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if _is_target and click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		targeted.emit(self)


func fade_out_cards() -> void:
	for view in _cards:
		view.fade_out()


## Sets each hole card's highlight from [param highlight_for] (a Callable taking a Card or null).
func highlight_cards(highlight_for: Callable) -> void:
	for view in _cards:
		view.set_highlight(highlight_for.call(view.card))


func _process(_delta: float) -> void:
	queue_redraw() # animates the winner / target / shimmer glow and the hit flash
	if not _animating():
		set_process(false)


func _draw() -> void:
	# Dark backing so labels stay readable over any part of the map.
	var backing := Rect2(Vector2(-1, -1), seat_size() + Vector2(2, 2))
	var look := InterfaceStyle.current
	draw_rect(backing, look.seat_backing)
	# Brass trim with gilt corner brackets.
	draw_rect(backing, Color(look.brass, 0.35), false, 1)
	Ornament.draw_corner_brackets(self, backing, Color(look.trim, 0.8), 4)
	if _infected():
		_draw_fuzz(backing)
	_portrait_layer.queue_redraw()
	_draw_hearts()
	if _is_dealer:
		# In the seat's bottom corner on the side facing the table (the left, for the human),
		# a pixel clear of the gilt corner bracket.
		var inner_right := style == Style.COMPACT_LEFT
		var origin := Vector2(seat_size().x - 1 - DEALER_SIZE if inner_right else 1.0, seat_size().y - 1 - DEALER_SIZE)
		draw_rect(Rect2(origin, Vector2(DEALER_SIZE, DEALER_SIZE)), PixelArt.PAPER)
		draw_rect(Rect2(origin, Vector2(DEALER_SIZE, DEALER_SIZE)), PixelArt.INK, false, 1)
		PixelArt.draw(self, PixelArt.GLYPHS["D"], origin + Vector2(3, 2), 1, PixelArt.INK)


## Pixel hearts (2x) on the line under the name: full for lives left, empty for lost.
## Two pixels thick, just outside the seat's backing.
func _draw_active_outline() -> void:
	if _active_alpha <= 0 and not _battling:
		return
	var outline := PixelArt.HEART_RED if _battling else Color(PixelArt.GOLD, _active_alpha)
	_outline_layer.draw_rect(Rect2(Vector2(-2, -2), seat_size() + Vector2(4, 4)), outline, false, 1)
	_outline_layer.draw_rect(Rect2(Vector2(-3, -3), seat_size() + Vector2(6, 6)), outline, false, 1)


func _draw_hearts() -> void:
	const PX := 2
	const SPACING := 2
	var heart_w := float(PixelArt.HEART[0].length() * PX)
	var heart_h := float(PixelArt.HEART.size() * PX)
	var row_width := max_hearts * heart_w + (max_hearts - 1) * SPACING
	var line_y := (52.0 if _is_compact() else _wide_labels_y()) + UiTheme.LINE_HEIGHT
	var x := seat_size().x - 2 - row_width if style == Style.COMPACT_RIGHT else 2.0
	if style == Style.WIDE:
		x += DEALER_SIZE + 2 # clear of the dealer button in the corner below-left
	var y := line_y + floorf((UiTheme.LINE_HEIGHT - heart_h) / 2)
	var tint := KNOCKED_OUT_TINT if _knocked_out() else Color.WHITE

	for i in max_hearts:
		# Right-column seats fill from the right, so the hearts read toward the name's end.
		var full := i >= max_hearts - player.hearts if style == Style.COMPACT_RIGHT else i < player.hearts
		var origin := Vector2(x + i * (heart_w + SPACING), y)
		for d: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			PixelArt.draw(self, PixelArt.HEART, origin + d, PX, PixelArt.INK * tint) # 1px outline
		PixelArt.draw(self, PixelArt.HEART, origin, PX, (PixelArt.HEART_RED if full else PixelArt.HEART_EMPTY) * tint)
		if full:
			draw_rect(Rect2(origin + Vector2(PX, PX), Vector2(PX, PX)), Color(tint, 0.7)) # shine


## The portrait with its frame, glow and hit flash. Drawn onto [member _portrait_layer],
## which sits above [constant DARKEN_Z] so the screen can darken around the faces.
func _draw_portrait(c: CanvasItem) -> void:
	var face := _face()
	if face == null:
		return
	var frame := _portrait_frame()
	var dimmed := player.folded or player.is_out
	var hex_k := _hex_glow_progress()
	if hex_k >= 0:
		_draw_hex_halo(c, frame, hex_k)
	# A hand's winner can also be a target; while picking one, the red target glow wins.
	if _is_target:
		_draw_target_glow(c, frame, face)
	elif _is_winner:
		_draw_winner_glow(c, frame, face)
	elif _shimmering():
		_draw_shimmer_glow(c, frame, face, dimmed)
	else:
		_draw_portrait_frame(c, frame, dimmed)
		c.draw_texture_rect(face, frame, false, Color(0.45, 0.45, 0.5) if dimmed else Color.WHITE)
	# Out of the game: an X if shot down to no hearts, a dollar sign if they went broke.
	if player.hearts == 0:
		_draw_eliminated_x(c, frame)
	elif player.is_out:
		_draw_broke_sign(c, frame)
	if _shimmering():
		_draw_shimmer(c, frame)
	if _leeched():
		_draw_leech_glow(c, frame)
	_draw_item(c, frame)
	if _hex_fizzle_time() >= 0:
		_draw_hex_fizzle(c, frame, _hex_fizzle_time())
	if _leeched():
		_draw_leech(c, frame)
	if _infected():
		_draw_cordyceps(c, frame)
	if _trapped():
		_draw_bomb(c, frame, 0.0)
	elif _bomb_drop_time() >= 0:
		_draw_bomb(c, frame, _bomb_drop_time())
	if hex_k >= 0:
		_draw_hex_tint(c, frame, hex_k)
	if _hit_active():
		var k := 1.0 - (Time.get_ticks_msec() / 1000.0 - _hit_at) / HIT_SECONDS
		var blink := int(Time.get_ticks_msec() / 80.0) % 2 == 0
		c.draw_rect(frame, Color(Color.WHITE if blink else _flash_color, 0.65 * k))


## A gilt frame round the portrait: lit along the top and left, shadowed along the bottom and
## right, with gold studs at the corners. Dull pewter while [param dimmed].
static func _draw_portrait_frame(c: CanvasItem, frame: Rect2, dimmed: bool) -> void:
	var light := Color("8a8a96") if dimmed else InterfaceStyle.current.trim_light
	var dark := Color("4a4a56") if dimmed else InterfaceStyle.current.trim_dark
	var outer := frame.grow(1)
	c.draw_rect(outer, dark, false, 1)
	c.draw_rect(Rect2(outer.position, Vector2(outer.size.x - 1, 1)), light)
	c.draw_rect(Rect2(outer.position, Vector2(1, outer.size.y - 1)), light)
	for corner: Vector2 in [outer.position, Vector2(outer.end.x - 1, outer.position.y),
			Vector2(outer.position.x, outer.end.y - 1), outer.end - Vector2.ONE]:
		Ornament.draw_diamond(c, corner, 1, PixelArt.INK if not dimmed else dark)
		c.draw_rect(Rect2(corner, Vector2.ONE), light)


## The carried items, each a small icon on a dark plate in a bottom corner of the portrait, the
## first in the one nearest the cards. [member hidden_item] isn't drawn.
func _draw_item(c: CanvasItem, frame: Rect2) -> void:
	var slots := _slots()
	var plates := _plates(frame, slots)
	for i in slots.size():
		var held: HeldItem = slots[i]
		if held == null or held == hidden_item:
			continue # the fizzling hex's place, drawn by _draw_hex_fizzle
		var art := item_art(held.kind)
		c.draw_rect(plates[i].grow(1), InterfaceStyle.current.trim_dark)
		c.draw_rect(plates[i], PixelArt.INK)
		c.draw_rect(plates[i].grow(-1), InterfaceStyle.current.button_normal)
		PixelArt.draw_colored(c, art[0], art[1], plates[i].position + Vector2(2, 2), 1)


## What's in each slot along the portrait's bottom: the carried items, with null keeping the place
## of a hex that's still sputtering out (see [method fizzle_hex]).
func _slots() -> Array:
	var slots: Array = player.items.duplicate()
	var t := _hex_fizzle_time()
	if t >= 0 and t < HEX_SPUTTER_SECONDS:
		slots.insert(mini(_hex_fizzle_slot, slots.size()), null)
	return slots


## The plate for each of [param slots] (items, or null for a hex's place) on the portrait
## [param frame]: the first in the bottom corner nearest the cards, the second in the other bottom corner.
func _plates(frame: Rect2, slots: Array) -> Array[Rect2]:
	var plates: Array[Rect2] = []
	for i in slots.size():
		var held: HeldItem = slots[i]
		var icon: Array = item_art(held.kind if held else Item.Kind.HEX)[0]
		var plate_size := Vector2(icon[0].length(), icon.size()) + Vector2(4, 4)
		var on_left := (style == Style.COMPACT_RIGHT) == (i == 0)
		var left := frame.position.x if on_left else frame.end.x - plate_size.x
		plates.append(Rect2(Vector2(left, frame.end.y - plate_size.y), plate_size))
	return plates


## The hex's icon, [param t] seconds after it was cast or fizzled (it's gone from [member player] by now):
## each pixel of the pentagram gutters out at its own moment, flickering down to a dull ember
## first, then the bare plate fades. Wisps of smoke curl up from all along its top edge, swaying
## as they rise, growing and thinning out.
func _draw_hex_fizzle(c: CanvasItem, frame: Rect2, t: float) -> void:
	var icon := PixelArt.HEX_ICON
	var slots := _slots()
	var gap := slots.find(null)
	# Once its place is given up, the smoke carries on from where it was.
	if gap < 0:
		slots.insert(mini(_hex_fizzle_slot, slots.size()), null)
		gap = slots.find(null)
	var plate: Rect2 = _plates(frame, slots)[gap]
	var plate_fade := clampf((HEX_SPUTTER_SECONDS - t) / HEX_PLATE_FADE_SECONDS, 0.0, 1.0)
	if plate_fade > 0:
		c.draw_rect(plate.grow(1), Color(InterfaceStyle.current.trim_dark, plate_fade))
		c.draw_rect(plate, Color(PixelArt.INK, plate_fade))
		c.draw_rect(plate.grow(-1), Color(InterfaceStyle.current.button_normal, plate_fade))
		var black: Color = PixelArt.HEX_COLORS.K
		var red: Color = PixelArt.HEX_COLORS.R
		var gutter_by := HEX_SPUTTER_SECONDS - HEX_PLATE_FADE_SECONDS
		for y in icon.size():
			for x in icon[y].length():
				var at := Rect2(plate.position + Vector2(2 + x, 2 + y), Vector2.ONE)
				if icon[y][x] != "R":
					c.draw_rect(at, Color(black, plate_fade))
					continue
				# Each pixel goes out at its own moment, guttering for a while before it does.
				var out_at := gutter_by * (0.3 + 0.7 * _pixel_noise(x, y))
				var k := t / out_at
				var color := black
				if k < 1.0:
					var flicker := int(t / 0.06 + x * 3 + y * 7) % 3 == 0
					color = red.lerp(EMBER_COLOR, k)
					if flicker and k > 0.3:
						color = EMBER_COLOR.lerp(black, 0.5)
				c.draw_rect(at, Color(color, plate_fade))
	for i in SMOKE_PUFFS:
		var born := HEX_SPUTTER_SECONDS * i / SMOKE_PUFFS
		var age := t - born
		if age < 0 or age >= SMOKE_PUFF_SECONDS:
			continue
		var k := age / SMOKE_PUFF_SECONDS
		# The whole wisp curls one way then the other as it rises, each puff following it.
		var sway := sin(t * 2.5 - age * 4.0) * SMOKE_SWAY * k
		var drift := Vector2(sway + (i % 3 - 1) * 1.5 * k, -SMOKE_RISE * age)
		var puff := roundf(lerpf(SMOKE_PUFF_SIZE.x, SMOKE_PUFF_SIZE.y, k))
		var alpha := 0.5 * (1.0 - k * k)
		# Puffs rise from all along the plate's top, spread evenly (golden-ratio steps) across it.
		var along := fmod(i * 0.618034, 1.0)
		var source := Vector2(plate.position.x + 1 + (plate.size.x - 2) * along, plate.position.y)
		var at := (source + drift - Vector2.ONE * puff / 2).floor()
		# A darker underside, so it reads against a pale portrait as well as the dark seat.
		c.draw_rect(Rect2(at + Vector2(1, 1), Vector2.ONE * puff), Color(SMOKE_SHADE, alpha * 0.6))
		c.draw_rect(Rect2(at, Vector2.ONE * puff), Color(SMOKE_COLOR, alpha))


## A steady pseudo-random 0-1 for the icon pixel at [param x], [param y].
static func _pixel_noise(x: int, y: int) -> float:
	var n := sin(x * 12.9898 + y * 78.233) * 43758.5453
	return n - floorf(n)


## Centre of the plate [param item] (one this player carries) is shown on, in the parent's coordinates.
func item_center(item: HeldItem) -> Vector2:
	var slots := _slots()
	return position + _plates(_portrait_frame(), slots)[maxi(slots.find(item), 0)].get_center()


## Centre of the plate a newly gained [param kind] will be shown on, after what this player
## carries now, in the parent's coordinates.
func next_item_center(kind: Item.Kind) -> Vector2:
	var slots: Array = player.items.duplicate()
	slots.append(HeldItem.new(kind, 0))
	return position + _plates(_portrait_frame(), slots)[-1].get_center()


## The icon for [param item] (drawn at 1x): [pattern, colours] for [method PixelArt.draw_colored].
static func item_art(item: Item.Kind) -> Array:
	match item:
		Item.Kind.GUN: return [PixelArt.GUN_ICON, PixelArt.GUN_COLORS]
		Item.Kind.SHIELD: return [PixelArt.SHIELD_ICON, PixelArt.SHIELD_COLORS]
		Item.Kind.STIMPAK: return [PixelArt.STIMPAK_ICON, PixelArt.STIMPAK_COLORS]
		Item.Kind.HEX: return [PixelArt.HEX_ICON, PixelArt.HEX_COLORS]
	assert(false, "unknown item %d" % item)
	return [[], {}]


## A black X across the portrait of a player shot out of the game, drawn in blocks on the
## portrait's own pixel grid (16 art pixels across) so it matches the art.
static func _draw_eliminated_x(c: CanvasItem, frame: Rect2) -> void:
	var px := frame.size.x / 16
	var block := Vector2(px * 2, px)
	for i in range(1, 15):
		c.draw_rect(Rect2(frame.position + Vector2(i - 1, i) * px, block), Color.BLACK)
		c.draw_rect(Rect2(frame.position + Vector2(15 - i, i) * px, block), Color.BLACK)


## A black dollar sign centred on the portrait of a player who ran out of chips.
static func _draw_broke_sign(c: CanvasItem, frame: Rect2) -> void:
	var px := int(frame.size.x / 16)
	var sign_art := PixelArt.DOLLAR_SIGN
	var art_size := Vector2(sign_art[0].length(), sign_art.size()) * px
	PixelArt.draw(c, sign_art, frame.position + ((frame.size - art_size) / 2).floor(), px, Color.BLACK)


## How strong the hex glow is [param k] of the way through: swells in, then fades, flickering.
static func _hex_glow_strength(k: float) -> float:
	var flicker := 0.88 + 0.12 * sin(k * 47.0)
	return sin(k * PI) * flicker


## The side of the portrait facing the middle of the table: inward for the side columns, up for
## the human.
func _table_side() -> Vector2:
	match style:
		Style.COMPACT_LEFT: return Vector2.RIGHT
		Style.COMPACT_RIGHT: return Vector2.LEFT
		_: return Vector2.UP


## A 1-pixel line along the [param side] edge of [param frame], [param d] pixels out from it (1 is
## just outside the frame, 0 and below inside it), reaching [param spread] past each end.
static func _side_line(frame: Rect2, side: Vector2, d: float, spread: float) -> Rect2:
	match side:
		Vector2.RIGHT: return Rect2(frame.end.x - 1 + d, frame.position.y - spread, 1, frame.size.y + spread * 2)
		Vector2.LEFT: return Rect2(frame.position.x - d, frame.position.y - spread, 1, frame.size.y + spread * 2)
		Vector2.DOWN: return Rect2(frame.position.x - spread, frame.end.y - 1 + d, frame.size.x + spread * 2, 1)
		_: return Rect2(frame.position.x - spread, frame.position.y - d, frame.size.x + spread * 2, 1)


## The hex glow behind the portrait: magical fire. The caster's licks out a long way from the side
## facing the table; the target's burns shorter, off every side, spilling round the corners.
func _draw_hex_halo(c: CanvasItem, frame: Rect2, k: float) -> void:
	const CASTER_reach := 31
	const CASTER_inset := 2 # starts a little in from the ends of its edge
	const TARGET_reach := 22
	const TARGET_inset := -3 # runs past the ends of each edge, to meet round the corners
	if _hex_glow_one_sided:
		_draw_hex_fire(c, frame, k, _table_side(), CASTER_reach, CASTER_inset)
		return
	for side: Vector2 in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
		_draw_hex_fire(c, frame, k, side, TARGET_reach, TARGET_inset)


## Magical fire licking out from the [param side] of the portrait, on a 2px grid: tongues of flame
## up to [param reach] cells long, from [param inset] cells in from each end of that edge (negative
## to spill past them), white-hot at the base, through magenta to purple at the tips, flecked
## with sparks of other colours, with embers drifting off the top. Grows and dies down with the glow.
func _draw_hex_fire(c: CanvasItem, frame: Rect2, k: float, side: Vector2, reach: int, inset: int) -> void:
	const PX := 2
	const TAPER := 2 # cells at each end of the fire over which it dies down
	const RISE := 26.0 # cells a second the flames' pattern travels out
	const EMBERS := 9
	const SPARK_CHANCE := 26 # about one cell in this many is a spark at any moment
	const SPARK_RATE := 12.0 # times a second the sparks move to new cells
	if _fire_noise == null:
		_fire_noise = FastNoiseLite.new()
		_fire_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_fire_noise.frequency = 0.2
		_fire_noise.fractal_octaves = 2
	var strength := _hex_glow_strength(k)
	var t := k * _hex_glow_seconds

	# Drawn as if the fire rises up from a horizontal edge at the origin, then turned to face [param side].
	var length := frame.size.x if side.y != 0 else frame.size.y
	match side:
		Vector2.RIGHT: c.draw_set_transform(Vector2(frame.end.x + 1, frame.position.y), PI / 2)
		Vector2.LEFT: c.draw_set_transform(Vector2(frame.position.x - 1, frame.end.y), -PI / 2)
		Vector2.DOWN: c.draw_set_transform(Vector2(frame.end.x, frame.end.y + 1), PI)
		_: c.draw_set_transform(Vector2(frame.position.x, frame.position.y - 1))
	var cols := int(length / PX)
	# Different flames for each seat and each side.
	var side_index := int(side.angle() / (PI / 2)) + 2
	var seed := player.seat * 37.0 + side_index * 101.0
	var spark_step := int(t * SPARK_RATE)
	# A soft glow behind the flames, fading out from the edge.
	for row in reach:
		var glow := 0.3 * strength * pow(1.0 - float(row) / reach, 2.0)
		c.draw_rect(Rect2(inset * PX, -(row + 1) * PX, (cols - inset * 2) * PX, PX), Color(FIRE_BODY, glow))
	for col in range(inset, cols - inset):
		# Full height along the middle of the edge, dying down towards its ends.
		var from_end := mini(col - inset, cols - 1 - inset - col)
		var taper := minf(1.0, (from_end + 1.0) / (TAPER + 1))
		# Each column's flame leaps and drops on its own, so the fire breaks into tongues.
		var leap := 0.5 + 0.5 * _fire_noise.get_noise_2d(col * 0.7 + seed, t * 14.0)
		var height := reach * (0.35 + 0.65 * leap) * taper * (0.4 + 0.6 * strength)
		for row in reach:
			# Licks of flame travel out along the tongues.
			var lick := _fire_noise.get_noise_2d(col * 0.6 - seed, (row - t * RISE) * 0.45)
			var heat := (1.0 - row / height) * 1.25 + lick * 0.4
			if strength < 0.999:
				heat *= 0.5 + 0.5 * strength
			var color: Color
			if heat > 1.0:
				color = FIRE_CORE
			elif heat > 0.72:
				color = FIRE_FLAME
			elif heat > 0.42:
				color = FIRE_BODY
			elif heat > 0.15:
				color = Color(FIRE_TIPS, 0.85)
			else:
				continue
			# Here and there, a cell flickers to another colour.
			var roll := absi(col * 73856093 ^ row * 19349663 ^ (spark_step + player.seat * 4 + side_index) * 83492791)
			if heat > 0.3 and roll % SPARK_CHANCE == 0:
				color = FIRE_SPARKS[roll / SPARK_CHANCE % FIRE_SPARKS.size()]
			c.draw_rect(Rect2(col * PX, -(row + 1) * PX, PX, PX), color)

	# Embers rise off the flames in all the fire's colours, flickering and drifting side to side as
	# they fade.
	for i in EMBERS:
		var life := fmod(t * 1.3 + float(i) / EMBERS, 1.0)
		var x := (fmod(i * 7.3 + seed, cols) + sin(life * TAU + i) * 1.5) * PX
		var y := -(reach * 0.5 + life * reach * 0.9) * PX
		var alpha := (1.0 - life) * strength * (0.6 + 0.4 * sin(t * 30.0 + i))
		c.draw_rect(Rect2(Vector2(x, y).floor(), Vector2(PX, PX)), Color(FIRE_FLAME if i % 2 == 0 else FIRE_SPARKS[(i / 2 + player.seat + side_index) % FIRE_SPARKS.size()], alpha))
	c.draw_set_transform(Vector2.ZERO)


## The hex glow over the portrait, in the fire's colours: a burning frame and the face washed with
## it. One-sided (the caster's), just that edge burns and the wash fades in from it.
func _draw_hex_tint(c: CanvasItem, frame: Rect2, k: float) -> void:
	const WASH := 16 # pixels the one-sided wash reaches into the portrait
	var strength := _hex_glow_strength(k)
	if not _hex_glow_one_sided:
		c.draw_rect(frame.grow(2), Color(FIRE_FLAME, strength), false, 1)
		c.draw_rect(frame.grow(1), Color(FIRE_CORE, strength), false, 1)
		c.draw_rect(frame, Color(FIRE_BODY, 0.4 * strength))
		return
	var side := _table_side()
	c.draw_rect(_side_line(frame, side, 2, 1), Color(FIRE_FLAME, strength))
	c.draw_rect(_side_line(frame, side, 1, 1), Color(FIRE_CORE, strength))
	for j in WASH:
		c.draw_rect(_side_line(frame, side, -j, 0), Color(FIRE_BODY, 0.5 * strength * pow(1.0 - float(j) / WASH, 1.5)))


## Red pulsing halo and tint for a seat that can be targeted, plus a red seat outline.
func _draw_target_glow(c: CanvasItem, frame: Rect2, face: Texture2D) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var pulse := 0.55 + 0.45 * sin(t * 6.0)
	var red := PixelArt.HEART_RED
	c.draw_rect(Rect2(Vector2(-2, -2), seat_size() + Vector2(4, 4)), Color(red, 0.5 + 0.5 * pulse), false, 1)
	c.draw_rect(frame.grow(4), Color(red, 0.3 * pulse), false, 1)
	c.draw_rect(frame.grow(3), Color(red, 0.6 * pulse), false, 1)
	c.draw_rect(frame.grow(2), Color("ff8a8a"), false, 1)
	c.draw_rect(frame.grow(1), red, false, 1)
	c.draw_texture_rect(face, frame, false, Color.WHITE.lerp(Color("ff9090"), 0.55 * pulse))
	c.draw_rect(frame, Color(red, 0.22 * pulse))


## White frame with softly pulsing halo rings, for a player under a shimmer.
func _draw_shimmer_glow(c: CanvasItem, frame: Rect2, face: Texture2D, dimmed: bool) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var pulse := 0.6 + 0.4 * sin(t * 3.0)
	c.draw_rect(frame.grow(4), Color(Color.WHITE, 0.2 * pulse), false, 1)
	c.draw_rect(frame.grow(3), Color(Color.WHITE, 0.45 * pulse), false, 1)
	c.draw_rect(frame.grow(2), Color(Color.WHITE, 0.75), false, 1)
	c.draw_rect(frame.grow(1), Color.WHITE, false, 1)
	c.draw_texture_rect(face, frame, false, Color(0.45, 0.45, 0.5) if dimmed else Color.WHITE)


## The shimmer over the portrait, on its own pixel grid: a pale diagonal band sweeping across,
## and scattered pixels twinkling white.
func _draw_shimmer(c: CanvasItem, frame: Rect2) -> void:
	const GRID := 16
	const SWEEP_SECONDS := 1.8
	var px := frame.size.x / GRID
	var t := Time.get_ticks_msec() / 1000.0
	# The band runs from the top-left corner to the bottom-right, then pauses off the portrait.
	var band := fmod(t / SWEEP_SECONDS, 1.0) * GRID * 3 - GRID * 0.5
	var twinkle_step := int(t * 6)
	for y in GRID:
		for x in GRID:
			var alpha := 0.0
			var d := absf(x + y - band)
			if d < 2.5:
				alpha = 0.32 * (1.0 - d / 2.5)
			# Each pixel twinkles now and then, out of step with its neighbours.
			if (x * 7 + y * 13 + twinkle_step * 5 + _twinkle_seed()) % 37 == 0:
				alpha = maxf(alpha, 0.7)
			if alpha > 0:
				c.draw_rect(Rect2(frame.position + Vector2(x, y) * px, Vector2(px, px)), Color(Color.WHITE, alpha))
	c.draw_rect(frame, Color(Color("dde8ff"), 0.08))


## Gold welling up from the bottom of the portrait, pulsing, with a glow spilling out under it.
func _draw_leech_glow(c: CanvasItem, frame: Rect2) -> void:
	const GRID := 16
	const ROWS := 10 # art rows the glow climbs, from the bottom
	var px := frame.size.x / GRID
	var pulse := 0.7 + 0.3 * sin(Time.get_ticks_msec() / 1000.0 * 3.5)
	for r in ROWS:
		var alpha := 0.75 * pulse * pow(1.0 - float(r) / ROWS, 1.3)
		c.draw_rect(Rect2(frame.position.x, frame.end.y - (r + 1) * px, frame.size.x, px), Color(PixelArt.GOLD, alpha))
	# The frame's bottom edge lit gold, and light spilling out below it.
	c.draw_rect(Rect2(frame.position.x - 1, frame.end.y, frame.size.x + 2, 1), PixelArt.GOLD)
	for i in 4:
		var y := frame.end.y + 1 + i
		c.draw_rect(Rect2(frame.position.x - 2, y, frame.size.x + 4, 1), Color(PixelArt.GOLD, (0.85 - 0.22 * i) * pulse))


## The leech, latched onto the bottom of the portrait on the side away from the item and
## dangling a little below it, its tail swinging.
func _draw_leech(c: CanvasItem, frame: Rect2) -> void:
	const PX := 2
	var art := PixelArt.LEECH if int(Time.get_ticks_msec() / 500.0) % 2 == 0 else PixelArt.LEECH_SWUNG
	var art_size := Vector2(art[0].length(), art.size()) * PX
	var x := frame.end.x - 6 - art_size.x if style == Style.COMPACT_RIGHT else frame.position.x + 6
	PixelArt.draw_colored(c, art, PixelArt.LEECH_COLORS, Vector2(x, frame.end.y - art_size.y + 4), PX)


## The bomb, strapped to the side of the portrait facing the table, near the top (away from the
## item), its fuse fizzing. [param dropped] seconds after it fell off it's dropping away, fading,
## its fuse out.
func _draw_bomb(c: CanvasItem, frame: Rect2, dropped: float) -> void:
	const PX := 2
	const GRAVITY := 600.0
	var art := PixelArt.BOMB if int(Time.get_ticks_msec() / 90.0) % 2 == 0 else PixelArt.BOMB_FIZZ
	if dropped > 0:
		art = PixelArt.BOMB.duplicate()
		for i in 3: # the spark's out
			art[i] = ".".repeat(art[i].length())
	var side := _table_side()
	if side == Vector2.LEFT: # fuse pointing away from the portrait
		var flipped: Array[String] = []
		for row in art:
			flipped.append(row.reverse())
		art = flipped
	var art_size := Vector2(art[0].length(), art.size()) * PX
	var at: Vector2
	if side == Vector2.UP:
		at = Vector2(frame.get_center().x - art_size.x / 2, frame.position.y - art_size.y / 2)
	else:
		var edge := frame.end.x if side == Vector2.RIGHT else frame.position.x
		at = Vector2(edge - art_size.x / 2, frame.position.y + 2)
	at.y += 0.5 * GRAVITY * dropped * dropped
	var fade := 1.0 - dropped / BOMB_DROP_SECONDS
	var colors := {}
	for key: String in PixelArt.BOMB_COLORS:
		colors[key] = Color(PixelArt.BOMB_COLORS[key], fade)
	PixelArt.draw_colored(c, art, colors, at.floor(), PX)


## White cordyceps fuzz over an infected seat's [param backing], under everything else on it:
## soft clumps of mould in pixel cells, thicker toward the edges as if creeping in from them,
## slowly shifting.
func _draw_fuzz(backing: Rect2) -> void:
	const CELL := 2
	## How far in from the edges the fuzz is thickened, and how much.
	const EDGE_REACH := 18.0
	const EDGE_WEIGHT := 0.45
	## Cells below this much fuzz are left clear; denser ones are whiter, up to MAX_ALPHA.
	const THRESHOLD := 0.62
	const MAX_ALPHA := 0.5
	if _fuzz_noise == null:
		_fuzz_noise = FastNoiseLite.new()
		_fuzz_noise.frequency = 0.18
		_fuzz_noise.fractal_octaves = 3
	var t := Time.get_ticks_msec() / 1000.0 * 6.0
	var offset := float(player.seat * 97) # so infected seats don't fuzz in lockstep
	for y in range(0, int(backing.size.y), CELL):
		for x in range(0, int(backing.size.x), CELL):
			var edge := minf(minf(x, backing.size.x - x), minf(y, backing.size.y - y))
			var edge_k := 1.0 - clampf(edge / EDGE_REACH, 0.0, 1.0)
			var n := _fuzz_noise.get_noise_3d(x / CELL + offset, y / CELL, t) * 0.5 + 0.5
			var v := n * 0.8 + edge_k * EDGE_WEIGHT
			if v < THRESHOLD:
				continue
			var alpha := minf((v - THRESHOLD) * 1.6, MAX_ALPHA)
			draw_rect(Rect2(backing.position + Vector2(x, y), Vector2(CELL, CELL)), Color(1, 1, 1, alpha))


## Cordyceps sprouting from the head: a few orange fungal stalks rising out of the top of the
## portrait, each topped with a pale bulb, swaying slowly and out of step.
func _draw_cordyceps(c: CanvasItem, frame: Rect2) -> void:
	const PX := 2
	const STALK := Color("b8642a")
	const BULB := Color("f2b060")
	const DARK := Color("3a1a08")
	var t := Time.get_ticks_msec() / 1000.0
	# Where each stalk rises from (share of the portrait's width) and how many cells tall it is.
	for stalk: Vector3 in [Vector3(0.3, 7, 0.0), Vector3(0.5, 9, 2.1), Vector3(0.7, 6, 4.3)]:
		var base := Vector2(frame.position.x + frame.size.x * stalk.x, frame.position.y + 8).floor()
		var cells := int(stalk.y)
		var tip := base
		for j in cells:
			# Bends more toward the tip, so it sways from the root.
			var bend := pow(float(j) / cells, 2) * sin(t * 1.6 + stalk.z) * 3.0
			tip = (base + Vector2(bend, -j * PX)).round()
			c.draw_rect(Rect2(tip - Vector2(1, 0), Vector2(PX + 2, PX)), DARK)
			c.draw_rect(Rect2(tip, Vector2(PX, PX)), STALK)
		var bulb := Rect2(tip - Vector2(2, 3), Vector2(PX + 4, 4))
		c.draw_rect(bulb.grow(1), DARK)
		c.draw_rect(bulb, BULB)


## Offsets the shimmer's twinkles so seats under a shimmer don't sparkle in lockstep.
func _twinkle_seed() -> int:
	return player.seat * 11


## Gold frame with pulsing halo rings, a warm tint and twinkling corner sparkles.
func _draw_winner_glow(c: CanvasItem, frame: Rect2, face: Texture2D) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var pulse := 0.6 + 0.4 * sin(t * 5.0)
	c.draw_rect(frame.grow(4), Color(PixelArt.GOLD, 0.3 * pulse), false, 1)
	c.draw_rect(frame.grow(3), Color(PixelArt.GOLD, 0.6 * pulse), false, 1)
	c.draw_rect(frame.grow(2), Color("ffe9a0"), false, 1)
	c.draw_rect(frame.grow(1), PixelArt.GOLD, false, 1)
	c.draw_texture_rect(face, frame, false, Color.WHITE.lerp(Color("ffe9a0"), 0.5 * pulse))
	c.draw_rect(frame, Color(PixelArt.GOLD, 0.25 * pulse))

	# Two diagonal corners twinkle at a time.
	var phase := int(t * 3) % 2 == 0
	var a := frame.position + Vector2(-5, -5) if phase else frame.position + Vector2(frame.size.x + 4, -5)
	var b := frame.end + Vector2(4, 4) if phase else frame.position + Vector2(-5, frame.size.y + 4)
	for p: Vector2 in [a, b]:
		c.draw_rect(Rect2(p, Vector2.ONE), Color.WHITE)
		c.draw_rect(Rect2(p + Vector2(-1, 0), Vector2.ONE), Color(PixelArt.GOLD, 0.8))
		c.draw_rect(Rect2(p + Vector2(1, 0), Vector2.ONE), Color(PixelArt.GOLD, 0.8))
		c.draw_rect(Rect2(p + Vector2(0, -1), Vector2.ONE), Color(PixelArt.GOLD, 0.8))
		c.draw_rect(Rect2(p + Vector2(0, 1), Vector2.ONE), Color(PixelArt.GOLD, 0.8))

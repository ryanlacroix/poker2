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
const HIT_SECONDS := 0.6

## Z index of the shot's screen-darkening overlay. Portraits (and the gun) draw above it;
## everything else stays below.
const DARKEN_Z := 1

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
var _is_dealer := false
var _is_active := false
var _reveal := false
var _is_winner := false
var _is_target := false
var _hit_at := -1.0
var _flash_color := PixelArt.HEART_RED


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
	set_process(false) # only runs while the winner glow animates
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


## [param deal_delays] staggers newly dealt hole cards: how long each waits before going down.
func refresh(deal_delays: Array[float] = []) -> void:
	# RIP once shot out of hearts (straight away, not just from the next hand); OUT if they went broke.
	_chips_label.text = "RIP" if player.hearts == 0 else "OUT" if player.is_out else "$%d" % player.chips
	var face_up := player.is_human() or _reveal
	for i in 2:
		var hole_card: Card = player.hole_cards[i] if i < player.hole_cards.size() else null
		_cards[i].set_card(hole_card, face_up, deal_delays[i] if i < deal_delays.size() else 0.0)
		_cards[i].modulate = Color(1, 1, 1, 0.35) if player.folded else Color.WHITE
	queue_redraw()


func set_status(text: String, color := STATUS_COLOR) -> void:
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", color)


func set_dealer(value: bool) -> void:
	_is_dealer = value
	queue_redraw()


func set_active(value: bool) -> void:
	_is_active = value
	queue_redraw()


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


func _hit_active() -> bool:
	return _hit_at >= 0 and Time.get_ticks_msec() / 1000.0 - _hit_at < HIT_SECONDS


# Only redraw every frame while something is animating.
func _update_processing() -> void:
	set_process(_is_winner or _is_target or _hit_active())


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
	queue_redraw() # animates the winner / target glow and the hit flash
	if not _is_winner and not _is_target and not _hit_active():
		set_process(false)


func _draw() -> void:
	# Dark backing so labels stay readable over any part of the map.
	draw_rect(Rect2(Vector2(-1, -1), seat_size() + Vector2(2, 2)), Color(0.05, 0.06, 0.11, 0.78))
	if _is_active:
		draw_rect(Rect2(Vector2(-2, -2), seat_size() + Vector2(4, 4)), PixelArt.GOLD, false, 1)
	_portrait_layer.queue_redraw()
	_draw_hearts()
	if _is_dealer:
		var origin: Vector2
		match style:
			Style.COMPACT_LEFT: origin = Vector2(seat_size().x - 10, 53)
			Style.COMPACT_RIGHT: origin = Vector2(1, 53)
			_: origin = Vector2(1, _portrait_frame().end.y + 3) # under the portrait
		draw_rect(Rect2(origin, Vector2(9, 9)), PixelArt.PAPER)
		draw_rect(Rect2(origin, Vector2(9, 9)), PixelArt.INK, false, 1)
		PixelArt.draw(self, PixelArt.GLYPHS["D"], origin + Vector2(3, 2), 1, PixelArt.INK)


## Pixel hearts (2x) on the line under the name: full for lives left, empty for lost.
func _draw_hearts() -> void:
	const PX := 2
	const SPACING := 2
	var heart_w := float(PixelArt.HEART[0].length() * PX)
	var heart_h := float(PixelArt.HEART.size() * PX)
	var row_width := max_hearts * heart_w + (max_hearts - 1) * SPACING
	var line_y := (52.0 if _is_compact() else _wide_labels_y()) + UiTheme.LINE_HEIGHT
	var x := seat_size().x - 2 - row_width if style == Style.COMPACT_RIGHT else 2.0
	var y := line_y + floorf((UiTheme.LINE_HEIGHT - heart_h) / 2)

	for i in max_hearts:
		# Right-column seats fill from the right, so the hearts read toward the name's end.
		var full := i >= max_hearts - player.hearts if style == Style.COMPACT_RIGHT else i < player.hearts
		var origin := Vector2(x + i * (heart_w + SPACING), y)
		for d: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			PixelArt.draw(self, PixelArt.HEART, origin + d, PX, PixelArt.INK) # 1px outline
		PixelArt.draw(self, PixelArt.HEART, origin, PX, PixelArt.HEART_RED if full else PixelArt.HEART_EMPTY)
		if full:
			draw_rect(Rect2(origin + Vector2(PX, PX), Vector2(PX, PX)), Color(1, 1, 1, 0.7)) # shine


## The portrait with its frame, glow and hit flash. Drawn onto [member _portrait_layer],
## which sits above [constant DARKEN_Z] so the screen can darken around the faces.
func _draw_portrait(c: CanvasItem) -> void:
	var face := _face()
	if face == null:
		return
	var frame := _portrait_frame()
	var dimmed := player.folded or player.is_out
	# A hand's winner can also be a target; while picking one, the red target glow wins.
	if _is_target:
		_draw_target_glow(c, frame, face)
	elif _is_winner:
		_draw_winner_glow(c, frame, face)
	else:
		c.draw_rect(frame.grow(1), PixelArt.INK if dimmed else PixelArt.PAPER, false, 1)
		c.draw_texture_rect(face, frame, false, Color(0.45, 0.45, 0.5) if dimmed else Color.WHITE)
	# Out of the game: an X if shot down to no hearts, a dollar sign if they went broke.
	if player.hearts == 0:
		_draw_eliminated_x(c, frame)
	elif player.is_out:
		_draw_broke_sign(c, frame)
	_draw_item(c, frame)
	if _hit_active():
		var k := 1.0 - (Time.get_ticks_msec() / 1000.0 - _hit_at) / HIT_SECONDS
		var blink := int(Time.get_ticks_msec() / 80.0) % 2 == 0
		c.draw_rect(frame, Color(Color.WHITE if blink else _flash_color, 0.65 * k))


## The carried item, as a small icon on a dark plate in the portrait's bottom corner
## nearest the cards.
func _draw_item(c: CanvasItem, frame: Rect2) -> void:
	if not player.has_item():
		return
	var icon: Array[String]
	var colors: Dictionary
	match player.item:
		Item.Kind.GUN:
			icon = PixelArt.GUN_ICON
			colors = PixelArt.GUN_COLORS
		Item.Kind.SHIELD:
			icon = PixelArt.SHIELD_ICON
			colors = PixelArt.SHIELD_COLORS
		Item.Kind.STIMPAK:
			icon = PixelArt.STIMPAK_ICON
			colors = PixelArt.STIMPAK_COLORS
		_:
			assert(false, "unknown item %d" % player.item)
			return
	var icon_size := Vector2(icon[0].length(), icon.size())
	var plate_size := icon_size + Vector2(4, 4)
	var plate := Rect2(
		Vector2(frame.position.x if style == Style.COMPACT_RIGHT else frame.end.x - plate_size.x,
			frame.end.y - plate_size.y), plate_size)
	c.draw_rect(plate, PixelArt.INK)
	c.draw_rect(plate.grow(-1), Color("2d3a5a"))
	PixelArt.draw_colored(c, icon, colors, plate.position + Vector2(2, 2), 1)


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

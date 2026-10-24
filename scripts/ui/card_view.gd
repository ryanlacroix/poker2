class_name CardView
extends Control
## Draws one card (face up, face down, or an empty slot) in pixel-art style.

enum Highlight { NONE, WINNING, KICKER, DIMMED }

const CARD_SIZE := Vector2(26, 36)

# A newly placed card pops in a little large, then quickly settles to its real size.
const POP_SCALE := 1.4
const POP_SECONDS := 0.15
## How long [method fade_out] takes.
const FADE_SECONDS := 0.2
## How long a dealt card takes to fly to its place (see [method deal_card]).
const FLY_SECONDS := 0.25
## Z index while flying: above the portraits, so a card never passes under one. A card that
## rests higher (see [member resting_z]) keeps its own.
const FLY_Z := SeatView.DARKEN_Z + 2

## A swaying card (see [member sway]) bobs up and down by up to [constant SWAY_BOB] pixels and
## tilts by up to [constant SWAY_TILT] radians either way, each on its own slow cycle.
const SWAY_BOB := 1.0
const SWAY_BOB_SECONDS := 3.6
const SWAY_TILT := 0.018
const SWAY_TILT_SECONDS := 5.1

## A see-through sword over the card's face: a sword card (see [signal PokerTable.battle_started]).
const SWORD: Array[String] = [
	"....o....",
	"...oWo...",
	"..oBWBo..", "..oBWBo..", "..oBWBo..", "..oBWBo..", "..oBWBo..", "..oBWBo..",
	"..oBWBo..", "..oBWBo..", "..oBWBo..", "..oBWBo..", "..oBWBo..", "..oBWBo..",
	"..oBWBo..", "..oBWBo..", "..oBWBo..", "..oBWBo..", "..oBWBo..",
	"ooooooooo",
	"oGGGGGGGo",
	"ooooooooo",
	"...oHo...", "...oHo...", "...oHo...", "...oHo...", "...oHo...",
	"..oGGGo..",
	"..ooooo..",
]
const SWORD_COLORS := {
	"o": Color(PixelArt.INK, 0.4),
	"B": Color(0.82, 0.86, 0.92, 0.55),
	"W": Color(1, 1, 1, 0.65),
	"G": Color(PixelArt.GOLD, 0.6),
	"H": Color(0.45, 0.28, 0.12, 0.55),
}

var show_empty_slot := false
## Whole-number size multiplier; the pixel art is drawn scaled so it stays crisp. Set before adding.
var pixel_scale := 1
## The card shown, if any. Set with [method set_card].
var card: Card
## Z index the card returns to after flying in.
var resting_z := 0
## Shows the sword over the card's face.
var sword := false:
	set(value):
		sword = value
		queue_redraw()
## While showing a card, it hovers and sways a little, never quite still.
var sway := false:
	set(value):
		sway = value
		set_process(value)

var _face_up := false
var _highlight := Highlight.NONE
var _pop_tween: Tween
var _fade_tween: Tween
## Where the card sits; it's away from here only while flying in.
var _home: Vector2
var _flying := false
## Seconds into the sway; each card starts at a random point so they don't move in step.
var _sway_time := randf() * 100.0


func _ready() -> void:
	custom_minimum_size = CARD_SIZE * pixel_scale
	size = CARD_SIZE * pixel_scale
	mouse_filter = MOUSE_FILTER_IGNORE
	set_process(sway)


func _process(delta: float) -> void:
	_sway_time += delta
	if card != null:
		queue_redraw()


## A new card pops in after [param delay] seconds, hidden until then.
func set_card(p_card: Card, face_up: bool, delay := 0.0) -> void:
	if _replace(p_card, face_up) and p_card != null:
		_pop_in(delay)


## Like [method set_card], but a new card flies in to its place from [param from] (a point in
## canvas coordinates, where the card's centre starts).
func deal_card(p_card: Card, face_up: bool, delay: float, from: Vector2) -> void:
	if _replace(p_card, face_up) and p_card != null:
		_fly_in(delay, from)


## Shows [param p_card]. Returns whether it's a different card, in which case any animation of
## the old one is stopped.
func _replace(p_card: Card, face_up: bool) -> bool:
	var changed := p_card != card
	if changed:
		# A new card (or an empty slot) replaces any faded-out one at full opacity.
		if _fade_tween:
			_fade_tween.kill()
		if _pop_tween:
			_pop_tween.kill()
		_land()
		scale = Vector2.ONE
		self_modulate = Color.WHITE
	card = p_card
	_face_up = face_up
	queue_redraw()
	return changed


## Quickly fades the card out (end of a hand), keeping it set until it's replaced or cleared.
## Uses self_modulate, so the seat's own modulate (e.g. folded cards) is left alone.
func fade_out() -> void:
	if card == null or not is_inside_tree():
		return
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "self_modulate:a", 0.0, FADE_SECONDS) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## After [param delay] seconds (hidden till then), moves the card to [param from] and glides it
## back to its place.
func _fly_in(delay: float, from: Vector2) -> void:
	if not is_inside_tree():
		return
	_home = position
	_flying = true
	var start := position + get_global_transform().affine_inverse() * from - size / 2
	self_modulate.a = 0
	_pop_tween = create_tween()
	_pop_tween.tween_interval(delay)
	_pop_tween.tween_callback(func() -> void:
		self_modulate.a = 1
		position = start
		z_index = maxi(FLY_Z, resting_z))
	_pop_tween.tween_property(self, "position", _home, FLY_SECONDS) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_pop_tween.tween_callback(_land)


## Puts a flying card straight back in its place.
func _land() -> void:
	if not _flying:
		return
	_flying = false
	position = _home
	z_index = resting_z


## After [param delay] seconds (hidden till then), starts the card at [constant POP_SCALE] and
## shrinks it to its final size, from its centre.
func _pop_in(delay: float) -> void:
	if not is_inside_tree():
		return
	pivot_offset = size / 2
	_pop_tween = create_tween()
	if delay > 0:
		self_modulate.a = 0
		_pop_tween.tween_interval(delay)
	_pop_tween.tween_callback(func() -> void:
		self_modulate.a = 1
		scale = Vector2.ONE * POP_SCALE)
	_pop_tween.tween_property(self, "scale", Vector2.ONE, POP_SECONDS) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Winning cards lift and get a bright double gold outline; kickers stay put with a faint
## single outline; dimmed cards are shaded.
func set_highlight(highlight: Highlight) -> void:
	_highlight = highlight
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, CARD_SIZE)
	if card == null:
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE * pixel_scale)
		_draw_empty_slot(rect)
		return
	var lift := -3.0 * pixel_scale if _highlight == Highlight.WINNING else 0.0
	_set_card_transform(lift, pixel_scale)

	# At 2x and up there's room for finer art: draw it on a grid twice as dense.
	var fine := pixel_scale % 2 == 0
	if fine:
		@warning_ignore("integer_division")
		_set_card_transform(lift, pixel_scale / 2)
		_draw_fine_card(Rect2(Vector2.ZERO, CARD_SIZE * 2))
		_set_card_transform(lift, pixel_scale)
	else:
		_draw_card(rect)
	if sword and _face_up:
		var origin := ((CARD_SIZE - Vector2(SWORD[0].length(), SWORD.size())) / 2).floor()
		PixelArt.draw_colored(self, SWORD, SWORD_COLORS, origin, 1)

	if _highlight == Highlight.WINNING:
		draw_rect(rect.grow(1), PixelArt.GOLD, false, 1)
		draw_rect(rect.grow(2), Color(PixelArt.GOLD, 0.4), false, 1)
	elif _highlight == Highlight.KICKER:
		draw_rect(rect.grow(1), Color(PixelArt.GOLD, 0.45), false, 1)
	elif _highlight == Highlight.DIMMED:
		draw_rect(rect, Color(0.05, 0.05, 0.1, 0.5))


## Draws from here on at [param art_scale] screen pixels per art pixel, raised by [param lift],
## plus the sway's bob and tilt (about the card's centre) if it's swaying.
func _set_card_transform(lift: float, art_scale: float) -> void:
	var offset := Vector2(0, lift)
	var tilt := 0.0
	if sway:
		offset.y += sin(_sway_time * TAU / SWAY_BOB_SECONDS) * SWAY_BOB
		tilt = sin(_sway_time * TAU / SWAY_TILT_SECONDS) * SWAY_TILT
	var center := size / 2
	draw_set_transform(offset + center - center.rotated(tilt), tilt, Vector2.ONE * art_scale)


func _draw_empty_slot(rect: Rect2) -> void:
	if not show_empty_slot:
		return
	draw_rect(rect, Color(0, 0, 0, 0.25))
	var trim := InterfaceStyle.current.trim
	draw_rect(rect, Color(trim, 0.18), false, 1)
	Ornament.draw_corner_brackets(self, rect, Color(trim, 0.5), 3)
	Ornament.draw_diamond(self, (rect.get_center() - Vector2.ONE * 0.5).floor(), 2, Color(trim, 0.15))


func _draw_card(rect: Rect2) -> void:
	draw_rect(rect, PixelArt.INK)
	var inner := rect.grow(-1)
	if not _face_up:
		# A gilt-edged back: a light inner border round a trellis, with a gem in the middle.
		var style := InterfaceStyle.current
		draw_rect(inner, style.card_back)
		var frame := rect.grow(-2)
		draw_rect(frame, style.card_back_light, false, 1)
		for y in range(int(frame.position.y) + 2, int(frame.end.y) - 2):
			for x in range(int(frame.position.x) + 2, int(frame.end.x) - 2):
				if (x + y) % 4 == 0 and (x - y) % 4 == 0:
					draw_rect(Rect2(x, y, 1, 1), style.card_back_light)
		Ornament.draw_corner_brackets(self, frame, style.trim, 2)
		var centre := (rect.get_center() - Vector2.ONE * 0.5).floor()
		Ornament.draw_diamond(self, centre, 4, style.card_back)
		Ornament.draw_gem(self, centre, 2)
		return

	draw_rect(inner, PixelArt.PAPER)
	var color := PixelArt.RED if card.is_red() else PixelArt.INK
	var suit: Array = PixelArt.SUITS[card.suit]
	PixelArt.draw_text(self, card.rank_name(), Vector2(3, 3), 2, color)
	PixelArt.draw(self, suit, Vector2(3, 15), 1, color)
	PixelArt.draw(self, suit, Vector2(11, 20), 2, color)


## The same card on a 52x72 grid: rounded corners, a shaded edge, bold 5x7 ranks and finer suits.
func _draw_fine_card(rect: Rect2) -> void:
	_fill_rounded(rect, PixelArt.INK)
	var inner := rect.grow(-1)
	if not _face_up:
		# A gilt frame round a fine trellis, gold brackets in its corners and a jewelled
		# medallion in the middle.
		var style := InterfaceStyle.current
		_fill_rounded(inner, style.card_back)
		var gilt := rect.grow(-3)
		draw_rect(gilt, style.trim_dark, false, 1)
		draw_rect(Rect2(gilt.position, Vector2(gilt.size.x - 1, 1)), style.trim)
		draw_rect(Rect2(gilt.position, Vector2(1, gilt.size.y - 1)), style.trim)
		var frame := gilt.grow(-2)
		draw_rect(frame, style.card_back_light, false, 1)
		for y in range(int(frame.position.y) + 2, int(frame.end.y) - 2):
			for x in range(int(frame.position.x) + 2, int(frame.end.x) - 2):
				if (x + y) % 6 == 0 or (x - y) % 6 == 0:
					draw_rect(Rect2(x, y, 1, 1), style.card_back_light)
		Ornament.draw_corner_brackets(self, frame.grow(-2), style.trim, 4)
		var centre := (rect.get_center() - Vector2.ONE * 0.5).floor()
		Ornament.draw_diamond(self, centre, 9, style.card_back)
		Ornament.draw_diamond(self, centre, 8, PixelArt.INK)
		Ornament.draw_diamond(self, centre, 7, style.trim_dark)
		Ornament.draw_diamond(self, centre, 6, style.card_back)
		Ornament.draw_gem(self, centre, 3, style.card_back_gem)
		return

	_fill_rounded(inner, PixelArt.PAPER_SHADE)
	_fill_rounded(Rect2(inner.position, inner.size - Vector2.ONE), PixelArt.PAPER)
	var color := PixelArt.RED if card.is_red() else PixelArt.INK
	var suit := card.suit as int
	var origin := Vector2(4, 4)
	var rank_name := card.rank_name()
	for ch in rank_name:
		# Drawn twice, a pixel apart, for a bold stroke.
		PixelArt.draw(self, PixelArt.RANK_GLYPHS[ch], origin, 2, color)
		PixelArt.draw(self, PixelArt.RANK_GLYPHS[ch], origin + Vector2.RIGHT, 2, color)
		origin.x += 12
	PixelArt.draw(self, PixelArt.SUITS_SMALL[suit], Vector2(5 if rank_name.length() == 1 else 4, 21), 1, color)
	PixelArt.draw(self, PixelArt.SUITS_LARGE[suit], rect.end - Vector2(30, 30), 2, color)


## Fills [param rect] with its four corner pixels left out.
func _fill_rounded(rect: Rect2, color: Color) -> void:
	draw_rect(Rect2(rect.position.x + 1, rect.position.y, rect.size.x - 2, 1), color)
	draw_rect(Rect2(rect.position.x, rect.position.y + 1, rect.size.x, rect.size.y - 2), color)
	draw_rect(Rect2(rect.position.x + 1, rect.end.y - 1, rect.size.x - 2, 1), color)

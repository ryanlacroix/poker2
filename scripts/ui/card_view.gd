class_name CardView
extends Control
## Draws one card (face up, face down, or an empty slot) in pixel-art style.

enum Highlight { NONE, WINNING, KICKER, DIMMED }

const CARD_SIZE := Vector2(26, 36)

# A newly placed card pops in a little large, then quickly settles to its real size.
const POP_SCALE := 1.25
const POP_SECONDS := 0.15
## How long [method fade_out] takes.
const FADE_SECONDS := 0.2

var show_empty_slot := false
## Whole-number size multiplier; the pixel art is drawn scaled so it stays crisp. Set before adding.
var pixel_scale := 1
## The card shown, if any. Set with [method set_card].
var card: Card

var _face_up := false
var _highlight := Highlight.NONE
var _pop_tween: Tween
var _fade_tween: Tween


func _ready() -> void:
	custom_minimum_size = CARD_SIZE * pixel_scale
	size = CARD_SIZE * pixel_scale
	mouse_filter = MOUSE_FILTER_IGNORE


## A new card pops in after [param delay] seconds, hidden until then.
func set_card(p_card: Card, face_up: bool, delay := 0.0) -> void:
	if p_card != card:
		# A new card (or an empty slot) replaces any faded-out one at full opacity.
		if _fade_tween:
			_fade_tween.kill()
		if _pop_tween:
			_pop_tween.kill()
		scale = Vector2.ONE
		self_modulate = Color.WHITE
		if p_card != null:
			_pop_in(delay)
	card = p_card
	_face_up = face_up
	queue_redraw()


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
	var lift := -3.0 * pixel_scale if card != null and _highlight == Highlight.WINNING else 0.0
	draw_set_transform(Vector2(0, lift), 0, Vector2.ONE * pixel_scale)
	if card == null:
		_draw_empty_slot(rect)
		return

	# At 2x and up there's room for finer art: draw it on a grid twice as dense.
	var fine := pixel_scale % 2 == 0
	if fine:
		@warning_ignore("integer_division")
		draw_set_transform(Vector2(0, lift), 0, Vector2.ONE * (pixel_scale / 2))
		_draw_fine_card(Rect2(Vector2.ZERO, CARD_SIZE * 2))
		draw_set_transform(Vector2(0, lift), 0, Vector2.ONE * pixel_scale)
	else:
		_draw_card(rect)

	if _highlight == Highlight.WINNING:
		draw_rect(rect.grow(1), PixelArt.GOLD, false, 1)
		draw_rect(rect.grow(2), Color(PixelArt.GOLD, 0.4), false, 1)
	elif _highlight == Highlight.KICKER:
		draw_rect(rect.grow(1), Color(PixelArt.GOLD, 0.45), false, 1)
	elif _highlight == Highlight.DIMMED:
		draw_rect(rect, Color(0.05, 0.05, 0.1, 0.5))


func _draw_empty_slot(rect: Rect2) -> void:
	if not show_empty_slot:
		return
	draw_rect(rect, Color(0, 0, 0, 0.25))
	draw_rect(rect, Color(1, 1, 1, 0.15), false, 1)


func _draw_card(rect: Rect2) -> void:
	draw_rect(rect, PixelArt.INK)
	var inner := rect.grow(-1)
	if not _face_up:
		draw_rect(inner, PixelArt.BACK)
		for y in range(3, int(CARD_SIZE.y) - 3, 2):
			for x in range(3, int(CARD_SIZE.x) - 3, 2):
				if (x + y) % 4 == 0:
					draw_rect(Rect2(x, y, 1, 1), PixelArt.BACK_LIGHT)
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
		_fill_rounded(inner, PixelArt.BACK)
		var frame := rect.grow(-3)
		draw_rect(frame, PixelArt.BACK_LIGHT, false, 1)
		for y in range(int(frame.position.y) + 2, int(frame.end.y) - 2):
			for x in range(int(frame.position.x) + 2, int(frame.end.x) - 2):
				if (x + y) % 6 == 0 or (x - y) % 6 == 0:
					draw_rect(Rect2(x, y, 1, 1), PixelArt.BACK_LIGHT)
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

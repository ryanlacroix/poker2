class_name ChipPileView
extends Control
## A pixel-art pile of chips sitting on the felt beside a seat, drawn at a whole-number
## [constant PIXEL_SCALE] so the art stays crisp. The pile grows (logarithmically) with
## [member amount] up to three stacks of five; chip colours follow standard denominations.
## The node's position is the base centre of the pile.

const CHIP_WIDTH := 8
const CHIP_HEIGHT := 2
const CHIPS_PER_COLUMN := 5
const MAX_CHIPS := 15
## Pixel-art scale of the chips and of the amount label's digits.
const PIXEL_SCALE := 2
const LABEL_Y := 6 # top of the digits, below the chips

# Base offset of each column (unscaled), in fill order: two in front, one behind (drawn first).
const COLUMN_OFFSETS: Array[Vector2i] = [Vector2i(-4, 0), Vector2i(5, 0), Vector2i(0, -4)]

# Value, body colour, stripe colour.
const DENOMINATIONS := [
	[500, Color("7a3ab0"), PixelArt.PAPER],
	[100, Color("2a2a34"), PixelArt.PAPER],
	[25, Color("2f9a4a"), PixelArt.PAPER],
	[5, Color("c0303a"), PixelArt.PAPER],
	[1, Color("e8e8e8"), Color("c0303a")],
]

## Draw the amount in pixel digits under the pile.
var show_label := true

var amount := 0:
	set(value):
		if value == amount:
			return
		amount = value
		_rebuild()
		queue_redraw()

var _chips: Array[int] = [] # denomination index per chip, bottom-up


## Area the largest pile can cover (plus its label), relative to the node's position.
static func bounds_for(with_label: bool) -> Rect2:
	# Unscaled chips span x -9..11 (outline + shadow), y -16..2.
	var chips := Rect2(-9 * PIXEL_SCALE, -16 * PIXEL_SCALE, 20 * PIXEL_SCALE, 18 * PIXEL_SCALE)
	# Label: up to 4 digits of 3x5 glyphs (4px advance) at PIXEL_SCALE, plus a 2px backing.
	var label_width := (4 * 4 - 1) * PIXEL_SCALE + 4.0
	return chips.merge(Rect2(-label_width / 2, LABEL_Y - 2, label_width, 5 * PIXEL_SCALE + 4)) if with_label else chips


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func _rebuild() -> void:
	_chips.clear()
	if amount <= 0:
		return

	# Real chips the amount breaks into, highest value first...
	var exact: Array[int] = []
	var rest := amount
	for d in DENOMINATIONS.size():
		var value: int = DENOMINATIONS[d][0]
		while rest >= value:
			exact.append(d)
			rest -= value

	# ...resampled to a chip count that keeps growing with the amount but stays compact
	# (10 -> 2 chips, 100 -> 7, 1000 -> 12, 7000 -> 15).
	var count := clampi(roundi(2.2 * log(amount / 5.0 + 1)), 1, MAX_CHIPS)
	for i in count:
		@warning_ignore("integer_division")
		_chips.append(exact[i * exact.size() / count])


func _draw() -> void:
	if _chips.is_empty():
		return

	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE * PIXEL_SCALE)
	@warning_ignore("integer_division")
	var columns := (_chips.size() + CHIPS_PER_COLUMN - 1) / CHIPS_PER_COLUMN
	var order: Array[int] = []
	for c in columns:
		order.append(c)
	# Back to front (ties keep fill order).
	order.sort_custom(func(a: int, b: int) -> bool:
		return COLUMN_OFFSETS[a].y < COLUMN_OFFSETS[b].y or (COLUMN_OFFSETS[a].y == COLUMN_OFFSETS[b].y and a < b))

	for c in order:
		var start := c * CHIPS_PER_COLUMN
		var height := mini(CHIPS_PER_COLUMN, _chips.size() - start)
		_draw_column(COLUMN_OFFSETS[c], _chips.slice(start, start + height))

	draw_set_transform(Vector2.ZERO)
	if show_label:
		_draw_amount()


func _draw_column(base_offset: Vector2i, chips: Array[int]) -> void:
	@warning_ignore("integer_division")
	var x := base_offset.x - CHIP_WIDTH / 2
	var bottom := base_offset.y # y of the bottom chip's lowest pixel row
	var top := bottom - chips.size() * CHIP_HEIGHT - 1

	# Shadow on the felt, then a dark outline around the whole column.
	draw_rect(Rect2(x, bottom + 1, CHIP_WIDTH + 1, 1), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(x - 1, top - 1, CHIP_WIDTH + 2, bottom - top + 2), PixelArt.INK)

	for i in chips.size():
		var body: Color = DENOMINATIONS[chips[i]][1]
		var stripe: Color = DENOMINATIONS[chips[i]][2]
		var y := bottom - (i + 1) * CHIP_HEIGHT + 1
		draw_rect(Rect2(x, y, CHIP_WIDTH, 1), body)
		draw_rect(Rect2(x, y + 1, CHIP_WIDTH, 1), body.darkened(0.35))
		draw_rect(Rect2(x + 2, y, 1, 1), stripe)
		draw_rect(Rect2(x + 5, y, 1, 1), stripe)

	# Top face of the top chip.
	var top_body: Color = DENOMINATIONS[chips[-1]][1]
	draw_rect(Rect2(x, top, CHIP_WIDTH, 1), top_body.lightened(0.25))
	draw_rect(Rect2(x + 3, top, 2, 1), DENOMINATIONS[chips[-1]][2])


func _draw_amount() -> void:
	var text := str(amount)
	var width := (text.length() * 4 - 1) * PIXEL_SCALE
	@warning_ignore("integer_division")
	var origin := Vector2(-width / 2, LABEL_Y)
	draw_rect(Rect2(origin - Vector2.ONE * 2, Vector2(width + 4, 5 * PIXEL_SCALE + 4)), Color(0, 0, 0, 0.45))
	PixelArt.draw_text(self, text, origin, PIXEL_SCALE, PixelArt.GOLD)

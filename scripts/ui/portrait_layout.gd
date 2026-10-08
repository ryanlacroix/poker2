class_name PortraitLayout
extends RefCounted
## Where everything goes on a portrait (phone) screen. Top: NPCs stacked closely in a column down
## each screen edge, with their chips beside them. Below: the board, drawn large. Bottom: the
## human's seat in the bottom-right corner, with the action panel beside it. Designed on a 360x640 base; extra height goes
## to the board area, extra width widens the table. Safe-area insets keep clear of notches and
## gesture bars.

## A seat (top-left corner + style) and where its stack/bet piles sit on the table.
class SeatSlot:
	var seat_position: Vector2
	var style: SeatView.Style
	var pile_center: Vector2
	var vertical_piles: bool

	func _init(p_seat_position: Vector2, p_style: SeatView.Style, p_pile_center: Vector2, p_vertical_piles: bool) -> void:
		seat_position = p_seat_position
		style = p_style
		pile_center = p_pile_center
		vertical_piles = p_vertical_piles


const BASE_SIZE := Vector2(360, 640)

const MAX_OPPONENTS := 6
const MARGIN := 4.0
const ROW_GAP := 3.0

# Action panel: big, well-spaced touch targets (FOLD, CALL, raise slider, RAISE).
const ACTION_PADDING := 6.0
const ACTION_GAP := 8.0
const ACTION_BUTTON_HEIGHT := 36.0
const ACTION_SLIDER_HEIGHT := 24.0
const ACTION_PANEL_HEIGHT := ACTION_PADDING * 2 + ACTION_BUTTON_HEIGHT * 3 + ACTION_SLIDER_HEIGHT + ACTION_GAP * 3

## NEXT HAND button, sized like the action buttons.
const NEXT_HAND_SIZE := Vector2(140, ACTION_BUTTON_HEIGHT)
const BOARD_CARD_SCALE := 2
const BOARD_CARD_GAP := 6.0

# Slots are numbered clockwise from the human (bottom right): left column bottom to top,
# then right column top to bottom. These pick a balanced set for 1..6 opponents.
const SLOTS_FOR_COUNT := [
	[1],
	[1, 4],
	[0, 2, 4],
	[0, 2, 3, 5],
	[0, 1, 2, 3, 5],
	[0, 1, 2, 3, 4, 5],
]

var table: Rect2
## Top-left of the first (large) board card.
var board_origin: Vector2
## Centre of the pot label / NEXT HAND button, just under the board.
var pot_center: Vector2
var opponents: Array[SeatSlot] = []
var human: SeatSlot
var debug_button: Rect2
var action_bar: Rect2


func _init(viewport: Vector2, opponent_count: int, safe_top := 0.0, safe_bottom := 0.0) -> void:
	assert(opponent_count >= 1 and opponent_count <= MAX_OPPONENTS,
		"the table seats 1-%d opponents" % MAX_OPPONENTS)

	var compact := SeatView.COMPACT_SIZE
	var wide := SeatView.WIDE_SIZE
	var top := safe_top + 2 # the DEBUG button sits between the columns, not above them
	var row_y: Array[float] = [top, top + compact.y + ROW_GAP, top + (compact.y + ROW_GAP) * 2]
	var npc_bottom := row_y[2] + compact.y

	# Columns hug the screen edges; each NPC's piles sit on the table right beside them.
	var left_x := MARGIN
	var right_x := viewport.x - MARGIN - compact.x
	var bounds := TableScene.vertical_pile_unit_bounds()
	var left_pile_x := left_x + compact.x + 4 - bounds.position.x
	var right_pile_x := right_x - 4 - bounds.end.x
	var pile_dy := 2 - bounds.position.y # unit top level with the portrait

	var slots: Array[SeatSlot] = []
	slots.resize(6)
	for row in 3:
		slots[2 - row] = SeatSlot.new(Vector2(left_x, row_y[row]), SeatView.Style.COMPACT_LEFT,
			Vector2(left_pile_x, row_y[row] + pile_dy), true)
		slots[3 + row] = SeatSlot.new(Vector2(right_x, row_y[row]), SeatView.Style.COMPACT_RIGHT,
			Vector2(right_pile_x, row_y[row] + pile_dy), true)
	for i: int in SLOTS_FOR_COUNT[opponent_count - 1]:
		opponents.append(slots[i])

	# Bottom: human seat in the corner with their piles on the table edge just above it;
	# the (taller) action panel to its left, overlapping the table's corner while shown.
	var bottom := viewport.y - safe_bottom - MARGIN
	var human_seat := Vector2(viewport.x - MARGIN - wide.x, bottom - wide.y)
	action_bar = Rect2(MARGIN, bottom - ACTION_PANEL_HEIGHT, viewport.x - wide.x - MARGIN * 3, ACTION_PANEL_HEIGHT)
	table = Rect2(2, top - 2, viewport.x - 4, human_seat.y - 2 - (top - 2))

	var pair_bounds := TableScene.horizontal_pile_unit_bounds()
	var human_piles := Vector2(viewport.x - MARGIN - 4 - pair_bounds.end.x, table.end.y - 2 - pair_bounds.end.y)
	human = SeatSlot.new(human_seat, SeatView.Style.WIDE, human_piles, false)

	# Large board centred in the space between the NPCs and the bottom, with the
	# pot / NEXT HAND button under it, kept clear of the action panel and the human's piles.
	var card := CardView.CARD_SIZE * BOARD_CARD_SCALE
	var board_width := card.x * 5 + BOARD_CARD_GAP * 4
	var area_top := npc_bottom + 6 # room for winning cards to lift
	var area_bottom := minf(action_bar.position.y, human_piles.y + pair_bounds.position.y) - 4
	var block_height := card.y + 6 + NEXT_HAND_SIZE.y
	var board_y := floorf(area_top + maxf(0, area_bottom - area_top - block_height) / 2)
	board_origin = Vector2(floorf((viewport.x - board_width) / 2), board_y)
	pot_center = Vector2(floorf(viewport.x / 2), board_y + card.y + 6 + NEXT_HAND_SIZE.y / 2)

	# DEBUG: top centre, in the gap between the two columns of chip piles.
	debug_button = Rect2(floorf(viewport.x / 2) - 26, top, 52, 26)


## Safe-area insets (x = top, y = bottom) in viewport units; zero except on phones.
static func safe_insets(viewport: Viewport) -> Vector2:
	if not OS.has_feature("mobile"):
		return Vector2.ZERO
	var screen := DisplayServer.screen_get_size()
	var safe := DisplayServer.get_display_safe_area()
	var scale := screen.y / viewport.get_visible_rect().size.y
	return Vector2(safe.position.y / scale, (screen.y - safe.end.y) / scale)

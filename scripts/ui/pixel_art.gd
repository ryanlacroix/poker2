class_name PixelArt
extends RefCounted
## Tiny bitmap glyphs drawn with draw_rect, so cards stay crisp without any image assets.
## Swap these for real sprites in assets/sprites/ whenever you like.

const INK := Color("1b1b2a")
const PAPER := Color("f4f1e8")
const PAPER_SHADE := Color("d8d2c4")
const RED := Color("c0303a")
const BACK := Color("3050a0")
const BACK_LIGHT := Color("5078c8")
const GOLD := Color("f0c040")

# Indexed by Suit: Clubs, Diamonds, Hearts, Spades.
const SUITS := [
	["..XXX..", "..XXX..", "XXXXXXX", "XXXXXXX", "XX.X.XX", "...X...", "..XXX.."],
	["...X...", "..XXX..", ".XXXXX.", "XXXXXXX", ".XXXXX.", "..XXX..", "...X..."],
	[".......", ".XX.XX.", "XXXXXXX", "XXXXXXX", ".XXXXX.", "..XXX..", "...X..."],
	["...X...", "..XXX..", ".XXXXX.", "XXXXXXX", "XXXXXXX", "...X...", "..XXX.."],
]

# Finer card art for cards drawn at 2x and up, on a grid twice as dense as SUITS above.
# Indexed by Suit: small pips sit under the rank, large ones fill the bottom-right corner.
const SUITS_SMALL := [
	# Clubs
	[
		"...XXX...",
		"..XXXXX..",
		"..XXXXX..",
		"XX.XXX.XX",
		"XXXXXXXXX",
		"XXXXXXXXX",
		"XX..X..XX",
		"....X....",
		"...XXX...",
	],
	# Diamonds
	[
		"....X....",
		"...XXX...",
		"...XXX...",
		"..XXXXX..",
		".XXXXXXX.",
		"..XXXXX..",
		"...XXX...",
		"...XXX...",
		"....X....",
	],
	# Hearts
	[
		".XX...XX.",
		"XXXX.XXXX",
		"XXXXXXXXX",
		"XXXXXXXXX",
		".XXXXXXX.",
		"..XXXXX..",
		"...XXX...",
		"....X....",
	],
	# Spades
	[
		"....X....",
		"...XXX...",
		"..XXXXX..",
		".XXXXXXX.",
		"XXXXXXXXX",
		"XXXXXXXXX",
		".XX.X.XX.",
		"....X....",
		"...XXX...",
	],
]

const SUITS_LARGE := [
	# Clubs
	[
		".....XXX.....",
		"....XXXXX....",
		"...XXXXXXX...",
		"...XXXXXXX...",
		"....XXXXX....",
		".XXX.XXX.XXX.",
		"XXXXXXXXXXXXX",
		"XXXXXXXXXXXXX",
		"XXXXXXXXXXXXX",
		".XXX.XXX.XXX.",
		".....XXX.....",
		"....XXXXX....",
		"...XXXXXXX...",
	],
	# Diamonds
	[
		"......X......",
		".....XXX.....",
		"....XXXXX....",
		"....XXXXX....",
		"...XXXXXXX...",
		"..XXXXXXXXX..",
		".XXXXXXXXXXX.",
		"..XXXXXXXXX..",
		"...XXXXXXX...",
		"....XXXXX....",
		"....XXXXX....",
		".....XXX.....",
		"......X......",
	],
	# Hearts
	[
		".XXXX...XXXX.",
		"XXXXXX.XXXXXX",
		"XXXXXXXXXXXXX",
		"XXXXXXXXXXXXX",
		"XXXXXXXXXXXXX",
		".XXXXXXXXXXX.",
		".XXXXXXXXXXX.",
		"..XXXXXXXXX..",
		"...XXXXXXX...",
		"....XXXXX....",
		".....XXX.....",
		".....XXX.....",
		"......X......",
	],
	# Spades
	[
		"......X......",
		".....XXX.....",
		"....XXXXX....",
		"...XXXXXXX...",
		"..XXXXXXXXX..",
		".XXXXXXXXXXX.",
		"XXXXXXXXXXXXX",
		"XXXXXXXXXXXXX",
		"XXXXXXXXXXXXX",
		".XXXX.X.XXXX.",
		"......X......",
		".....XXX.....",
		"...XXXXXXX...",
	],
]

# 5x7 rank glyphs for the finer card art.
const RANK_GLYPHS := {
	"A": [".XXX.", "X...X", "X...X", "XXXXX", "X...X", "X...X", "X...X"],
	"K": ["X...X", "X..X.", "X.X..", "XX...", "X.X..", "X..X.", "X...X"],
	"Q": [".XXX.", "X...X", "X...X", "X...X", "X.X.X", "X..X.", ".XX.X"],
	"J": ["..XXX", "...X.", "...X.", "...X.", "...X.", "X..X.", ".XX.."],
	"0": [".XXX.", "X...X", "X...X", "X...X", "X...X", "X...X", ".XXX."],
	"1": ["..X..", ".XX..", "..X..", "..X..", "..X..", "..X..", ".XXX."],
	"2": [".XXX.", "X...X", "....X", "...X.", "..X..", ".X...", "XXXXX"],
	"3": ["XXXXX", "...X.", "..X..", "...X.", "....X", "X...X", ".XXX."],
	"4": ["...X.", "..XX.", ".X.X.", "X..X.", "XXXXX", "...X.", "...X."],
	"5": ["XXXXX", "X....", "XXXX.", "....X", "....X", "X...X", ".XXX."],
	"6": ["..XX.", ".X...", "X....", "XXXX.", "X...X", "X...X", ".XXX."],
	"7": ["XXXXX", "....X", "...X.", "..X..", ".X...", ".X...", ".X..."],
	"8": [".XXX.", "X...X", "X...X", ".XXX.", "X...X", "X...X", ".XXX."],
	"9": [".XXX.", "X...X", "X...X", ".XXXX", "....X", "...X.", ".XX.."],
}

# Dollar sign (10x12), stamped on the portrait of a player who went broke.
const DOLLAR_SIGN: Array[String] = [
	"....XX....",
	".XXXXXXXX.",
	"XXXXXXXXXX",
	"XX..XX....",
	"XX..XX....",
	"XXXXXXXXX.",
	".XXXXXXXXX",
	"....XX..XX",
	"....XX..XX",
	"XXXXXXXXXX",
	".XXXXXXXX.",
	"....XX....",
]

const HEART: Array[String] = [".XX.XX.", "XXXXXXX", "XXXXXXX", ".XXXXX.", "..XXX..", "...X..."]
const HEART_RED := Color("e03848")
const HEART_EMPTY := Color("3a3448")

# 3x5 glyphs for card ranks plus "D" for the dealer button.
const GLYPHS := {
	"A": [".X.", "X.X", "XXX", "X.X", "X.X"],
	"K": ["X.X", "X.X", "XX.", "X.X", "X.X"],
	"Q": [".X.", "X.X", "X.X", "XX.", ".XX"],
	"J": ["..X", "..X", "..X", "X.X", ".X."],
	"D": ["XX.", "X.X", "X.X", "X.X", "XX."],
	"0": ["XXX", "X.X", "X.X", "X.X", "XXX"],
	"1": [".X.", "XX.", ".X.", ".X.", "XXX"],
	"2": ["XXX", "..X", "XXX", "X..", "XXX"],
	"3": ["XXX", "..X", "XXX", "..X", "XXX"],
	"4": ["X.X", "X.X", "XXX", "..X", "..X"],
	"5": ["XXX", "X..", "XXX", "..X", "XXX"],
	"6": ["XXX", "X..", "XXX", "X.X", "XXX"],
	"7": ["XXX", "..X", "..X", "..X", "..X"],
	"8": ["XXX", "X.X", "XXX", "X.X", "XXX"],
	"9": ["XXX", "X.X", "XXX", "..X", "XXX"],
}

# Side-view gun pointing right (28x16): K outline, L/G/g slide steel, D frame, B/b wooden grip.
const GUN: Array[String] = [
	"............................",
	"...KKKKKKKKKKKKKKKKKKKKKKK..",
	"...KLLLLLLLLLLLLLLLLLLLLLKK.",
	"...KGGGGGGGGGGGGKKKKGGGGGGKK",
	"...KGgGgGgGGGGGGKggKGGGGGGGK",
	"...KGgGgGgGGGGGGKKKKGGGGGGKK",
	"...KgggggggggggggggggggggKK.",
	"...KKKKKKKKKKKKKKKKKKKKKKK..",
	"....KDDDDDDKDDDDDDDDDDDK....",
	"...KBBBBBBKKKKKKKKKKKKK.....",
	"...KBbBBBBK..K...K..........",
	"..KBBBBbBBK..K..K...........",
	"..KBbBBBBBK...KK............",
	".KBBBBBbBK..................",
	".KBbBBBBBK..................",
	".KKKKKKKKK..................",
]

const GUN_COLORS := {
	"K": INK,
	"L": Color("f0f4fa"),
	"G": Color("aab4c4"),
	"g": Color("6e7888"),
	"B": Color("a8642e"),
	"b": Color("6a3c1c"),
	"D": Color("5a6478"),
}

# Small gun item icon (15x12), coloured with GUN_COLORS.
const GUN_ICON: Array[String] = [
	"KKKKKKKKKKKKKKK",
	"KLLLLLLLLLLLLLK",
	"KGGGGGGGGGGGGGK",
	"KGgGgGGGGGGGGGK",
	"KgggggggggggggK",
	"KKKKKKKKKKKKKKK",
	".KDDDDDDDDDDK..",
	".KBBBBKKKKKK...",
	".KBbBBK.K.K....",
	"KBBBBBK.KK.....",
	"KBbBBBK........",
	"KKKKKKK........",
]

# Small shield item icon (11x12): a steel heater shield with a red cross.
const SHIELD_ICON: Array[String] = [
	"KKKKKKKKKKK",
	"KLLLLRGGGGK",
	"KLLLLRGGGGK",
	"KRRRRRRRRRK",
	"KLLLLRGGGGK",
	"KLLLLRGGGGK",
	".KLLLRGGGK.",
	".KLLLRGGGK.",
	"..KLLRGGK..",
	"...KLRGK...",
	"....KRK....",
	".....K.....",
]

const SHIELD_COLORS := {
	"K": INK,
	"L": Color("d4dce8"),
	"G": Color("8a96aa"),
	"R": RED,
}

# Pot of gold (12x12): a dark cauldron heaped with coins; shown in place of the word "POT".
const POT_OF_GOLD: Array[String] = [
	"....YYYY....",
	"..YYWYYyYY..",
	".YYyYYYYWYY.",
	"KKKKKKKKKKKK",
	"KrrrrrrrrrrK",
	".KCCCCCCCCK.",
	"KChCCCCCCCCK",
	"KChCCCCCCCCK",
	"KCCCCCCCCCCK",
	".KCCCCCCCCK.",
	"..KKKKKKKK..",
	"..KK....KK..",
]

const POT_OF_GOLD_COLORS := {
	"Y": GOLD,
	"y": Color("c08a20"),
	"W": Color("fff6d0"),
	"K": INK,
	"r": Color("6a6a7c"),
	"C": Color("2e2e3c"),
	"h": Color("4a4a5c"),
}

const MUZZLE_FLASH: Array[String] = [
	"..Y.Y..",
	"...O...",
	"YOOWOOY",
	"...O...",
	"..Y.Y..",
]

const FLASH_COLORS := {
	"Y": GOLD,
	"O": Color("ff8a30"),
	"W": Color("fff6d0"),
}


## Draws a multi-colour pattern; characters missing from [param colors] are transparent.
static func draw_colored(canvas: CanvasItem, pattern: Array, colors: Dictionary, origin: Vector2, px: int) -> void:
	for y in pattern.size():
		var row: String = pattern[y]
		for x in row.length():
			var color: Variant = colors.get(row[x])
			if color != null:
				canvas.draw_rect(Rect2(origin + Vector2(x, y) * px, Vector2(px, px)), color)


## Fills every non-'.' cell of [param pattern] with one colour (a glyph or a silhouette).
static func draw(canvas: CanvasItem, pattern: Array, origin: Vector2, px: int, color: Color) -> void:
	for y in pattern.size():
		var row: String = pattern[y]
		for x in row.length():
			if row[x] != ".":
				canvas.draw_rect(Rect2(origin + Vector2(x, y) * px, Vector2(px, px)), color)


static func draw_text(canvas: CanvasItem, text: String, origin: Vector2, px: int, color: Color) -> void:
	for ch in text:
		if GLYPHS.has(ch):
			draw(canvas, GLYPHS[ch], origin, px, color)
		origin.x += 4 * px

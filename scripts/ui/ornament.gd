class_name Ornament
extends RefCounted
## Gilded pixel-art trim shared by the UI: framed nine-patch boxes, gold rules with diamond
## caps, corner brackets and a damask wallpaper. Everything is generated in code at 1px per
## texel, so it stays crisp at any integer scale.

const GOLD_LIGHT := Color("f8dc78")
const GOLD_DARK := Color("a0701c")
## Muted brass for quieter trim (seat frames, the action panel).
const BRASS := Color("b0904a")
const BRASS_DARK := Color("6a5228")
## Margin of the generated frame's corners: outline, gold line, inner outline, then the bracket.
const FRAME_MARGIN := 5


## A framed box: ink outline with cut corners, a bevelled gold line (light top/left, dark
## bottom/right), an inner ink line, a little gold bracket in each corner and a lit top edge on
## the [param fill]. As an 11x11 nine-patch texture.
static func frame_texture(fill: Color, light: Color, dark: Color, outline := PixelArt.INK) -> Texture2D:
	const SIZE := FRAME_MARGIN * 2 + 1
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in SIZE:
		for x in SIZE:
			var dx := mini(x, SIZE - 1 - x)
			var dy := mini(y, SIZE - 1 - y)
			var ring := mini(dx, dy)
			# Top/left edges catch the light; bottom/right sit in shadow.
			var lit := (y * 2 < SIZE - 1) if dy <= dx else (x * 2 < SIZE - 1)
			var color: Color
			if dx + dy < 2:
				continue # the cut corner
			elif ring == 0 or dx + dy == 2:
				color = outline
			elif ring == 1:
				color = light if lit else dark
			elif ring == 2:
				color = outline
			elif dx <= 4 and dy <= 4 and (dx == 3 or dy == 3) and dx + dy <= 7:
				color = light if lit else dark # corner bracket
			elif y == 3:
				color = fill.lightened(0.12) if fill.a > 0 else fill
			elif y == SIZE - 4:
				color = fill.darkened(0.2) if fill.a > 0 else fill
			else:
				color = fill
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)


static func frame_box(fill: Color, light: Color, dark: Color, margin_h := 6.0, margin_v := 4.0) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = frame_texture(fill, light, dark)
	box.set_texture_margin_all(FRAME_MARGIN)
	box.content_margin_left = margin_h
	box.content_margin_right = margin_h
	box.content_margin_top = margin_v
	box.content_margin_bottom = margin_v
	return box


## A solid pixel diamond of [param radius] centred on [param center].
static func draw_diamond(c: CanvasItem, center: Vector2, radius: int, color: Color) -> void:
	for i in range(-radius, radius + 1):
		var w := radius - absi(i)
		c.draw_rect(Rect2(center.x - w, center.y + i, w * 2 + 1, 1), color)


## A gem: a gold diamond outlined in ink, with a light glint.
static func draw_gem(c: CanvasItem, center: Vector2, radius: int, color := PixelArt.GOLD) -> void:
	draw_diamond(c, center, radius + 1, PixelArt.INK)
	draw_diamond(c, center, radius, color)
	if radius >= 2:
		c.draw_rect(Rect2(center + Vector2(-1, -radius + 1), Vector2.ONE), GOLD_LIGHT)


## A gold rule from [param from_x] to [param to_x] at row [param y] with a dark underline and a
## gem at each end (and one in the middle if [param middle_gem]).
static func draw_rule(c: CanvasItem, from_x: float, to_x: float, y: float, middle_gem := false) -> void:
	from_x = floorf(from_x)
	to_x = floorf(to_x)
	y = floorf(y)
	if to_x - from_x < 8:
		return
	c.draw_rect(Rect2(from_x, y - 1, to_x - from_x, 1), PixelArt.INK)
	c.draw_rect(Rect2(from_x, y, to_x - from_x, 1), PixelArt.GOLD)
	c.draw_rect(Rect2(from_x, y + 1, to_x - from_x, 1), GOLD_DARK)
	c.draw_rect(Rect2(from_x, y + 2, to_x - from_x, 1), PixelArt.INK)
	draw_gem(c, Vector2(from_x + 2, y), 2)
	draw_gem(c, Vector2(to_x - 3, y), 2)
	if middle_gem:
		draw_gem(c, Vector2(floorf((from_x + to_x) / 2), y), 3)


## Little L-shaped brackets just inside each corner of [param rect], [param length] long.
static func draw_corner_brackets(c: CanvasItem, rect: Rect2, color: Color, length := 4) -> void:
	var p := rect.position
	var e := rect.end - Vector2.ONE
	for corner: Vector2 in [p, Vector2(e.x, p.y), Vector2(p.x, e.y), e]:
		var sx := 1.0 if corner.x == p.x else -1.0
		var sy := 1.0 if corner.y == p.y else -1.0
		for i in length:
			c.draw_rect(Rect2(corner + Vector2(i * sx, 0), Vector2.ONE), color)
			c.draw_rect(Rect2(corner + Vector2(0, i * sy), Vector2.ONE), color)


## Damask wallpaper: [param base] with faint grain, a diamond trellis and a small fleuron in each
## cell, as a texture of [param size].
static func wallpaper(base: Color, size: Vector2i) -> Texture2D:
	const TILE := 24
	const H := 12 # half a tile
	var line := base.lightened(0.07)
	var shade := base.darkened(0.25)
	var motif := base.lightened(0.13)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var tile := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	tile.fill(base)
	for y in TILE:
		for x in TILE:
			var roll := rng.randf()
			if roll < 0.1:
				tile.set_pixel(x, y, base.darkened(0.1))
			elif roll < 0.16:
				tile.set_pixel(x, y, base.lightened(0.04))
	# Trellis: diagonals through the tile, each with a shadow pixel under it.
	for i in TILE:
		tile.set_pixel(i, (i + H) % TILE, line)
		tile.set_pixel(i, (H - i + TILE) % TILE, line)
		tile.set_pixel(i, (i + H + 1) % TILE, shade)
		tile.set_pixel(i, (H - i + 1 + TILE) % TILE, shade)
	# A fleuron (a little four-petal flower) in the middle of each trellis cell.
	for centre: Vector2i in [Vector2i(H, H), Vector2i(0, 0)]:
		for d: Vector2i in [Vector2i(0, -2), Vector2i(0, 2), Vector2i(-2, 0), Vector2i(2, 0),
				Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			var q := (centre + d + Vector2i(TILE, TILE)) % TILE
			tile.set_pixel(q.x, q.y, motif)
		tile.set_pixel(centre.x, centre.y, shade)
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in range(0, size.y, TILE):
		for x in range(0, size.x, TILE):
			image.blit_rect(tile, Rect2i(0, 0, TILE, TILE), Vector2i(x, y))
	return ImageTexture.create_from_image(image)


## A slider grabber: a faceted gold gem, [param radius] cells out from its centre.
static func gem_texture(radius: int, color := PixelArt.GOLD) -> Texture2D:
	var size := radius * 2 + 3
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var c := radius + 1
	for y in size:
		for x in size:
			var d := absi(x - c) + absi(y - c)
			if d > radius + 1:
				continue
			var color_here: Color = PixelArt.INK
			if d <= radius:
				color_here = GOLD_LIGHT if (y < c and x <= c) else (color if y <= c or x < c else GOLD_DARK)
				if d == 0:
					color_here = color
			image.set_pixel(x, y, color_here)
	return ImageTexture.create_from_image(image)

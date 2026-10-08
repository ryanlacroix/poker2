class_name GunView
extends Control
## The pixel-art gun floating in the middle of the screen while the human picks a target:
## large, with a pulsing halo so it stands out against the cards and felt. Bobs gently;
## [method fire] shows a muzzle flash and a little recoil.

const PIXEL_SCALE := 5
const FLASH_SCALE := 4
const MUZZLE_ROW := 4.5 # vertical centre of the barrel, in art pixels
const FLASH_SECONDS := 0.25
const HALO_OFFSETS: Array[Vector2] = [
	Vector2(-3, 0), Vector2(3, 0), Vector2(0, -3), Vector2(0, 3),
	Vector2(-2, -2), Vector2(2, -2), Vector2(-2, 2), Vector2(2, 2),
]

static var art_size := Vector2(PixelArt.GUN[0].length(), PixelArt.GUN.size()) * PIXEL_SCALE

var _fired_at := -1.0


func _ready() -> void:
	size = art_size
	mouse_filter = MOUSE_FILTER_IGNORE


func fire() -> void:
	_fired_at = Time.get_ticks_msec() / 1000.0
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var flashing := _fired_at >= 0 and now - _fired_at < FLASH_SECONDS
	var offset := Vector2(-PIXEL_SCALE, 0) if flashing \
		else Vector2(0, roundf(sin(now * 3.0) * 1.5) * 2) # recoil, or idle bob

	var pulse := 0.5 + 0.5 * sin(now * 6.0)

	# Pale-gold halo around the silhouette, then the gun itself.
	var halo := Color("ffe9a0", 0.45 + 0.4 * pulse)
	for d in HALO_OFFSETS:
		PixelArt.draw(self, PixelArt.GUN, offset + d, PIXEL_SCALE, halo)
	PixelArt.draw_colored(self, PixelArt.GUN, PixelArt.GUN_COLORS, offset, PIXEL_SCALE)

	if flashing:
		# Flash just past the muzzle.
		var flash_size := Vector2(PixelArt.MUZZLE_FLASH[0].length(), PixelArt.MUZZLE_FLASH.size()) * FLASH_SCALE
		var muzzle := offset + Vector2(PixelArt.GUN[0].length() * PIXEL_SCALE, MUZZLE_ROW * PIXEL_SCALE - flash_size.y / 2)
		PixelArt.draw_colored(self, PixelArt.MUZZLE_FLASH, PixelArt.FLASH_COLORS, muzzle, FLASH_SCALE)

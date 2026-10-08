#!/usr/bin/env python3
"""Generate the main-menu figure: a gambler holding up a playing card in one hand
and a pistol in the other, in shaded pixel art.

The figure is modelled as simple 3D shapes (ellipsoids and capsules) seen head-on,
rendered with a key light, a rim light, cast shadows and ambient occlusion, then
snapped to a small hand-picked colour ramp per material and outlined, so it reads
as pixel art rather than a downscaled render. Tweak the shapes or palettes below
and re-run:

    python3 tools/generate_menu_art.py

Requires Pillow. Writes assets/sprites/menu_gambler.png (96x144, transparent).
"""
import math
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "sprites" / "menu_gambler.png"

W, H = 96, 144
SUPERSAMPLE = 4
OUTLINE = (11, 10, 16)


def _hex(c):
    return tuple(int(c[i:i + 2], 16) for i in (1, 3, 5))


# Colour ramps, darkest to lightest. Shadows lean cool, highlights warm.
PALETTES = {k: [_hex(c) for c in v] for k, v in {
    "skin": ["#3b2420", "#6b3f30", "#a0634a", "#c98a68", "#e8b48a", "#f6d2b0"],
    "coat": ["#221f1c", "#3c342c", "#5c4c3c", "#806a52", "#a68a68", "#c8ac86"],
    "lapel": ["#14110e", "#251f19", "#382f25", "#4c4032", "#62533f"],
    "hat": ["#121016", "#1e1b24", "#2e2a36", "#433d4c", "#5c5468", "#776d84"],
    "band": ["#0c0a0e", "#16121a", "#5a1a22", "#7e2830"],
    "shirt": ["#4c4a58", "#7a7888", "#aeacba", "#d8d6e0", "#f2f1f6"],
    "tie": ["#2c0a10", "#561420", "#86202c", "#b0303c", "#cc4c52"],
    "pants": ["#121118", "#1e1c25", "#2e2b37", "#423e4c", "#585364"],
    "shoe": ["#0c0a0c", "#1c1514", "#30241f", "#4a3a30", "#6c5848"],
    "belt": ["#140f0c", "#2a2018", "#463624", "#665036"],
    "metal": ["#181b22", "#2c323c", "#465060", "#66727f", "#94a0b0", "#c8d2de", "#f0f4fa"],
    "grip": ["#1e100a", "#3a2012", "#5c361c", "#84502a", "#a46a38"],
    "card": ["#7c7a76", "#b0ada4", "#d8d4c8", "#efebe0", "#fcfaf4"],
}.items()}

# Lights (screen space: x right, y down, z toward the viewer).
def _norm(v):
    length = math.sqrt(sum(c * c for c in v))
    return tuple(c / length for c in v)


KEY = _norm((-0.5, -0.85, 0.5))       # key light from above on the left, slightly in front
RIM = _norm((0.95, -0.25, -0.15))     # cool rim light from behind on the right
HALF = _norm((KEY[0], KEY[1], KEY[2] + 1))  # for specular highlights (viewer looks down -z)
SHINY = {"metal": (40, 0.9), "card": (12, 0.15), "shoe": (18, 0.35), "band": (16, 0.3)}


# --- Shapes -------------------------------------------------------------------

class Ellipsoid:
    def __init__(self, center, radii, material):
        self.c, self.r, self.material = center, radii, material
        self.box = (center[0] - radii[0], center[1] - radii[1], center[0] + radii[0], center[1] + radii[1])

    def hit(self, x, y):
        cx, cy, cz = self.c
        rx, ry, rz = self.r
        dx, dy = (x - cx) / rx, (y - cy) / ry
        q = 1 - dx * dx - dy * dy
        if q <= 0:
            return None
        dz = math.sqrt(q)
        return cz + rz * dz, (dx / rx, dy / ry, dz / rz)


class Capsule:
    """A rounded limb from a to b, its radius tapering from ra to rb."""

    def __init__(self, a, b, ra, rb, material):
        self.a, self.b, self.ra, self.rb, self.material = a, b, ra, rb, material
        r = max(ra, rb)
        self.box = (min(a[0], b[0]) - r, min(a[1], b[1]) - r, max(a[0], b[0]) + r, max(a[1], b[1]) + r)
        self.d = (b[0] - a[0], b[1] - a[1], b[2] - a[2])
        self.len2 = self.d[0] ** 2 + self.d[1] ** 2 or 1e-9

    def hit(self, x, y):
        a, d = self.a, self.d
        t = max(0.0, min(1.0, ((x - a[0]) * d[0] + (y - a[1]) * d[1]) / self.len2))
        cx, cy, cz = a[0] + d[0] * t, a[1] + d[1] * t, a[2] + d[2] * t
        r = self.ra + (self.rb - self.ra) * t
        ox, oy = x - cx, y - cy
        h2 = r * r - ox * ox - oy * oy
        if h2 <= 0:
            return None
        h = math.sqrt(h2)
        return cz + h, (ox / r, oy / r, h / r)


class Slab:
    """A flat, bevelled rectangle facing the viewer (the playing card)."""

    def __init__(self, x0, y0, x1, y1, z, bevel, material):
        self.box, self.z, self.bevel, self.material = (x0, y0, x1, y1), z, bevel, material

    def hit(self, x, y):
        x0, y0, x1, y1 = self.box
        if not (x0 <= x <= x1 and y0 <= y <= y1):
            return None
        # Round off the corners.
        cr = 1.2
        qx, qy = max(x0 + cr - x, x - (x1 - cr), 0), max(y0 + cr - y, y - (y1 - cr), 0)
        if qx * qx + qy * qy > cr * cr:
            return None
        edge = min(x - x0, x1 - x, y - y0, y1 - y)
        n = (0.0, 0.0, 1.0)
        if edge < self.bevel:
            k = 1 - edge / self.bevel
            ex = -k if x - x0 == edge else k if x1 - x == edge else 0
            ey = -k if y - y0 == edge else k if y1 - y == edge else 0
            n = _norm((ex * 0.6, ey * 0.6, 1))
        return self.z, n


class Poly:
    """A flat, bevelled polygon facing the viewer (the pistol's profile).

    points are in the shape's own frame; it's rotated by angle (radians) about origin, then
    placed at offset."""

    def __init__(self, points, offset, angle, z, bevel, material):
        c, s = math.cos(angle), math.sin(angle)
        self.pts = [(offset[0] + x * c - y * s, offset[1] + x * s + y * c) for x, y in points]
        xs, ys = [p[0] for p in self.pts], [p[1] for p in self.pts]
        self.box = (min(xs), min(ys), max(xs), max(ys))
        self.z, self.bevel, self.material = z, bevel, material

    def hit(self, x, y):
        pts, inside, best, normal2d = self.pts, False, 1e9, (0.0, 0.0)
        for i in range(len(pts)):
            (x0, y0), (x1, y1) = pts[i], pts[(i + 1) % len(pts)]
            if (y0 > y) != (y1 > y) and x < x0 + (y - y0) * (x1 - x0) / (y1 - y0):
                inside = not inside
            ex, ey = x1 - x0, y1 - y0
            t = max(0.0, min(1.0, ((x - x0) * ex + (y - y0) * ey) / (ex * ex + ey * ey)))
            dx, dy = x - (x0 + ex * t), y - (y0 + ey * t)
            d = math.hypot(dx, dy)
            if d < best:
                best, normal2d = d, (-dx, -dy)
        if not inside:
            return None
        if best >= self.bevel:
            return self.z, (0.0, 0.0, 1.0)
        k = (1 - best / self.bevel) * 0.9 / max(1e-9, math.hypot(*normal2d))
        return self.z - (1 - best / self.bevel) * 0.5, _norm((normal2d[0] * k, normal2d[1] * k, 1))


class Region:
    """A shape whose material depends on where it's hit (e.g. shirt and tie on the coat)."""

    def __init__(self, shape, pick):
        self.shape, self.pick, self.box = shape, pick, shape.box
        self.material = shape.material

    def hit(self, x, y):
        return self.shape.hit(x, y)

    def material_at(self, x, y):
        return self.pick(x, y) or self.shape.material


def _coat_material(x, y):
    # A narrow V of shirt and tie under the collar, wide lapels either side, a belt at the
    # waist, and the coat's front split below it.
    dx = abs(x - 48)
    open_half = 1.5 + (y - 43) * 0.3
    if 43 <= y <= 60 and dx <= open_half:
        if 44.5 <= y <= 46.5 and dx <= 1.6:
            return "tie"  # knot
        if y > 46.5 and dx <= 1.0 + (y - 46.5) * 0.06:
            return "tie"
        return "shirt"
    if 42 <= y <= 66 and dx <= open_half + 4.5 - max(0.0, y - 58) * 0.55:
        return "lapel"
    if 79 <= y <= 82.5:
        return "belt"
    return None


def _hat_material(x, y):
    return "band" if 18.6 <= y <= 21.2 else None


# Viewer's left: his right arm, raised, holding the card beside his face.
# Viewer's right: his left arm, raised, pointing the pistol in the air.
# The pistol in its own frame: barrel along +x, grip hanging down (+y) from the back.
GUN_HAND = (75.0, 41.0)        # where his fist closes round the grip, clear of the hat brim
GUN_ANGLE = math.radians(-82)  # pointing up, tipped slightly outward
GUN_SCALE = 1.3
SLIDE = [(0, 0), (17, 0), (17, 3.6), (0, 3.6)]
FRAME = [(2, 3.4), (12, 3.4), (12, 5.2), (2, 5.2)]
GRIP = [(0.4, 3.4), (5.2, 3.4), (3.6, 11.5), (-1.6, 11.0)]
GUARD = [(5.0, 5.0), (10.0, 5.0), (9.2, 8.0), (6.4, 8.4), (5.6, 7.4)]
GRIP_MIDDLE = (2.0, 7.0)       # in the pistol's frame, before scaling


def _gun(points):
    return [(x * GUN_SCALE, y * GUN_SCALE) for x, y in points]


def _gun_origin():
    """Where the pistol's frame origin goes so the middle of the grip sits in his fist."""
    c, s = math.cos(GUN_ANGLE), math.sin(GUN_ANGLE)
    gx, gy = GRIP_MIDDLE[0] * GUN_SCALE, GRIP_MIDDLE[1] * GUN_SCALE
    return GUN_HAND[0] - (gx * c - gy * s), GUN_HAND[1] - (gx * s + gy * c)


GUN_AT = _gun_origin()

SHAPES = [
    # Legs and shoes (the legs sit behind the coat, showing below its hem).
    Capsule((42, 104, -3), (41, 133, 2), 5.4, 4.4, "pants"),
    Capsule((54, 104, -3), (55, 133, 2), 5.4, 4.4, "pants"),
    Ellipsoid((39.5, 137, 6), (6.2, 3.2, 5), "shoe"),
    Ellipsoid((56.5, 137, 6), (6.2, 3.2, 5), "shoe"),
    # Trench coat: a squared-off body, rounded at the edges, flaring into a long skirt.
    Region(Poly([(34, 44), (62, 44), (63.5, 60), (61.5, 82), (34.5, 82), (32.5, 60)], (0, 0), 0, 8, 6,
                "coat"), _coat_material),
    Region(Poly([(34.5, 79), (61.5, 79), (66, 116), (30, 116)], (0, 0), 0, 6.5, 5, "coat"), _coat_material),
    Region(Capsule((36, 47.5, 3), (60, 47.5, 3), 6.6, 6.6, "coat"), _coat_material),
    # Neck and head.
    Capsule((48, 36, 6), (48, 43, 7), 3.6, 3.8, "skin"),
    Ellipsoid((48, 31, 10), (7.2, 8.6, 7), "skin"),
    Ellipsoid((41, 31.5, 8), (1.4, 2.2, 1.2), "skin"),   # ears
    Ellipsoid((55, 31.5, 8), (1.4, 2.2, 1.2), "skin"),
    Ellipsoid((48, 32.5, 16.4), (1.5, 2.6, 1.6), "skin"),  # nose
    # Fedora crown: tapered sides, a flat top with a dent down the middle.
    Region(Poly([(39.5, 22), (56.5, 22), (54.5, 12.5), (51.5, 10.8), (48, 12.2), (44.5, 10.8), (41.5, 12.5)],
                (0, 0), 0, 11, 3.2, "hat"), _hat_material),
    Ellipsoid((48, 23.8, 12), (15.5, 1.9, 11.5), "hat"),  # brim
    # Card arm: upper arm out and down to the elbow, forearm back up to the face.
    Capsule((35, 49, 4), (26, 66, 7), 6, 5, "coat"),
    Capsule((26, 66, 7), (28.5, 47, 13), 5, 4.2, "coat"),
    Ellipsoid((28.5, 46.5, 13), (4.6, 2.2, 4), "shirt"),  # cuff
    Slab(21.5, 25, 35.5, 44, 15, 1.2, "card"),
    Ellipsoid((29.5, 42.5, 16), (4.2, 3.6, 3.4), "skin"),  # fingers over the card
    Ellipsoid((32.8, 39.5, 16.5), (1.5, 2.6, 1.4), "skin"),  # thumb
    # Gun arm: the card arm's mirror image, the fist level with his chin.
    Capsule((61, 49, 4), (76, 63, 7), 6, 5, "coat"),
    Capsule((76, 63, 7), (75, 47, 13), 5, 4.2, "coat"),
    Ellipsoid((75, 46.5, 13), (4.6, 2.2, 4), "shirt"),  # cuff
    # Pistol: slide pointing up, frame, raked grip, trigger guard.
    Poly(_gun(SLIDE), GUN_AT, GUN_ANGLE, 18, 1.1, "metal"),
    Poly(_gun(FRAME), GUN_AT, GUN_ANGLE, 17.6, 0.9, "metal"),
    Poly(_gun(GUARD), GUN_AT, GUN_ANGLE, 17.4, 0.9, "metal"),
    Poly(_gun(GRIP), GUN_AT, GUN_ANGLE, 17.8, 1.2, "grip"),
    Ellipsoid((GUN_HAND[0], GUN_HAND[1] + 1, 20), (3.8, 4.2, 3.2), "skin"),  # fist round the grip
]


# --- Rendering ----------------------------------------------------------------

def render_samples():
    """Per supersample: (z, normal, material) of the front-most shape, or None."""
    sw, sh = W * SUPERSAMPLE, H * SUPERSAMPLE
    buf = [None] * (sw * sh)
    for shape in SHAPES:
        x0, y0, x1, y1 = shape.box
        for sy in range(max(0, int(y0 * SUPERSAMPLE) - 1), min(sh, int(y1 * SUPERSAMPLE) + 2)):
            y = (sy + 0.5) / SUPERSAMPLE
            for sx in range(max(0, int(x0 * SUPERSAMPLE) - 1), min(sw, int(x1 * SUPERSAMPLE) + 2)):
                x = (sx + 0.5) / SUPERSAMPLE
                hit = shape.hit(x, y)
                if hit is None:
                    continue
                i = sy * sw + sx
                if buf[i] is None or hit[0] > buf[i][0]:
                    material = shape.material_at(x, y) if isinstance(shape, Region) else shape.material
                    buf[i] = (hit[0], hit[1], material)
    return buf


def resolve(buf):
    """Collapse supersamples to art pixels: majority material, averaged depth and normal."""
    sw = W * SUPERSAMPLE
    pixels = [None] * (W * H)
    half = SUPERSAMPLE * SUPERSAMPLE / 2
    for py in range(H):
        for px in range(W):
            groups = {}
            for sy in range(py * SUPERSAMPLE, (py + 1) * SUPERSAMPLE):
                for sx in range(px * SUPERSAMPLE, (px + 1) * SUPERSAMPLE):
                    s = buf[sy * sw + sx]
                    if s is not None:
                        groups.setdefault(s[2], []).append(s)
            if not groups:
                continue
            material, samples = max(groups.items(), key=lambda kv: len(kv[1]))
            if sum(len(v) for v in groups.values()) < half:
                continue
            z = sum(s[0] for s in samples) / len(samples)
            n = _norm(tuple(sum(s[1][k] for s in samples) for k in range(3)))
            pixels[py * W + px] = (z, n, material)
    return pixels


def in_shadow(pixels, px, py, z):
    """March toward the key light over the depth buffer: is anything in front of the light?"""
    step = math.hypot(KEY[0], KEY[1])
    dx, dy, dz = KEY[0] / step, KEY[1] / step, KEY[2] / step
    x, y = px + 0.5, py + 0.5
    for i in range(1, 40):
        sx, sy, sz = x + dx * i, y + dy * i, z + dz * i
        ix, iy = int(sx), int(sy)
        if not (0 <= ix < W and 0 <= iy < H):
            return False
        p = pixels[iy * W + ix]
        if p is not None and p[0] > sz + 0.6:
            return True
    return False


def occlusion(pixels, px, py, z):
    """How much nearby geometry stands in front of this pixel (0 = open, 1 = buried)."""
    total = 0.0
    for ox, oy in ((-3, 0), (3, 0), (0, -3), (0, 3), (-2, -2), (2, -2), (-2, 2), (2, 2)):
        ix, iy = px + ox, py + oy
        if 0 <= ix < W and 0 <= iy < H and pixels[iy * W + ix] is not None:
            total += max(0.0, min(1.0, (pixels[iy * W + ix][0] - z) / 6))
    return total / 8


def shade(pixels):
    out = [None] * (W * H)
    for py in range(H):
        for px in range(W):
            p = pixels[py * W + px]
            if p is None:
                continue
            z, n, material = p
            diffuse = max(0.0, n[0] * KEY[0] + n[1] * KEY[1] + n[2] * KEY[2])
            if diffuse > 0 and in_shadow(pixels, px, py, z):
                diffuse *= 0.15
            rim = max(0.0, n[0] * RIM[0] + n[1] * RIM[1] + n[2] * RIM[2]) * (1 - n[2]) ** 1.2
            ao = occlusion(pixels, px, py, z)
            light = 0.16 + 0.82 * diffuse + 0.45 * rim - 0.35 * ao
            if material in SHINY:
                power, strength = SHINY[material]
                spec = max(0.0, n[0] * HALF[0] + n[1] * HALF[1] + n[2] * HALF[2]) ** power
                light += strength * spec * (0 if diffuse < 0.1 else 1)
            ramp = PALETTES[material]
            index = round(max(0.0, min(1.0, light)) ** 0.9 * (len(ramp) - 1))
            out[py * W + px] = [material, index]
    return out


# --- Hand-placed details --------------------------------------------------------

SPADE = ["...X...", "..XXX..", ".XXXXX.", "XXXXXXX", "XXXXXXX", "...X...", "..XXX.."]
ACE = [".X.", "X.X", "XXX", "X.X", "X.X"]


def add_details(cells):
    def put(x, y, material, index):
        if 0 <= x < W and 0 <= y < H:
            cells[y * W + x] = [material, index]

    # Narrow eyes in the shade of the brim, and a set mouth.
    for x in (44, 45, 51, 52):
        put(x, 29, "skin", 0)
    for x in range(46, 51):
        put(x, 36, "skin", 1)
    # Crease down the crown of the fedora.
    for y in range(13, 17):
        put(48, y, "hat", 1)
    # Double-breasted buttons, a belt buckle and pocket slits.
    for bx in (43, 53):
        for by in (64, 72):
            put(bx, by, "belt", 0)
            put(bx, by - 1, "belt", 2)
    for x in range(46, 51):
        put(x, 79, "metal", 4)
        put(x, 82, "metal", 2)
    put(46, 80, "metal", 3)
    put(46, 81, "metal", 3)
    put(50, 80, "metal", 2)
    put(50, 81, "metal", 2)
    for x in range(36, 42):
        put(x, 92, "lapel", 0)
    for x in range(54, 59):
        put(x, 92, "lapel", 0)
    # The coat's front opening below the belt, parting at the hem over the trousers.
    for y in range(83, 116):
        put(48, y, "lapel", 0)
        if y >= 108:
            put(47, y, "pants", 1)
            put(49, y, "pants", 1)
    # A few fold lines down the skirt.
    for y in range(90, 115, 1):
        if y % 3:
            put(41 - (y - 90) // 8, y, "coat", 2)
            put(56 + (y - 90) // 8, y, "coat", 2)
    # Ace of spades on the card face (its top-left corner is at 22, 25), above the fingers.
    for gy, row in enumerate(ACE):
        for gx, ch in enumerate(row):
            if ch == "X":
                put(24 + gx, 27 + gy, "hat", 0)
    for gy, row in enumerate(SPADE):
        for gx, ch in enumerate(row):
            if ch == "X":
                put(26 + gx, 31 + gy, "hat", 0)


def to_image(cells):
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    # A soft ground shadow under the feet, drawn first.
    for py in range(H):
        for px in range(W):
            dx, dy = (px + 0.5 - 48) / 22, (py + 0.5 - 140.5) / 3.2
            if dx * dx + dy * dy <= 1:
                img.putpixel((px, py), (0, 0, 0, 110))
    for py in range(H):
        for px in range(W):
            c = cells[py * W + px]
            if c is not None:
                img.putpixel((px, py), PALETTES[c[0]][c[1]] + (255,))
    # Dark outline round the whole figure.
    solid = {(px, py) for py in range(H) for px in range(W) if cells[py * W + px] is not None}
    for px, py in list(solid):
        for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            q = (px + ox, py + oy)
            if q not in solid and 0 <= q[0] < W and 0 <= q[1] < H:
                img.putpixel(q, OUTLINE + (255,))
    return img


def main():
    pixels = resolve(render_samples())
    cells = shade(pixels)
    add_details(cells)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    to_image(cells).save(OUT)
    print(f"Wrote {OUT.relative_to(ROOT)} ({W}x{H})")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Generate the pixel-art world map used as the game background.

Rasterizes Natural Earth's public-domain 1:110m land polygons onto a small
equirectangular grid, then colours it with a retro palette (shallow-water
halo, lighter coastline, polar ice, faint lat/long grid).

    python3 tools/generate_world_map.py [width height]

Requires Pillow. Writes assets/sprites/world_map.png (default 400x200, i.e. 0.9 degrees
per cell). The game draws a crop of it at 4x, sized to fill the portrait screen.
"""
import json
import sys
import urllib.request
from pathlib import Path

from PIL import Image, ImageDraw

SOURCE = "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_110m_land.geojson"
ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / "tools" / ".cache" / "ne_110m_land.geojson"
OUT = ROOT / "assets" / "sprites" / "world_map.png"

SUPERSAMPLE = 10      # render this much larger, then vote per cell
LAND_THRESHOLD = 0.3  # fraction of a cell that must be land
GRID_STEP_DEG = 30

# Kept dark and desaturated so the table and cards stay readable on top.
DEEP = (16, 28, 52)
SHALLOW = (24, 44, 76)
GRID = (21, 37, 66)
LAND = (52, 86, 58)
COAST = (78, 116, 70)
ICE = (120, 136, 152)
ICE_COAST = (150, 164, 178)


def load_geojson():
    if not CACHE.exists():
        CACHE.parent.mkdir(parents=True, exist_ok=True)
        urllib.request.urlretrieve(SOURCE, CACHE)
    return json.loads(CACHE.read_text())


def land_mask(width, height):
    big_w, big_h = width * SUPERSAMPLE, height * SUPERSAMPLE
    img = Image.new("L", (big_w, big_h), 0)
    draw = ImageDraw.Draw(img)

    def project(lon, lat):
        return ((lon + 180) / 360 * big_w, (90 - lat) / 180 * big_h)

    for feature in load_geojson()["features"]:
        geom = feature["geometry"]
        polygons = geom["coordinates"] if geom["type"] == "MultiPolygon" else [geom["coordinates"]]
        for rings in polygons:
            draw.polygon([project(*pt) for pt in rings[0]], fill=255)
            for hole in rings[1:]:
                draw.polygon([project(*pt) for pt in hole], fill=0)

    # Box-filter downsample = coverage fraction per cell.
    small = img.resize((width, height), Image.Resampling.BOX)
    return [[small.getpixel((x, y)) >= 255 * LAND_THRESHOLD for x in range(width)] for y in range(height)]


def main():
    width, height = (int(sys.argv[1]), int(sys.argv[2])) if len(sys.argv) == 3 else (400, 200)
    land = land_mask(width, height)

    def is_land(x, y):
        return 0 <= y < height and land[y][x % width]  # wrap east-west

    def near_land(x, y, r):
        return any(is_land(x + dx, y + dy) for dy in range(-r, r + 1) for dx in range(-r, r + 1))

    grid_cols = _grid_cells(width, 360)
    grid_rows = _grid_cells(height, 180)
    out = Image.new("RGB", (width, height))
    for y in range(height):
        lat = 90 - (y + 0.5) / height * 180
        for x in range(width):
            lon = (x + 0.5) / width * 360 - 180
            polar = _is_ice(lon, lat)
            if land[y][x]:
                edge = not all(is_land(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                color = (ICE_COAST if edge else ICE) if polar else (COAST if edge else LAND)
            elif near_land(x, y, 1):
                color = SHALLOW
            elif x in grid_cols or y in grid_rows:
                color = GRID
            else:
                color = DEEP
            out.putpixel((x, y), color)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    out.save(OUT)
    print(f"wrote {OUT.relative_to(ROOT)} ({width}x{height})")


def _grid_cells(cells, span):
    """Indices of the cells each interior GRID_STEP_DEG line passes through."""
    return {int(offset / (span / cells)) for offset in range(GRID_STEP_DEG, span, GRID_STEP_DEG)}


def _is_ice(lon, lat):
    """Antarctica, Greenland and the high Arctic islands."""
    return lat < -60 or lat > 78 or (lat > 59 and -75 < lon < -10)


if __name__ == "__main__":
    main()

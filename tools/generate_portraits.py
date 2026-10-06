#!/usr/bin/env python3
"""Generate the 16x16 player portraits in assets/portraits/.

Each portrait is ASCII art plus a palette. '.' is background; a dark outline is
added automatically around the figure. Edit the art below and re-run:

    python3 tools/generate_portraits.py

Requires Pillow. Feel free to replace the PNGs with hand-drawn sprites instead.
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "assets" / "portraits"
OUTLINE = "#0e0e18"

COMMON = {
    "K": "#1b1b2a",  # dark detail / eyes
    "S": "#e8b48a",  # skin
    "s": "#c48a64",  # skin shadow
    "W": "#f4f1e8",  # white
    "M": "#8a3a3a",  # mouth
}

PORTRAITS = {
    # The human: messy brown hair, blue hoodie.
    "you": ("#2a5a5a", {"H": "#6b3e22", "C": "#3a6ea8", "w": "#f4f1e8"}, [
        "................",
        "......HHHH......",
        "....HHHHHHHH....",
        "...HHHHHHHHHH...",
        "...HHSSSSSSHH...",
        "...HSSSSSSSSH...",
        "...SSSSSSSSSS...",
        "...SSKSSSSKSS...",
        "..sSSSSSSSSSSs..",
        "...SSSSssSSSS...",
        "...SSSSSSSSSS...",
        "....SSSMMSSS....",
        ".....SSSSSS.....",
        "......ssss......",
        "..CCCCwCCwCCCC..",
        ".CCCCCCCCCCCCCC.",
    ]),
    # Tight-passive: old-timer in a flat cap with grey stubble.
    "rocky": ("#4a2430", {"G": "#6a5a48", "g": "#4e4234", "h": "#9a9aa0", "B": "#4a4a50",
                          "b": "#8a8a90", "J": "#6b4a2a", "S": "#d8a070", "s": "#b07850"}, [
        "................",
        "................",
        "....GGGGGGGGG...",
        "...GGGGGGGGGGG..",
        "..gggggggggggg..",
        "...hSSSSSSSSh...",
        "...hBBSSSSBBh...",
        "...SSKSSSSKSS...",
        "..sSSSSSSSSSSs..",
        "...SSSSssSSSS...",
        "...bbSSSSSSbb...",
        "...bbbMMMMbbb...",
        "....bbbbbbbb....",
        "......ssss......",
        "..JJJJJWWJJJJJ..",
        ".JJJJJJWWJJJJJJ.",
    ]),
    # Calling station: ginger, freckled, grinning, green top hat.
    "lucky": ("#5a4a1e", {"T": "#2f7a3a", "Y": "#f0c040", "R": "#d0602a", "p": "#e88a8a",
                          "V": "#3a8a40", "S": "#f0c8a0", "s": "#d0a078"}, [
        ".....TTTTTT.....",
        ".....TTTTTT.....",
        ".....TTTTTT.....",
        ".....YYYYYY.....",
        "...TTTTTTTTTT...",
        "...RSSSSSSSSR...",
        "...RSSSSSSSSR...",
        "...SSKSSSSKSS...",
        "..sSSSSSSSSSSs..",
        "...SpSSssSSpS...",
        "...SSSSSSSSSS...",
        "...SSKWWWWKSS...",
        "....SSKKKKSS....",
        "......ssss......",
        "..VVVVVWWVVVVV..",
        ".VVVVVVWWVVVVVV.",
    ]),
    # Loose-aggressive: blond pompadour, aviators, leather jacket.
    "maverick": ("#6a1e24", {"H": "#e8c050", "G": "#303848", "L": "#5a2a1e"}, [
        "................",
        ".....HHHHHHH....",
        "...HHHHHHHHHH...",
        "..HHHHHHHHHHH...",
        "...HHSSSSSSSH...",
        "...HSSSSSSSSS...",
        "...SSSSSSSSSS...",
        "...KKKKKKKKKK...",
        "..sKGGKSSKGGKs..",
        "...SKKSssSKKS...",
        "...SSSSSSSSSS...",
        "....SSSMMMSS....",
        ".....SSSSSS.....",
        "......ssss......",
        "..LLLLWsWWLLLL..",
        ".LLLLLWWWWLLLLL.",
    ]),
    # Tight-aggressive: an actual shark, in a suit.
    "shark": ("#123048", {"A": "#6a8aa8", "a": "#4a6a88", "W": "#e8eef0", "N": "#1e2a4a", "R": "#c0303a"}, [
        ".......A........",
        "......AA........",
        ".....AAA........",
        "....AAAAAAAA....",
        "...AAAAAAAAAA...",
        "..AAAAAAAAAAAA..",
        "..AAKAAAAAAKAA..",
        "..AAAAAAAAAAAA..",
        "..AaaAAAAAAaaA..",
        "..AKWKWKWKWKWA..",
        "..AWWWWWWWWWWA..",
        "...WWWWWWWWWW...",
        "....WWWWWWWW....",
        ".....AAAAAA.....",
        "..NNNNWRRWNNNN..",
        ".NNNNNWRRWNNNNN.",
    ]),
    # Balanced: bald professor with round glasses, moustache and lab coat.
    "doc": ("#3a2a5a", {"h": "#c8c8d0", "E": "#1b1b2a", "K": "#8a8a9a", "C": "#4a7ab8", "S": "#e0b090", "s": "#c09070"}, [
        "................",
        "................",
        ".....SSSSSS.....",
        "....SSSSSSSS....",
        "...SSSSSSSSSS...",
        "...hSSSSSSSSh...",
        "...hSSSSSSSSh...",
        "...KKKSSSSKKK...",
        "..sKEKSKKSKEKs..",
        "...KKKSssSKKK...",
        "...SSSSSSSSSS...",
        "....hhhhhhhh....",
        ".....SSMMSS.....",
        "......ssss......",
        "..WWWWWCCWWWWW..",
        ".WWWWWWCCWWWWWW.",
    ]),
    # Maniac: crowned, monocled, curly moustache, royal robe with ermine.
    "duke": ("#3a1420", {"Y": "#f0c040", "R": "#c0303a", "G": "#40a060", "H": "#3a2418", "P": "#6a2a8a"}, [
        "...Y..Y..Y..Y...",
        "...YY.YY.YY.YY..",
        "...YYYYYYYYYY...",
        "...YRYYGYYRYY...",
        "...YYYYYYYYYY...",
        "...HSSSSSSSSH...",
        "...SSSSSSYYYS...",
        "...SSKSSSYKYS...",
        "..sSSSSSSYYYSs..",
        "...SSSSssSSSS...",
        "..HHHHHHHHHHHH..",
        "..H.SSSMMSSS.H..",
        ".....SSSSSS.....",
        "......ssss......",
        "..WWKWWPPWWKWW..",
        ".PPPPPPYYPPPPPP.",
    ]),
}


def render(background, palette, art):
    colors = {**COMMON, **palette}
    size = len(art)
    assert all(len(row) == size for row in art), [i for i, row in enumerate(art) if len(row) != size]
    img = Image.new("RGB", (size, size), background)

    def filled(x, y):
        return 0 <= x < size and 0 <= y < size and art[y][x] != "."

    for y, row in enumerate(art):
        for x, ch in enumerate(row):
            if ch != ".":
                img.putpixel((x, y), Image.new("RGB", (1, 1), colors[ch]).getpixel((0, 0)))
            elif any(filled(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                img.putpixel((x, y), Image.new("RGB", (1, 1), OUTLINE).getpixel((0, 0)))
    return img


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for name, (background, palette, art) in PORTRAITS.items():
        render(background, palette, art).save(OUT_DIR / f"{name}.png")
        print(f"wrote assets/portraits/{name}.png")


if __name__ == "__main__":
    main()

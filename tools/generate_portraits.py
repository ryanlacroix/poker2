#!/usr/bin/env python3
"""Generate the 16x16 player portraits in assets/portraits/.

Each portrait is ASCII art plus a palette. '.' is background; a dark outline is
added automatically around the figure. Each character also gets an injured
portrait (<name>_injured.png, shown at 1 heart): the same art with the rows in
INJURIES swapped in. Edit the art below and re-run:

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
    "X": "#ece6d4",  # bandage
    "r": "#b02030",  # blood
    "u": "#7a4a8a",  # bruise
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
    # --- Table 2: the King's court ---
    # Loose-aggressive bully: tall jewelled crown, long white beard, red robe with ermine.
    "king": ("#1a2a5a", {"Y": "#f0c040", "y": "#b08020", "R": "#c0303a", "B": "#3a6ad0",
                         "h": "#e4e4ec", "C": "#a01828"}, [
        "................",
        "...Y...YY...Y...",
        "...YY..YY..YY...",
        "...YYYYYYYYYY...",
        "...YRYYBBYYRY...",
        "...yyyyyyyyyy...",
        "...hSSSSSSSSh...",
        "...SSKSSSSKSS...",
        "..sSSSSSSSSSSs..",
        "...SSSSssSSSS...",
        "...hhhSSSShhh...",
        "...hhhhMMhhhh...",
        "...hhhhhhhhhh...",
        "....hhhhhhhh....",
        "..CWWhhhhhhWWC..",
        ".CCWKWhhhhWKWCC.",
    ]),
    # Tight-aggressive, the sharpest at court: ruby tiara, long dark hair, pearls, purple gown.
    "queen": ("#4a1a3a", {"Y": "#f0c040", "R": "#c0303a", "H": "#2a1810", "L": "#d03050",
                          "D": "#6a2a9a", "S": "#f0c8a8", "s": "#d0a080"}, [
        "................",
        ".....Y.YY.Y.....",
        "....YYYRRYYY....",
        "...HHHHHHHHHH...",
        "..HHHSSSSSSHHH..",
        "..HHSSSSSSSSHH..",
        "..HSSSSSSSSSSH..",
        "..HSSKSSSSKSSH..",
        "..HSSSSSSSSSSH..",
        "..HSSSSssSSSSH..",
        "..HSSSSSSSSSSH..",
        "..HHSSSLLSSSHH..",
        "..HHHSSSSSSHHH..",
        "..HHHsWWWWsHHH..",
        "..HHDDDSSDDDHH..",
        ".HHDDDDDDDDDDHH.",
    ]),
    # Maniac: red-and-green belled cap, painted cheeks, huge grin, harlequin collar.
    "jester": ("#3a2a50", {"Y": "#f0c040", "R": "#c0303a", "G": "#2f8a3a", "p": "#e88a8a"}, [
        "................",
        ".Y....RRGG....Y.",
        ".RR..RRRGGG..GG.",
        "..RRRRRRGGGGGG..",
        "...RRRRRGGGGG...",
        "...YYYYYYYYYY...",
        "...SSSSSSSSSS...",
        "...SSKSSSSKSS...",
        "..sSSSSSSSSSSs..",
        "...SpSSssSSpS...",
        "...SSSSSSSSSS...",
        "...SKWWWWWWKS...",
        "....SSKKKKSS....",
        "......ssss......",
        "..RRRRRRGGGGGG..",
        ".GGGGGGGRRRRRRR.",
    ]),
    # Tight and honest, never bluffs: great helm with eye slit and red plume, blue tabard.
    "knight": ("#4a3a1e", {"R": "#c0303a", "A": "#a8b0bc", "a": "#6a7280", "L": "#d8dee6",
                           "T": "#2a4a9a", "Y": "#f0c040"}, [
        ".......RR.......",
        "......RRRR......",
        ".....RRRRRR.....",
        "....AAAAAAAA....",
        "...LAAAAAAAAa...",
        "...LAAAAAAAAa...",
        "...LAAAAAAAAa...",
        "...KKKKKKKKKK...",
        "..aLAAAAAAAAaa..",
        "...LAAAAAAAAa...",
        "...LAKAKAKAKa...",
        "...LAAKAKAKAa...",
        "...LAAAAAAAAa...",
        "....aaaaaaaa....",
        "..AATTTYYTTTAA..",
        ".AAATTYYYYTTAAA.",
    ]),
    # Timid calling station: straw hat, sunburnt and smudged, gap-toothed grin, rough tunic.
    "peasant": ("#2e4a24", {"T": "#d8b860", "t": "#a88a40", "H": "#6a4a2a", "d": "#8a6040",
                            "C": "#7a5a3a", "c": "#5a3e24", "S": "#d09868", "s": "#a87048"}, [
        "................",
        "................",
        ".....TTTTTT.....",
        "....TTTTTTTT....",
        ".tTTTTTTTTTTTTt.",
        "..tttttttttttt..",
        "...HSSSSSSSSH...",
        "...SSKSSSSKSS...",
        "..sSSSSSSSSSSs..",
        "...SdSSssSSSS...",
        "...SSSSSSSSSS...",
        "....SSKWKWSS....",
        ".....SSSSSS.....",
        "......ssss......",
        "..CCCCCccCCCCC..",
        ".CCCCCcCCcCCCCC.",
    ]),
    # Balanced and calculating: feathered velvet cap, pointed beard, fur collar, gold chain.
    "nobleman": ("#5a2a1a", {"F": "#f4f1e8", "V": "#1e5a4a", "H": "#3a2418", "f": "#8a6a4a",
                             "Y": "#f0c040", "D": "#1e5a4a"}, [
        "...........FF...",
        "..........FF....",
        "....VVVVVVFV....",
        "...VVVVVVVVVV...",
        "..VVVVVVVVVVVV..",
        "...HSSSSSSSSH...",
        "...SSSSSSSSSS...",
        "...SSKSSSSKSS...",
        "..sSSSSSSSSSSs..",
        "...SSSSssSSSS...",
        "...SSHHHHHHSS...",
        "...SSSSMMSSSS...",
        "....SSHHHHSS....",
        "......HHHH......",
        "..ffffYHHYffff..",
        ".DDDDYDDDDYDDDD.",
    ]),
}


# Injured versions: row index -> replacement row. Bandages (with a blood spot), black eyes,
# cracked lenses, knocked-out teeth, nosebleeds and pained mouths.
INJURIES = {
    "you": {
        5: "...XXXXXrXXXX...",
        6: "...SSSSSSuuuS...",
        7: "...SSKSSSuKuS...",
        8: "..sSSSSSSuuuSs..",
        11: "....SSMMMMSS....",
        12: ".....MSSSSM.....",
    },
    "rocky": {
        5: "...hXXXXXrXXh...",
        7: "...SSKSSSuKuS...",
        8: "..sSSSSSSuuuSs..",
        12: "....bMbbbbMb....",
    },
    "lucky": {
        5: "...RXXXXXrXXR...",
        7: "...SSKSSSuKuS...",
        8: "..sSSSSSSuuuSs..",
        11: "...SSKWKWWKSS...",
    },
    "maverick": {
        5: "...HXXXXrXXXX...",
        8: "..sKGGKSSKWGKs..",
        10: "...SSSSSrSSSS...",
        12: ".....SMSSSM.....",
    },
    "shark": {
        4: "...AXXXXrXXXA...",
        5: "..AAAAAAAAuuuA..",
        6: "..AAKAAAAAuKuA..",
        7: "..AAAAAAAAuuuA..",
        9: "..AKWKKKWKWKKA..",
    },
    "doc": {
        3: "....XXXXrXXX....",
        8: "..sKEKSKKSKWKs..",
        12: ".....SMMMMS.....",
    },
    "duke": {
        0: "...Y..Y.....Y...",
        1: "...YY.YY....YY..",
        5: "...HXXXXXrXXH...",
        6: "...SuuuSSYYYS...",
        7: "...SuKuSSYKYS...",
        8: "..sSuuuSSYYYSs..",
        11: "..H.SSMMMMSS.H..",
        12: ".....MSSSSM.....",
    },
    # Table 2: crowns and tiaras knocked about, a dented helm bleeding from the slit.
    "king": {
        1: "...Y...Y........",
        6: "...hXXXXXrXXh...",
        7: "...SSKSSSuKuS...",
        8: "..sSSSSSSuuuSs..",
        11: "...hhhMMMMhhh...",
    },
    "queen": {
        1: ".....Y.....Y....",
        5: "..HHXXXXrXXXHH..",
        7: "..HSSKSSSuKuSH..",
        8: "..HSSSSSSuuuSH..",
        11: "..HHSSMMMMSSHH..",
    },
    "jester": {
        1: ".Y....RRGG......",
        6: "...XXXXXrXXXX...",
        7: "...SSKSSSuKuS...",
        8: "..sSSSSSSuuuSs..",
        11: "...SKWKWWKWKS...",
    },
    "knight": {
        0: "......RR........",
        1: ".....RRR........",
        2: ".....RRRR.......",
        4: "...LAAAKAAAAa...",
        5: "...LAAAAKAAAa...",
        8: "..aLAAAAArAAaa..",
        9: "...LAAAArAAAa...",
    },
    "peasant": {
        4: ".tTTT.TTTTTTTTt.",
        6: "...HXXXXrXXXH...",
        7: "...SSKSSSuKuS...",
        8: "..sSSSSSSuuuSs..",
        9: "...SdSSsrSSSS...",
        11: "....SSMMMMSS....",
    },
    "nobleman": {
        0: "................",
        1: "..........F.....",
        5: "...HXXXXXrXXH...",
        7: "...SSKSSSuKuS...",
        8: "..sSSSSSSuuuSs..",
        11: "...SSSMMMMSSS...",
    },
}


def injured(art, rows):
    return [rows.get(y, row) for y, row in enumerate(art)]


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
        render(background, palette, injured(art, INJURIES[name])).save(OUT_DIR / f"{name}_injured.png")
        print(f"wrote assets/portraits/{name}.png, {name}_injured.png")


if __name__ == "__main__":
    main()

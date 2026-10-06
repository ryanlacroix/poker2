using System.Collections.Generic;
using Godot;

namespace PokerGame;

/// <summary>
/// Tiny bitmap glyphs drawn with DrawRect, so cards stay crisp without any image assets.
/// Swap these for real sprites in assets/sprites/ whenever you like.
/// </summary>
public static class PixelArt
{
    public static readonly Color Ink = new("1b1b2a");
    public static readonly Color Paper = new("f4f1e8");
    public static readonly Color Red = new("c0303a");
    public static readonly Color Back = new("3050a0");
    public static readonly Color BackLight = new("5078c8");
    public static readonly Color Gold = new("f0c040");

    // Indexed by Suit: Clubs, Diamonds, Hearts, Spades.
    public static readonly string[][] Suits =
    {
        new[] { "..XXX..", "..XXX..", "XXXXXXX", "XXXXXXX", "XX.X.XX", "...X...", "..XXX.." },
        new[] { "...X...", "..XXX..", ".XXXXX.", "XXXXXXX", ".XXXXX.", "..XXX..", "...X..." },
        new[] { ".......", ".XX.XX.", "XXXXXXX", "XXXXXXX", ".XXXXX.", "..XXX..", "...X..." },
        new[] { "...X...", "..XXX..", ".XXXXX.", "XXXXXXX", "XXXXXXX", "...X...", "..XXX.." },
    };

    public static readonly string[] Heart = { ".XX.XX.", "XXXXXXX", "XXXXXXX", ".XXXXX.", "..XXX..", "...X..." };
    public static readonly Color HeartRed = new("e03848");
    public static readonly Color HeartEmpty = new("3a3448");

    // 3x5 glyphs for card ranks plus "D" for the dealer button.
    public static readonly Dictionary<char, string[]> Glyphs = new()
    {
        ['A'] = new[] { ".X.", "X.X", "XXX", "X.X", "X.X" },
        ['K'] = new[] { "X.X", "X.X", "XX.", "X.X", "X.X" },
        ['Q'] = new[] { ".X.", "X.X", "X.X", "XX.", ".XX" },
        ['J'] = new[] { "..X", "..X", "..X", "X.X", ".X." },
        ['D'] = new[] { "XX.", "X.X", "X.X", "X.X", "XX." },
        ['0'] = new[] { "XXX", "X.X", "X.X", "X.X", "XXX" },
        ['1'] = new[] { ".X.", "XX.", ".X.", ".X.", "XXX" },
        ['2'] = new[] { "XXX", "..X", "XXX", "X..", "XXX" },
        ['3'] = new[] { "XXX", "..X", "XXX", "..X", "XXX" },
        ['4'] = new[] { "X.X", "X.X", "XXX", "..X", "..X" },
        ['5'] = new[] { "XXX", "X..", "XXX", "..X", "XXX" },
        ['6'] = new[] { "XXX", "X..", "XXX", "X.X", "XXX" },
        ['7'] = new[] { "XXX", "..X", "..X", "..X", "..X" },
        ['8'] = new[] { "XXX", "X.X", "XXX", "X.X", "XXX" },
        ['9'] = new[] { "XXX", "X.X", "XXX", "..X", "XXX" },
    };

    // Side-view pistol pointing right (28x16): K outline, L/G/g slide steel, D frame, B/b wooden grip.
    public static readonly string[] Pistol =
    {
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
    };

    public static readonly Dictionary<char, Color> PistolColors = new()
    {
        ['K'] = Ink,
        ['L'] = new Color("f0f4fa"),
        ['G'] = new Color("aab4c4"),
        ['g'] = new Color("6e7888"),
        ['B'] = new Color("a8642e"),
        ['b'] = new Color("6a3c1c"),
        ['D'] = new Color("5a6478"),
    };

    public static readonly string[] MuzzleFlash =
    {
        "..Y.Y..",
        "...O...",
        "YOOWOOY",
        "...O...",
        "..Y.Y..",
    };

    public static readonly Dictionary<char, Color> FlashColors = new()
    {
        ['Y'] = Gold,
        ['O'] = new Color("ff8a30"),
        ['W'] = new Color("fff6d0"),
    };

    /// <summary>Draws a multi-colour pattern; characters missing from <paramref name="colors"/> are transparent.</summary>
    public static void DrawColored(CanvasItem canvas, string[] pattern, IReadOnlyDictionary<char, Color> colors, Vector2 origin, int px)
    {
        for (int y = 0; y < pattern.Length; y++)
            for (int x = 0; x < pattern[y].Length; x++)
                if (colors.TryGetValue(pattern[y][x], out var color))
                    canvas.DrawRect(new Rect2(origin + new Vector2(x, y) * px, new Vector2(px, px)), color);
    }

    /// <summary>Fills every non-'.' cell of <paramref name="pattern"/> with one colour (a glyph or a silhouette).</summary>
    public static void Draw(CanvasItem canvas, string[] pattern, Vector2 origin, int px, Color color)
    {
        for (int y = 0; y < pattern.Length; y++)
            for (int x = 0; x < pattern[y].Length; x++)
                if (pattern[y][x] != '.')
                    canvas.DrawRect(new Rect2(origin + new Vector2(x, y) * px, new Vector2(px, px)), color);
    }

    public static void DrawText(CanvasItem canvas, string text, Vector2 origin, int px, Color color)
    {
        foreach (char ch in text)
        {
            if (Glyphs.TryGetValue(ch, out var glyph))
                Draw(canvas, glyph, origin, px, color);
            origin.X += 4 * px;
        }
    }
}

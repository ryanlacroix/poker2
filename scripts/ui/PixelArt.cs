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

    public static void Draw(CanvasItem canvas, string[] pattern, Vector2 origin, int px, Color color)
    {
        for (int y = 0; y < pattern.Length; y++)
            for (int x = 0; x < pattern[y].Length; x++)
                if (pattern[y][x] == 'X')
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

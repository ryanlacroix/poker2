using System;
using System.Collections.Generic;
using Godot;

namespace PokerGame;

/// <summary>
/// A pixel-art pile of chips sitting on the felt beside a seat, drawn at a whole-number
/// <see cref="PixelScale"/> so the art stays crisp. The pile grows (logarithmically) with
/// <see cref="Amount"/> up to three stacks of five; chip colours follow standard denominations.
/// The node's position is the base centre of the pile.
/// </summary>
public partial class ChipPileView : Control
{
    private const int ChipWidth = 8;
    private const int ChipHeight = 2;
    private const int ChipsPerColumn = 5;
    private const int MaxChips = 15;
    /// <summary>Pixel-art scale of the chips and of the amount label's digits.</summary>
    public const int PixelScale = 2;
    private const int LabelY = 6; // top of the digits, below the chips

    // Base offset of each column (unscaled), in fill order: two in front, one behind (drawn first).
    private static readonly Vector2I[] ColumnOffsets = { new(-4, 0), new(5, 0), new(0, -4) };

    /// <summary>Area the largest pile can cover (plus its label), relative to the node's position.</summary>
    public static Rect2 BoundsFor(bool showLabel)
    {
        // Unscaled chips span x -9..11 (outline + shadow), y -16..2.
        var chips = new Rect2(-9 * PixelScale, -16 * PixelScale, 20 * PixelScale, 18 * PixelScale);
        // Label: up to 4 digits of 3x5 glyphs (4px advance) at PixelScale, plus a 2px backing.
        float labelWidth = (4 * 4 - 1) * PixelScale + 4;
        return showLabel ? chips.Merge(new Rect2(-labelWidth / 2, LabelY - 2, labelWidth, 5 * PixelScale + 4)) : chips;
    }

    private static readonly (int Value, Color Body, Color Stripe)[] Denominations =
    {
        (500, new Color("7a3ab0"), PixelArt.Paper),
        (100, new Color("2a2a34"), PixelArt.Paper),
        (25, new Color("2f9a4a"), PixelArt.Paper),
        (5, new Color("c0303a"), PixelArt.Paper),
        (1, new Color("e8e8e8"), new Color("c0303a")),
    };

    /// <summary>Draw the amount in pixel digits under the pile.</summary>
    public bool ShowLabel { get; set; } = true;

    private int _amount;
    private readonly List<int> _chips = new(); // denomination index per chip, bottom-up

    public int Amount
    {
        get => _amount;
        set
        {
            if (value == _amount) return;
            _amount = value;
            Rebuild();
            QueueRedraw();
        }
    }

    public override void _Ready() => MouseFilter = MouseFilterEnum.Ignore;

    private void Rebuild()
    {
        _chips.Clear();
        if (_amount <= 0) return;

        // Real chips the amount breaks into, highest value first...
        var exact = new List<int>();
        int rest = _amount;
        for (int d = 0; d < Denominations.Length; d++)
        {
            for (; rest >= Denominations[d].Value; rest -= Denominations[d].Value)
                exact.Add(d);
        }

        // ...resampled to a chip count that keeps growing with the amount but stays compact
        // (10 -> 2 chips, 100 -> 7, 1000 -> 12, 7000 -> 15).
        int count = Math.Clamp((int)Math.Round(2.2 * Math.Log(_amount / 5.0 + 1)), 1, MaxChips);
        for (int i = 0; i < count; i++)
            _chips.Add(exact[i * exact.Count / count]);
    }

    public override void _Draw()
    {
        if (_chips.Count == 0) return;

        DrawSetTransform(Vector2.Zero, 0, Vector2.One * PixelScale);
        int columns = (_chips.Count + ChipsPerColumn - 1) / ChipsPerColumn;
        var order = new List<int>();
        for (int c = 0; c < columns; c++) order.Add(c);
        order.Sort((a, b) => ColumnOffsets[a].Y.CompareTo(ColumnOffsets[b].Y)); // back to front

        foreach (int c in order)
        {
            int start = c * ChipsPerColumn;
            int height = Math.Min(ChipsPerColumn, _chips.Count - start);
            DrawColumn(ColumnOffsets[c], _chips.GetRange(start, height));
        }

        DrawSetTransform(Vector2.Zero);
        if (ShowLabel) DrawAmount();
    }

    private void DrawColumn(Vector2I baseOffset, List<int> chips)
    {
        var x = baseOffset.X - ChipWidth / 2;
        int bottom = baseOffset.Y; // y of the bottom chip's lowest pixel row
        int top = bottom - chips.Count * ChipHeight - 1;

        // Shadow on the felt, then a dark outline around the whole column.
        DrawRect(new Rect2(x, bottom + 1, ChipWidth + 1, 1), new Color(0, 0, 0, 0.35f));
        DrawRect(new Rect2(x - 1, top - 1, ChipWidth + 2, bottom - top + 2), PixelArt.Ink);

        for (int i = 0; i < chips.Count; i++)
        {
            var (_, body, stripe) = Denominations[chips[i]];
            int y = bottom - (i + 1) * ChipHeight + 1;
            DrawRect(new Rect2(x, y, ChipWidth, 1), body);
            DrawRect(new Rect2(x, y + 1, ChipWidth, 1), body.Darkened(0.35f));
            DrawRect(new Rect2(x + 2, y, 1, 1), stripe);
            DrawRect(new Rect2(x + 5, y, 1, 1), stripe);
        }

        // Top face of the top chip.
        var topBody = Denominations[chips[^1]].Body;
        DrawRect(new Rect2(x, top, ChipWidth, 1), topBody.Lightened(0.25f));
        DrawRect(new Rect2(x + 3, top, 2, 1), Denominations[chips[^1]].Stripe);
    }

    private void DrawAmount()
    {
        string text = _amount.ToString();
        int width = (text.Length * 4 - 1) * PixelScale;
        var origin = new Vector2(-width / 2, LabelY);
        DrawRect(new Rect2(origin - Vector2.One * 2, new Vector2(width + 4, 5 * PixelScale + 4)), new Color(0, 0, 0, 0.45f));
        PixelArt.DrawText(this, text, origin, PixelScale, PixelArt.Gold);
    }
}

using Godot;

namespace PokerGame;

public enum CardHighlight { None, Winning, Kicker, Dimmed }

/// <summary>Draws one card (face up, face down, or an empty slot) in pixel-art style.</summary>
public partial class CardView : Control
{
    public static readonly Vector2 CardSize = new(26, 36);

    private Card? _card;
    private bool _faceUp;
    private CardHighlight _highlight;

    public bool ShowEmptySlot { get; set; }
    /// <summary>Whole-number size multiplier; the pixel art is drawn scaled so it stays crisp.</summary>
    public int PixelScale { get; init; } = 1;
    public Card? Card => _card;

    public override void _Ready()
    {
        CustomMinimumSize = CardSize * PixelScale;
        Size = CardSize * PixelScale;
        MouseFilter = MouseFilterEnum.Ignore;
    }

    public void SetCard(Card? card, bool faceUp)
    {
        _card = card;
        _faceUp = faceUp;
        QueueRedraw();
    }

    /// <summary>
    /// Winning cards lift and get a bright double gold outline; kickers stay put with a faint
    /// single outline; dimmed cards are shaded.
    /// </summary>
    public void SetHighlight(CardHighlight highlight)
    {
        _highlight = highlight;
        QueueRedraw();
    }

    public override void _Draw()
    {
        var rect = new Rect2(Vector2.Zero, CardSize);
        float lift = _card != null && _highlight == CardHighlight.Winning ? -3 * PixelScale : 0;
        DrawSetTransform(new Vector2(0, lift), 0, Vector2.One * PixelScale);
        if (_card == null)
        {
            DrawEmptySlot(rect);
            return;
        }

        // At 2x and up there's room for finer art: draw it on a grid twice as dense.
        bool fine = PixelScale % 2 == 0;
        if (fine)
        {
            DrawSetTransform(new Vector2(0, lift), 0, Vector2.One * (PixelScale / 2));
            DrawFineCard(new Rect2(Vector2.Zero, CardSize * 2));
            DrawSetTransform(new Vector2(0, lift), 0, Vector2.One * PixelScale);
        }
        else
        {
            DrawCard(rect);
        }

        if (_highlight == CardHighlight.Winning)
        {
            DrawRect(rect.Grow(1), PixelArt.Gold, false, 1);
            DrawRect(rect.Grow(2), new Color(PixelArt.Gold, 0.4f), false, 1);
        }
        else if (_highlight == CardHighlight.Kicker)
        {
            DrawRect(rect.Grow(1), new Color(PixelArt.Gold, 0.45f), false, 1);
        }
        else if (_highlight == CardHighlight.Dimmed)
        {
            DrawRect(rect, new Color(0.05f, 0.05f, 0.1f, 0.5f));
        }
    }

    private void DrawEmptySlot(Rect2 rect)
    {
        if (!ShowEmptySlot) return;
        DrawRect(rect, new Color(0, 0, 0, 0.25f));
        DrawRect(rect, new Color(1, 1, 1, 0.15f), false, 1);
    }

    private void DrawCard(Rect2 rect)
    {
        DrawRect(rect, PixelArt.Ink);
        var inner = rect.Grow(-1);
        if (!_faceUp)
        {
            DrawRect(inner, PixelArt.Back);
            for (int y = 3; y < CardSize.Y - 3; y += 2)
                for (int x = 3; x < CardSize.X - 3; x += 2)
                    if ((x + y) % 4 == 0)
                        DrawRect(new Rect2(x, y, 1, 1), PixelArt.BackLight);
            return;
        }

        DrawRect(inner, PixelArt.Paper);
        var color = _card!.IsRed ? PixelArt.Red : PixelArt.Ink;
        var suit = PixelArt.Suits[(int)_card.Suit];
        PixelArt.DrawText(this, _card.RankName, new Vector2(3, 3), 2, color);
        PixelArt.Draw(this, suit, new Vector2(3, 15), 1, color);
        PixelArt.Draw(this, suit, new Vector2(11, 20), 2, color);
    }

    /// <summary>The same card on a 52x72 grid: rounded corners, a shaded edge, bold 5x7 ranks and finer suits.</summary>
    private void DrawFineCard(Rect2 rect)
    {
        FillRounded(rect, PixelArt.Ink);
        var inner = rect.Grow(-1);
        if (!_faceUp)
        {
            FillRounded(inner, PixelArt.Back);
            var frame = rect.Grow(-3);
            DrawRect(frame, PixelArt.BackLight, false, 1);
            for (int y = (int)frame.Position.Y + 2; y < frame.End.Y - 2; y++)
                for (int x = (int)frame.Position.X + 2; x < frame.End.X - 2; x++)
                    if ((x + y) % 6 == 0 || (x - y) % 6 == 0)
                        DrawRect(new Rect2(x, y, 1, 1), PixelArt.BackLight);
            return;
        }

        FillRounded(inner, PixelArt.PaperShade);
        FillRounded(new Rect2(inner.Position, inner.Size - Vector2.One), PixelArt.Paper);
        var color = _card!.IsRed ? PixelArt.Red : PixelArt.Ink;
        int suit = (int)_card.Suit;
        var origin = new Vector2(4, 4);
        foreach (char ch in _card.RankName)
        {
            // Drawn twice, a pixel apart, for a bold stroke.
            PixelArt.Draw(this, PixelArt.RankGlyphs[ch], origin, 2, color);
            PixelArt.Draw(this, PixelArt.RankGlyphs[ch], origin + Vector2.Right, 2, color);
            origin.X += 12;
        }
        PixelArt.Draw(this, PixelArt.SuitsSmall[suit], new Vector2(_card.RankName.Length == 1 ? 5 : 4, 21), 1, color);
        PixelArt.Draw(this, PixelArt.SuitsLarge[suit], rect.End - new Vector2(30, 30), 2, color);
    }

    /// <summary>Fills <paramref name="rect"/> with its four corner pixels left out.</summary>
    private void FillRounded(Rect2 rect, Color color)
    {
        DrawRect(new Rect2(rect.Position.X + 1, rect.Position.Y, rect.Size.X - 2, 1), color);
        DrawRect(new Rect2(rect.Position.X, rect.Position.Y + 1, rect.Size.X, rect.Size.Y - 2), color);
        DrawRect(new Rect2(rect.Position.X + 1, rect.End.Y - 1, rect.Size.X - 2, 1), color);
    }
}

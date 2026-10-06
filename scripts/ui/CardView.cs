using Godot;

namespace PokerGame;

public enum CardHighlight { None, Winning, Dimmed }

/// <summary>Draws one card (face up, face down, or an empty slot) in pixel-art style.</summary>
public partial class CardView : Control
{
    public static readonly Vector2 CardSize = new(26, 36);

    private Card? _card;
    private bool _faceUp;
    private CardHighlight _highlight;

    public bool ShowEmptySlot { get; set; }
    public Card? Card => _card;

    public override void _Ready()
    {
        CustomMinimumSize = CardSize;
        Size = CardSize;
        MouseFilter = MouseFilterEnum.Ignore;
    }

    public void SetCard(Card? card, bool faceUp)
    {
        _card = card;
        _faceUp = faceUp;
        QueueRedraw();
    }

    /// <summary>Winning cards lift and get a gold outline; dimmed cards are shaded.</summary>
    public void SetHighlight(CardHighlight highlight)
    {
        _highlight = highlight;
        QueueRedraw();
    }

    public override void _Draw()
    {
        var rect = new Rect2(Vector2.Zero, CardSize);
        if (_card != null && _highlight == CardHighlight.Winning)
            DrawSetTransform(new Vector2(0, -3));
        DrawCard(rect);
        if (_card == null) return;
        if (_highlight == CardHighlight.Winning)
        {
            DrawRect(rect.Grow(1), PixelArt.Gold, false, 1);
            DrawRect(rect.Grow(2), new Color(PixelArt.Gold, 0.4f), false, 1);
        }
        else if (_highlight == CardHighlight.Dimmed)
        {
            DrawRect(rect, new Color(0.05f, 0.05f, 0.1f, 0.5f));
        }
    }

    private void DrawCard(Rect2 rect)
    {
        if (_card == null)
        {
            if (ShowEmptySlot)
            {
                DrawRect(rect, new Color(0, 0, 0, 0.25f));
                DrawRect(rect, new Color(1, 1, 1, 0.15f), false, 1);
            }
            return;
        }

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
        var color = _card.IsRed ? PixelArt.Red : PixelArt.Ink;
        var suit = PixelArt.Suits[(int)_card.Suit];
        PixelArt.DrawText(this, _card.RankName, new Vector2(3, 3), 2, color);
        PixelArt.Draw(this, suit, new Vector2(3, 15), 1, color);
        PixelArt.Draw(this, suit, new Vector2(11, 20), 2, color);
    }
}

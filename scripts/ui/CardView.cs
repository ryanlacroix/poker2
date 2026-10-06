using Godot;

namespace PokerGame;

/// <summary>Draws one card (face up, face down, or an empty slot) in pixel-art style.</summary>
public partial class CardView : Control
{
    public static readonly Vector2 CardSize = new(26, 36);

    private Card? _card;
    private bool _faceUp;

    public bool ShowEmptySlot { get; set; }

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

    public override void _Draw()
    {
        var rect = new Rect2(Vector2.Zero, CardSize);
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

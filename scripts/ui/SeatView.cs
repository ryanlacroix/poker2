using Godot;

namespace PokerGame;

/// <summary>One player's spot at the table: portrait, hole cards, name, stack and last action.</summary>
public partial class SeatView : Control
{
    public static readonly Vector2 SeatSize = new(104, 76);

    public static readonly Vector2 PortraitSize = new(32, 32);

    public PokerPlayer Player { get; init; } = null!;
    public Texture2D? Portrait { get; init; }

    private readonly CardView[] _cards = { new(), new() };
    private readonly Label _name = new();
    private readonly Label _chips = new();
    private readonly Label _status = new();
    private bool _isDealer;
    private bool _isActive;
    private bool _reveal;

    public override void _Ready()
    {
        Size = SeatSize;
        MouseFilter = MouseFilterEnum.Ignore;
        // Portrait on the left, cards beside it, dealer button on the right.
        float cardsX = PortraitSize.X + 4;
        for (int i = 0; i < 2; i++)
        {
            _cards[i].Position = new Vector2(cardsX + i * (CardView.CardSize.X + 2), 0);
            AddChild(_cards[i]);
        }
        AddLabel(_name, 38, PixelArt.Paper);
        AddLabel(_chips, 50, PixelArt.Gold);
        AddLabel(_status, 62, new Color("9fe0a0"));
        _name.Text = Player.DisplayName;
        Refresh();
    }

    private void AddLabel(Label label, float y, Color color)
    {
        label.Position = new Vector2(0, y);
        label.Size = new Vector2(SeatSize.X, 12);
        label.HorizontalAlignment = HorizontalAlignment.Center;
        label.AddThemeColorOverride("font_color", color);
        AddChild(label);
    }

    public void Refresh()
    {
        _chips.Text = Player.IsOut ? "OUT" : $"${Player.Chips}";
        bool faceUp = Player.IsHuman || _reveal;
        for (int i = 0; i < 2; i++)
        {
            var card = i < Player.HoleCards.Count ? Player.HoleCards[i] : null;
            _cards[i].SetCard(card, faceUp);
            _cards[i].Modulate = Player.Folded ? new Color(1, 1, 1, 0.35f) : Colors.White;
        }
        QueueRedraw();
    }

    public void SetStatus(string text, Color? color = null)
    {
        _status.Text = text;
        _status.AddThemeColorOverride("font_color", color ?? new Color("9fe0a0"));
    }

    public void SetDealer(bool value) { _isDealer = value; QueueRedraw(); }
    public void SetActive(bool value) { _isActive = value; QueueRedraw(); }
    public void SetReveal(bool value) { _reveal = value; Refresh(); }

    public override void _Draw()
    {
        if (_isActive)
            DrawRect(new Rect2(-2, -2, SeatSize + new Vector2(4, 4)), PixelArt.Gold, false, 1);
        if (Portrait != null)
        {
            var frame = new Rect2(new Vector2(1, 2), PortraitSize);
            bool dimmed = Player.Folded || Player.IsOut;
            DrawRect(frame.Grow(1), dimmed ? PixelArt.Ink : PixelArt.Paper, false, 1);
            DrawTextureRect(Portrait, frame, false, dimmed ? new Color(0.45f, 0.45f, 0.5f) : Colors.White);
        }
        if (_isDealer)
        {
            var origin = new Vector2(SeatSize.X - 12, 2);
            DrawRect(new Rect2(origin, new Vector2(9, 9)), PixelArt.Paper);
            DrawRect(new Rect2(origin, new Vector2(9, 9)), PixelArt.Ink, false, 1);
            PixelArt.Draw(this, PixelArt.Glyphs['D'], origin + new Vector2(3, 2), 1, PixelArt.Ink);
        }
    }
}

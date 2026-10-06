using System.Collections.Generic;
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
    private bool _isWinner;

    public override void _Ready()
    {
        Size = SeatSize;
        MouseFilter = MouseFilterEnum.Ignore;
        SetProcess(false); // only runs while the winner glow animates
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
        label.HorizontalAlignment = HorizontalAlignment.Center;
        label.AddThemeColorOverride("font_color", color);
        this.AddAt(label, new Vector2(0, y), new Vector2(SeatSize.X, 12));
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

    /// <summary>Make the portrait pulse gold.</summary>
    public void SetWinner(bool value)
    {
        _isWinner = value;
        SetProcess(value);
        QueueRedraw();
    }

    /// <summary>Highlight hole cards in <paramref name="winning"/> and dim the rest; null clears.</summary>
    public void HighlightCards(ISet<Card>? winning)
    {
        foreach (var view in _cards)
        {
            view.SetHighlight(winning == null || view.Card == null ? CardHighlight.None
                : winning.Contains(view.Card) ? CardHighlight.Winning
                : CardHighlight.Dimmed);
        }
    }

    public override void _Process(double delta) => QueueRedraw(); // animates the winner glow

    public override void _Draw()
    {
        if (_isActive)
            DrawRect(new Rect2(-2, -2, SeatSize + new Vector2(4, 4)), PixelArt.Gold, false, 1);
        if (Portrait != null)
        {
            var frame = new Rect2(new Vector2(1, 2), PortraitSize);
            bool dimmed = Player.Folded || Player.IsOut;
            if (_isWinner)
            {
                DrawWinnerGlow(frame);
            }
            else
            {
                DrawRect(frame.Grow(1), dimmed ? PixelArt.Ink : PixelArt.Paper, false, 1);
                DrawTextureRect(Portrait, frame, false, dimmed ? new Color(0.45f, 0.45f, 0.5f) : Colors.White);
            }
        }
        if (_isDealer)
        {
            var origin = new Vector2(SeatSize.X - 12, 2);
            DrawRect(new Rect2(origin, new Vector2(9, 9)), PixelArt.Paper);
            DrawRect(new Rect2(origin, new Vector2(9, 9)), PixelArt.Ink, false, 1);
            PixelArt.Draw(this, PixelArt.Glyphs['D'], origin + new Vector2(3, 2), 1, PixelArt.Ink);
        }
    }

    /// <summary>Gold frame with pulsing halo rings, a warm tint and twinkling corner sparkles.</summary>
    private void DrawWinnerGlow(Rect2 frame)
    {
        float t = Time.GetTicksMsec() / 1000f;
        float pulse = 0.6f + 0.4f * Mathf.Sin(t * 5f);
        DrawRect(frame.Grow(4), new Color(PixelArt.Gold, 0.3f * pulse), false, 1);
        DrawRect(frame.Grow(3), new Color(PixelArt.Gold, 0.6f * pulse), false, 1);
        DrawRect(frame.Grow(2), new Color("ffe9a0"), false, 1);
        DrawRect(frame.Grow(1), PixelArt.Gold, false, 1);
        DrawTextureRect(Portrait!, frame, false, Colors.White.Lerp(new Color("ffe9a0"), 0.5f * pulse));
        DrawRect(frame, new Color(PixelArt.Gold, 0.25f * pulse));

        // Two diagonal corners twinkle at a time.
        bool phase = (int)(t * 3) % 2 == 0;
        var a = phase ? frame.Position + new Vector2(-5, -5) : frame.Position + new Vector2(frame.Size.X + 4, -5);
        var b = phase ? frame.End + new Vector2(4, 4) : frame.Position + new Vector2(-5, frame.Size.Y + 4);
        foreach (var p in new[] { a, b })
        {
            DrawRect(new Rect2(p, Vector2.One), Colors.White);
            DrawRect(new Rect2(p + new Vector2(-1, 0), Vector2.One), new Color(PixelArt.Gold, 0.8f));
            DrawRect(new Rect2(p + new Vector2(1, 0), Vector2.One), new Color(PixelArt.Gold, 0.8f));
            DrawRect(new Rect2(p + new Vector2(0, -1), Vector2.One), new Color(PixelArt.Gold, 0.8f));
            DrawRect(new Rect2(p + new Vector2(0, 1), Vector2.One), new Color(PixelArt.Gold, 0.8f));
        }
    }
}

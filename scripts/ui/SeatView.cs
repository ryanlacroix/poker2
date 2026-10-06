using System.Collections.Generic;
using Godot;

namespace PokerGame;

/// <summary>
/// Wide: the human's seat, with 2x cards beside the portrait. Compact: the NPC columns, 1x cards
/// beside the portrait (mirrored on the right); text aligns toward the middle of the screen so
/// long labels never run off it.
/// </summary>
public enum SeatStyle { Wide, CompactLeft, CompactRight }

/// <summary>One player's spot at the table: portrait, hole cards, name, stack and last action.</summary>
public partial class SeatView : Control
{
    public static readonly Vector2 WideSize = new(160, 74 + UiTheme.LineHeight * 2);
    public static readonly Vector2 CompactSize = new(106, 52 + UiTheme.LineHeight * 3);
    /// <summary>Portraits: the 16px art at a crisp 3x.</summary>
    public static readonly Vector2 PortraitSize = new(48, 48);
    private const int WideCardScale = 2;

    public PokerPlayer Player { get; init; } = null!;
    public Texture2D? Portrait { get; init; }
    public SeatStyle Style { get; init; }
    /// <summary>Heart slots to draw; lost hearts show as empty.</summary>
    public int MaxHearts { get; init; } = 3;

    public static Vector2 SizeFor(SeatStyle style) => style == SeatStyle.Wide ? WideSize : CompactSize;
    public Vector2 SeatSize => SizeFor(Style);
    private bool IsCompact => Style != SeatStyle.Wide;
    private static float WideLabelsY => CardView.CardSize.Y * WideCardScale + 2; // just under the 2x cards
    // Compact seats mirror: left column is [portrait][cards], right column is [cards][portrait].
    private Rect2 PortraitFrame => Style switch
    {
        SeatStyle.CompactLeft => new Rect2(new Vector2(1, 1), PortraitSize),
        SeatStyle.CompactRight => new Rect2(new Vector2(CompactSize.X - 1 - PortraitSize.X, 1), PortraitSize),
        _ => new Rect2(new Vector2(1, 12), PortraitSize),
    };

    private CardView[] _cards = System.Array.Empty<CardView>();
    private readonly Label _name = new();
    private readonly Label _chips = new();
    private readonly Label _status = new();
    private bool _isDealer;
    private bool _isActive;
    private bool _reveal;
    private bool _isWinner;
    private bool _isTarget;
    private double _hitAt = -1;
    private const double HitSeconds = 0.6;

    /// <summary>Raised when the human taps this seat while it is targetable.</summary>
    public event System.Action<SeatView>? Targeted;

    public override void _Ready()
    {
        Size = SeatSize;
        MouseFilter = MouseFilterEnum.Ignore;
        SetProcess(false); // only runs while the winner glow animates
        // Cards sit beside the portrait (on the inner side for compact seats).
        int cardScale = IsCompact ? 1 : WideCardScale;
        _cards = new[] { new CardView { PixelScale = cardScale }, new CardView { PixelScale = cardScale } };
        var cardsOrigin = Style switch
        {
            SeatStyle.CompactLeft => new Vector2(PortraitSize.X + 4, 7),
            SeatStyle.CompactRight => new Vector2(0, 7),
            _ => new Vector2(PortraitSize.X + 4, 0),
        };
        for (int i = 0; i < 2; i++)
        {
            _cards[i].Position = cardsOrigin + new Vector2(i * (CardView.CardSize.X * cardScale + 2), 0);
            AddChild(_cards[i]);
        }
        float labelsY = IsCompact ? 52 : WideLabelsY;
        if (IsCompact)
        {
            // Name; then hearts under it with the chips at the far end of that line; then status.
            var chipsAlign = Style == SeatStyle.CompactLeft ? HorizontalAlignment.Right : HorizontalAlignment.Left;
            AddLabel(_name, labelsY, PixelArt.Paper);
            AddLabel(_chips, labelsY + UiTheme.LineHeight, PixelArt.Gold, chipsAlign);
            AddLabel(_status, labelsY + UiTheme.LineHeight * 2, new Color("9fe0a0"));
        }
        else
        {
            // Name left and chips right; hearts under the name with the status at the right.
            AddLabel(_name, labelsY, PixelArt.Paper, HorizontalAlignment.Left);
            AddLabel(_chips, labelsY, PixelArt.Gold, HorizontalAlignment.Right);
            AddLabel(_status, labelsY + UiTheme.LineHeight, new Color("9fe0a0"), HorizontalAlignment.Right);
        }
        _name.Text = Player.DisplayName;
        Refresh();
    }

    private void AddLabel(Label label, float y, Color color, HorizontalAlignment? align = null)
    {
        label.HorizontalAlignment = align ?? Style switch
        {
            SeatStyle.CompactLeft => HorizontalAlignment.Left,
            SeatStyle.CompactRight => HorizontalAlignment.Right,
            _ => HorizontalAlignment.Center,
        };
        label.AddThemeColorOverride("font_color", color);
        this.AddAt(label, new Vector2(0, y), new Vector2(SeatSize.X, UiTheme.LineHeight));
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
        UpdateProcessing();
        QueueRedraw();
    }

    /// <summary>Target mode: the portrait pulses red and the seat accepts a tap.</summary>
    public void SetTargetable(bool value)
    {
        _isTarget = value;
        MouseFilter = value ? MouseFilterEnum.Stop : MouseFilterEnum.Ignore;
        MouseDefaultCursorShape = CursorShape.PointingHand;
        UpdateProcessing();
        QueueRedraw();
    }

    /// <summary>Brief red flash on the portrait after being shot.</summary>
    public void FlashHit()
    {
        _hitAt = Time.GetTicksMsec() / 1000.0;
        UpdateProcessing();
    }

    private bool HitActive => _hitAt >= 0 && Time.GetTicksMsec() / 1000.0 - _hitAt < HitSeconds;

    // Only redraw every frame while something is animating.
    private void UpdateProcessing() => SetProcess(_isWinner || _isTarget || HitActive);

    public override void _GuiInput(InputEvent @event)
    {
        if (_isTarget && @event is InputEventMouseButton { Pressed: true, ButtonIndex: MouseButton.Left })
        {
            AcceptEvent();
            Targeted?.Invoke(this);
        }
    }

    /// <summary>Sets each hole card's highlight from <paramref name="highlightFor"/>.</summary>
    public void HighlightCards(System.Func<Card?, CardHighlight> highlightFor)
    {
        foreach (var view in _cards)
            view.SetHighlight(highlightFor(view.Card));
    }

    public override void _Process(double delta)
    {
        QueueRedraw(); // animates the winner / target glow and the hit flash
        if (!_isWinner && !_isTarget && !HitActive) SetProcess(false);
    }

    public override void _Draw()
    {
        // Dark backing so labels stay readable over any part of the map.
        DrawRect(new Rect2(-1, -1, SeatSize + new Vector2(2, 2)), new Color(0.05f, 0.06f, 0.11f, 0.78f));
        if (_isActive)
            DrawRect(new Rect2(-2, -2, SeatSize + new Vector2(4, 4)), PixelArt.Gold, false, 1);
        if (Portrait != null)
        {
            var frame = PortraitFrame;
            bool dimmed = Player.Folded || Player.IsOut;
            if (_isWinner)
            {
                DrawWinnerGlow(frame);
            }
            else if (_isTarget)
            {
                DrawTargetGlow(frame);
            }
            else
            {
                DrawRect(frame.Grow(1), dimmed ? PixelArt.Ink : PixelArt.Paper, false, 1);
                DrawTextureRect(Portrait, frame, false, dimmed ? new Color(0.45f, 0.45f, 0.5f) : Colors.White);
            }
            if (HitActive)
            {
                float k = 1f - (float)((Time.GetTicksMsec() / 1000.0 - _hitAt) / HitSeconds);
                bool blink = (int)(Time.GetTicksMsec() / 80) % 2 == 0;
                DrawRect(frame, new Color(blink ? Colors.White : PixelArt.HeartRed, 0.65f * k));
            }
        }
        DrawHearts();
        if (_isDealer)
        {
            var origin = Style switch
            {
                SeatStyle.CompactLeft => new Vector2(SeatSize.X - 10, 53),
                SeatStyle.CompactRight => new Vector2(1, 53),
                _ => new Vector2(1, PortraitFrame.End.Y + 3), // under the portrait
            };
            DrawRect(new Rect2(origin, new Vector2(9, 9)), PixelArt.Paper);
            DrawRect(new Rect2(origin, new Vector2(9, 9)), PixelArt.Ink, false, 1);
            PixelArt.Draw(this, PixelArt.Glyphs['D'], origin + new Vector2(3, 2), 1, PixelArt.Ink);
        }
    }

    /// <summary>Pixel hearts (2x) on the line under the name: full for lives left, empty for lost.</summary>
    private void DrawHearts()
    {
        const int px = 2, spacing = 2;
        float heartW = PixelArt.Heart[0].Length * px, heartH = PixelArt.Heart.Length * px;
        float rowWidth = MaxHearts * heartW + (MaxHearts - 1) * spacing;
        float lineY = (IsCompact ? 52 : WideLabelsY) + UiTheme.LineHeight;
        float x = Style == SeatStyle.CompactRight ? SeatSize.X - 2 - rowWidth : 2;
        float y = lineY + Mathf.Floor((UiTheme.LineHeight - heartH) / 2);

        for (int i = 0; i < MaxHearts; i++)
        {
            // Right-column seats fill from the right, so the hearts read toward the name's end.
            bool full = Style == SeatStyle.CompactRight ? i >= MaxHearts - Player.Hearts : i < Player.Hearts;
            var origin = new Vector2(x + i * (heartW + spacing), y);
            foreach (var d in new[] { Vector2.Left, Vector2.Right, Vector2.Up, Vector2.Down })
                PixelArt.Draw(this, PixelArt.Heart, origin + d, px, PixelArt.Ink); // 1px outline
            PixelArt.Draw(this, PixelArt.Heart, origin, px, full ? PixelArt.HeartRed : PixelArt.HeartEmpty);
            if (full)
                DrawRect(new Rect2(origin + new Vector2(px, px), new Vector2(px, px)), new Color(1, 1, 1, 0.7f)); // shine
        }
    }

    /// <summary>Red pulsing halo and tint for a seat that can be targeted, plus a red seat outline.</summary>
    private void DrawTargetGlow(Rect2 frame)
    {
        float t = Time.GetTicksMsec() / 1000f;
        float pulse = 0.55f + 0.45f * Mathf.Sin(t * 6f);
        var red = PixelArt.HeartRed;
        DrawRect(new Rect2(-2, -2, SeatSize + new Vector2(4, 4)), new Color(red, 0.5f + 0.5f * pulse), false, 1);
        DrawRect(frame.Grow(4), new Color(red, 0.3f * pulse), false, 1);
        DrawRect(frame.Grow(3), new Color(red, 0.6f * pulse), false, 1);
        DrawRect(frame.Grow(2), new Color("ff8a8a"), false, 1);
        DrawRect(frame.Grow(1), red, false, 1);
        DrawTextureRect(Portrait!, frame, false, Colors.White.Lerp(new Color("ff9090"), 0.55f * pulse));
        DrawRect(frame, new Color(red, 0.22f * pulse));
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

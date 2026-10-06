using Godot;

namespace PokerGame;

/// <summary>
/// Big centred announcement of the winning hand ("FULL HOUSE") with the winner's name under it.
/// Text is drawn at the normal font size and blown up by a whole-number scale, so each font
/// pixel becomes a crisp block. Shown for <see cref="HoldTime"/>, then fades out.
/// </summary>
public partial class WinBanner : Control
{
    private const float HoldTime = 1.0f;
    private const float FadeTime = 0.4f;
    private const int MaxTitleScale = 3;
    private const int OutlineSize = 4; // in unscaled font pixels: 2 on each side
    private const int SideMargin = 8;
    private const int LineGap = 4;

    private string _title = "";
    private string _subtitle = "";
    private Tween? _tween;

    /// <summary>Lowest y the text may reach; the banner rises above it (e.g. to clear the board).</summary>
    public float MaxBottom { get; set; } = float.MaxValue;

    /// <summary>Raised once the banner has faded out (not when it's cut short by <see cref="Hide"/>).</summary>
    public event System.Action? Finished;

    public override void _Ready()
    {
        MouseFilter = MouseFilterEnum.Ignore;
        Visible = false;
    }

    public void Show(string title, string subtitle)
    {
        _title = title;
        _subtitle = subtitle;
        _tween?.Kill();
        Modulate = Colors.White;
        Visible = true;
        QueueRedraw();
        _tween = CreateTween();
        _tween.TweenInterval(HoldTime);
        _tween.TweenProperty(this, "modulate:a", 0f, FadeTime);
        _tween.TweenCallback(Callable.From(() =>
        {
            Visible = false;
            Finished?.Invoke();
        }));
    }

    public new void Hide()
    {
        _tween?.Kill();
        Visible = false;
    }

    public override void _Draw()
    {
        var font = GetThemeDefaultFont();
        int size = UiTheme.FontSize;

        // Largest whole-number scale that keeps the title on screen; the name goes one step smaller.
        float titleWidth = font.GetStringSize(_title, HorizontalAlignment.Left, -1, size).X + OutlineSize;
        int titleScale = MaxTitleScale;
        while (titleScale > 1 && titleWidth * titleScale > Size.X - SideMargin * 2) titleScale--;
        int subtitleScale = Mathf.Max(1, titleScale - 1);

        float lineHeight = font.GetHeight(size);
        float totalHeight = lineHeight * titleScale + LineGap + lineHeight * subtitleScale;
        float top = Mathf.Floor(Mathf.Min(Size.Y / 2 - totalHeight / 2, MaxBottom - totalHeight));
        DrawLine(font, size, _title, titleScale, top);
        DrawLine(font, size, _subtitle, subtitleScale, top + lineHeight * titleScale + LineGap);
        DrawSetTransform(Vector2.Zero);
    }

    /// <summary>White text with a black outline, centred horizontally, its top at <paramref name="top"/>.</summary>
    private void DrawLine(Font font, int size, string text, int scale, float top)
    {
        float width = font.GetStringSize(text, HorizontalAlignment.Left, -1, size).X * scale;
        var origin = new Vector2(Mathf.Floor((Size.X - width) / 2), top);
        DrawSetTransform(origin, 0, Vector2.One * scale);
        var baseline = new Vector2(0, font.GetAscent(size));
        DrawStringOutline(font, baseline, text, HorizontalAlignment.Left, -1, size, OutlineSize, Colors.Black);
        DrawString(font, baseline, text, HorizontalAlignment.Left, -1, size, Colors.White);
    }
}

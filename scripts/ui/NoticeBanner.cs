using System.Collections.Generic;
using Godot;

namespace PokerGame;

/// <summary>
/// Caption-style notices: a translucent black strip across the full width of the screen with
/// white text on it. Queued messages play one at a time, each shown for <see cref="HoldTime"/>
/// and then faded out. The node's rect is the strip.
/// </summary>
public partial class NoticeBanner : Control
{
    private const float HoldTime = 1.0f;
    private const float FadeTime = 0.4f;
    public const float StripHeight = 30;

    private readonly Queue<string> _queue = new();
    private string _text = "";
    private Tween? _tween;

    /// <summary>Raised when the last queued notice has faded out (not when cut short by <see cref="Clear"/>).</summary>
    public event System.Action? Finished;

    public override void _Ready()
    {
        MouseFilter = MouseFilterEnum.Ignore;
        Visible = false;
    }

    public void Enqueue(string text)
    {
        _queue.Enqueue(text);
        if (!Visible) ShowNext();
    }

    public void Clear()
    {
        _queue.Clear();
        _tween?.Kill();
        Visible = false;
    }

    private void ShowNext()
    {
        if (!_queue.TryDequeue(out var text))
        {
            Visible = false;
            Finished?.Invoke();
            return;
        }
        _text = text;
        Modulate = Colors.White;
        Visible = true;
        QueueRedraw();
        _tween?.Kill();
        _tween = CreateTween();
        _tween.TweenInterval(HoldTime);
        _tween.TweenProperty(this, "modulate:a", 0f, FadeTime);
        _tween.TweenCallback(Callable.From(ShowNext));
    }

    public override void _Draw()
    {
        DrawRect(new Rect2(Vector2.Zero, Size), new Color(0, 0, 0, 0.6f));
        var font = GetThemeDefaultFont();
        int size = UiTheme.FontSize;
        float baseline = Mathf.Floor((Size.Y + font.GetAscent(size) - font.GetDescent(size)) / 2);
        DrawString(font, new Vector2(0, baseline), _text, HorizontalAlignment.Center, Size.X, size, Colors.White);
    }
}

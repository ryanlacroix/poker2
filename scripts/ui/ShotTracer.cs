using Godot;

namespace PokerGame;

/// <summary>
/// A gunshot tracer: a glowing red line flashed between shooter and target that quickly fades.
/// Full-screen and click-through; <see cref="Fire"/> draws one.
/// </summary>
public partial class ShotTracer : Control
{
    private const double FadeSeconds = 0.35;

    private Vector2 _from;
    private Vector2 _to;
    private Tween? _tween;

    public override void _Ready()
    {
        MouseFilter = MouseFilterEnum.Ignore;
        Visible = false;
    }

    /// <summary>Flashes the tracer from <paramref name="from"/> to <paramref name="to"/> (local coordinates).</summary>
    public void Fire(Vector2 from, Vector2 to)
    {
        _from = from.Floor();
        _to = to.Floor();
        _tween?.Kill();
        Modulate = Colors.White;
        Visible = true;
        QueueRedraw();
        _tween = CreateTween();
        _tween.TweenProperty(this, "modulate:a", 0f, FadeSeconds)
            .SetTrans(Tween.TransitionType.Quad).SetEase(Tween.EaseType.Out);
        _tween.TweenCallback(Callable.From(Hide));
    }

    public override void _Draw()
    {
        // Wide faint glow, a brighter band, then a hot near-white core.
        DrawLine(_from, _to, new Color(PixelArt.HeartRed, 0.35f), 11);
        DrawLine(_from, _to, new Color(PixelArt.HeartRed, 0.6f), 7);
        DrawLine(_from, _to, new Color(PixelArt.HeartRed, 0.9f), 5);
        DrawLine(_from, _to, new Color("ff6a6a"), 3);
        DrawLine(_from, _to, new Color("ffe0e0"), 1);
    }
}

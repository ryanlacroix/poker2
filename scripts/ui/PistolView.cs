using Godot;

namespace PokerGame;

/// <summary>
/// The pixel-art pistol floating in the middle of the screen while the human picks a target:
/// large, with a pulsing halo so it stands out against the cards and felt. Bobs gently;
/// <see cref="Fire"/> shows a muzzle flash and a little recoil.
/// </summary>
public partial class PistolView : Control
{
    public const int PixelScale = 5;
    private const int FlashScale = 4;
    private const float MuzzleRow = 4.5f; // vertical centre of the barrel, in art pixels
    public static readonly Vector2 ArtSize = new Vector2(PixelArt.Pistol[0].Length, PixelArt.Pistol.Length) * PixelScale;

    private double _firedAt = -1;
    private const double FlashSeconds = 0.25;

    public override void _Ready()
    {
        Size = ArtSize;
        MouseFilter = MouseFilterEnum.Ignore;
    }

    public void Fire()
    {
        _firedAt = Time.GetTicksMsec() / 1000.0;
        QueueRedraw();
    }

    public override void _Process(double delta) => QueueRedraw();

    public override void _Draw()
    {
        double now = Time.GetTicksMsec() / 1000.0;
        bool flashing = _firedAt >= 0 && now - _firedAt < FlashSeconds;
        var offset = flashing
            ? new Vector2(-PixelScale, 0)                                         // recoil
            : new Vector2(0, Mathf.Round(Mathf.Sin((float)now * 3f) * 1.5f) * 2); // idle bob

        float pulse = 0.5f + 0.5f * Mathf.Sin((float)now * 6f);

        // Pale-gold halo around the silhouette, then the pistol itself.
        var halo = new Color("ffe9a0", 0.45f + 0.4f * pulse);
        foreach (var d in new Vector2[] { new(-3, 0), new(3, 0), new(0, -3), new(0, 3), new(-2, -2), new(2, -2), new(-2, 2), new(2, 2) })
            PixelArt.Draw(this, PixelArt.Pistol, offset + d, PixelScale, halo);
        PixelArt.DrawColored(this, PixelArt.Pistol, PixelArt.PistolColors, offset, PixelScale);

        if (flashing)
        {
            // Flash just past the muzzle.
            var flashSize = new Vector2(PixelArt.MuzzleFlash[0].Length, PixelArt.MuzzleFlash.Length) * FlashScale;
            var muzzle = offset + new Vector2(PixelArt.Pistol[0].Length * PixelScale, MuzzleRow * PixelScale - flashSize.Y / 2);
            PixelArt.DrawColored(this, PixelArt.MuzzleFlash, PixelArt.FlashColors, muzzle, FlashScale);
        }
    }
}

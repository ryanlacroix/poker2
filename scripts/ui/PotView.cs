using Godot;

namespace PokerGame;

/// <summary>
/// The pot display under the board: a pixel-art pot of gold followed by the amount ("$70"),
/// centred as a unit. <see cref="FontSize"/> drives the pop animation; the icon steps up
/// in whole-pixel scales alongside the text so it stays crisp.
/// </summary>
public partial class PotView : Control
{
    private const int Gap = 4;
    private int _amount;
    private int _fontSize = UiTheme.FontSize;

    public int Amount
    {
        get => _amount;
        set { _amount = value; QueueRedraw(); }
    }

    public int FontSize
    {
        get => _fontSize;
        set { _fontSize = value; QueueRedraw(); }
    }

    public override void _Ready() => MouseFilter = MouseFilterEnum.Ignore;

    public override void _Draw()
    {
        if (_amount <= 0) return;

        var font = GetThemeDefaultFont();
        string text = $"${_amount}";
        float textWidth = font.GetStringSize(text, HorizontalAlignment.Left, -1, _fontSize).X;

        // Icon roughly as tall as the text: 2x at the resting size, 3x at the peak of a pop.
        int px = Mathf.Max(1, Mathf.RoundToInt(_fontSize / 9f));
        var icon = new Vector2(PixelArt.PotOfGold[0].Length, PixelArt.PotOfGold.Length) * px;

        float left = Mathf.Floor((Size.X - (icon.X + Gap + textWidth)) / 2);
        float midY = Size.Y / 2;
        PixelArt.DrawColored(this, PixelArt.PotOfGold, PixelArt.PotOfGoldColors,
            new Vector2(left, Mathf.Floor(midY - icon.Y / 2)), px);

        // Baseline that vertically centres the text's cap height on the icon.
        float baseline = Mathf.Floor(midY + (font.GetAscent(_fontSize) - font.GetDescent(_fontSize)) / 2);
        DrawString(font, new Vector2(left + icon.X + Gap, baseline), text,
            HorizontalAlignment.Left, -1, _fontSize, PixelArt.Gold);
    }
}

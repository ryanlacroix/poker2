using Godot;

namespace PokerGame;

/// <summary>
/// Modal popup of debug / testing actions, opened from the table's DEBUG button. Dims the
/// screen and blocks input to the table; clicking outside the panel (or CLOSE) dismisses it.
/// </summary>
public partial class DebugMenu : Control
{
    /// <summary>Draws over everything on the table, including portraits and the pistol.</summary>
    private const int ModalZ = 10;

    /// <summary>Raised when a "give" action is picked; the menu closes itself.</summary>
    public event System.Action<Item>? GiveItem;

    public override void _Ready()
    {
        Visible = false;
        ZIndex = ModalZ;
        MouseFilter = MouseFilterEnum.Ignore;

        var dim = new ColorRect { Color = new Color(0, 0, 0, 0.6f) };
        dim.SetAnchorsPreset(LayoutPreset.FullRect);
        dim.GuiInput += e =>
        {
            if (e is InputEventMouseButton { Pressed: true }) Hide();
        };
        AddChild(dim);

        var center = new CenterContainer { MouseFilter = MouseFilterEnum.Ignore };
        center.SetAnchorsPreset(LayoutPreset.FullRect);
        AddChild(center);
        var panel = new PanelContainer();
        center.AddChild(panel);
        var box = new VBoxContainer();
        box.AddThemeConstantOverride("separation", 8);
        panel.AddChild(box);

        var title = new Label { Text = "DEBUG", HorizontalAlignment = HorizontalAlignment.Center };
        title.AddThemeColorOverride("font_color", PixelArt.Gold);
        box.AddChild(title);
        AddButton(box, "GIVE GUN", () => Give(Item.Pistol));
        AddButton(box, "GIVE SHIELD", () => Give(Item.Shield));
        AddButton(box, "CLOSE", Hide);
    }

    private static void AddButton(Container box, string text, System.Action onPressed)
    {
        var button = new Button { Text = text, CustomMinimumSize = new Vector2(160, 36) };
        button.Pressed += onPressed;
        box.AddChild(button);
    }

    private void Give(Item item)
    {
        Hide();
        GiveItem?.Invoke(item);
    }
}

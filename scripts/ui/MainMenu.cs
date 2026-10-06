using Godot;

namespace PokerGame;

/// <summary>Title screen.</summary>
public partial class MainMenu : Control
{
    private readonly Texture2D _worldMap = GD.Load<Texture2D>(UiTheme.WorldMapPath);

    public override void _Ready()
    {
        Resized += QueueRedraw;

        var center = new CenterContainer();
        center.SetAnchorsPreset(LayoutPreset.FullRect);
        AddChild(center);
        var box = new VBoxContainer();
        box.AddThemeConstantOverride("separation", 10);
        center.AddChild(box);

        var title = new Label { Text = "PIXEL POKER", HorizontalAlignment = HorizontalAlignment.Center };
        title.AddThemeFontSizeOverride("font_size", 44);
        title.AddThemeColorOverride("font_color", PixelArt.Gold);
        box.AddChild(title);
        box.AddChild(new Label { Text = "No-limit Texas Hold'em", HorizontalAlignment = HorizontalAlignment.Center });
        box.AddChild(new Control { CustomMinimumSize = new Vector2(0, 16) });

        var play = new Button { Text = "PLAY", CustomMinimumSize = new Vector2(160, 36) };
        play.Pressed += () => GetTree().ChangeSceneToFile("res://scenes/table.tscn");
        box.AddChild(play);
        var quit = new Button { Text = "QUIT", CustomMinimumSize = new Vector2(160, 36) };
        quit.Pressed += () => GetTree().Quit();
        box.AddChild(quit);
        play.CallDeferred(Control.MethodName.GrabFocus);
    }

    public override void _Draw() => UiTheme.DrawWorldMap(this, _worldMap, Size);
}

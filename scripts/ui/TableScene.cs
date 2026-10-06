using System;
using System.Collections.Generic;
using System.Linq;
using Godot;

namespace PokerGame;

/// <summary>
/// Visual layer for a poker table. Builds the UI, owns a <see cref="PokerTable"/>, and
/// translates its events into on-screen updates and human input back into decisions.
/// </summary>
public partial class TableScene : Control
{
    private static readonly Vector2 FeltCenter = new(320, 160);
    private static readonly Vector2 FeltRadii = new(250, 108);
    private static readonly Vector2 SeatRadii = new(262, 118);
    private const int LogLines = 3;

    private PokerTable _table = null!;
    private readonly Texture2D _worldMap = GD.Load<Texture2D>(UiTheme.WorldMapPath);
    private readonly List<SeatView> _seats = new();
    private readonly List<CardView> _community = new();
    private readonly Queue<string> _log = new();
    private Label _potLabel = null!;
    private Label _logLabel = null!;
    private Panel _actionBar = null!;
    private Button _foldButton = null!;
    private Button _callButton = null!;
    private Button _raiseButton = null!;
    private HSlider _raiseSlider = null!;
    private Label _raiseLabel = null!;
    private int _toCall;

    public override void _Ready()
    {
        var cfg = GameConfig.Instance;
        _table = new PokerTable
        {
            SmallBlind = cfg.SmallBlind,
            BigBlind = cfg.BigBlind,
            NpcThinkTime = cfg.NpcThinkTime,
            DealDelay = cfg.DealDelay,
            ShowdownDelay = cfg.ShowdownDelay,
            BetweenHandsDelay = cfg.BetweenHandsDelay,
        };
        AddChild(_table);
        _table.Setup(cfg.CreatePlayers());

        BuildUi();
        ConnectTable();
        _table.StartGame();
    }

    public override void _Draw()
    {
        DrawTextureRect(_worldMap, new Rect2(Vector2.Zero, Size), false);
        DrawColoredPolygon(Ellipse(FeltCenter, FeltRadii + new Vector2(8, 8)), new Color("5a3a22"));
        DrawColoredPolygon(Ellipse(FeltCenter, FeltRadii), new Color("1f6b3a"));
        DrawColoredPolygon(Ellipse(FeltCenter, FeltRadii - new Vector2(14, 14)), new Color("247a43"));
    }

    private static Vector2[] Ellipse(Vector2 center, Vector2 radii, int points = 64) =>
        Enumerable.Range(0, points)
            .Select(i => center + new Vector2(Mathf.Cos(Mathf.Tau * i / points), Mathf.Sin(Mathf.Tau * i / points)) * radii)
            .ToArray();

    // --- UI construction ---------------------------------------------------

    private void BuildUi()
    {
        // Seats go clockwise starting at the bottom (the human).
        var humanPortrait = GD.Load<Texture2D>(GameConfig.Instance.PlayerPortraitPath);
        int n = _table.Players.Count;
        for (int i = 0; i < n; i++)
        {
            float angle = Mathf.Pi / 2 + Mathf.Tau * i / n;
            var center = FeltCenter + new Vector2(Mathf.Cos(angle), Mathf.Sin(angle)) * SeatRadii;
            var player = _table.Players[i];
            var seat = new SeatView
            {
                Player = player,
                Portrait = player.Brain?.Portrait ?? humanPortrait,
                Position = (center - SeatView.SeatSize / 2).Round(),
            };
            AddChild(seat);
            _seats.Add(seat);
        }

        float rowWidth = 5 * CardView.CardSize.X + 4 * 4;
        for (int i = 0; i < 5; i++)
        {
            var view = new CardView
            {
                ShowEmptySlot = true,
                Position = new Vector2(FeltCenter.X - rowWidth / 2 + i * (CardView.CardSize.X + 4), FeltCenter.Y - 24).Round(),
            };
            AddChild(view);
            _community.Add(view);
        }

        _potLabel = new Label
        {
            Position = new Vector2(FeltCenter.X - 60, FeltCenter.Y + 16),
            Size = new Vector2(120, 12),
            HorizontalAlignment = HorizontalAlignment.Center,
        };
        _potLabel.AddThemeColorOverride("font_color", PixelArt.Gold);
        AddChild(_potLabel);

        var logPanel = new Panel { Position = new Vector2(4, 318), Size = new Vector2(232, 38) };
        AddChild(logPanel);
        _logLabel = new Label { Position = new Vector2(4, 0), Size = new Vector2(224, 38) };
        _logLabel.AddThemeConstantOverride("line_spacing", -2);
        logPanel.AddChild(_logLabel);

        var menuButton = new Button { Text = "MENU", Position = new Vector2(4, 4), Size = new Vector2(40, 16) };
        menuButton.Pressed += () => GetTree().ChangeSceneToFile("res://scenes/main_menu.tscn");
        AddChild(menuButton);

        BuildActionBar();
    }

    private void BuildActionBar()
    {
        _actionBar = new Panel { Position = new Vector2(392, 316), Size = new Vector2(244, 40), Visible = false };
        AddChild(_actionBar);

        _raiseSlider = new HSlider { Position = new Vector2(4, 3), Size = new Vector2(160, 12), Step = 1 };
        _raiseSlider.ValueChanged += _ => UpdateRaiseLabel();
        _actionBar.AddChild(_raiseSlider);
        _raiseLabel = new Label { Position = new Vector2(168, 1), Size = new Vector2(72, 12), HorizontalAlignment = HorizontalAlignment.Right };
        _actionBar.AddChild(_raiseLabel);

        _foldButton = ActionButton("FOLD", 4, () => Submit(new Decision(PokerAction.Fold)));
        _callButton = ActionButton("CALL", 84, () => Submit(new Decision(_toCall == 0 ? PokerAction.Check : PokerAction.Call)));
        _raiseButton = ActionButton("RAISE", 164, () => Submit(new Decision(PokerAction.Raise, (int)_raiseSlider.Value)));
    }

    private Button ActionButton(string text, float x, Action onPressed)
    {
        var button = new Button { Text = text, Position = new Vector2(x, 19), Size = new Vector2(76, 18) };
        button.Pressed += onPressed;
        _actionBar.AddChild(button);
        return button;
    }

    private void Submit(Decision decision)
    {
        _actionBar.Visible = false;
        _table.SubmitHumanAction(decision);
    }

    private void UpdateRaiseLabel()
    {
        bool allIn = (int)_raiseSlider.Value >= (int)_raiseSlider.MaxValue;
        _raiseLabel.Text = allIn ? "ALL IN" : $"TO ${(int)_raiseSlider.Value}";
    }

    // --- Human input -------------------------------------------------------

    private void ShowActions(PokerPlayer p, int toCall, int minTo, int maxTo)
    {
        _toCall = toCall;
        _callButton.Text = toCall == 0 ? "CHECK" : toCall >= p.Chips ? "ALL IN" : $"CALL ${toCall}";

        bool canRaise = p.Chips > toCall;
        _raiseButton.Disabled = !canRaise;
        _raiseSlider.Editable = canRaise && maxTo > minTo;
        _raiseSlider.MinValue = minTo;
        _raiseSlider.MaxValue = maxTo;
        _raiseSlider.Value = minTo;
        _raiseButton.Text = _table.CurrentBet == 0 ? "BET" : "RAISE";
        UpdateRaiseLabel();
        _actionBar.Visible = true;
    }

    public override void _UnhandledKeyInput(InputEvent @event)
    {
        if (!_actionBar.Visible || @event is not InputEventKey { Pressed: true, Echo: false } key) return;
        switch (key.Keycode)
        {
            case Key.F: _foldButton.EmitSignal(BaseButton.SignalName.Pressed); break;
            case Key.C: _callButton.EmitSignal(BaseButton.SignalName.Pressed); break;
            case Key.R when !_raiseButton.Disabled: _raiseButton.EmitSignal(BaseButton.SignalName.Pressed); break;
        }
    }

    // --- Table events ------------------------------------------------------

    private void ConnectTable()
    {
        _table.Message += AddLog;
        _table.HandStarted += (number, dealer) =>
        {
            AddLog($"-- HAND {number} --");
            foreach (var seat in _seats)
            {
                seat.SetDealer(seat.Player.Seat == dealer);
                seat.SetReveal(false);
                seat.SetStatus("");
            }
            foreach (var view in _community) view.SetCard(null, false);
        };
        _table.StreetStarted += street =>
        {
            if (street == Street.Preflop) return;
            AddLog(PokerText.StreetName(street));
            foreach (var seat in _seats.Where(s => s.Player.InHand && !s.Player.AllIn))
                seat.SetStatus("");
        };
        _table.HoleCardsDealt += RefreshSeats;
        _table.CommunityChanged += cards =>
        {
            for (int i = 0; i < _community.Count; i++)
                _community[i].SetCard(i < cards.Count ? cards[i] : null, true);
        };
        _table.TurnStarted += (player, toCall, minTo, maxTo) =>
        {
            foreach (var seat in _seats) seat.SetActive(seat.Player == player);
            if (player.IsHuman) ShowActions(player, toCall, minTo, maxTo);
        };
        _table.PlayerActed += (player, action, amount) =>
        {
            string text = action switch
            {
                PokerAction.Fold => "FOLD",
                PokerAction.Check => "CHECK",
                PokerAction.Call => $"CALL {amount}",
                _ => $"RAISE TO {amount}",
            };
            if (player.AllIn && action != PokerAction.Fold) text = "ALL IN";
            _seats[player.Seat].SetStatus(text);
            _seats[player.Seat].SetActive(false);
            AddLog($"{player.DisplayName}: {text.ToLower()}");
        };
        _table.ChipsChanged += RefreshSeats;
        _table.Showdown += (contenders, scores) =>
        {
            foreach (var p in contenders)
            {
                _seats[p.Seat].SetReveal(true);
                _seats[p.Seat].SetStatus(HandEvaluator.Describe(scores[p]).ToUpper(), PixelArt.Paper);
            }
        };
        _table.PotAwarded += (player, amount, handName) =>
        {
            _seats[player.Seat].SetStatus($"WINS ${amount}", PixelArt.Gold);
            AddLog(handName == ""
                ? $"{player.DisplayName} wins ${amount}"
                : $"{player.DisplayName} wins ${amount} ({handName})");
        };
        _table.GameOver += ShowGameOver;
    }

    private void RefreshSeats()
    {
        foreach (var seat in _seats) seat.Refresh();
        _potLabel.Text = _table.Pot > 0 ? $"POT ${_table.Pot}" : "";
    }

    private void AddLog(string line)
    {
        _log.Enqueue(line);
        while (_log.Count > LogLines) _log.Dequeue();
        _logLabel.Text = string.Join("\n", _log);
    }

    private void ShowGameOver(PokerPlayer winner)
    {
        _actionBar.Visible = false;
        var center = new CenterContainer();
        center.SetAnchorsPreset(LayoutPreset.FullRect);
        AddChild(center);
        var panel = new PanelContainer();
        center.AddChild(panel);
        var box = new VBoxContainer { Alignment = BoxContainer.AlignmentMode.Center };
        box.AddThemeConstantOverride("separation", 8);
        panel.AddChild(box);

        var title = new Label
        {
            Text = winner.IsHuman ? "YOU WIN!" : "BUSTED!",
            HorizontalAlignment = HorizontalAlignment.Center,
        };
        title.AddThemeFontSizeOverride("font_size", 24);
        title.AddThemeColorOverride("font_color", PixelArt.Gold);
        box.AddChild(title);
        box.AddChild(new Label
        {
            Text = winner.IsHuman ? "You took every chip at the table." : $"{winner.DisplayName} leads with ${winner.Chips}.",
            HorizontalAlignment = HorizontalAlignment.Center,
        });
        var again = new Button { Text = "PLAY AGAIN" };
        again.Pressed += () => GetTree().ReloadCurrentScene();
        box.AddChild(again);
        var menu = new Button { Text = "MAIN MENU" };
        menu.Pressed += () => GetTree().ChangeSceneToFile("res://scenes/main_menu.tscn");
        box.AddChild(menu);
    }
}

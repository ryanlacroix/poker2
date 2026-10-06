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
    // Stack pile (no label) and bet pile (with label) offsets from a pair's centre.
    private static readonly Vector2 StackPileOffset = new(-22, 0);
    private static readonly Vector2 BetPileOffset = new(22, 0);
    private static readonly Vector2 StackPileOffsetVertical = new(0, -19);
    private static readonly Vector2 BetPileOffsetVertical = new(0, 19);

    /// <summary>Area a stack-over-bet pile pair can cover, relative to its centre.</summary>
    public static Rect2 VerticalPileUnitBounds => PairBounds(StackPileOffsetVertical, BetPileOffsetVertical);

    /// <summary>Area a stack-beside-bet pile pair can cover, relative to its centre.</summary>
    public static Rect2 HorizontalPileUnitBounds => PairBounds(StackPileOffset, BetPileOffset);

    private static Rect2 PairBounds(Vector2 stackOffset, Vector2 betOffset)
    {
        var stack = ChipPileView.BoundsFor(showLabel: false);
        var bet = ChipPileView.BoundsFor(showLabel: true);
        return new Rect2(stack.Position + stackOffset, stack.Size).Merge(new Rect2(bet.Position + betOffset, bet.Size));
    }

    private PokerTable _table = null!;
    private PortraitLayout _layout = null!;
    private readonly Texture2D _worldMap = GD.Load<Texture2D>(UiTheme.WorldMapPath);
    private readonly List<SeatView> _seats = new();
    private readonly List<ChipPileView> _stackPiles = new();
    private readonly List<ChipPileView> _betPiles = new();
    private readonly List<CardView> _community = new();
    private readonly HashSet<PokerPlayer> _winners = new();
    private readonly HashSet<Card> _winningCards = new();
    private Label _potLabel = null!;
    private Panel _actionBar = null!;
    private Button _foldButton = null!;
    private Button _callButton = null!;
    private Button _raiseButton = null!;
    private HSlider _raiseSlider = null!;
    private Label _raiseLabel = null!;
    private Button _nextHandButton = null!;
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
            WaitForNextHand = true,
        };
        AddChild(_table);
        _table.Setup(cfg.CreatePlayers());

        BuildUi();
        ConnectTable();
        _table.StartGame();
    }

    public override void _Draw()
    {
        UiTheme.DrawWorldMap(this, _worldMap, Size);
        // A long table between the two NPC columns: wooden rail, felt, lighter inner felt.
        var table = _layout.Table;
        DrawColoredPolygon(Chamfered(table, 6), new Color("5a3a22"));
        DrawColoredPolygon(Chamfered(table.Grow(-3), 5), new Color("1f6b3a"));
        DrawColoredPolygon(Chamfered(table.Grow(-9), 4), new Color("247a43"));
    }

    /// <summary>Rectangle with its corners cut at 45 degrees: reads as "rounded" at pixel scale.</summary>
    private static Vector2[] Chamfered(Rect2 r, float c) => new[]
    {
        new Vector2(r.Position.X + c, r.Position.Y), new Vector2(r.End.X - c, r.Position.Y),
        new Vector2(r.End.X, r.Position.Y + c), new Vector2(r.End.X, r.End.Y - c),
        new Vector2(r.End.X - c, r.End.Y), new Vector2(r.Position.X + c, r.End.Y),
        new Vector2(r.Position.X, r.End.Y - c), new Vector2(r.Position.X, r.Position.Y + c),
    };

    // --- UI construction ---------------------------------------------------

    private void BuildUi()
    {
        var (safeTop, safeBottom) = PortraitLayout.SafeInsets(GetViewport());
        _layout = new PortraitLayout(GetViewportRect().Size, _table.Players.Count - 1, safeTop, safeBottom);
        var potCenter = _layout.PotCenter;

        // Players[0] is the human (bottom right); opponents fill the edge columns clockwise.
        var humanPortrait = GD.Load<Texture2D>(GameConfig.Instance.PlayerPortraitPath);
        for (int i = 0; i < _table.Players.Count; i++)
        {
            var player = _table.Players[i];
            var slot = i == 0 ? _layout.Human : _layout.Opponents[i - 1];
            var seat = new SeatView
            {
                Player = player,
                Portrait = player.Brain?.Portrait ?? humanPortrait,
                Style = slot.Style,
                MaxHearts = GameConfig.Instance.StartingHearts,
                Position = slot.SeatPosition.Round(),
            };
            AddChild(seat);
            _seats.Add(seat);

            // Stack (whole bankroll) left/above, this hand's bet right/below.
            var stack = new ChipPileView
            {
                Position = slot.PileCenter + (slot.VerticalPiles ? StackPileOffsetVertical : StackPileOffset),
                ShowLabel = false,
            };
            AddChild(stack);
            _stackPiles.Add(stack);
            var bet = new ChipPileView { Position = slot.PileCenter + (slot.VerticalPiles ? BetPileOffsetVertical : BetPileOffset) };
            AddChild(bet);
            _betPiles.Add(bet);
        }

        // The board, drawn large in the space under the NPCs.
        float step = CardView.CardSize.X * PortraitLayout.BoardCardScale + PortraitLayout.BoardCardGap;
        for (int i = 0; i < 5; i++)
        {
            var view = new CardView
            {
                ShowEmptySlot = true,
                PixelScale = PortraitLayout.BoardCardScale,
                Position = _layout.BoardOrigin + new Vector2(i * step, 0),
            };
            AddChild(view);
            _community.Add(view);
        }

        _potLabel = this.AddAt(new Label { HorizontalAlignment = HorizontalAlignment.Center },
            potCenter - new Vector2(60, UiTheme.LineHeight / 2), new Vector2(120, UiTheme.LineHeight));
        _potLabel.AddThemeColorOverride("font_color", PixelArt.Gold);

        var menuButton = this.AddAt(new Button { Text = "MENU" }, _layout.MenuButton.Position, _layout.MenuButton.Size);
        menuButton.Pressed += () => GetTree().ChangeSceneToFile("res://scenes/main_menu.tscn");

        // Shown under the board, in the (then empty) pot label's spot, once a hand is over.
        _nextHandButton = this.AddAt(new Button { Text = "NEXT HAND", Visible = false },
            potCenter - PortraitLayout.NextHandSize / 2, PortraitLayout.NextHandSize);
        _nextHandButton.Pressed += () =>
        {
            _nextHandButton.Visible = false;
            _table.ContinueToNextHand();
        };

        BuildActionBar();
    }

    private void BuildActionBar()
    {
        // A column of big, well-spaced touch targets beside the human's seat:
        // FOLD, CALL, raise amount, RAISE.
        var bar = _layout.ActionBar;
        _actionBar = this.AddAt(new Panel { Visible = false }, bar.Position, bar.Size);
        float pad = PortraitLayout.ActionPadding, gap = PortraitLayout.ActionGap;
        float buttonH = PortraitLayout.ActionButtonHeight, sliderH = PortraitLayout.ActionSliderHeight;
        float inner = bar.Size.X - pad * 2;

        float y = pad;
        _foldButton = ActionButton("FOLD", y, () => Submit(new Decision(PokerAction.Fold)));
        y += buttonH + gap;
        _callButton = ActionButton("CALL", y, () => Submit(new Decision(_toCall == 0 ? PokerAction.Check : PokerAction.Call)));
        y += buttonH + gap;

        _raiseSlider = _actionBar.AddAt(new HSlider { Step = 1 }, new Vector2(pad, y), new Vector2(inner - 78, sliderH));
        _raiseSlider.ValueChanged += _ => UpdateRaiseLabel();
        _raiseLabel = _actionBar.AddAt(new Label { HorizontalAlignment = HorizontalAlignment.Right, VerticalAlignment = VerticalAlignment.Center },
            new Vector2(pad + inner - 74, y), new Vector2(74, sliderH));
        y += sliderH + gap;

        _raiseButton = ActionButton("RAISE", y, () => Submit(new Decision(PokerAction.Raise, (int)_raiseSlider.Value)));
    }

    private Button ActionButton(string text, float y, Action onPressed)
    {
        float pad = PortraitLayout.ActionPadding;
        var button = _actionBar.AddAt(new Button { Text = text },
            new Vector2(pad, y), new Vector2(_layout.ActionBar.Size.X - pad * 2, PortraitLayout.ActionButtonHeight));
        button.Pressed += onPressed;
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
        _table.HandStarted += (number, dealer) =>
        {
            foreach (var seat in _seats)
            {
                seat.SetDealer(seat.Player.Seat == dealer);
                seat.SetReveal(false);
                seat.SetStatus("");
            }
            foreach (var view in _community) view.SetCard(null, false);
            _winners.Clear();
            _winningCards.Clear();
            ApplyWinHighlights();
        };
        _table.StreetStarted += street =>
        {
            if (street == Street.Preflop) return;
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
        };
        _table.ChipsChanged += RefreshSeats;
        _table.Showdown += (contenders, scores) =>
        {
            foreach (var p in contenders)
            {
                _seats[p.Seat].SetReveal(true);
                _seats[p.Seat].SetStatus(SeatHandName(scores[p]), PixelArt.Paper);
            }
        };
        _table.PotAwarded += (player, amount, handName) =>
        {
            _seats[player.Seat].SetStatus($"WINS ${amount}", PixelArt.Gold);
            _winners.Add(player);
            // Uncontested pots have no shown hand; only showdown winners light up cards.
            if (handName != "")
                _winningCards.UnionWith(HandEvaluator.BestFive(player.HoleCards.Concat(_table.Community).ToList()));
            ApplyWinHighlights();
        };
        _table.WaitingForNextHand += () =>
        {
            foreach (var seat in _seats) seat.SetActive(false);
            _nextHandButton.Visible = true;
            _nextHandButton.GrabFocus(); // Enter / Space also continue
        };
        _table.GameOver += ShowGameOver;
    }

    /// <summary>Hand name short enough for a seat's status line (poker shorthand for the long ones).</summary>
    private static string SeatHandName(int[] score) => (HandCategory)score[0] switch
    {
        HandCategory.ThreeOfAKind => "TRIPS",
        HandCategory.FourOfAKind => "QUADS",
        _ => HandEvaluator.Describe(score).ToUpper(),
    };

    /// <summary>Gold glow on winners' portraits; lift the winning five cards and dim the rest.</summary>
    private void ApplyWinHighlights()
    {
        ISet<Card>? cards = _winningCards.Count > 0 ? _winningCards : null;
        foreach (var seat in _seats)
        {
            seat.SetWinner(_winners.Contains(seat.Player));
            seat.HighlightCards(cards);
        }
        foreach (var view in _community)
        {
            view.SetHighlight(cards == null || view.Card == null ? CardHighlight.None
                : cards.Contains(view.Card) ? CardHighlight.Winning
                : CardHighlight.Dimmed);
        }
    }

    private void RefreshSeats()
    {
        foreach (var seat in _seats) seat.Refresh();
        for (int i = 0; i < _table.Players.Count; i++)
        {
            _stackPiles[i].Amount = _table.Players[i].Chips;
            _betPiles[i].Amount = _table.Players[i].TotalBet;
        }
        _potLabel.Text = _table.Pot > 0 ? $"POT ${_table.Pot}" : "";
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
        title.AddThemeFontSizeOverride("font_size", 32);
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

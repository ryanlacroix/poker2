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
    private readonly HashSet<Card> _winningCards = new(); // winners' best five, kickers included
    private readonly HashSet<Card> _scoringCards = new(); // just the cards that made each winning hand
    private PotView _pot = null!;
    private int _shownPot;
    private Tween? _potTween;
    private const int PotFontSize = UiTheme.FontSize + 4;
    private const int PotPopSize = PotFontSize + 6;
    private Panel _actionBar = null!;
    private Button _foldButton = null!;
    private Button _callButton = null!;
    private Button _raiseButton = null!;
    private HSlider _raiseSlider = null!;
    private Label _raiseLabel = null!;
    private Button _nextHandButton = null!;
    private PistolView _pistol = null!;
    private Label _targetHint = null!;
    private WinBanner _winBanner = null!;
    private bool _targeting;
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
            seat.Targeted += OnSeatTargeted;
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

        // Pot of gold + amount; the box is tall and centred so it grows from its middle when it pops.
        _pot = this.AddAt(new PotView { FontSize = PotFontSize }, potCenter - new Vector2(80, 20), new Vector2(160, 40));

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

        // Target mode (after the human wins a hand): pistol in the screen centre, hint under the board.
        _pistol = new PistolView
        {
            Visible = false,
            // Floats in the centre of the screen.
            Position = (GetViewportRect().Size / 2 - PistolView.ArtSize / 2).Round(),
        };
        AddChild(_pistol);
        _targetHint = this.AddAt(new Label
        {
            Text = "PICK A TARGET",
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center,
            Visible = false,
        }, potCenter - PortraitLayout.NextHandSize / 2, PortraitLayout.NextHandSize);
        _targetHint.AddThemeColorOverride("font_color", PixelArt.HeartRed);

        BuildActionBar();

        // Added last so it draws over everything else.
        _winBanner = this.AddAt(new WinBanner { MaxBottom = _layout.BoardOrigin.Y - 4 }, Vector2.Zero, GetViewportRect().Size);
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
            _scoringCards.Clear();
            _winBanner.Hide();
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
            // Announce the best hand at the table (it takes the main pot) and whoever holds it.
            var best = contenders.Select(p => scores[p]).Aggregate((a, b) => HandEvaluator.Compare(a, b) >= 0 ? a : b);
            var names = contenders.Where(p => HandEvaluator.Compare(scores[p], best) == 0).Select(p => p.DisplayName.ToUpper());
            _winBanner.Show(HandEvaluator.Describe(best).ToUpper(), string.Join(" & ", names));
        };
        _table.PotAwarded += (player, amount, handName) =>
        {
            _seats[player.Seat].SetStatus($"WINS ${amount}", PixelArt.Gold);
            _winners.Add(player);
            // Uncontested pots have no shown hand; only showdown winners light up cards.
            if (handName != "")
            {
                var five = HandEvaluator.BestFive(player.HoleCards.Concat(_table.Community).ToList());
                _winningCards.UnionWith(five);
                _scoringCards.UnionWith(HandEvaluator.ScoringCards(five));
            }
            ApplyWinHighlights();
        };
        _table.WaitingForNextHand += () =>
        {
            foreach (var seat in _seats) seat.SetActive(false);
            // Let the winning-hand banner finish before the pistol or NEXT HAND take the screen.
            if (_winBanner.Visible) _winBanner.Finished += AfterBanner;
            else AfterHand();
        };
        _table.GameOver += ShowGameOver;
    }

    private void AfterBanner()
    {
        _winBanner.Finished -= AfterBanner;
        AfterHand();
    }

    /// <summary>The hand is settled: offer a shot at an NPC if it was earned, else NEXT HAND.</summary>
    private void AfterHand()
    {
        // Winning a hand earns a shot at an NPC; otherwise just wait for NEXT HAND.
        var targets = _seats.Where(s => !s.Player.IsHuman && s.Player.Hearts > 0 && s.Player.Chips > 0).ToList();
        bool earnedShot = _winners.Contains(_table.Players[0]) || GameConfig.Instance.DebugTargetEveryHand;
        if (earnedShot && targets.Count > 0)
        {
            EnterTargetMode(targets);
        }
        else
        {
            _nextHandButton.Visible = true;
            _nextHandButton.GrabFocus(); // Enter / Space also continue
        }
    }

    private void EnterTargetMode(List<SeatView> targets)
    {
        _targeting = true;
        _pistol.Visible = true;
        _pistol.SetProcess(true);
        _targetHint.Visible = true;
        foreach (var seat in targets) seat.SetTargetable(true);
    }

    /// <summary>The human picked an NPC: fire, take a heart, then deal the next hand.</summary>
    private void OnSeatTargeted(SeatView target)
    {
        if (!_targeting) return;
        _targeting = false;
        foreach (var seat in _seats) seat.SetTargetable(false);
        _targetHint.Visible = false;

        _pistol.Fire();
        target.FlashHit();
        bool eliminated = _table.RemoveHeart(target.Player, _table.Players[0]);
        target.SetStatus(eliminated ? "ELIMINATED" : "DIRECT HIT", PixelArt.HeartRed);
        target.Refresh();

        GetTree().CreateTimer(0.9).Timeout += () =>
        {
            if (!IsInstanceValid(this)) return; // left the scene meanwhile
            _pistol.Visible = false;
            _pistol.SetProcess(false);
            _table.ContinueToNextHand();
        };
    }

    /// <summary>Hand name short enough for a seat's status line (poker shorthand for the long ones).</summary>
    private static string SeatHandName(int[] score) => (HandCategory)score[0] switch
    {
        HandCategory.ThreeOfAKind => "TRIPS",
        HandCategory.FourOfAKind => "QUADS",
        _ => HandEvaluator.Describe(score).ToUpper(),
    };

    /// <summary>
    /// Gold glow on winners' portraits; lift the cards that made the winning hand, faintly outline
    /// its kickers, and dim the rest.
    /// </summary>
    private void ApplyWinHighlights()
    {
        foreach (var seat in _seats)
        {
            seat.SetWinner(_winners.Contains(seat.Player));
            seat.HighlightCards(WinHighlightFor);
        }
        foreach (var view in _community)
            view.SetHighlight(WinHighlightFor(view.Card));
    }

    private CardHighlight WinHighlightFor(Card? card) =>
        _winningCards.Count == 0 || card == null ? CardHighlight.None
        : _scoringCards.Contains(card) ? CardHighlight.Winning
        : _winningCards.Contains(card) ? CardHighlight.Kicker
        : CardHighlight.Dimmed;

    private void RefreshSeats()
    {
        foreach (var seat in _seats) seat.Refresh();
        for (int i = 0; i < _table.Players.Count; i++)
        {
            _stackPiles[i].Amount = _table.Players[i].Chips;
            _betPiles[i].Amount = _table.Players[i].TotalBet;
        }
        int pot = _table.Pot;
        _pot.Amount = pot;
        if (pot > _shownPot) PopPotLabel();
        _shownPot = pot;
    }

    /// <summary>Money went into the pot: the pot display swells briefly, then settles back.</summary>
    private void PopPotLabel()
    {
        _potTween?.Kill();
        var setSize = Callable.From<float>(size => _pot.FontSize = Mathf.RoundToInt(size));
        _potTween = CreateTween();
        _potTween.TweenMethod(setSize, (float)PotFontSize, (float)PotPopSize, 0.08)
            .SetTrans(Tween.TransitionType.Quad).SetEase(Tween.EaseType.Out);
        _potTween.TweenMethod(setSize, (float)PotPopSize, (float)PotFontSize, 0.2)
            .SetTrans(Tween.TransitionType.Quad).SetEase(Tween.EaseType.In);
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

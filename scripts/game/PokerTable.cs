using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Godot;

namespace PokerGame;

/// <summary>
/// Texas Hold'em rules engine. Has no visuals: it runs the game as an async loop and
/// reports everything through events so any view (or a test) can follow along.
/// </summary>
public partial class PokerTable : Node
{
	public event Action<int, int>? HandStarted;                 // hand number, dealer seat
	public event Action<Street>? StreetStarted;
	public event Action? HoleCardsDealt;
	public event Action<IReadOnlyList<Card>>? CommunityChanged;
	public event Action<PokerPlayer, int, int, int>? TurnStarted; // player, to call, min raise-to, max raise-to
	public event Action<PokerPlayer, PokerAction, int>? PlayerActed;
	public event Action? ChipsChanged;
	public event Action<IReadOnlyList<PokerPlayer>, IReadOnlyDictionary<PokerPlayer, int[]>>? Showdown;
	public event Action<PokerPlayer, int, string>? PotAwarded;  // winner, amount, hand name ("" if uncontested)
	/// <summary>A player picked up an item at the end of a hand.</summary>
	public event Action<PokerPlayer, Item>? ItemGained;
	public event Action? HandFinished;
	/// <summary>
	/// Raised after a hand (when <see cref="WaitForNextHand"/> is on) so the view can finish showing
	/// it first; call <see cref="BeginItemPhase"/> to start the item turns.
	/// </summary>
	public event Action? WaitingForItemPhase;
	/// <summary>
	/// It's this player's item turn (player, whether they can use their item now). For the human,
	/// answer with <see cref="SubmitItemDecision"/>; NPCs only raise it when they'll use or drop.
	/// </summary>
	public event Action<PokerPlayer, bool>? ItemTurnStarted;
	/// <summary>A gun was fired: shooter, target, outcome.</summary>
	public event Action<PokerPlayer, PokerPlayer, ShotResult>? Shot;
	public event Action<PokerPlayer, Item>? ItemDropped;
	public event Action? ItemPhaseFinished;
	/// <summary>Raised between hands when <see cref="WaitForNextHand"/> is on; call <see cref="ContinueToNextHand"/>.</summary>
	public event Action? WaitingForNextHand;
	public event Action<PokerPlayer>? GameOver;
	public event Action<string>? Message;

	public int SmallBlind { get; set; } = 10;
	public int BigBlind { get; set; } = 20;
	public double DealDelay { get; set; } = 0.4;
	public double NpcThinkTime { get; set; } = 0.8;
	public double ShowdownDelay { get; set; } = 2.0;
	public double BetweenHandsDelay { get; set; } = 1.5;
	/// <summary>Pause after a gunshot in the item phase, so it can be seen before the next turn.</summary>
	public double ShotDelay { get; set; } = 0.9;
	/// <summary>0 = unlimited.</summary>
	public int MaxHands { get; set; }
	/// <summary>
	/// Pause after each hand for the view: before the item phase (until <see cref="BeginItemPhase"/>)
	/// and before the next hand (until <see cref="ContinueToNextHand"/>), instead of waiting
	/// ShowdownDelay + BetweenHandsDelay.
	/// </summary>
	public bool WaitForNextHand { get; set; }
	/// <summary>Chance, at the end of each hand, that each empty-handed player still in the game gets a random item.</summary>
	/// <remarks>TESTING: raised to 1 in 2 from the intended 1 in 6.</remarks>
	public double ItemChance { get; set; } = 1.0 / 2;

	public List<PokerPlayer> Players { get; } = new();
	public List<Card> Community { get; } = new();
	public Street Street { get; private set; }
	public int DealerIndex { get; private set; } = -1;
	public int HandNumber { get; private set; }
	/// <summary>Highest StreetBet this betting round.</summary>
	public int CurrentBet { get; private set; }

	private int _minRaise;
	private readonly Deck _deck = new();
	private TaskCompletionSource<Decision>? _humanDecision;
	private TaskCompletionSource? _nextHand;
	private TaskCompletionSource? _itemPhase;
	private TaskCompletionSource<ItemDecision>? _humanItemDecision;
	private readonly CancellationTokenSource _cts = new();

	public int Pot => Players.Sum(p => p.TotalBet);

	public void Setup(IEnumerable<PokerPlayer> players)
	{
		Players.Clear();
		Players.AddRange(players);
		for (int i = 0; i < Players.Count; i++)
			Players[i].Seat = i;
	}

	/// <summary>Called by the UI when the human picks an action.</summary>
	public void SubmitHumanAction(Decision decision) => _humanDecision?.TrySetResult(decision);

	/// <summary>Called by the UI to deal the next hand while paused (see <see cref="WaitForNextHand"/>).</summary>
	public void ContinueToNextHand() => _nextHand?.TrySetResult();

	/// <summary>Called by the UI to start the item turns once it has finished showing the hand.</summary>
	public void BeginItemPhase() => _itemPhase?.TrySetResult();

	/// <summary>Called by the UI with the human's choice on their item turn.</summary>
	public void SubmitItemDecision(ItemDecision decision) => _humanItemDecision?.TrySetResult(decision);

	/// <summary>
	/// <paramref name="shooter"/> fires their gun (used up) at <paramref name="target"/>
	/// (call between hands). A shield breaks and absorbs the shot; otherwise it takes a heart.
	/// </summary>
	public ShotResult Shoot(PokerPlayer shooter, PokerPlayer target)
	{
		if (shooter.Item == Item.Gun) shooter.Item = null;
		if (target.Item == Item.Shield)
		{
			target.Item = null;
			ChipsChanged?.Invoke();
			return ShotResult.ShieldBroke;
		}
		return RemoveHeart(target, shooter) ? ShotResult.Eliminated : ShotResult.Hit;
	}

	/// <summary>
	/// Takes one heart from <paramref name="target"/> (call between hands). At zero hearts the
	/// target is eliminated and their chips go to <paramref name="taker"/>. Returns true if eliminated.
	/// </summary>
	public bool RemoveHeart(PokerPlayer target, PokerPlayer taker)
	{
		if (target.Hearts <= 0) return false;
		target.Hearts--;
		bool eliminated = target.Hearts == 0;
		if (eliminated && target != taker)
		{
			taker.Chips += target.Chips;
			target.Chips = 0;
		}
		ChipsChanged?.Invoke();
		return eliminated;
	}

	/// <summary>Still playing: has chips and hearts left.</summary>
	public static bool InGame(PokerPlayer p) => p.Chips > 0 && p.Hearts > 0;

	/// <summary>Everyone <paramref name="shooter"/> could shoot.</summary>
	public List<PokerPlayer> GunTargets(PokerPlayer shooter) =>
		Players.Where(t => t != shooter && InGame(t)).ToList();

	/// <summary>
	/// Whether <paramref name="p"/> may use their item now (between hands): it has a use, they've
	/// held it since an earlier hand, and (for a gun) there's someone to shoot.
	/// </summary>
	public bool CanUseItem(PokerPlayer p) =>
		p.Item is { } item && Items.CanBeUsed(item) && p.CanUseItem(HandNumber)
		&& (item != Item.Gun || GunTargets(p).Count > 0);

	public override void _ExitTree()
	{
		// Stops the game loop cleanly if the scene is left mid-hand.
		_cts.Cancel();
		_humanDecision?.TrySetCanceled();
		_nextHand?.TrySetCanceled();
		_itemPhase?.TrySetCanceled();
		_humanItemDecision?.TrySetCanceled();
	}

	private bool GameContinues =>
		Players.Count(p => p.Chips > 0) > 1
		&& !Players.Any(p => p.IsHuman && p.Chips <= 0)
		&& (MaxHands == 0 || HandNumber < MaxHands);

	public async void StartGame()
	{
		try
		{
			while (GameContinues)
			{
				await PlayHand();
				if (!GameContinues) break;
				await ItemPhase();
				if (!GameContinues) break;
				if (WaitForNextHand)
				{
					_nextHand = new TaskCompletionSource();
					WaitingForNextHand?.Invoke();
					await _nextHand.Task;
					_nextHand = null;
				}
				else
				{
					await Wait(BetweenHandsDelay);
				}
			}
			GameOver?.Invoke(Players.MaxBy(p => p.Chips)!);
		}
		catch (OperationCanceledException)
		{
		}
	}

	// --- Hand flow ---------------------------------------------------------

	private async Task PlayHand()
	{
		HandNumber++;
		foreach (var p in Players) p.ResetForHand();
		Community.Clear();
		_deck.Reset();

		static bool Seated(PokerPlayer p) => !p.IsOut;
		DealerIndex = NextSeat(DealerIndex, Seated);
		// Heads-up: the dealer posts the small blind.
		int sbIndex = Players.Count(Seated) == 2 ? DealerIndex : NextSeat(DealerIndex, Seated);
		int bbIndex = NextSeat(sbIndex, Seated);

		HandStarted?.Invoke(HandNumber, DealerIndex);
		StartStreet(Street.Preflop);
		PostBlind(Players[sbIndex], SmallBlind, "small");
		PostBlind(Players[bbIndex], BigBlind, "big");
		CurrentBet = BigBlind;

		for (int round = 0; round < 2; round++)
		{
			for (int step = 1; step <= Players.Count; step++)
			{
				var p = Players[(DealerIndex + step) % Players.Count];
				if (!p.IsOut) p.HoleCards.Add(_deck.Draw());
			}
		}
		HoleCardsDealt?.Invoke();
		ChipsChanged?.Invoke();
		await Wait(DealDelay);

		await BettingRound(NextSeat(bbIndex, p => p.CanAct));

		foreach (var next in new[] { Street.Flop, Street.Turn, Street.River })
		{
			if (Players.Count(p => p.InHand) <= 1) break;
			StartStreet(next);
			int n = next == Street.Flop ? 3 : 1;
			for (int i = 0; i < n; i++) Community.Add(_deck.Draw());
			CommunityChanged?.Invoke(Community);
			await Wait(DealDelay);
			if (Players.Count(p => p.CanAct) >= 2)
				await BettingRound(NextSeat(DealerIndex, p => p.CanAct));
		}

		await ResolveHand();
		HandOutItems();
		HandFinished?.Invoke();
	}

	private void StartStreet(Street s)
	{
		Street = s;
		CurrentBet = 0;
		_minRaise = BigBlind;
		foreach (var p in Players)
		{
			p.StreetBet = 0;
			p.HasActed = false;
		}
		StreetStarted?.Invoke(s);
	}

	private void PostBlind(PokerPlayer p, int amount, string kind)
	{
		int paid = p.Commit(amount);
		Message?.Invoke($"{p.DisplayName} posts {kind} blind {paid}");
	}

	private bool NeedsToAct(PokerPlayer p) => p.CanAct && (!p.HasActed || p.StreetBet < CurrentBet);

	private async Task BettingRound(int start)
	{
		if (start < 0) return;
		int idx = start;
		while (true)
		{
			if (Players.Count(p => p.InHand) <= 1) return;
			if (!Players.Any(NeedsToAct)) return;
			var actors = Players.Where(p => p.CanAct).ToList();
			if (actors.Count == 1 && actors[0].StreetBet >= CurrentBet) return;

			var player = Players[idx];
			if (NeedsToAct(player))
			{
				int toCall = CurrentBet - player.StreetBet;
				int maxTo = player.StreetBet + player.Chips;
				int minTo = Math.Min(CurrentBet + _minRaise, maxTo);
				TurnStarted?.Invoke(player, toCall, minTo, maxTo);

				Decision decision;
				if (player.IsHuman)
				{
					_humanDecision = new TaskCompletionSource<Decision>();
					decision = await _humanDecision.Task;
					_humanDecision = null;
				}
				else
				{
					await Wait(NpcThinkTime);
					decision = player.Brain!.Decide(new DecisionContext(
						player.HoleCards, Community, Street, toCall, Pot, CurrentBet,
						minTo, maxTo, player.Chips, BigBlind, Players.Count(p => p.InHand) - 1));
				}
				ApplyAction(player, decision);
			}
			idx = (idx + 1) % Players.Count;
		}
	}

	/// <summary>Validates and applies a decision. Illegal choices are coerced to the nearest legal one.</summary>
	private void ApplyAction(PokerPlayer p, Decision decision)
	{
		int toCall = CurrentBet - p.StreetBet;
		var action = decision.Action;
		int amount = decision.Amount;

		if (action == PokerAction.Raise)
		{
			amount = Math.Min(Math.Max(amount, CurrentBet + _minRaise), p.StreetBet + p.Chips);
			if (amount <= CurrentBet) action = PokerAction.Call;
		}
		if (action == PokerAction.Check && toCall > 0) action = PokerAction.Call;
		if (action == PokerAction.Call && toCall == 0) action = PokerAction.Check;

		switch (action)
		{
			case PokerAction.Fold:
				p.Folded = true;
				amount = 0;
				break;
			case PokerAction.Check:
				amount = 0;
				break;
			case PokerAction.Call:
				amount = p.Commit(toCall);
				break;
			case PokerAction.Raise:
				int raiseSize = amount - CurrentBet;
				p.Commit(amount - p.StreetBet);
				if (raiseSize >= _minRaise)
				{
					_minRaise = raiseSize;
					// A full raise re-opens the action for everyone else.
					foreach (var other in Players)
						if (other != p) other.HasActed = false;
				}
				CurrentBet = amount;
				break;
		}
		p.HasActed = true;
		PlayerActed?.Invoke(p, action, amount);
		ChipsChanged?.Invoke();
	}

	private async Task ResolveHand()
	{
		var contenders = Players.Where(p => p.InHand).ToList();
		if (contenders.Count == 1)
		{
			int amount = Pot;
			contenders[0].Chips += amount;
			PotAwarded?.Invoke(contenders[0], amount, "");
			ClearBets();
			return;
		}

		Street = Street.Showdown;
		var scores = contenders.ToDictionary(p => p, p => HandEvaluator.Evaluate(p.HoleCards.Concat(Community)));
		Showdown?.Invoke(contenders, scores);

		// Main pot + one side pot per distinct all-in level.
		var levels = contenders.Select(p => p.TotalBet).Distinct().OrderBy(x => x).ToList();
		int prev = 0;
		for (int i = 0; i < levels.Count; i++)
		{
			int level = levels[i];
			bool isLast = i == levels.Count - 1;
			int amount = 0;
			foreach (var p in Players)
			{
				int over = p.TotalBet - prev;
				// The last pot also sweeps up chips folded players put in above every all-in level.
				if (over > 0) amount += isLast ? over : Math.Min(over, level - prev);
			}
			prev = level;
			if (amount == 0) continue;

			var winners = new List<PokerPlayer>();
			foreach (var p in contenders.Where(p => p.TotalBet >= level))
			{
				int cmp = winners.Count == 0 ? 1 : HandEvaluator.Compare(scores[p], scores[winners[0]]);
				if (cmp > 0) winners = new List<PokerPlayer> { p };
				else if (cmp == 0) winners.Add(p);
			}
			int share = amount / winners.Count;
			int remainder = amount % winners.Count;
			foreach (var w in winners)
			{
				int won = share + remainder;
				remainder = 0;
				w.Chips += won;
				PotAwarded?.Invoke(w, won, HandEvaluator.Describe(scores[w]));
			}
		}

		ClearBets();
		if (!WaitForNextHand)
			await Wait(ShowdownDelay);
	}

	/// <summary>
	/// Between hands, after items are handed out: everyone still in the game who holds an item and
	/// didn't fold this hand gets a turn to use it, drop it or keep it, starting with this hand's
	/// dealer and going round in play order. NPCs that keep their item pass without a pause.
	/// </summary>
	private async Task ItemPhase()
	{
		if (WaitForNextHand)
		{
			_itemPhase = new TaskCompletionSource();
			WaitingForItemPhase?.Invoke();
			await _itemPhase.Task;
			_itemPhase = null;
		}

		int n = Players.Count;
		for (int step = 0; step < n; step++)
		{
			var p = Players[(DealerIndex + step) % n];
			if (p.Item is not { } item || !InGame(p) || p.Folded) continue;
			bool canUse = CanUseItem(p);

			ItemDecision decision;
			if (p.IsHuman)
			{
				ItemTurnStarted?.Invoke(p, canUse);
				_humanItemDecision = new TaskCompletionSource<ItemDecision>();
				decision = await _humanItemDecision.Task;
				_humanItemDecision = null;
			}
			else
			{
				decision = p.Brain!.DecideItem(p, canUse, GunTargets(p));
				if (decision.Action == ItemAction.Keep) continue;
				ItemTurnStarted?.Invoke(p, canUse);
				await Wait(NpcThinkTime);
			}
			await ApplyItemDecision(p, item, canUse, decision);
		}
		ItemPhaseFinished?.Invoke();
	}

	/// <summary>Carries out an item-phase choice; anything not allowed right now counts as keeping the item.</summary>
	private async Task ApplyItemDecision(PokerPlayer p, Item item, bool canUse, ItemDecision decision)
	{
		switch (decision.Action)
		{
			case ItemAction.Use when canUse && item == Item.Gun
				&& decision.Target is { } target && target != p && InGame(target):
				var result = Shoot(p, target);
				Shot?.Invoke(p, target, result);
				await Wait(ShotDelay);
				break;
			case ItemAction.Drop:
				p.Item = null;
				ItemDropped?.Invoke(p, item);
				break;
		}
	}

	/// <summary>
	/// End of hand: each player still in the game with free hands may pick up a random item.
	/// Players already carrying one don't roll.
	/// </summary>
	private void HandOutItems()
	{
		foreach (var p in Players)
		{
			if (p.Chips <= 0 || p.Item != null || Random.Shared.NextDouble() >= ItemChance) continue;
			p.Item = Items.Random(Random.Shared);
			p.ItemGainedOnHand = HandNumber;
			ItemGained?.Invoke(p, p.Item.Value);
		}
	}

	private void ClearBets()
	{
		foreach (var p in Players)
		{
			p.TotalBet = 0;
			p.StreetBet = 0;
		}
		ChipsChanged?.Invoke();
	}

	// --- Helpers -----------------------------------------------------------

	/// <summary>First seat after <paramref name="from"/> (wrapping, <paramref name="from"/> itself last) matching pred, or -1.</summary>
	private int NextSeat(int from, Func<PokerPlayer, bool> pred)
	{
		int n = Players.Count;
		for (int step = 1; step <= n; step++)
		{
			int i = ((from + step) % n + n) % n;
			if (pred(Players[i])) return i;
		}
		return -1;
	}

	private async Task Wait(double seconds)
	{
		_cts.Token.ThrowIfCancellationRequested();
		await ToSignal(GetTree().CreateTimer(seconds), SceneTreeTimer.SignalName.Timeout);
		_cts.Token.ThrowIfCancellationRequested();
	}
}

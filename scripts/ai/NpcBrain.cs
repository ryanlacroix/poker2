using System;
using System.Collections.Generic;
using System.Linq;
using Godot;

namespace PokerGame;

/// <summary>
/// Decision-making for an NPC opponent. Each .tres in data/npcs/ is one personality.
/// Hand strength comes from a Monte Carlo equity estimate; the personality knobs shift
/// how that strength turns into folds, calls, raises and bluffs.
/// </summary>
[GlobalClass]
public partial class NpcBrain : Resource
{
	[Export] public string DisplayName { get; set; } = "NPC";
	/// <summary>16x16 pixel portrait shown at the seat (see tools/generate_portraits.py).</summary>
	[Export] public Texture2D? Portrait { get; set; }
	/// <summary>The same face beaten up, shown once they're down to their last heart.</summary>
	[Export] public Texture2D? InjuredPortrait { get; set; }
	/// <summary>0 = plays almost anything, 1 = only premium hands.</summary>
	[Export(PropertyHint.Range, "0,1,0.01")] public float Tightness { get; set; } = 0.5f;
	/// <summary>0 = calls and checks, 1 = bets and raises constantly.</summary>
	[Export(PropertyHint.Range, "0,1,0.01")] public float Aggression { get; set; } = 0.5f;
	/// <summary>Chance to bet with a weak hand.</summary>
	[Export(PropertyHint.Range, "0,1,0.01")] public float BluffRate { get; set; } = 0.1f;
	/// <summary>Monte Carlo samples per decision: more = smarter but slower.</summary>
	[Export(PropertyHint.Range, "20,5000")] public int Simulations { get; set; } = 500;
	/// <summary>Noise added to equity so NPCs aren't perfectly predictable.</summary>
	[Export(PropertyHint.Range, "0,0.3,0.01")] public float Randomness { get; set; } = 0.05f;

	private static readonly Random Rng = Random.Shared;

	public Decision Decide(DecisionContext ctx)
	{
		float equity = EstimateEquity(ctx.Hole, ctx.Community, ctx.NumOpponents);
		equity = Math.Clamp(equity + RandRange(-Randomness, Randomness), 0f, 1f);

		// Equity needed to raise, scaled from "fair share" (1 / players) toward 1.
		float fairShare = 1f / (ctx.NumOpponents + 1);
		float raiseBar = fairShare + (1f - fairShare) * (Mathf.Lerp(0.25f, 0.5f, Tightness) - 0.15f * Aggression);

		if (equity >= raiseBar && Rng.NextSingle() < 0.4f + Aggression * 0.6f)
			return Raise(ctx, equity);

		if (ctx.ToCall == 0)
		{
			if (Rng.NextSingle() < BluffRate * (0.5f + Aggression))
				return Raise(ctx, equity);
			return new Decision(PokerAction.Check);
		}

		float potOdds = (float)ctx.ToCall / (ctx.Pot + ctx.ToCall);
		// Loose players over-call (implied odds, curiosity); tight ones demand a margin.
		float callBar = potOdds * Mathf.Lerp(0.6f, 1.1f, Tightness);
		if (equity >= callBar)
			return new Decision(PokerAction.Call);

		if (Rng.NextSingle() < BluffRate * 0.5f)
			return Raise(ctx, equity);
		return new Decision(PokerAction.Fold);
	}

	private Decision Raise(DecisionContext ctx, float equity)
	{
		if (ctx.MaxRaiseTo <= ctx.CurrentBet)
			return new Decision(PokerAction.Call);

		float sizeFrac = Mathf.Lerp(0.4f, 1.0f, Aggression) * RandRange(0.7f, 1.3f);
		int target = ctx.CurrentBet + (int)(ctx.Pot * sizeFrac);
		if (equity > 0.85f && Rng.NextSingle() < Aggression)
			target = ctx.MaxRaiseTo;
		target = (int)Math.Round((double)target / ctx.BigBlind) * ctx.BigBlind;
		target = Math.Min(Math.Max(target, ctx.MinRaiseTo), ctx.MaxRaiseTo);
		return new Decision(PokerAction.Raise, target);
	}

	/// <summary>
	/// Item phase: fire a ready gun (more likely the more aggressive), and timid players who
	/// won't fire it drop it to try for a shield instead. A shield is always worth keeping.
	/// </summary>
	public ItemDecision DecideItem(PokerPlayer self, bool canUse, IReadOnlyList<PokerPlayer> targets)
	{
		if (self.Item != Item.Gun || !canUse || targets.Count == 0)
			return new ItemDecision(ItemAction.Keep);
		if (Rng.NextSingle() < 0.5f + 0.5f * Aggression)
			return new ItemDecision(ItemAction.Use, PickTarget(targets));
		return Aggression < 0.3f ? new ItemDecision(ItemAction.Drop) : new ItemDecision(ItemAction.Keep);
	}

	/// <summary>
	/// The most rewarding shot: finishing someone off takes their whole stack, so favour big stacks
	/// with few hearts left; a shield only breaks, so shielded players are a poor target.
	/// </summary>
	private static PokerPlayer PickTarget(IReadOnlyList<PokerPlayer> targets) =>
		targets.MaxBy(t => (float)t.Chips / t.Hearts * (t.Item == Item.Shield ? 0.25f : 1f) * RandRange(0.8f, 1.2f))!;

	/// <summary>Probability of winning at showdown against <paramref name="opponents"/> random hands.</summary>
	public float EstimateEquity(IReadOnlyList<Card> hole, IReadOnlyList<Card> community, int opponents)
	{
		if (opponents <= 0) return 1f;

		var known = new HashSet<(int, Suit)>(hole.Concat(community).Select(c => (c.Rank, c.Suit)));
		var remaining = new List<Card>();
		foreach (Suit suit in Enum.GetValues<Suit>())
			for (int rank = 2; rank <= 14; rank++)
				if (!known.Contains((rank, suit)))
					remaining.Add(new Card(rank, suit));
		var deck = remaining.ToArray();

		var mine = new Card[7];
		var theirs = new Card[7];
		int boardNeeded = 5 - community.Count;
		float wins = 0f;
		for (int sim = 0; sim < Simulations; sim++)
		{
			Rng.Shuffle(deck);
			int idx = 0;
			// Slots 0-4: board, 5-6: hole cards.
			for (int i = 0; i < community.Count; i++) mine[i] = community[i];
			for (int i = 0; i < boardNeeded; i++) mine[community.Count + i] = deck[idx++];
			Array.Copy(mine, theirs, 5);
			mine[5] = hole[0];
			mine[6] = hole[1];
			var myScore = HandEvaluator.Evaluate(mine);

			int tied = 1;
			bool lost = false;
			for (int o = 0; o < opponents && !lost; o++)
			{
				theirs[5] = deck[idx++];
				theirs[6] = deck[idx++];
				int cmp = HandEvaluator.Compare(myScore, HandEvaluator.Evaluate(theirs));
				if (cmp < 0) lost = true;
				else if (cmp == 0) tied++;
			}
			if (!lost) wins += 1f / tied;
		}
		return wins / Simulations;
	}

	private static float RandRange(float min, float max) => min + Rng.NextSingle() * (max - min);
}

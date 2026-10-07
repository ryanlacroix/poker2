using System.Linq;
using Godot;

namespace PokerGame.Tests;

/// <summary>
/// Headless smoke test. Run with:
///   godot --headless res://tests/sim_test.tscn
/// Checks the hand evaluator, then plays an all-NPC game with no delays and verifies
/// that chips are conserved after every hand. Exit code = number of failures.
/// </summary>
public partial class SimTest : Node
{
    private int _failures;

    public override void _Ready()
    {
        TestEvaluator();
        RunSimulation();
    }

    private void TestEvaluator()
    {
        Expect("As Ks Qs Js Ts 2d 3c", HandCategory.StraightFlush, 14);
        Expect("Ah 2d 3c 4s 5h Kd Kc", HandCategory.Straight, 5);
        Expect("Ah Ad Ac Kh Kd Kc 2s", HandCategory.FullHouse, 14, 13);
        Expect("Ah Ad Kh Kd Qh Qd 2c", HandCategory.TwoPair, 14, 13, 12);
        Expect("9h 9d 9c 9s 2h 3d Kc", HandCategory.FourOfAKind, 9, 13);
        Expect("2h 7h 9h Jh Kh Ad Qd", HandCategory.Flush, 13, 11, 9, 7, 2);
        Expect("2h 3h 4h 5h 7h 6d 8c", HandCategory.Flush, 7, 5, 4, 3, 2);
        Expect("2c 5d 9h Jh Kh Ad 3s", HandCategory.HighCard, 14, 13, 11, 9, 5);
        Check(HandEvaluator.Compare(Score("Ah Kd 2c 3c 4d 8h 9s"), Score("Ac Kh 2d 3s 4h 8d 9c")) == 0, "split pot tie");
        Check(HandEvaluator.Compare(Score("Ah Ad Kc 7s 2d 3h 4s"), Score("Ah Ad Qc 7s 2d 3h 4s")) > 0, "pair kicker");
        TestRemoveHeart();
        TestShield();
        TestItems();
        ExpectBestFive("Ah Kd 7c 7s 2d 3h Ac", "Ah Ac 7c 7s Kd");
        ExpectBestFive("2h 3h 4h 5h 7h 6d 8c", "7h 5h 4h 3h 2h");
        ExpectBestFive("Ah 2d 3c 4s 5h Kd Kc", "Ah 2d 3c 4s 5h");
    }

    private void TestShield()
    {
        var table = new PokerTable();
        var you = new PokerPlayer("YOU", 1000) { Item = Item.Pistol };
        var npc = new PokerPlayer("NPC", 400, new NpcBrain()) { Item = Item.Shield };
        table.Setup(new[] { you, npc });
        Check(table.Shoot(you, npc) == ShotResult.ShieldBroke && npc.Hearts == 3 && npc.Item == null, "a shield breaks instead of losing a heart");
        Check(you.Item == null, "shooting uses up the pistol");
        Check(table.Shoot(you, npc) == ShotResult.Hit && npc.Hearts == 2, "once broken, the next shot takes a heart");
        table.Free();
    }

    private void TestRemoveHeart()
    {
        var table = new PokerTable();
        var you = new PokerPlayer("YOU", 1000);
        var npc = new PokerPlayer("NPC", 400, new NpcBrain());
        table.Setup(new[] { you, npc });
        Check(!table.RemoveHeart(npc, you) && npc.Hearts == 2 && npc.Chips == 400, "first shot only takes a heart");
        Check(!table.RemoveHeart(npc, you) && npc.Hearts == 1, "second shot only takes a heart");
        Check(table.RemoveHeart(npc, you) && npc.Hearts == 0, "third shot eliminates");
        Check(npc.Chips == 0 && you.Chips == 1400, "eliminated player's chips go to the shooter");
        Check(!table.RemoveHeart(npc, you) && npc.Hearts == 0, "no hearts below zero");
        table.Free();
    }

    /// <summary>Plays one all-NPC hand at a forced item chance, then calls <paramref name="done"/>.</summary>
    private void PlayOneHand(double itemChance, PokerPlayer[] players, System.Action<PokerTable> done)
    {
        var table = new PokerTable
        {
            DealDelay = 0, NpcThinkTime = 0, ShowdownDelay = 0, BetweenHandsDelay = 0, MaxHands = 1,
            ItemChance = itemChance,
        };
        AddChild(table);
        table.Setup(players);
        table.GameOver += _ =>
        {
            done(table);
            table.QueueFree();
        };
        table.StartGame();
    }

    private void TestItems()
    {
        var brain = new NpcBrain { Simulations = 20 };
        var never = new[] { new PokerPlayer("A", 1000, brain), new PokerPlayer("B", 1000, brain) };
        PlayOneHand(0, never, _ => Check(never.All(p => p.Item == null), "no items at 0% chance"));

        var always = new[] { new PokerPlayer("A", 1000, brain), new PokerPlayer("B", 1000, brain), new PokerPlayer("C", 0, brain) };
        PlayOneHand(1, always, table =>
        {
            Check(always.Where(p => p.Chips > 0).All(p => p.Item != null), "everyone still in gets an item at 100%");
            Check(always[2].Item == null, "busted players get no item");
            Check(!table.CanUseItem(always[0]), "a new item can't be used at the end of the hand it was picked up");
            Check(always[0].CanUseItem(table.HandNumber + 1), "an item can be used at the end of the next hand");
        });

        // Someone already carrying an item doesn't roll for another.
        var holding = new[] { new PokerPlayer("A", 1000, brain), new PokerPlayer("B", 1000, brain) };
        holding[0].Item = Item.Pistol;
        holding[0].ItemGainedOnHand = -1;
        PlayOneHand(1, holding, _ =>
            Check(holding[0].Chips == 0 || holding[0].ItemGainedOnHand == -1, "no new item while already carrying one"));
    }

    private void RunSimulation()
    {
        var brains = GameConfig.OpponentPaths.Select(GD.Load<NpcBrain>).ToList();
        foreach (var brain in brains)
            Check(brain.Portrait != null, $"{brain.DisplayName} has a portrait");
        var table = new PokerTable
        {
            DealDelay = 0, NpcThinkTime = 0, ShowdownDelay = 0, BetweenHandsDelay = 0, MaxHands = 300,
            WaitForNextHand = true,
        };
        AddChild(table);
        // One NPC per opponent slot plus one in the human's seat, so the game runs unattended.
        table.Setup(brains.Append(brains[0]).Select((b, i) => new PokerPlayer($"{b.DisplayName}{i}", 1000, b)));
        int expected = table.Players.Sum(p => p.Chips);

        table.HandFinished += () =>
        {
            int total = table.Players.Sum(p => p.Chips);
            Check(total == expected, $"chips conserved after hand {table.HandNumber} ({total} != {expected})");
            Check(table.Players.All(p => p.Chips >= 0), "no negative stacks");
        };
        // Stand in for the "next hand" button.
        int pauses = 0;
        table.WaitingForNextHand += () =>
        {
            pauses++;
            table.ContinueToNextHand();
        };
        table.GameOver += winner =>
        {
            // Every hand but the game-ending one should pause for the button.
            Check(pauses == table.HandNumber - 1, $"paused {pauses} times over {table.HandNumber} hands");
            GD.Print($"Simulated {table.HandNumber} hands, leader {winner.DisplayName} with {winner.Chips}");
            GD.Print(_failures == 0 ? "ALL TESTS PASSED" : $"{_failures} FAILURE(S)");
            GetTree().Quit(_failures);
        };
        table.StartGame();
    }

    private void Expect(string hand, HandCategory category, params int[] tiebreaks)
    {
        var score = Score(hand);
        int[] expected = [(int)category, .. tiebreaks];
        Check(score.SequenceEqual(expected), $"{hand}: got [{string.Join(",", score)}], want [{string.Join(",", expected)}]");
    }

    private void ExpectBestFive(string hand, string expected)
    {
        var best = HandEvaluator.BestFive(hand.Split(' ').Select(Parse).ToList()).Select(c => c.ToString()).OrderBy(x => x);
        var want = expected.Split(' ').Select(s => Parse(s).ToString()).OrderBy(x => x);
        Check(best.SequenceEqual(want), $"best five of {hand}: got {string.Join(" ", best)}, want {string.Join(" ", want)}");
    }

    private static int[] Score(string hand) => HandEvaluator.Evaluate(hand.Split(' ').Select(Parse));

    private static Card Parse(string s)
    {
        int rank = "23456789TJQKA".IndexOf(s[0]) + 2;
        return new Card(rank, (Suit)"cdhs".IndexOf(s[1]));
    }

    private void Check(bool ok, string what)
    {
        if (ok) return;
        _failures++;
        GD.PrintErr("FAIL: " + what);
    }
}

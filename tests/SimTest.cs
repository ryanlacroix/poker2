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
    }

    private void RunSimulation()
    {
        var brains = GameConfig.OpponentPaths.Select(GD.Load<NpcBrain>).ToList();
        foreach (var brain in brains)
            Check(brain.Portrait != null, $"{brain.DisplayName} has a portrait");
        var table = new PokerTable
        {
            DealDelay = 0, NpcThinkTime = 0, ShowdownDelay = 0, BetweenHandsDelay = 0, MaxHands = 300,
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
        table.GameOver += winner =>
        {
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

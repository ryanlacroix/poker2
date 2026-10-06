using System.Collections.Generic;
using System.Linq;

namespace PokerGame;

public enum HandCategory
{
    HighCard,
    Pair,
    TwoPair,
    ThreeOfAKind,
    Straight,
    Flush,
    FullHouse,
    FourOfAKind,
    StraightFlush,
}

/// <summary>
/// Scores the best 5-card hand out of 5-7 cards. A score is
/// [category, tiebreak1, tiebreak2, ...]; compare scores with <see cref="Compare"/>.
/// </summary>
public static class HandEvaluator
{
    private static readonly string[] CategoryNames =
    {
        "High Card", "Pair", "Two Pair", "Three of a Kind", "Straight",
        "Flush", "Full House", "Four of a Kind", "Straight Flush",
    };

    public static int[] Evaluate(IEnumerable<Card> cards)
    {
        var list = cards as IReadOnlyList<Card> ?? cards.ToList();
        var counts = new int[15];
        var suitCounts = new int[4];
        foreach (var c in list)
        {
            counts[c.Rank]++;
            suitCounts[(int)c.Suit]++;
        }

        List<int>? flush = null;
        for (int s = 0; s < 4; s++)
        {
            if (suitCounts[s] >= 5)
                flush = list.Where(c => (int)c.Suit == s).Select(c => c.Rank).OrderByDescending(r => r).ToList();
        }
        if (flush != null)
        {
            int sfHigh = StraightHigh(flush);
            if (sfHigh > 0)
                return [(int)HandCategory.StraightFlush, sfHigh];
        }

        var quads = new List<int>();
        var trips = new List<int>();
        var pairs = new List<int>();
        var present = new List<int>();
        for (int r = 14; r >= 2; r--)
        {
            if (counts[r] > 0) present.Add(r);
            if (counts[r] == 4) quads.Add(r);
            else if (counts[r] == 3) trips.Add(r);
            else if (counts[r] == 2) pairs.Add(r);
        }

        if (quads.Count > 0)
            return [(int)HandCategory.FourOfAKind, quads[0], .. Kickers(present, 1, quads[0])];

        if (trips.Count > 0 && (trips.Count >= 2 || pairs.Count > 0))
        {
            int pairRank = trips.Count >= 2 ? trips[1] : 0;
            if (pairs.Count > 0) pairRank = System.Math.Max(pairRank, pairs[0]);
            return [(int)HandCategory.FullHouse, trips[0], pairRank];
        }

        if (flush != null)
            return [(int)HandCategory.Flush, .. flush.Take(5)];

        int straightHigh = StraightHigh(present);
        if (straightHigh > 0)
            return [(int)HandCategory.Straight, straightHigh];

        if (trips.Count > 0)
            return [(int)HandCategory.ThreeOfAKind, trips[0], .. Kickers(present, 2, trips[0])];

        if (pairs.Count >= 2)
            return [(int)HandCategory.TwoPair, pairs[0], pairs[1], .. Kickers(present, 1, pairs[0], pairs[1])];

        if (pairs.Count == 1)
            return [(int)HandCategory.Pair, pairs[0], .. Kickers(present, 3, pairs[0])];

        return [(int)HandCategory.HighCard, .. present.Take(5)];
    }

    /// <summary>1 if a beats b, -1 if b beats a, 0 on a tie.</summary>
    public static int Compare(int[] a, int[] b)
    {
        for (int i = 0; i < System.Math.Min(a.Length, b.Length); i++)
        {
            if (a[i] != b[i])
                return a[i] > b[i] ? 1 : -1;
        }
        return 0;
    }

    public static string Describe(int[] score) => CategoryNames[score[0]];

    /// <summary>Highest card of a 5-card run, or 0. Handles the A-2-3-4-5 wheel.</summary>
    private static int StraightHigh(List<int> ranks)
    {
        for (int high = 14; high >= 5; high--)
        {
            bool found = true;
            for (int k = 0; k < 5 && found; k++)
            {
                int r = high - k;
                found = ranks.Contains(r == 1 ? 14 : r);
            }
            if (found) return high;
        }
        return 0;
    }

    private static IEnumerable<int> Kickers(List<int> present, int n, params int[] exclude) =>
        present.Where(r => !exclude.Contains(r)).Take(n);
}

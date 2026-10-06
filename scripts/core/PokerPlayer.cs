using System.Collections.Generic;

namespace PokerGame;

/// <summary>Per-seat state: stack, hole cards, and betting status for the current hand.</summary>
public sealed class PokerPlayer
{
    public string DisplayName { get; }
    public NpcBrain? Brain { get; }
    public bool IsHuman => Brain == null;
    public int Seat { get; set; }
    public int Chips { get; set; }

    public List<Card> HoleCards { get; } = new();
    /// <summary>Chips put in during the current betting round.</summary>
    public int StreetBet { get; set; }
    /// <summary>Chips put in during the whole hand (used for side pots).</summary>
    public int TotalBet { get; set; }
    public bool Folded { get; set; }
    public bool AllIn { get; set; }
    public bool HasActed { get; set; }
    /// <summary>Busted; no longer dealt in.</summary>
    public bool IsOut { get; private set; }

    public PokerPlayer(string name, int chips, NpcBrain? brain = null)
    {
        DisplayName = name;
        Chips = chips;
        Brain = brain;
    }

    public void ResetForHand()
    {
        HoleCards.Clear();
        StreetBet = 0;
        TotalBet = 0;
        Folded = false;
        AllIn = false;
        HasActed = false;
        IsOut = Chips <= 0;
    }

    public bool InHand => !IsOut && !Folded;
    public bool CanAct => InHand && !AllIn;

    /// <summary>Move up to <paramref name="amount"/> chips into the pot. Returns what was actually paid.</summary>
    public int Commit(int amount)
    {
        int paid = System.Math.Min(amount, Chips);
        Chips -= paid;
        StreetBet += paid;
        TotalBet += paid;
        if (Chips == 0) AllIn = true;
        return paid;
    }
}

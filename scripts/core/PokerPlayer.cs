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
    /// <summary>Hearts shown under the player's name. Nothing removes them yet.</summary>
    public int Hearts { get; set; }
    /// <summary>The one item this player carries, if any.</summary>
    public Item? Item { get; set; }
    /// <summary>Number of the hand at whose end <see cref="Item"/> was picked up.</summary>
    public int ItemGainedOnHand { get; set; }

    /// <summary>
    /// Items can't be used straight away: only at the end of a later hand than the one they
    /// were picked up in.
    /// </summary>
    public bool CanUseItem(int handNumber) => Item != null && handNumber > ItemGainedOnHand;

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

    public PokerPlayer(string name, int chips, NpcBrain? brain = null, int hearts = 3)
    {
        DisplayName = name;
        Chips = chips;
        Brain = brain;
        Hearts = hearts;
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

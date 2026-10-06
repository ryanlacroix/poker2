using System.Collections.Generic;

namespace PokerGame;

public enum PokerAction { Fold, Check, Call, Raise }

public enum Street { Preflop, Flop, Turn, River, Showdown }

/// <summary>What a player chose to do. Amount is the total "raise to" for Raise.</summary>
public readonly record struct Decision(PokerAction Action, int Amount = 0);

/// <summary>Everything an NPC is allowed to know when deciding.</summary>
public sealed record DecisionContext(
    IReadOnlyList<Card> Hole,
    IReadOnlyList<Card> Community,
    Street Street,
    int ToCall,
    int Pot,
    int CurrentBet,
    int MinRaiseTo,
    int MaxRaiseTo,
    int Chips,
    int BigBlind,
    int NumOpponents);

public static class PokerText
{
    public static string StreetName(Street s) => s switch
    {
        Street.Preflop => "PRE-FLOP",
        Street.Flop => "FLOP",
        Street.Turn => "TURN",
        Street.River => "RIVER",
        _ => "SHOWDOWN",
    };
}

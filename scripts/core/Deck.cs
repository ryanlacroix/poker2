using System;

namespace PokerGame;

/// <summary>A standard 52-card deck.</summary>
public sealed class Deck
{
    private readonly Card[] _cards = new Card[52];
    private int _next;

    public Deck()
    {
        int i = 0;
        foreach (Suit suit in Enum.GetValues<Suit>())
            for (int rank = 2; rank <= 14; rank++)
                _cards[i++] = new Card(rank, suit);
        Reset();
    }

    /// <summary>Put all cards back and shuffle.</summary>
    public void Reset()
    {
        Random.Shared.Shuffle(_cards);
        _next = 0;
    }

    public Card Draw() => _cards[_next++];

    public int Remaining => _cards.Length - _next;
}

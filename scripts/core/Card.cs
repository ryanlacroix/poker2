namespace PokerGame;

public enum Suit { Clubs, Diamonds, Hearts, Spades }

/// <summary>A single playing card. Rank is 2..14 (14 = ace).</summary>
public sealed class Card
{
    public int Rank { get; }
    public Suit Suit { get; }

    public Card(int rank, Suit suit)
    {
        Rank = rank;
        Suit = suit;
    }

    public bool IsRed => Suit is Suit.Hearts or Suit.Diamonds;

    public string RankName => Rank switch
    {
        11 => "J",
        12 => "Q",
        13 => "K",
        14 => "A",
        _ => Rank.ToString(),
    };

    public override string ToString() => RankName + "cdhs"[(int)Suit];
}

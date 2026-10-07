namespace PokerGame;

/// <summary>Something a player can carry, one at a time. Shown as a small icon on their seat.</summary>
public enum Item { Pistol }

public static class ItemText
{
    /// <summary>The notification shown when <paramref name="name"/> picks up <paramref name="item"/>.</summary>
    public static string Gained(Item item, string name) => item switch
    {
        Item.Pistol => $"{name} got a gun",
        _ => throw new System.ArgumentOutOfRangeException(nameof(item)),
    };
}

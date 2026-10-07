namespace PokerGame;

/// <summary>Something a player can carry, one at a time. Shown as a small icon on their seat.</summary>
public enum Item
{
    /// <summary>Used between hands to shoot an NPC, taking one of their hearts.</summary>
    Pistol,
    /// <summary>
    /// Protects from the moment it's picked up: the next shot breaks it instead of taking a heart.
    /// Has no use action; it can only be dropped.
    /// </summary>
    Shield,
}

/// <summary>What happened when someone was shot.</summary>
public enum ShotResult { ShieldBroke, Hit, Eliminated }

public static class Items
{
    /// <summary>Whether <paramref name="item"/> has an action besides being dropped.</summary>
    public static bool CanBeUsed(Item item) => item == Item.Pistol;
}

public static class ItemText
{
    /// <summary>Short upper-case name, as on the "USE ..." and "DROP ..." buttons.</summary>
    public static string Name(Item item) => item switch
    {
        Item.Pistol => "PISTOL",
        Item.Shield => "SHIELD",
        _ => throw new System.ArgumentOutOfRangeException(nameof(item)),
    };

    /// <summary>The notification shown when <paramref name="name"/> picks up <paramref name="item"/>.</summary>
    public static string Gained(Item item, string name) => item switch
    {
        Item.Pistol => $"{name} got a gun",
        Item.Shield => $"{name} GOT THE SHIELD",
        _ => throw new System.ArgumentOutOfRangeException(nameof(item)),
    };
}

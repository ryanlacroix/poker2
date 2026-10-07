using System.Linq;

namespace PokerGame;

/// <summary>Something a player can carry, one at a time. Shown as a small icon on their seat.</summary>
public enum Item
{
    /// <summary>Used between hands to shoot an NPC, taking one of their hearts.</summary>
    Gun,
    /// <summary>
    /// Protects from the moment it's picked up: the next shot breaks it instead of taking a heart.
    /// Has no use action; it can only be dropped.
    /// </summary>
    Shield,
}

/// <summary>What a player does with their item on their turn in the item phase.</summary>
public enum ItemAction { Keep, Use, Drop }

/// <summary>An item-phase choice. <see cref="Target"/> is who to shoot, for <see cref="ItemAction.Use"/> with a gun.</summary>
public readonly record struct ItemDecision(ItemAction Action, PokerPlayer? Target = null);

/// <summary>What happened when someone was shot.</summary>
public enum ShotResult { ShieldBroke, Hit, Eliminated }

public static class Items
{
    /// <summary>Whether <paramref name="item"/> has an action besides being dropped.</summary>
    public static bool CanBeUsed(Item item) => item == Item.Gun;

    /// <summary>How likely each item is, relative to the others, when a player picks one up: 3 guns to 1 shield.</summary>
    public static int Weight(Item item) => item switch
    {
        Item.Gun => 3,
        Item.Shield => 1,
        _ => throw new System.ArgumentOutOfRangeException(nameof(item)),
    };

    /// <summary>A random item, chosen by <see cref="Weight"/>.</summary>
    public static Item Random(System.Random rng)
    {
        var all = System.Enum.GetValues<Item>();
        int roll = rng.Next(all.Sum(Weight));
        foreach (var item in all)
        {
            roll -= Weight(item);
            if (roll < 0) return item;
        }
        return all[^1];
    }
}

public static class ItemText
{
    /// <summary>Short upper-case name, as on the "USE ..." and "DROP ..." buttons.</summary>
    public static string Name(Item item) => item switch
    {
        Item.Gun => "GUN",
        Item.Shield => "SHIELD",
        _ => throw new System.ArgumentOutOfRangeException(nameof(item)),
    };

    /// <summary>The notification shown when <paramref name="name"/> picks up <paramref name="item"/>.</summary>
    public static string Gained(Item item, string name) => item switch
    {
        Item.Gun => $"{name} got a gun",
        Item.Shield => $"{name} GOT THE SHIELD",
        _ => throw new System.ArgumentOutOfRangeException(nameof(item)),
    };
}

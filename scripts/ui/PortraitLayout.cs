using System;
using System.Linq;
using Godot;

namespace PokerGame;

/// <summary>
/// Where everything goes on a portrait (phone) screen. Top: NPCs stacked closely in a column down
/// each screen edge, with their chips beside them. Below: the board, drawn large. Bottom: the
/// human's seat in the bottom-right corner, with the action panel beside it. Designed on a 360x640 base; extra height goes
/// to the board area, extra width widens the table. Safe-area insets keep clear of notches and
/// gesture bars.
/// </summary>
public sealed class PortraitLayout
{
    public static readonly Vector2 BaseSize = new(360, 640);

    /// <summary>A seat (top-left corner + style) and where its stack/bet piles sit on the table.</summary>
    public readonly record struct SeatSlot(Vector2 SeatPosition, SeatStyle Style, Vector2 PileCenter, bool VerticalPiles);

    public const int MaxOpponents = 6;
    private const float Margin = 4;
    private const float RowGap = 3;

    // Action panel: big, well-spaced touch targets (FOLD, CALL, raise slider, RAISE).
    public const float ActionPadding = 6;
    public const float ActionGap = 8;
    public const float ActionButtonHeight = 36;
    public const float ActionSliderHeight = 24;
    private const float ActionPanelHeight =
        ActionPadding * 2 + ActionButtonHeight * 3 + ActionSliderHeight + ActionGap * 3;

    /// <summary>NEXT HAND button, sized like the action buttons.</summary>
    public static readonly Vector2 NextHandSize = new(140, ActionButtonHeight);
    public const int BoardCardScale = 2;
    public const float BoardCardGap = 6;

    // Slots are numbered clockwise from the human (bottom right): left column bottom to top,
    // then right column top to bottom. These pick a balanced set for 1..6 opponents.
    private static readonly int[][] SlotsForCount =
    {
        new[] { 1 },
        new[] { 1, 4 },
        new[] { 0, 2, 4 },
        new[] { 0, 2, 3, 5 },
        new[] { 0, 1, 2, 3, 5 },
        new[] { 0, 1, 2, 3, 4, 5 },
    };

    public Rect2 Table { get; }
    /// <summary>Top-left of the first (large) board card.</summary>
    public Vector2 BoardOrigin { get; }
    /// <summary>Centre of the pot label / NEXT HAND button, just under the board.</summary>
    public Vector2 PotCenter { get; }
    public SeatSlot[] Opponents { get; }
    public SeatSlot Human { get; }
    public Rect2 MenuButton { get; }
    public Rect2 ActionBar { get; }

    public PortraitLayout(Vector2 viewport, int opponentCount, float safeTop = 0, float safeBottom = 0)
    {
        if (opponentCount < 1 || opponentCount > MaxOpponents)
            throw new ArgumentOutOfRangeException(nameof(opponentCount), $"the table seats 1-{MaxOpponents} opponents");

        var compact = SeatView.CompactSize;
        var wide = SeatView.WideSize;
        float top = safeTop + 2; // the MENU button sits between the columns, not above them
        float[] rowY = { top, top + compact.Y + RowGap, top + (compact.Y + RowGap) * 2 };
        float npcBottom = rowY[2] + compact.Y;

        // Columns hug the screen edges; each NPC's piles sit on the table right beside them.
        float leftX = Margin;
        float rightX = viewport.X - Margin - compact.X;
        var bounds = TableScene.VerticalPileUnitBounds;
        float leftPileX = leftX + compact.X + 4 - bounds.Position.X;
        float rightPileX = rightX - 4 - bounds.End.X;
        float pileDy = 2 - bounds.Position.Y; // unit top level with the portrait

        var slots = new SeatSlot[6];
        for (int row = 0; row < 3; row++)
        {
            slots[2 - row] = new SeatSlot(new Vector2(leftX, rowY[row]), SeatStyle.CompactLeft,
                new Vector2(leftPileX, rowY[row] + pileDy), true);
            slots[3 + row] = new SeatSlot(new Vector2(rightX, rowY[row]), SeatStyle.CompactRight,
                new Vector2(rightPileX, rowY[row] + pileDy), true);
        }
        Opponents = SlotsForCount[opponentCount - 1].Select(i => slots[i]).ToArray();

        // Bottom: human seat in the corner with their piles on the table edge just above it;
        // the (taller) action panel to its left, overlapping the table's corner while shown.
        float bottom = viewport.Y - safeBottom - Margin;
        var humanSeat = new Vector2(viewport.X - Margin - wide.X, bottom - wide.Y);
        ActionBar = new Rect2(Margin, bottom - ActionPanelHeight, viewport.X - wide.X - Margin * 3, ActionPanelHeight);
        Table = new Rect2(2, top - 2, viewport.X - 4, humanSeat.Y - 2 - (top - 2));

        var pairBounds = TableScene.HorizontalPileUnitBounds;
        var humanPiles = new Vector2(viewport.X - Margin - 4 - pairBounds.End.X, Table.End.Y - 2 - pairBounds.End.Y);
        Human = new SeatSlot(humanSeat, SeatStyle.Wide, humanPiles, false);

        // Large board centred in the space between the NPCs and the bottom, with the
        // pot / NEXT HAND button under it, kept clear of the action panel and the human's piles.
        var card = CardView.CardSize * BoardCardScale;
        float boardWidth = card.X * 5 + BoardCardGap * 4;
        float areaTop = npcBottom + 6; // room for winning cards to lift
        float areaBottom = Mathf.Min(ActionBar.Position.Y, humanPiles.Y + pairBounds.Position.Y) - 4;
        float blockHeight = card.Y + 6 + NextHandSize.Y;
        float boardY = Mathf.Floor(areaTop + Mathf.Max(0, areaBottom - areaTop - blockHeight) / 2);
        BoardOrigin = new Vector2(Mathf.Floor((viewport.X - boardWidth) / 2), boardY);
        PotCenter = new Vector2(Mathf.Floor(viewport.X / 2), boardY + card.Y + 6 + NextHandSize.Y / 2);

        // MENU: top centre, in the gap between the two columns of chip piles.
        MenuButton = new Rect2(Mathf.Floor(viewport.X / 2) - 24, top, 48, 26);
    }

    /// <summary>Safe-area insets (top, bottom) in viewport units; zero except on phones.</summary>
    public static (float Top, float Bottom) SafeInsets(Viewport viewport)
    {
        if (!OS.HasFeature("mobile")) return (0, 0);
        var screen = DisplayServer.ScreenGetSize();
        var safe = DisplayServer.GetDisplaySafeArea();
        float scale = screen.Y / viewport.GetVisibleRect().Size.Y;
        return (safe.Position.Y / scale, (screen.Y - safe.End.Y) / scale);
    }
}

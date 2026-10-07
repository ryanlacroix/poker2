# Pixel Poker

A pixel-art No-Limit Texas Hold'em game against NPC opponents, built with Godot 4.7 (.NET / C#), laid out in portrait for Android phones.

Open the project in the Godot .NET editor and press **F5**. On desktop the game opens in a 540x960 portrait window. Keyboard shortcuts on your turn: **F** fold, **C** check/call, **R** bet/raise. Enter/Space deals the next hand.

## Layout

```
scenes/            main_menu.tscn, table.tscn (thin; UI is built in code)
scripts/
  core/            Pure C# poker model, no Godot dependency
    Card.cs, Deck.cs, Poker.cs (enums, Decision, DecisionContext)
    HandEvaluator.cs   best 5 of 7, comparable scores
    PokerPlayer.cs     stack + per-hand betting state
  game/PokerTable.cs   rules engine: blinds, betting rounds, side pots, showdown.
                       Async game loop that reports through C# events
  ai/NpcBrain.cs       Monte Carlo equity + personality (Resource)
  ui/                  TableScene, SeatView, CardView, ChipPileView, MainMenu, PixelArt, UiTheme
  autoload/GameConfig.cs  blinds, stacks, timings, opponent roster
data/npcs/*.tres     NPC personalities (edit in the inspector)
assets/sprites/      world_map.png background; fonts/, audio/ are placeholders
assets/portraits/    16x16 player portraits (one per NPC + you.png), each with an _injured variant
tools/               generate_world_map.py, generate_portraits.py (ignored by Godot)
tests/               headless smoke test
```

**How it fits together:** `PokerTable` owns the rules and never touches the UI. `TableScene` listens to its events and calls `SubmitHumanAction()` when the human picks an action. NPCs get a `DecisionContext` and return a `Decision`.

## Hearts

Every player starts with 3 hearts (`GameConfig.StartingHearts`), shown as pixel hearts under their name (lost hearts show as empty outlines). Down to the last heart, a player's portrait switches to an injured version (bandage, black eye and so on). Running out of chips knocks a player out, as before.

**Items:** a player can carry one item, shown as a small icon on their portrait. At the end of each hand, every player still in the game who isn't already carrying an item has a 1 in 6 chance (`PokerTable.ItemChance`; temporarily 1 in 2 for testing) of getting a random item, and each pickup is announced in turn ("SHARK got a gun"). Item names and messages live in `Item.cs`.

**Using the gun:** an item can't be used at the end of the hand it was picked up in, only from the end of the next hand on. Once it's ready, a **USE GUN** button appears in the bottom-left button area. Use it and a pixel gun appears over the board while every NPC still in the game glows red. Tap one to take a heart from them; the gun is used up and the next hand is dealt.

**The shield:** protects from the moment it's picked up: a shot at a shielded player breaks the shield instead of taking a heart. It has no use action.

**Dropping items:** whenever you hold an item between hands, a **DROP <item>** button sits in the bottom-left button area, even at the end of the hand you picked it up. Dropping frees the slot for a new item at the end of the next hand. An NPC who loses their last heart is eliminated, and their chips go to you.

## Portrait layout and Android

The base resolution is 360x640 (portrait), locked to portrait orientation. `PortraitLayout.cs` holds every position:

- NPCs are stacked closely at the top, 3 down each screen edge (6 in total). Each seat has a 48px portrait beside its cards, with the chip piles (drawn at 2x) on the table next to it.
- The board sits in the space below them, drawn at 2x size.
- Your seat (48px portrait, 2x cards) is pinned to the bottom-right corner, and your chips sit on the table's near edge above it.
- A column of big, well-spaced FOLD / CALL / raise-slider / RAISE buttons sits to the left of your seat (sizes in `PortraitLayout`). DEBUG is at the top centre: it opens a popup of testing actions (GIVE GUN / GIVE SHIELD, which replace your current item and make it ready to use at once).
- On taller phones (for example 1080x2400, which gives 360x800) the extra height goes to the board area. Wider screens widen the table.
- On phones, safe-area insets keep the UI clear of notches and gesture bars.

On phones the game scales up by whole numbers (`integer` scale mode), for example 3x on a 1080-wide screen. Desktop uses `fractional` (via the `.pc` override in `project.godot`) so the preview window fits a 1080p monitor.

To build for Android, install the Android SDK and a JDK, set their paths in Editor Settings, and install the .NET export templates for 4.7.2. Then use Project > Export > Add > Android. C# Android export needs the .NET build of the editor, which this project already uses.

## Pixel look

Everything scales up with nearest filtering and pixel snapping. Cards and suits are drawn as bitmap patterns in `PixelArt.cs`, so no card art is needed yet.

The world-map background (`assets/sprites/world_map.png`, 400x200; a screen-sized crop is drawn at 4x) is generated from Natural Earth's public-domain coastlines. To regenerate it, for example after changing the palette or the size, run `python3 tools/generate_world_map.py [width height]` (needs Pillow). To use a pixel font, put it at `assets/fonts/pixel_font.ttf` and `UiTheme` loads it automatically.

## Adding an opponent

Duplicate a file in `data/npcs/`, set its Portrait and InjuredPortrait (add the art and its injury rows to `tools/generate_portraits.py`, or drop in your own 16x16 PNGs), tweak Tightness / Aggression / BluffRate / Simulations, and add its path to `GameConfig.OpponentPaths`. The table fits at most 6 opponents (3 per side); with fewer, `PortraitLayout` picks a balanced subset of seats.

## Tests

```
godot --headless res://tests/sim_test.tscn
```
Checks hand-evaluator cases, then plays an all-NPC game with no delays and confirms chips are conserved after every hand. The exit code is the number of failures.

## Roadmap ideas

- Sprite art: card sheet, chip stacks, NPC portraits with tells/expressions
- Chip-slide and card-deal animations (Tweens), sound effects
- Rising blinds / tournament structure, settings menu
- Smarter AI: position awareness, opponent modelling, hand-range preflop tables
- Save/load bankroll, multiple tables or a "poker tour" progression

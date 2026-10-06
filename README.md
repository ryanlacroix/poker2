# Pixel Poker

A pixel-art No-Limit Texas Hold'em game against NPC opponents, built with Godot 4.7 (.NET / C#).

Open the project in the Godot .NET editor and press **F5**. Keyboard shortcuts on your turn: **F** fold, **C** check/call, **R** bet/raise.

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
assets/portraits/    16x16 player portraits (one per NPC + you.png)
tools/               generate_world_map.py, generate_portraits.py (ignored by Godot)
tests/               headless smoke test
```

**How it fits together:** `PokerTable` owns the rules and never touches the UI. `TableScene` listens to its events and calls `SubmitHumanAction()` when the human picks an action. NPCs get a `DecisionContext` and return a `Decision`.

## Pixel look

The game renders at 640x360 and scales up by whole numbers (`viewport` stretch, `integer` scale, nearest filtering, pixel snapping). Cards and suits are drawn as bitmap patterns in `PixelArt.cs`, so no card art is needed yet.

The world-map background (`assets/sprites/world_map.png`, 160x90, shown at 4x) is generated from Natural Earth's public-domain coastlines. To regenerate it, for example after changing the palette or the size, run `python3 tools/generate_world_map.py [width height]` (needs Pillow). To use a pixel font, put it at `assets/fonts/pixel_font.ttf` and `UiTheme` loads it automatically.

## Adding an opponent

Duplicate a file in `data/npcs/`, set its Portrait (add the art to `tools/generate_portraits.py` or drop in your own 16x16 PNG), tweak Tightness / Aggression / BluffRate / Simulations, and add its path to `GameConfig.OpponentPaths`. Seats are placed around the table automatically.

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

using System.Collections.Generic;
using System.Linq;
using Godot;

namespace PokerGame;

/// <summary>Global game settings, autoloaded as /root/GameConfig.</summary>
public partial class GameConfig : Node
{
    public static GameConfig Instance { get; private set; } = null!;

    /// <summary>
    /// NPC personalities seated at the table, in seat order (clockwise from the human).
    /// The portrait table has room for up to <see cref="PortraitLayout.MaxOpponents"/>.
    /// </summary>
    public static readonly string[] OpponentPaths =
    {
        "res://data/npcs/rocky.tres",    // tight-passive
        "res://data/npcs/lucky.tres",    // calling station
        "res://data/npcs/maverick.tres", // loose-aggressive
        "res://data/npcs/shark.tres",    // tight-aggressive, strongest reader
        "res://data/npcs/doc.tres",      // balanced
        "res://data/npcs/duke.tres",     // maniac
    };

    public string PlayerName { get; set; } = "YOU";
    public string PlayerPortraitPath { get; set; } = "res://assets/portraits/you.png";
    public int StartingChips { get; set; } = 1000;
    /// <summary>Hearts each player starts with (shown under their name).</summary>
    public int StartingHearts { get; set; } = 3;
    public int SmallBlind { get; set; } = 10;
    public int BigBlind { get; set; } = 20;
    public double NpcThinkTime { get; set; } = 0.8;
    public double DealDelay { get; set; } = 0.4;
    public double ShowdownDelay { get; set; } = 2.5;
    public double BetweenHandsDelay { get; set; } = 1.5;

    public override void _EnterTree()
    {
        Instance = this;
        GetTree().Root.Theme = UiTheme.Build();
    }

    public List<PokerPlayer> CreatePlayers()
    {
        var players = new List<PokerPlayer> { new(PlayerName, StartingChips, hearts: StartingHearts) };
        players.AddRange(OpponentPaths
            .Select(path => GD.Load<NpcBrain>(path))
            .Select(brain => new PokerPlayer(brain.DisplayName, StartingChips, brain, StartingHearts)));
        return players;
    }
}

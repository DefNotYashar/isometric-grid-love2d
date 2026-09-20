-- forest_elite_005 — elite: cross-shaped mountain fortress
return {
    id = "forest_elite_005",
    width = 10,
    height = 10,

    tiles = {
        { "grass", "grass", "grass", "grass", "mountain", "mountain", "grass", "grass", "grass", "grass" },
        { "grass", "grass", "grass", "grass", "mountain", "mountain", "grass", "grass", "grass", "grass" },
        { "grass", "grass", "grass", "grass", "mountain", "mountain", "grass", "grass", "grass", "grass" },
        { "grass", "grass", "grass", "grass", "mountain", "mountain", "grass", "grass", "grass", "grass" },
        { "mountain", "mountain", "mountain", "mountain", "mountain", "mountain", "mountain", "mountain", "mountain", "mountain" },
        { "mountain", "mountain", "mountain", "mountain", "mountain", "mountain", "mountain", "mountain", "mountain", "mountain" },
        { "grass", "grass", "grass", "grass", "mountain", "mountain", "grass", "grass", "grass", "grass" },
        { "grass", "grass", "grass", "grass", "mountain", "mountain", "grass", "grass", "grass", "grass" },
        { "grass", "grass", "grass", "grass", "mountain", "mountain", "grass", "grass", "grass", "grass" },
        { "grass", "grass", "grass", "grass", "mountain", "mountain", "grass", "grass", "grass", "grass" },
    },

    heights = {
        { 0, 0, 0, 0, 2, 2, 0, 0, 0, 0 },
        { 0, 0, 0, 0, 2, 2, 0, 0, 0, 0 },
        { 0, 0, 0, 0, 2, 2, 0, 0, 0, 0 },
        { 0, 0, 0, 0, 2, 2, 0, 0, 0, 0 },
        { 2, 2, 2, 2, 2, 2, 2, 2, 2, 2 },
        { 2, 2, 2, 2, 2, 2, 2, 2, 2, 2 },
        { 0, 0, 0, 0, 2, 2, 0, 0, 0, 0 },
        { 0, 0, 0, 0, 2, 2, 0, 0, 0, 0 },
        { 0, 0, 0, 0, 2, 2, 0, 0, 0, 0 },
        { 0, 0, 0, 0, 2, 2, 0, 0, 0, 0 },
    },

    player_spawns = {
        { x = 2, y = 5 }, { x = 3, y = 5 }, { x = 2, y = 6 }, { x = 3, y = 6 },
    },

    enemy_spawns = {
        { x = 8, y = 5 }, { x = 9, y = 5 }, { x = 8, y = 6 }, { x = 9, y = 6 },
    },

    tags = { "forest", "elite", "mountain", "fortress", "cross", "chokepoint" },
}
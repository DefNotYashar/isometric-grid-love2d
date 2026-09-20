-- forest_008 — mountain pass (long winding corridor)
return {
    id = "forest_008",
    width = 10,
    height = 10,

    tiles = {
        { "mountain", "mountain", "mountain", "mountain", "mountain", "mountain", "mountain", "mountain", "mountain", "mountain" },
        { "mountain", "grass", "grass", "grass", "grass", "grass", "grass", "grass", "grass", "mountain" },
        { "mountain", "grass", "mountain", "mountain", "mountain", "mountain", "mountain", "mountain", "grass", "mountain" },
        { "mountain", "grass", "mountain", "grass", "grass", "grass", "grass", "mountain", "grass", "mountain" },
        { "mountain", "grass", "mountain", "grass", "mountain", "mountain", "grass", "mountain", "grass", "mountain" },
        { "mountain", "grass", "mountain", "grass", "mountain", "mountain", "grass", "mountain", "grass", "mountain" },
        { "mountain", "grass", "mountain", "grass", "grass", "grass", "grass", "mountain", "grass", "mountain" },
        { "mountain", "grass", "mountain", "mountain", "mountain", "mountain", "mountain", "mountain", "grass", "mountain" },
        { "mountain", "grass", "grass", "grass", "grass", "grass", "grass", "grass", "grass", "mountain" },
        { "mountain", "mountain", "mountain", "mountain", "mountain", "mountain", "mountain", "mountain", "mountain", "mountain" },
    },

    heights = {
        { 2, 2, 2, 2, 2, 2, 2, 2, 2, 2 },
        { 2, 0, 0, 0, 0, 0, 0, 0, 0, 2 },
        { 2, 0, 2, 2, 2, 2, 2, 2, 0, 2 },
        { 2, 0, 2, 0, 0, 0, 0, 2, 0, 2 },
        { 2, 0, 2, 0, 2, 2, 0, 2, 0, 2 },
        { 2, 0, 2, 0, 2, 2, 0, 2, 0, 2 },
        { 2, 0, 2, 0, 0, 0, 0, 2, 0, 2 },
        { 2, 0, 2, 2, 2, 2, 2, 2, 0, 2 },
        { 2, 0, 0, 0, 0, 0, 0, 0, 0, 2 },
        { 2, 2, 2, 2, 2, 2, 2, 2, 2, 2 },
    },

    player_spawns = {
        { x = 2, y = 9 }, { x = 2, y = 8 }, { x = 2, y = 7 }, { x = 2, y = 6 },
    },

    enemy_spawns = {
        { x = 9, y = 2 }, { x = 9, y = 3 }, { x = 9, y = 4 }, { x = 9, y = 5 },
    },

    tags = { "forest", "mountain", "chokepoint", "corridor" },
}
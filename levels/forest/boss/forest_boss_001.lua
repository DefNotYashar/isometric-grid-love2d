-- forest_boss_001 — boss arena: designed for boss encounter
return {
    id = "forest_boss_001",
    width = 10,
    height = 10,

    tiles = {
        { "default", "default", "grass",   "grass",   "mountain", "mountain", "grass",   "grass",   "default", "default" },
        { "default", "grass",   "grass",   "mountain", "mountain", "mountain", "mountain", "grass",   "grass",   "default" },
        { "grass",   "grass",   "mountain", "mountain", "grass",    "grass",    "mountain", "mountain", "grass",   "grass" },
        { "grass",   "mountain", "mountain", "water",   "grass",    "grass",    "water",    "mountain", "mountain", "grass" },
        { "mountain", "mountain", "water",   "grass",   "grass",    "grass",    "grass",    "water",    "mountain", "mountain" },
        { "mountain", "mountain", "water",   "grass",   "grass",    "grass",    "grass",    "water",    "mountain", "mountain" },
        { "grass",   "mountain", "mountain", "water",   "grass",    "grass",    "water",    "mountain", "mountain", "grass" },
        { "grass",   "grass",   "mountain", "mountain", "grass",    "grass",    "mountain", "mountain", "grass",   "grass" },
        { "default", "grass",   "grass",   "mountain", "grass",   "grass",   "mountain", "grass",   "grass",   "default" },
        { "default", "default", "grass",   "grass",   "grass",   "grass",   "grass",   "grass",   "default", "default" },
    },

    heights = {
        { 0, 0, 0, 0, 2, 2, 0, 0, 0, 0 },
        { 0, 0, 0, 2, 2, 2, 2, 0, 0, 0 },
        { 0, 0, 2, 2, 0, 0, 2, 2, 0, 0 },
        { 0, 2, 2, 0, 0, 0, 0, 2, 2, 0 },
        { 2, 2, 0, 0, 0, 0, 0, 0, 2, 2 },
        { 2, 2, 0, 0, 0, 0, 0, 0, 2, 2 },
        { 0, 2, 2, 0, 0, 0, 0, 2, 2, 0 },
        { 0, 0, 2, 2, 0, 0, 2, 2, 0, 0 },
        { 0, 0, 0, 2, 0, 0, 2, 0, 0, 0 },
        { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
    },

    player_spawns = {
        { x = 5, y = 9 },
        { x = 6, y = 9 },
        { x = 5, y = 10 },
        { x = 6, y = 10 },
    },

    enemy_spawns = {
        { x = 5, y = 5 },
        { x = 6, y = 5 },
    },

    tags = { "forest", "boss", "mountain", "water", "arena" },
}
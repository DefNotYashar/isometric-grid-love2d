-- forest_002 — central obstacle (mountain cluster)
return {
    id = "forest_002",
    width = 10,
    height = 10,

    tiles = {
        { "default", "default", "grass",   "grass",   "grass",   "grass",   "grass",   "default", "default", "default" },
        { "default", "grass",   "grass",   "meadow",  "mountain", "mountain", "meadow",  "grass",   "default", "default" },
        { "grass",   "grass",   "meadow",  "mountain", "mountain", "mountain", "mountain", "meadow",  "grass",   "default" },
        { "grass",   "meadow",  "mountain", "mountain", "mountain", "mountain", "mountain", "mountain", "meadow",  "grass" },
        { "grass",   "meadow",  "mountain", "mountain", "mountain", "mountain", "mountain", "mountain", "meadow",  "grass" },
        { "grass",   "meadow",  "mountain", "mountain", "mountain", "mountain", "mountain", "mountain", "meadow",  "grass" },
        { "grass",   "meadow",  "mountain", "mountain", "mountain", "mountain", "mountain", "mountain", "meadow",  "grass" },
        { "default", "grass",   "meadow",  "mountain", "mountain", "mountain", "mountain", "meadow",  "grass",   "default" },
        { "default", "default", "grass",   "meadow",  "mountain", "mountain", "meadow",  "grass",   "default", "default" },
        { "default", "default", "default", "grass",   "grass",   "grass",   "grass",   "default", "default", "default" },
    },

    heights = {
        { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
        { 0, 0, 0, 0, 2, 2, 0, 0, 0, 0 },
        { 0, 0, 0, 2, 2, 2, 2, 2, 0, 0 },
        { 0, 0, 2, 2, 2, 2, 2, 2, 2, 0 },
        { 0, 0, 2, 2, 2, 2, 2, 2, 2, 0 },
        { 0, 0, 2, 2, 2, 2, 2, 2, 2, 0 },
        { 0, 0, 2, 2, 2, 2, 2, 2, 2, 0 },
        { 0, 0, 0, 2, 2, 2, 2, 2, 0, 0 },
        { 0, 0, 0, 0, 2, 2, 0, 0, 0, 0 },
        { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
    },

    player_spawns = {
        { x = 2, y = 9 },
        { x = 3, y = 9 },
        { x = 2, y = 10 },
        { x = 3, y = 10 },
    },

    enemy_spawns = {
        { x = 9, y = 2 },
        { x = 10, y = 2 },
        { x = 9, y = 3 },
        { x = 10, y = 3 },
    },

    tags = { "forest", "mountain", "chokepoint" },
}
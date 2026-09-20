-- forest_elite_001 — elite: more obstacles, tougher terrain
return {
    id = "forest_elite_001",
    width = 10,
    height = 10,

    tiles = {
        { "default", "grass",   "grass",   "mountain", "mountain", "mountain", "mountain", "grass",   "grass",   "default" },
        { "grass",   "grass",   "meadow",  "mountain", "tall",     "tall",     "mountain", "meadow",  "grass",   "grass" },
        { "grass",   "meadow",  "mountain", "tall",    "water",    "water",    "tall",    "mountain", "meadow",  "grass" },
        { "mountain", "mountain", "tall",   "water",   "water",    "water",    "water",   "tall",    "mountain", "mountain" },
        { "mountain", "tall",   "water",   "water",   "water",    "water",    "water",   "water",   "tall",    "mountain" },
        { "mountain", "tall",   "water",   "water",   "water",    "water",    "water",   "water",   "tall",    "mountain" },
        { "mountain", "mountain", "tall",   "water",   "water",    "water",    "water",   "tall",    "mountain", "mountain" },
        { "grass",   "meadow",  "mountain", "tall",    "water",    "water",    "tall",    "mountain", "meadow",  "grass" },
        { "grass",   "grass",   "meadow",  "mountain", "tall",     "tall",     "mountain", "meadow",  "grass",   "grass" },
        { "default", "grass",   "grass",   "mountain", "mountain", "mountain", "mountain", "grass",   "grass",   "default" },
    },

    heights = {
        { 0, 0, 0, 2, 2, 2, 2, 0, 0, 0 },
        { 0, 0, 0, 2, 0, 0, 2, 0, 0, 0 },
        { 0, 0, 2, 0, 0, 0, 0, 2, 0, 0 },
        { 2, 2, 0, 0, 0, 0, 0, 0, 2, 2 },
        { 2, 0, 0, 0, 0, 0, 0, 0, 0, 2 },
        { 2, 0, 0, 0, 0, 0, 0, 0, 0, 2 },
        { 2, 2, 0, 0, 0, 0, 0, 0, 2, 2 },
        { 0, 0, 2, 0, 0, 0, 0, 2, 0, 0 },
        { 0, 0, 0, 2, 0, 0, 2, 0, 0, 0 },
        { 0, 0, 0, 2, 2, 2, 2, 0, 0, 0 },
    },

    player_spawns = {
        { x = 2, y = 9 },
        { x = 3, y = 9 },
        { x = 2, y = 10 },
        { x = 3, y = 10 },
    },

    enemy_spawns = {
        { x = 8, y = 2 },
        { x = 9, y = 2 },
        { x = 8, y = 3 },
        { x = 9, y = 3 },
        { x = 7, y = 2 },
        { x = 7, y = 3 },
    },

    tags = { "forest", "elite", "mountain", "water", "tall", "chokepoint" },
}
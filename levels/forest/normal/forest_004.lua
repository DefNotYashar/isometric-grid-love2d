-- forest_004 — asymmetric terrain (uneven player/enemy areas)
return {
    id = "forest_004",
    width = 10,
    height = 10,

    tiles = {
        { "default", "default", "grass",   "grass",   "grass",   "grass",   "grass",   "grass",   "grass",   "grass" },
        { "default", "grass",   "grass",   "meadow",  "meadow",  "flower",  "grass",   "grass",   "grass",   "grass" },
        { "grass",   "grass",   "meadow",  "tall",    "tall",    "tall",    "tall",    "meadow",  "grass",   "grass" },
        { "grass",   "meadow",  "tall",    "tall",    "water",   "water",   "tall",    "tall",    "meadow",  "grass" },
        { "grass",   "meadow",  "tall",    "water",   "water",   "water",   "water",   "tall",    "meadow",  "grass" },
        { "grass",   "meadow",  "tall",    "water",   "water",   "water",   "water",   "tall",    "meadow",  "grass" },
        { "grass",   "meadow",  "tall",    "tall",    "water",   "water",   "tall",    "tall",    "meadow",  "grass" },
        { "grass",   "meadow",  "tall",    "tall",    "tall",    "tall",    "tall",    "meadow",  "grass",   "grass" },
        { "grass",   "grass",   "meadow",  "meadow",  "flower",  "grass",   "grass",   "grass",   "grass",   "grass" },
        { "default", "grass",   "grass",   "grass",   "grass",   "grass",   "grass",   "grass",   "grass",   "grass" },
    },

    heights = {
        { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
        { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
        { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
        { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
        { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
        { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
        { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
        { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
        { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
        { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
    },

    player_spawns = {
        { x = 2, y = 9 },
        { x = 3, y = 9 },
        { x = 2, y = 10 },
        { x = 3, y = 10 },
        { x = 4, y = 10 },
    },

    enemy_spawns = {
        { x = 7, y = 2 },
        { x = 8, y = 2 },
        { x = 9, y = 2 },
        { x = 7, y = 3 },
        { x = 8, y = 3 },
        { x = 9, y = 3 },
    },

    tags = { "forest", "asymmetric", "tall", "water" },
}
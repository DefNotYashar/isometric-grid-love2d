-- forest_003 — water division (river splitting the map)
return {
    id = "forest_003",
    width = 10,
    height = 10,

    tiles = {
        { "default", "default", "default", "grass",  "grass",  "water",  "water",  "grass",   "grass",   "default" },
        { "default", "grass",   "grass",   "grass",  "water",  "water",  "water",  "grass",   "default", "default" },
        { "grass",   "grass",   "meadow",  "water",  "water",  "water",  "water",  "water",   "grass",   "default" },
        { "grass",   "meadow",  "water",   "water",  "water",  "water",  "water",  "water",   "meadow",  "grass" },
        { "default", "grass",   "grass",   "grass",  "grass",  "grass",  "grass",  "grass",   "grass",   "default" },
        { "default", "grass",   "grass",   "grass",  "grass",  "grass",  "grass",  "grass",   "grass",   "default" },
        { "grass",   "meadow",  "water",   "water",  "water",  "water",  "water",  "water",   "meadow",  "grass" },
        { "grass",   "grass",   "meadow",  "water",  "water",  "water",  "water",  "water",   "grass",   "default" },
        { "default", "grass",   "grass",   "grass",  "water",  "water",  "water",  "grass",   "default", "default" },
        { "default", "default", "default", "grass",  "grass",  "water",  "water",  "grass",   "grass",   "default" },
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
    },

    enemy_spawns = {
        { x = 9, y = 5 },
        { x = 10, y = 5 },
        { x = 9, y = 6 },
        { x = 10, y = 6 },
    },

    tags = { "forest", "water", "division" },
}
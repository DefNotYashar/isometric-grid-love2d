-- forest_005 — chokepoint (narrow bridges over water)
return {
    id = "forest_005",
    width = 10,
    height = 10,

    tiles = {
        { "grass",   "grass",   "grass",   "water",   "water",   "water",   "water",   "grass",   "grass",   "grass" },
        { "grass",   "meadow",  "grass",   "water",   "water",   "water",   "water",   "grass",   "meadow",  "grass" },
        { "grass",   "grass",   "grass",   "grass",   "water",   "water",   "grass",   "grass",   "grass",   "grass" },
        { "water",   "water",   "grass",   "grass",   "grass",   "grass",   "grass",   "grass",   "water",   "water" },
        { "water",   "water",   "water",   "grass",   "grass",   "grass",   "grass",   "water",   "water",   "water" },
        { "water",   "water",   "water",   "grass",   "grass",   "grass",   "grass",   "water",   "water",   "water" },
        { "water",   "water",   "grass",   "grass",   "grass",   "grass",   "grass",   "grass",   "water",   "water" },
        { "grass",   "grass",   "grass",   "grass",   "water",   "water",   "grass",   "grass",   "grass",   "grass" },
        { "grass",   "meadow",  "grass",   "water",   "water",   "water",   "water",   "grass",   "meadow",  "grass" },
        { "grass",   "grass",   "grass",   "water",   "water",   "water",   "water",   "grass",   "grass",   "grass" },
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
        { x = 4, y = 9 },
        { x = 2, y = 10 },
        { x = 3, y = 10 },
    },

    enemy_spawns = {
        { x = 7, y = 2 },
        { x = 8, y = 2 },
        { x = 9, y = 2 },
        { x = 7, y = 3 },
        { x = 8, y = 3 },
        { x = 9, y = 3 },
    },

    tags = { "forest", "water", "chokepoint", "bridges" },
}
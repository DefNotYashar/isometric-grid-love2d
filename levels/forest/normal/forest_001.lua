-- forest_001 — open battlefield with scattered terrain
return {
    id = "forest_001",
    width = 10,
    height = 10,

    -- terrain[y][x]: "default" | "grass" | "meadow" | "flower" | "tall" | "water" | "mountain"
    tiles = {
        { "default", "default", "default", "grass",  "grass",  "grass",  "default", "default", "default", "default" },
        { "default", "grass",   "grass",   "grass",  "meadow", "flower", "grass",   "default", "default", "default" },
        { "default", "grass",   "meadow",  "meadow", "flower", "tall",   "tall",    "grass",   "default", "default" },
        { "grass",   "grass",   "grass",   "meadow", "tall",   "tall",   "water",   "water",   "default", "default" },
        { "grass",   "meadow",  "flower",  "tall",   "tall",   "water",  "water",   "default", "default", "default" },
        { "default", "grass",   "tall",    "tall",   "water",  "water",  "default", "default", "default", "default" },
        { "default", "default", "grass",   "water",  "water",  "default", "default", "default", "grass",   "grass" },
        { "default", "default", "default", "default", "default", "default", "default", "grass",   "grass",   "grass" },
        { "default", "default", "default", "default", "default", "default", "grass",   "grass",   "meadow",  "meadow" },
        { "default", "default", "default", "default", "default", "grass",   "grass",   "meadow",  "flower",  "flower" },
    },

    -- heights[y][x]: 0 = flat, 1 = hill (walkable), 2 = mountain (blocked)
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

    -- Player spawn positions (bottom-left area)
    player_spawns = {
        { x = 2, y = 9 },
        { x = 3, y = 9 },
        { x = 2, y = 10 },
        { x = 3, y = 10 },
    },

    -- Enemy spawn positions (top-right area)
    enemy_spawns = {
        { x = 8, y = 2 },
        { x = 9, y = 2 },
        { x = 8, y = 3 },
        { x = 9, y = 3 },
        { x = 10, y = 2 },
        { x = 10, y = 3 },
    },

    tags = { "forest", "open", "water" },
}
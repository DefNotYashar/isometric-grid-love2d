-- forest_010 — flower field (open with flowers, few obstacles)
return {
    id = "forest_010",
    width = 10,
    height = 10,

    tiles = {
        { "grass", "grass", "grass", "flower", "flower", "flower", "flower", "grass", "grass", "grass" },
        { "grass", "meadow", "flower", "flower", "flower", "flower", "flower", "flower", "meadow", "grass" },
        { "grass", "flower", "flower", "meadow", "meadow", "meadow", "meadow", "flower", "flower", "grass" },
        { "flower", "flower", "meadow", "meadow", "grass", "grass", "meadow", "meadow", "flower", "flower" },
        { "flower", "flower", "meadow", "grass", "default", "default", "grass", "meadow", "flower", "flower" },
        { "flower", "flower", "meadow", "grass", "default", "default", "grass", "meadow", "flower", "flower" },
        { "flower", "flower", "meadow", "meadow", "grass", "grass", "meadow", "meadow", "flower", "flower" },
        { "grass", "flower", "flower", "meadow", "meadow", "meadow", "meadow", "flower", "flower", "grass" },
        { "grass", "meadow", "flower", "flower", "flower", "flower", "flower", "flower", "meadow", "grass" },
        { "grass", "grass", "grass", "flower", "flower", "flower", "flower", "grass", "grass", "grass" },
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
        { x = 2, y = 9 }, { x = 3, y = 9 }, { x = 2, y = 10 }, { x = 3, y = 10 },
    },

    enemy_spawns = {
        { x = 8, y = 2 }, { x = 9, y = 2 }, { x = 8, y = 3 }, { x = 9, y = 3 },
    },

    tags = { "forest", "open", "flower" },
}
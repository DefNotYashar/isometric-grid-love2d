-- forest_009 — split battlefield (water divides left/right)
return {
    id = "forest_009",
    width = 10,
    height = 10,

    tiles = {
        { "grass", "grass", "grass", "grass", "water", "water", "grass", "grass", "grass", "grass" },
        { "grass", "meadow", "flower", "grass", "water", "water", "grass", "flower", "meadow", "grass" },
        { "grass", "grass", "grass", "grass", "water", "water", "grass", "grass", "grass", "grass" },
        { "tall", "tall", "grass", "grass", "water", "water", "grass", "grass", "tall", "tall" },
        { "tall", "tall", "tall", "tall", "grass", "grass", "tall", "tall", "tall", "tall" },
        { "tall", "tall", "tall", "tall", "grass", "grass", "tall", "tall", "tall", "tall" },
        { "tall", "tall", "grass", "grass", "water", "water", "grass", "grass", "tall", "tall" },
        { "grass", "grass", "grass", "grass", "water", "water", "grass", "grass", "grass", "grass" },
        { "grass", "meadow", "flower", "grass", "water", "water", "grass", "flower", "meadow", "grass" },
        { "grass", "grass", "grass", "grass", "water", "water", "grass", "grass", "grass", "grass" },
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

    tags = { "forest", "water", "division", "tall" },
}
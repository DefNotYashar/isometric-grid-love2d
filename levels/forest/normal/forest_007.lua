-- forest_007 — tall grass maze (dodge-heavy)
return {
    id = "forest_007",
    width = 10,
    height = 10,

    tiles = {
        { "default", "default", "tall", "tall", "tall", "tall", "tall", "default", "default", "default" },
        { "default", "tall", "tall", "grass", "grass", "grass", "tall", "tall", "default", "default" },
        { "tall", "tall", "grass", "tall", "tall", "tall", "grass", "tall", "tall", "default" },
        { "tall", "grass", "tall", "tall", "water", "water", "tall", "tall", "grass", "tall" },
        { "tall", "grass", "tall", "water", "tall", "tall", "water", "tall", "grass", "tall" },
        { "tall", "grass", "tall", "water", "tall", "tall", "water", "tall", "grass", "tall" },
        { "tall", "grass", "tall", "tall", "water", "water", "tall", "tall", "grass", "tall" },
        { "tall", "tall", "grass", "tall", "tall", "tall", "grass", "tall", "tall", "default" },
        { "default", "tall", "tall", "grass", "grass", "grass", "tall", "tall", "default", "default" },
        { "default", "default", "tall", "tall", "tall", "tall", "tall", "default", "default", "default" },
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

    tags = { "forest", "tall", "maze", "dodge" },
}
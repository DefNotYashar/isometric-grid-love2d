-- forest_boss_002 — boss: ancient grove arena (water moat, tall grass)
return {
    id = "forest_boss_002",
    width = 10,
    height = 10,

    tiles = {
        { "water", "water", "water", "water", "water", "water", "water", "water", "water", "water" },
        { "water", "tall", "tall", "tall", "tall", "tall", "tall", "tall", "tall", "water" },
        { "water", "tall", "grass", "grass", "grass", "grass", "grass", "grass", "tall", "water" },
        { "water", "tall", "grass", "flower", "flower", "flower", "flower", "grass", "tall", "water" },
        { "water", "tall", "grass", "flower", "default", "default", "flower", "grass", "tall", "water" },
        { "water", "tall", "grass", "flower", "default", "default", "flower", "grass", "tall", "water" },
        { "water", "tall", "grass", "flower", "flower", "flower", "flower", "grass", "tall", "water" },
        { "water", "tall", "grass", "grass", "grass", "grass", "grass", "grass", "tall", "water" },
        { "water", "tall", "tall", "tall", "tall", "tall", "tall", "tall", "tall", "water" },
        { "water", "water", "water", "water", "water", "water", "water", "water", "water", "water" },
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
        { x = 5, y = 9 }, { x = 6, y = 9 },
    },

    enemy_spawns = {
        { x = 5, y = 2 }, { x = 6, y = 2 },
    },

    tags = { "forest", "boss", "water", "tall", "flower", "arena", "moat" },
}
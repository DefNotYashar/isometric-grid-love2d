-- forest_boss_003 — boss: volcanic crater arena (mountain ring, central platform)
return {
    id = "forest_boss_003",
    width = 10,
    height = 10,

    tiles = {
        { "mountain", "mountain", "mountain", "mountain", "mountain", "mountain", "mountain", "mountain", "mountain", "mountain" },
        { "mountain", "grass", "grass", "grass", "grass", "grass", "grass", "grass", "grass", "mountain" },
        { "mountain", "grass", "water", "water", "water", "water", "water", "water", "grass", "mountain" },
        { "mountain", "grass", "water", "default", "default", "default", "default", "water", "grass", "mountain" },
        { "mountain", "grass", "water", "default", "mountain", "mountain", "default", "water", "grass", "mountain" },
        { "mountain", "grass", "water", "default", "mountain", "mountain", "default", "water", "grass", "mountain" },
        { "mountain", "grass", "water", "default", "default", "default", "default", "water", "grass", "mountain" },
        { "mountain", "grass", "water", "water", "water", "water", "water", "water", "grass", "mountain" },
        { "mountain", "grass", "grass", "grass", "grass", "grass", "grass", "grass", "grass", "mountain" },
        { "mountain", "mountain", "mountain", "mountain", "mountain", "mountain", "mountain", "mountain", "mountain", "mountain" },
    },

    heights = {
        { 2, 2, 2, 2, 2, 2, 2, 2, 2, 2 },
        { 2, 0, 0, 0, 0, 0, 0, 0, 0, 2 },
        { 2, 0, 0, 0, 0, 0, 0, 0, 0, 2 },
        { 2, 0, 0, 0, 0, 0, 0, 0, 0, 2 },
        { 2, 0, 0, 0, 2, 2, 0, 0, 0, 2 },
        { 2, 0, 0, 0, 2, 2, 0, 0, 0, 2 },
        { 2, 0, 0, 0, 0, 0, 0, 0, 0, 2 },
        { 2, 0, 0, 0, 0, 0, 0, 0, 0, 2 },
        { 2, 0, 0, 0, 0, 0, 0, 0, 0, 2 },
        { 2, 2, 2, 2, 2, 2, 2, 2, 2, 2 },
    },

    player_spawns = {
        { x = 5, y = 9 }, { x = 6, y = 9 }, { x = 4, y = 9 }, { x = 7, y = 9 },
    },

    enemy_spawns = {
        { x = 5, y = 2 }, { x = 6, y = 2 }, { x = 4, y = 2 }, { x = 7, y = 2 },
    },

    tags = { "forest", "boss", "mountain", "water", "crater", "arena" },
}
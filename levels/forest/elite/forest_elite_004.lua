-- forest_elite_004 — elite: asymmetric with multiple water channels
return {
    id = "forest_elite_004",
    width = 10,
    height = 10,

    tiles = {
        { "grass", "grass", "grass", "water", "water", "grass", "grass", "grass", "grass", "grass" },
        { "grass", "water", "water", "water", "water", "water", "water", "grass", "grass", "grass" },
        { "grass", "grass", "grass", "water", "mountain", "mountain", "water", "grass", "grass", "grass" },
        { "grass", "water", "water", "water", "mountain", "mountain", "water", "water", "water", "grass" },
        { "water", "mountain", "mountain", "mountain", "grass", "grass", "mountain", "mountain", "mountain", "grass" },
        { "water", "mountain", "mountain", "mountain", "grass", "grass", "mountain", "mountain", "mountain", "grass" },
        { "grass", "water", "water", "water", "mountain", "mountain", "water", "water", "water", "grass" },
        { "grass", "grass", "grass", "water", "mountain", "mountain", "water", "grass", "grass", "grass" },
        { "grass", "grass", "grass", "water", "water", "water", "water", "grass", "grass", "grass" },
        { "grass", "grass", "grass", "grass", "grass", "grass", "grass", "grass", "grass", "grass" },
    },

    heights = {
        { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
        { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
        { 0, 0, 0, 0, 2, 2, 0, 0, 0, 0 },
        { 0, 0, 0, 0, 2, 2, 0, 0, 0, 0 },
        { 0, 2, 2, 2, 0, 0, 2, 2, 2, 0 },
        { 0, 2, 2, 2, 0, 0, 2, 2, 2, 0 },
        { 0, 0, 0, 0, 2, 2, 0, 0, 0, 0 },
        { 0, 0, 0, 0, 2, 2, 0, 0, 0, 0 },
        { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
        { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
    },

    player_spawns = {
        { x = 2, y = 9 }, { x = 3, y = 9 }, { x = 2, y = 10 }, { x = 3, y = 10 },
    },

    enemy_spawns = {
        { x = 8, y = 2 }, { x = 9, y = 2 }, { x = 8, y = 3 }, { x = 9, y = 3 },
        { x = 10, y = 2 }, { x = 10, y = 3 },
    },

    tags = { "forest", "elite", "water", "mountain", "asymmetric", "channels" },
}
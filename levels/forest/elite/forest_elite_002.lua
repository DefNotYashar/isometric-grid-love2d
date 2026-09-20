-- forest_elite_002 — elite: water maze with mountain islands
return {
    id = "forest_elite_002",
    width = 10,
    height = 10,

    tiles = {
        { "water", "water", "water", "water", "water", "water", "water", "water", "water", "water" },
        { "water", "mountain", "grass", "grass", "water", "water", "grass", "grass", "mountain", "water" },
        { "water", "grass", "mountain", "grass", "water", "water", "grass", "mountain", "grass", "water" },
        { "water", "grass", "grass", "mountain", "water", "water", "mountain", "grass", "grass", "water" },
        { "water", "water", "water", "water", "water", "water", "water", "water", "water", "water" },
        { "water", "water", "water", "water", "water", "water", "water", "water", "water", "water" },
        { "water", "grass", "grass", "mountain", "water", "water", "mountain", "grass", "grass", "water" },
        { "water", "grass", "mountain", "grass", "water", "water", "grass", "mountain", "grass", "water" },
        { "water", "mountain", "grass", "grass", "water", "water", "grass", "grass", "mountain", "water" },
        { "water", "water", "water", "water", "water", "water", "water", "water", "water", "water" },
    },

    heights = {
        { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
        { 0, 2, 0, 0, 0, 0, 0, 0, 2, 0 },
        { 0, 0, 2, 0, 0, 0, 0, 2, 0, 0 },
        { 0, 0, 0, 2, 0, 0, 2, 0, 0, 0 },
        { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
        { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
        { 0, 0, 0, 2, 0, 0, 2, 0, 0, 0 },
        { 0, 0, 2, 0, 0, 0, 0, 2, 0, 0 },
        { 0, 2, 0, 0, 0, 0, 0, 0, 2, 0 },
        { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
    },

    player_spawns = {
        { x = 2, y = 9 }, { x = 3, y = 9 }, { x = 2, y = 10 }, { x = 3, y = 10 },
    },

    enemy_spawns = {
        { x = 8, y = 2 }, { x = 9, y = 2 }, { x = 8, y = 3 }, { x = 9, y = 3 },
    },

    tags = { "forest", "elite", "water", "mountain", "islands" },
}
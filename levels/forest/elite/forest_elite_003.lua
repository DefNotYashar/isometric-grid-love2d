-- forest_elite_003 — elite: tall grass forest with mountain walls
return {
    id = "forest_elite_003",
    width = 10,
    height = 10,

    tiles = {
        { "mountain", "mountain", "mountain", "mountain", "mountain", "mountain", "mountain", "mountain", "mountain", "mountain" },
        { "mountain", "tall", "tall", "tall", "tall", "tall", "tall", "tall", "tall", "mountain" },
        { "mountain", "tall", "grass", "grass", "grass", "grass", "grass", "grass", "tall", "mountain" },
        { "mountain", "tall", "grass", "water", "water", "water", "water", "grass", "tall", "mountain" },
        { "mountain", "tall", "grass", "water", "tall", "tall", "water", "grass", "tall", "mountain" },
        { "mountain", "tall", "grass", "water", "tall", "tall", "water", "grass", "tall", "mountain" },
        { "mountain", "tall", "grass", "water", "water", "water", "water", "grass", "tall", "mountain" },
        { "mountain", "tall", "grass", "grass", "grass", "grass", "grass", "grass", "tall", "mountain" },
        { "mountain", "tall", "tall", "tall", "tall", "tall", "tall", "tall", "tall", "mountain" },
        { "mountain", "mountain", "mountain", "mountain", "mountain", "mountain", "mountain", "mountain", "mountain", "mountain" },
    },

    heights = {
        { 2, 2, 2, 2, 2, 2, 2, 2, 2, 2 },
        { 2, 0, 0, 0, 0, 0, 0, 0, 0, 2 },
        { 2, 0, 0, 0, 0, 0, 0, 0, 0, 2 },
        { 2, 0, 0, 0, 0, 0, 0, 0, 0, 2 },
        { 2, 0, 0, 0, 0, 0, 0, 0, 0, 2 },
        { 2, 0, 0, 0, 0, 0, 0, 0, 0, 2 },
        { 2, 0, 0, 0, 0, 0, 0, 0, 0, 2 },
        { 2, 0, 0, 0, 0, 0, 0, 0, 0, 2 },
        { 2, 0, 0, 0, 0, 0, 0, 0, 0, 2 },
        { 2, 2, 2, 2, 2, 2, 2, 2, 2, 2 },
    },

    player_spawns = {
        { x = 5, y = 9 }, { x = 6, y = 9 }, { x = 5, y = 10 }, { x = 6, y = 10 },
    },

    enemy_spawns = {
        { x = 5, y = 2 }, { x = 6, y = 2 }, { x = 4, y = 2 }, { x = 7, y = 2 },
    },

    tags = { "forest", "elite", "tall", "mountain", "walled" },
}
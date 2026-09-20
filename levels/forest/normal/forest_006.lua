-- forest_006 — double chokepoint (two narrow land bridges)
return {
    id = "forest_006",
    width = 10,
    height = 10,

    tiles = {
        { "grass", "grass", "water", "water", "grass", "grass", "water", "water", "grass", "grass" },
        { "grass", "meadow", "water", "water", "meadow", "meadow", "water", "water", "grass", "grass" },
        { "grass", "grass", "water", "water", "grass", "grass", "water", "water", "grass", "grass" },
        { "grass", "grass", "grass", "grass", "water", "water", "grass", "grass", "grass", "grass" },
        { "grass", "grass", "grass", "grass", "grass", "grass", "grass", "grass", "grass", "grass" },
        { "grass", "grass", "grass", "grass", "grass", "grass", "grass", "grass", "grass", "grass" },
        { "grass", "grass", "grass", "grass", "water", "water", "grass", "grass", "grass", "grass" },
        { "grass", "grass", "water", "water", "grass", "grass", "water", "water", "grass", "grass" },
        { "grass", "meadow", "water", "water", "meadow", "meadow", "water", "water", "grass", "grass" },
        { "grass", "grass", "water", "water", "grass", "grass", "water", "water", "grass", "grass" },
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
        { x = 9, y = 5 }, { x = 10, y = 5 }, { x = 9, y = 6 }, { x = 10, y = 6 },
    },

    tags = { "forest", "water", "chokepoint", "bridges" },
}
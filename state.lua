-- state.lua — shared game state (spec 001).
-- Single table G required by every module. Access mutable scalars as
-- G.field AT USE TIME (never cache in module locals — Lua numbers
-- copy by value). Table rebinds must assign G.field to stay live.
local G = {
    -- constants
    GRID = 10,
    TILE_W = 64, TILE_H = 32,
    HALF_W = 32, HALF_H = 16,
    BLOCK_H = 26,   -- pixel height of one block level
    LIFT_PX = 10,   -- hover lift in pixels
    STEP_TIME = 0.14, -- seconds per path step
    AI_THINK = 0.55,  -- enemy pause before acting (readability beat)
    AI_STRIKE = 0.45, -- enemy pause after moving, before the hit lands
    MIN_ZOOM = 0.45, MAX_ZOOM = 2.5,

    -- viewport / camera
    W = 1280, H = 800,
    originX = 0, originY = 0,
    camX = 0, camY = 0, zoom = 1.8, zoomTarget = 1.8,

    -- board
    heights = {}, blocked = {}, terrain = {},
    pillars = { {5,5}, {5,6}, {6,5} },
    runLevel = 1, runSeed = 0,
    spawnTile = {1, 1}, finishTile = {10, 10},
    -- shop teleport: overworld has ONE "shopdoor" entrance tile
    -- (G.shopOver = {x, y}); the interior is a separate 8x8 room kept in
    -- G.maps.shop. G.map is the visible map ("over" | "shop").
    map = "over",
    maps = {},
    shopOver = nil,

    -- units
    roster = {}, units = {}, activeIdx = 1,
    turnOrder = {}, turnPos = 1, -- initiative: unit ids, speed desc
    round = 1, wiped = false,
    ai = nil, -- active enemy turn driver {id, phase, t}; nil = player time
    coins = 0, -- run-wide purse (kill bounties)
    levelKills = 0, levelCoins = 0, levelHp = 0, -- this level's rewards
    win = nil, -- win transition {t, dur, level, kills, coins, hp} or nil
    castMode = false, -- firebolt targeting armed
    showStats = true, -- portrait stat block expanded
    statsToggle = nil, -- clickable STATS arrow rect, set by render
    floats = {}, -- floating combat text {gx,gy,txt,col,t,life}
    arrows = {}, -- arrows in flight {fx,fy,tx,ty,t,dur} (grid coords)
    nextBtn = nil, boltBtn = nil, -- turn-box button rects, set by render

    -- per-frame / fx state
    hover = nil, lift = {}, log = {},
    dust = {}, puffs = {},
    cachedReach = {}, hoverPath = {},
    squash = {}, selAnim = 1,

    -- flow
    state = "menu",       -- "menu" | "game"
    menuScreen = "main",  -- "main" | "modes" | "select" | "settings"
    menuIdx = 1,
    gameMode = "free",    -- "run" | "free"

    -- fonts (set in love.load)
    fontTitle = nil, fontHead = nil, fontBody = nil, fontSmall = nil,

    -- palette (all LÖVE 11 colors are 0-1 floats; keep new colors here)
    C = {
        bg       = {0.095, 0.100, 0.085},
        glowWarm = {0.60, 0.48, 0.27, 0.10},
        glowDeep = {0.34, 0.27, 0.15, 0.08},
        glowCore = {0.72, 0.60, 0.34, 0.05},
        contour  = {0.80, 0.71, 0.52, 0.055},
        dust     = {0.95, 0.78, 0.50},
        gridLn   = {0.90, 0.85, 0.70, 0.022},
        vignette = {0.03, 0.030, 0.025},
        top      = {0.93, 0.90, 0.82},
        topEdge  = {1.00, 0.99, 0.95},
        north    = {0.66, 0.61, 0.50},
        west     = {0.47, 0.43, 0.34},
        stone    = {0.26, 0.26, 0.29},
        stoneN   = {0.22, 0.22, 0.25},
        stoneW   = {0.15, 0.15, 0.18},
        hover    = {0.62, 0.85, 0.58},
        hoverN   = {0.42, 0.62, 0.40},
        hoverW   = {0.30, 0.46, 0.29},
        select   = {0.35, 0.82, 1.00},
        selGlow  = {0.35, 0.82, 1.00, 0.16},
        selInk   = {0.75, 0.92, 1.00},
        panel    = {0.07, 0.08, 0.11, 0.92},
        panelLn  = {0.36, 0.66, 0.37, 0.55},
        barBg    = {0.04, 0.05, 0.07, 1},
        ink      = {0.92, 0.93, 0.90},
        muted    = {0.55, 0.58, 0.60},
        accent   = {0.45, 0.78, 0.46},
        shadow   = {0, 0, 0, 0.30},
        ring     = {0.05, 0.05, 0.07},
        rim      = {1.00, 0.97, 0.88, 0.85},
        pillarHi = {0.55, 0.55, 0.60},
        grassTop = {0.65, 0.72, 0.52},
        grassTop2= {0.57, 0.68, 0.43},
        grassTop3= {0.71, 0.74, 0.50},
        meadowTop= {0.60, 0.75, 0.47},
        flowerTop= {0.67, 0.72, 0.51},
        grassBlade={0.30, 0.50, 0.26},
        grassTip = {0.45, 0.62, 0.32},
        meadowBlade={0.27, 0.52, 0.25},
        meadowTip = {0.48, 0.68, 0.33},
        cloverLeaf={0.26, 0.55, 0.29},
        bloomWhite={0.96, 0.94, 0.87},
        bloomYellow={0.98, 0.82, 0.35},
        bloomPink = {0.93, 0.55, 0.62},
        seedHead  = {0.86, 0.81, 0.60},
        mossPatch = {0.44, 0.57, 0.34},
        tallTop  = {0.55, 0.70, 0.42},
        tallInset= {0.45, 0.57, 0.34},
        tallBlade= {0.22, 0.42, 0.20},
        tallTip  = {0.38, 0.55, 0.28},
        waterTop = {0.25, 0.52, 0.72},
        waterHi  = {0.55, 0.80, 0.95},
        waterN   = {0.16, 0.34, 0.50},
        waterW   = {0.10, 0.24, 0.38},
        shopTop  = {0.72, 0.55, 0.38},
        shopN    = {0.52, 0.38, 0.26},
        shopW    = {0.38, 0.27, 0.18},
        shopFloor= {0.80, 0.68, 0.50},
        shopBoard= {0.16, 0.12, 0.10},
        shopRug  = {0.75, 0.35, 0.30},
        flagPole = {0.20, 0.18, 0.16},
        holeDark = {0.03, 0.04, 0.06},
        floatDmg  = {1.00, 0.45, 0.40},
        floatCrit = {1.00, 0.85, 0.30},
        floatDodge= {0.70, 0.70, 0.75},
        floatHeal = {0.45, 0.90, 0.50},
        floatMana = {0.40, 0.75, 1.00},
        coin      = {1.00, 0.84, 0.30},
    },
}

function G.pushLog(msg)
    table.insert(G.log, 1, msg)
    while #G.log > 6 do table.remove(G.log) end
end

-- init classic static board (flat + pillars); run mode regenerates via Board.
function G.initBoard()
    G.map, G.maps, G.shopOver = "over", {}, nil
    for y = 1, G.GRID do
        G.heights[y] = {}
        G.terrain[y] = {}
        for x = 1, G.GRID do G.heights[y][x] = 0; G.terrain[y][x] = "default" end
    end
    G.blocked = {}
    for _, p in ipairs(G.pillars) do
        G.heights[p[2]][p[1]] = 2
        G.blocked[p[2] * 100 + p[1]] = true
    end
    G.spawnTile, G.finishTile = {1, 1}, {G.GRID, G.GRID}
end

return G

-- board.lua — map data, iso math, procedural run generation.
-- Deps: state (G) only. No love.* calls except via G fields.
-- Gen v2: seeded per-map RNG (replayable, never touches math.randomseed),
-- spawn/finish picked first, river water, tall groves, spaced mountains,
-- plus-shape spawn clear, retry loop with validation instead of L-carve.
-- Supports 10x10 standard and 15x15 big via setSize/generateBigMap.
-- Shop: the overworld holds ONE "shopdoor" entrance tile (G.shopOver);
-- stepping on it teleports the unit into a separate 8x8 room
-- (G.maps.shop); the room's door tile teleports back out.
local G = require("state")
local M = {}

local DIRS = {{1,0},{-1,0},{0,1},{0,-1}}

-- ---------- iso math ----------
function M.tileToScreen(gx, gy, z)
    z = z or 0
    return G.originX + G.camX + (gx - gy) * G.HALF_W * G.zoom,
           G.originY + G.camY + ((gx + gy) * G.HALF_H - z) * G.zoom
end

function M.screenToTile(sx, sy)
    local dx = (sx - G.originX - G.camX) / G.zoom
    local dy = (sy - G.originY - G.camY) / G.zoom
    local fx = (dy / G.HALF_H + dx / G.HALF_W) / 2
    local fy = (dy / G.HALF_H - dx / G.HALF_W) / 2
    -- tiles are drawn centered on integer coords, so round to nearest.
    return math.floor(fx + 0.5), math.floor(fy + 0.5)
end

-- top-surface height in px, mirroring drawBlock's z formula.
function M.tileTopZ(gx, gy)
    local hgt = (G.heights[gy] and G.heights[gy][gx]) or 0
    local l = G.lift[gx .. "," .. gy] or 0
    local z = hgt * G.BLOCK_H + l
    if G.terrain[gy] and G.terrain[gy][gx] == "water" then z = z - 6 end
    return z
end

-- Height-aware pick: base inverse is on the z=0 plane, so tall tiles
-- (pillars, shop walls) and hover lift would mis-pick. Test the ±2
-- ring's top diamonds and return the frontmost hit (largest
-- gx+gy, then tallest). Falls back to the base tile when nothing
-- contains the point (gaps between diamonds). Nil when off-board.
function M.pickTile(sx, sy)
    local bx, by = M.screenToTile(sx, sy)
    local hw, hh = G.HALF_W * G.zoom, G.HALF_H * G.zoom
    -- ±2 ring: a 2-level pillar top sits ~1.6 tiles off its z=0 plane.
    local best, bestS, bestZ = nil, -1, -1
    for oy = -2, 2 do for ox = -2, 2 do
        local gx, gy = bx + ox, by + oy
        if gx >= 1 and gy >= 1 and gx <= G.GRID and gy <= G.GRID then
            local cx, cy = M.tileToScreen(gx, gy, M.tileTopZ(gx, gy))
            if math.abs(sx - cx) / hw + math.abs(sy - cy) / hh <= 1.01 then
                local s = gx + gy
                local z = (G.heights[gy] and G.heights[gy][gx]) or 0
                if s > bestS or (s == bestS and z > bestZ) then
                    best, bestS, bestZ = {gx, gy}, s, z
                end
            end
        end
    end end
    if best then return best[1], best[2] end
    if M.inBounds(bx, by) then return bx, by end
    return nil
end

function M.inBounds(x, y) return x >= 1 and y >= 1 and x <= G.GRID and y <= G.GRID end
function M.isBlocked(x, y) return G.blocked[y * 100 + x] == true end

-- ---------- run terrain ----------
-- terrain[y][x]: "default" | "grass" | "tall" | "water" | "mountain"
--   | "spawn" | "finish" | "shopwall" | "shopfloor" | "shopdoor"
-- heights: 0 flat, 1 hill (walkable bump, big maps only) / shop wall, 2 blocked peak.
-- shopwall is blocked; shopfloor/shopdoor are walkable (room interior,
-- overworld entrance). Units carry u.map ("over" | "shop").

function M.tileCost(x, y)
    if G.terrain[y] and G.terrain[y][x] == "water" then return 2 end
    return 1
end

-- combat hook: 50% dodge while standing on tall grass (no combat yet)
function M.dodgeChanceAt(x, y)
    if G.terrain[y] and G.terrain[y][x] == "tall" then return 0.5 end
    return 0
end

function M.setSize(n)
    G.GRID = n
    G.heights, G.terrain, G.blocked = {}, {}, {}
    G.lift, G.cachedReach, G.hoverPath = {}, {}, {}
    G.map, G.maps, G.shopOver = "over", {}, nil
    for y = 1, n do
        G.heights[y] = {}
        G.terrain[y] = {}
        for x = 1, n do G.heights[y][x] = 0; G.terrain[y][x] = "default" end
    end
    G.spawnTile, G.finishTile = {1, 1}, {n, n}
end

function M.clearBoard()
    for y = 1, G.GRID do
        for x = 1, G.GRID do G.heights[y][x] = 0; G.terrain[y][x] = "default" end
    end
    G.blocked = {}
    G.map, G.maps, G.shopOver = "over", {}, nil
end

-- ---------- seeded RNG (LCG Park-Miller; no global randomseed touches) ----------
local function makeRng(seed)
    local s = (seed % 2147483646) + 1
    local function nextF()
        s = (s * 48271) % 2147483647
        return s / 2147483647
    end
    return {
        f = nextF,
        int = function(a, b) return a + math.floor(nextF() * ((b - a) + 1)) end,
        chance = function(p) return nextF() < p end,
        pick = function(t) return t[1 + math.floor(nextF() * #t)] end,
    }
end

local function cheb(ax, ay, bx, by)
    return math.max(math.abs(ax - bx), math.abs(ay - by))
end

-- momentum walker: keeps direction with prob `stick`, else turns.
local function walk(rng, n, sx, sy, steps, stick, paint)
    local x, y = sx, sy
    local d = rng.pick(DIRS)
    for _ = 1, steps do
        if x >= 1 and y >= 1 and x <= n and y <= n then paint(x, y) end
        if rng.chance(1 - stick) then d = rng.pick(DIRS) end
        x = math.max(1, math.min(n, x + d[1]))
        y = math.max(1, math.min(n, y + d[2]))
    end
end

local PROFILES = {
    standard = { grass = 24, riverLen = 9, lakes = 0, lakeSize = 0,
                 tallGroves = 2, tallSize = 4, mountains = 4, hills = 0,
                 minGrass = 12, minTall = 3, minWater = 5 },
    big      = { grass = 42, riverLen = 20, lakes = 1, lakeSize = 4,
                 tallGroves = 3, tallSize = 5, mountains = 11, hills = 4,
                 minGrass = 25, minTall = 8, minWater = 12 },
}

local function pathCostToFinish()
    -- Dijkstra spawn -> finish; nil if unreachable
    local sk = G.spawnTile[2] * 100 + G.spawnTile[1]
    local best = { [sk] = 0 }
    local queue = { {G.spawnTile[1], G.spawnTile[2], 0} }
    local head = 1
    while head <= #queue do
        local cx, cy, c = queue[head][1], queue[head][2], queue[head][3]
        head = head + 1
        if c > (best[cy * 100 + cx] or math.huge) then goto cont end
        if cx == G.finishTile[1] and cy == G.finishTile[2] then return c end
        for _, d in ipairs(DIRS) do
            local nx, ny = cx + d[1], cy + d[2]
            local k = ny * 100 + nx
            if nx >= 1 and ny >= 1 and nx <= G.GRID and ny <= G.GRID and not G.blocked[k] then
                local nc = c + M.tileCost(nx, ny)
                if best[k] == nil or nc < best[k] then
                    best[k] = nc
                    queue[#queue + 1] = {nx, ny, nc}
                end
            end
        end
        ::cont::
    end
    return nil
end

function M.costAwareConnected() return pathCostToFinish() ~= nil end

-- ---------- shop: one-tile entrance outside, 8x8 room inside ----------
local SHOP_N = 8 -- interior room is SHOP_N x SHOP_N

-- Fixed room layout: perimeter shopwall (h=1, blocked), shopfloor
-- inside, one shopdoor on the south edge, rug near the center,
-- spawn just inside the door.
function M.newInterior()
    local n = SHOP_N
    local heights, terrain, blocked = {}, {}, {}
    for y = 1, n do
        heights[y] = {}
        terrain[y] = {}
        for x = 1, n do heights[y][x] = 0; terrain[y][x] = "shopfloor" end
    end
    for x = 1, n do
        for _, y in ipairs({1, n}) do
            terrain[y][x] = "shopwall"; heights[y][x] = 1; blocked[y * 100 + x] = true
        end
    end
    for y = 1, n do
        for _, x in ipairs({1, n}) do
            terrain[y][x] = "shopwall"; heights[y][x] = 1; blocked[y * 100 + x] = true
        end
    end
    terrain[n][4] = "shopdoor"
    heights[n][4] = 0
    blocked[n * 100 + 4] = nil
    return { grid = n, heights = heights, terrain = terrain, blocked = blocked,
             door = {4, n}, rug = {4, 4}, spawn = {4, n - 1} }
end

-- Snapshot the live tables as the overworld and build a fresh room.
-- Call after the overworld board is final.
function M.stashMaps()
    G.maps = {
        over = { grid = G.GRID, heights = G.heights,
                 terrain = G.terrain, blocked = G.blocked },
        shop = M.newInterior(),
    }
    G.map = "over"
end

-- Free-play extras on the classic board: one shop entrance tile.
function M.setupFreeShop()
    G.terrain[5][8] = "shopdoor"
    G.shopOver = {8, 5}
    M.stashMaps()
end

-- Swap the visible map, stashing the current tables. Resets per-frame
-- fx and the camera so the new map starts centered.
function M.switchMap(name)
    -- stash live tables but keep record extras (door/rug/spawn).
    local cur = G.maps[G.map] or {}
    cur.grid, cur.heights, cur.terrain, cur.blocked =
        G.GRID, G.heights, G.terrain, G.blocked
    G.maps[G.map] = cur
    local m = G.maps[name]
    G.map = name
    G.GRID, G.heights, G.terrain, G.blocked = m.grid, m.heights, m.terrain, m.blocked
    G.hover = nil
    G.lift, G.cachedReach, G.hoverPath, G.puffs = {}, {}, {}, {}
    G.camX, G.camY = 0, 0
end

local function placeUnit(unit, x, y)
    unit.gx, unit.gy = x, y
    unit.px, unit.py = x, y
    unit.fx, unit.fy = x, y
    unit.path, unit.t = {}, 0
end

-- Step on the overworld entrance -> appear just inside the room.
function M.enterShop(unit)
    local rec = G.maps and G.maps.shop
    if not rec then return end
    M.switchMap("shop")
    G.zoom, G.zoomTarget = 1, 1
    unit.map = "shop"
    placeUnit(unit, rec.spawn[1], rec.spawn[2])
    G.pushLog(unit.name .. " enters the shop")
end

-- Step on the room door -> appear back on the entrance tile (or a free
-- orth neighbor if someone is standing on it). Path is always cleared.
function M.exitShop(unit)
    local over = G.maps and G.maps.over
    if not over or not G.shopOver then return end
    local tx, ty = G.shopOver[1], G.shopOver[2]
    local function occ(x, y)
        for _, u in ipairs(G.units) do
            if u ~= unit and u.map == "over" and u.gx == x and u.gy == y then return true end
        end
        return false
    end
    if occ(tx, ty) then
        local found = false
        for _, d in ipairs(DIRS) do
            local nx, ny = tx + d[1], ty + d[2]
            if nx >= 1 and ny >= 1 and nx <= over.grid and ny <= over.grid
                and not over.blocked[ny * 100 + nx] and not occ(nx, ny) then
                tx, ty = nx, ny
                found = true
                break
            end
        end
        if not found then G.pushLog(unit.name .. ": door blocked") return end
    end
    M.switchMap("over")
    unit.map = "over"
    placeUnit(unit, tx, ty)
    G.pushLog(unit.name .. " leaves the shop")
end

-- Step hook (called from the glide onStep chain): standing on a door
-- tile teleports, either direction. Entering/exiting clears the path.
function M.checkShop(u)
    local t = G.terrain[u.gy] and G.terrain[u.gy][u.gx]
    if t ~= "shopdoor" then return end
    if G.map == "shop" then
        M.exitShop(u)
    elseif G.shopOver and u.gx == G.shopOver[1] and u.gy == G.shopOver[2] then
        M.enterShop(u)
    end
end

function M.carvePath()
    -- last-resort fallback only (retry loop should already have connected).
    -- Minimal-damage carve: greedy walk preferring cheap terrain.
    local x, y = G.spawnTile[1], G.spawnTile[2]
    local guard = 0
    while (x ~= G.finishTile[1] or y ~= G.finishTile[2]) and guard < 400 do
        guard = guard + 1
        local opts = {}
        for _, d in ipairs(DIRS) do
            local nx, ny = x + d[1], y + d[2]
            if nx >= 1 and ny >= 1 and nx <= G.GRID and ny <= G.GRID then
                local dist = math.abs(nx - G.finishTile[1]) + math.abs(ny - G.finishTile[2])
                opts[#opts + 1] = {nx, ny, dist, M.tileCost(nx, ny)}
            end
        end
        table.sort(opts, function(a, b)
            if a[3] ~= b[3] then return a[3] < b[3] end
            return a[4] < b[4]
        end)
        x, y = opts[1][1], opts[1][2]
        if not (x == G.finishTile[1] and y == G.finishTile[2]) then
            if G.terrain[y][x] == "mountain" then
                G.terrain[y][x] = "default"
                G.heights[y][x] = 0
                G.blocked[y * 100 + x] = nil
            end
        end
    end
end

local function buildAttempt(seed, level, size, prof)
    local n = size
    local rng = makeRng(seed + level * 7919)
    M.setSize(n)
    M.clearBoard()

    -- spawn left edge, finish right edge (picked FIRST so terrain avoids them)
    local spawn = { rng.int(1, 2), rng.int(1, n) }
    local finish = { rng.int(n - 1, n), rng.int(1, n) }
    G.spawnTile, G.finishTile = spawn, finish
    local function isEndpoint(x, y)
        return (x == spawn[1] and y == spawn[2]) or (x == finish[1] and y == finish[2])
    end

    -- grass: momentum walkers sharing a tile budget (natural clusters)
    local grassLeft = prof.grass
    local walkers = 3
    for _ = 1, walkers do
        local steps = math.floor(prof.grass / walkers) + 2
        walk(rng, n, rng.int(1, n), rng.int(1, n), steps, 0.7, function(x, y)
            if grassLeft > 0 and G.terrain[y][x] == "default" and not isEndpoint(x, y) then
                G.terrain[y][x] = "grass"
                grassLeft = grassLeft - 1
            end
        end)
    end

    -- river: edge-to-edge momentum walk, width 1, forces a cost-2 crossing
    local edge = rng.int(1, 2) -- 1: top->bottom, 2: left->right
    local rx, ry = (edge == 1) and rng.int(2, n - 1) or 1, (edge == 1) and 1 or rng.int(2, n - 1)
    local riverLeft = prof.riverLen
    walk(rng, n, rx, ry, prof.riverLen + 6, 0.75, function(x, y)
        if riverLeft > 0 and not isEndpoint(x, y) and G.terrain[y][x] ~= "water" then
            G.terrain[y][x] = "water"
            G.heights[y][x] = 0
            riverLeft = riverLeft - 1
        end
    end)

    -- lake (big maps): one compact blob in the middle third
    for _ = 1, prof.lakes do
        local cx = rng.int(math.floor(n / 3), math.floor(2 * n / 3))
        local cy = rng.int(math.floor(n / 3), math.floor(2 * n / 3))
        local placed = 0
        local q = {{cx, cy}}
        local seen = { [cy * 100 + cx] = true }
        while #q > 0 and placed < prof.lakeSize do
            local c = table.remove(q, 1)
            local x, y = c[1], c[2]
            if not isEndpoint(x, y) and G.terrain[y][x] ~= "mountain" then
                G.terrain[y][x] = "water"
                G.heights[y][x] = 0
                placed = placed + 1
            end
            for _, d in ipairs(DIRS) do
                local nx, ny = x + d[1], y + d[2]
                local k = ny * 100 + nx
                if nx >= 1 and ny >= 1 and nx <= n and ny <= n and not seen[k] and rng.chance(0.6) then
                    seen[k] = true
                    q[#q + 1] = {nx, ny}
                end
            end
        end
    end

    -- tall groves: grow inside grass only (dense dodge thickets, not speckle)
    local grassCells = {}
    for y = 1, n do for x = 1, n do
        if G.terrain[y][x] == "grass" then grassCells[#grassCells + 1] = {x, y} end
    end end
    for g = 1, prof.tallGroves do
        if #grassCells == 0 then break end
        local ci = rng.int(1, #grassCells)
        local center = table.remove(grassCells, ci)
        local grown = 0
        local q = {center}
        local seen = { [center[2] * 100 + center[1]] = true }
        while #q > 0 and grown < prof.tallSize do
            local c = table.remove(q, 1)
            local x, y = c[1], c[2]
            if G.terrain[y][x] == "grass" then
                G.terrain[y][x] = "tall"
                grown = grown + 1
            end
            for _, d in ipairs(DIRS) do
                local nx, ny = x + d[1], y + d[2]
                local k = ny * 100 + nx
                if nx >= 1 and ny >= 1 and nx <= n and ny <= n and not seen[k]
                    and G.terrain[ny][nx] == "grass" then
                    seen[k] = true
                    q[#q + 1] = {nx, ny}
                end
            end
        end
    end

    local function waterAdjacent(x, y)
        for _, d in ipairs(DIRS) do
            local nx, ny = x + d[1], y + d[2]
            if nx >= 1 and ny >= 1 and nx <= n and ny <= n
                and G.terrain[ny][nx] == "water" then return true end
        end
        return false
    end

    -- mountains: spaced peaks, never on/near endpoints or water
    local placed, guard = {}, 0
    while #placed < prof.mountains and guard < 300 do
        guard = guard + 1
        local x, y = rng.int(1, n), rng.int(1, n)
        if isEndpoint(x, y) then goto mnext end
        if G.terrain[y][x] == "water" or waterAdjacent(x, y) then goto mnext end
        if cheb(x, y, spawn[1], spawn[2]) < 2 or cheb(x, y, finish[1], finish[2]) < 2 then goto mnext end
        for _, p in ipairs(placed) do
            if cheb(x, y, p[1], p[2]) < 2 then goto mnext end
        end
        G.terrain[y][x] = "mountain"
        G.heights[y][x] = 2
        G.blocked[y * 100 + x] = true
        placed[#placed + 1] = {x, y}
        -- 40%: grow one orth neighbor into a 2-peak
        if #placed < prof.mountains and rng.chance(0.4) then
            local d = rng.pick(DIRS)
            local nx, ny = x + d[1], y + d[2]
            if nx >= 1 and ny >= 1 and nx <= n and ny <= n
                and not isEndpoint(nx, ny) and G.terrain[ny][nx] ~= "water"
                and not waterAdjacent(nx, ny)
                and cheb(nx, ny, spawn[1], spawn[2]) >= 2
                and cheb(nx, ny, finish[1], finish[2]) >= 2 then
                G.terrain[ny][nx] = "mountain"
                G.heights[ny][nx] = 2
                G.blocked[ny * 100 + nx] = true
                placed[#placed + 1] = {nx, ny}
            end
        end
        ::mnext::
    end

    -- hills (big maps): walkable bumps for visual layering
    local hillsPlaced, hguard = 0, 0
    while hillsPlaced < prof.hills and hguard < 200 do
        hguard = hguard + 1
        local x, y = rng.int(1, n), rng.int(1, n)
        if isEndpoint(x, y) then goto hnext end
        if G.terrain[y][x] == "water" or G.terrain[y][x] == "mountain" then goto hnext end
        if G.heights[y][x] ~= 0 then goto hnext end
        local ok = true
        for _, p in ipairs(placed) do
            if cheb(x, y, p[1], p[2]) < 2 then ok = false break end
        end
        if ok then
            G.heights[y][x] = 1
            hillsPlaced = hillsPlaced + 1
        end
        ::hnext::
    end

    -- plus-shape spawn clear (center + 4 orth): safe start, keeps neighbors interesting
    for _, d in ipairs({{0,0},{1,0},{-1,0},{0,1},{0,-1}}) do
        local nx, ny = spawn[1] + d[1], spawn[2] + d[2]
        if nx >= 1 and ny >= 1 and nx <= n and ny <= n
            and not (nx == finish[1] and ny == finish[2]) then
            if G.terrain[ny][nx] ~= "water" then
                G.terrain[ny][nx] = "default"
            end
            G.heights[ny][nx] = 0
            G.blocked[ny * 100 + nx] = nil
        end
    end
    for y = 1, n do for x = 1, n do
        if G.terrain[y][x] == "water" then G.blocked[y * 100 + x] = nil end
    end end
    G.terrain[spawn[2]][spawn[1]] = "spawn"
    G.terrain[finish[2]][finish[1]] = "finish"
    G.heights[finish[2]][finish[1]] = 0
    G.blocked[finish[2] * 100 + finish[1]] = nil

    -- shop entrance: one walkable "shopdoor" tile (never an endpoint).
    -- The room itself lives in G.maps.shop; stepping on this teleports in.
    local doors = {}
    for y = 1, n do for x = 1, n do
        local t = G.terrain[y][x]
        if (t == "default" or t == "grass")
            and not (x == spawn[1] and y == spawn[2])
            and not (x == finish[1] and y == finish[2]) then
            doors[#doors + 1] = {x, y}
        end
    end end
    if #doors == 0 then return false end
    local door = rng.pick(doors)
    G.terrain[door[2]][door[1]] = "shopdoor"
    G.shopOver = {door[1], door[2]}

    -- validation
    local cost = pathCostToFinish()
    if not cost then return false end
    if not G.shopOver then return false end
    local man = math.abs(spawn[1] - finish[1]) + math.abs(spawn[2] - finish[2])
    if cost > man + 12 then return false end
    local cw, cg, ct = 0, 0, 0
    for y = 1, n do for x = 1, n do
        local t = G.terrain[y][x]
        if t == "water" then cw = cw + 1
        elseif t == "grass" then cg = cg + 1
        elseif t == "tall" then ct = ct + 1 end
    end end
    -- tall lives inside grass budget: count the meadow as a whole
    if cw < prof.minWater or (cg + ct) < prof.minGrass or ct < prof.minTall then return false end
    return true
end

function M.generateMap(level, size, seedOverride)
    level = level or 1
    size = size or G.GRID or 10
    local prof = (size >= 15) and PROFILES.big or PROFILES.standard
    local base = seedOverride or math.random(1, 999999)
    local seed = base
    local ok = false
    for attempt = 0, 24 do
        seed = base + attempt * 100003
        if buildAttempt(seed, level, size, prof) then ok = true break end
    end
    if not ok then
        -- fallback: keep last attempt, repair minimally (should be ~never)
        if not M.costAwareConnected() then M.carvePath() end
    end
    -- stash both maps; the overworld stays visible.
    M.stashMaps()
    G.runLevel = level
    G.runSeed = seed
    return seed
end

function M.generateBigMap(level, seedOverride)
    return M.generateMap(level, 15, seedOverride)
end

return M

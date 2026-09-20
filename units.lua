-- units.lua — roster, Dijkstra movement, orders, pawn glide.
-- Deps: state (G), board. No love.* calls.
-- The step-completion hook (finish check) is injected by the caller:
--   Units.updateGlide(dt, onStep) — main passes Menu.checkFinish.
local G = require("state")
local Board = require("board")
local M = {}

-- ---------- roster ----------
function M.defaultRoster()
    return {
        { id = "p1", name = "Alpha", gx = 3, gy = 3,
          color = {0.90, 0.34, 0.18}, dark = {0.62, 0.20, 0.10}, range = 4 },
        { id = "p2", name = "Bravo", gx = 8, gy = 8,
          color = {0.18, 0.53, 0.89}, dark = {0.10, 0.35, 0.64}, range = 3 },
        { id = "p3", name = "Charlie", gx = 3, gy = 8,
          color = {0.25, 0.72, 0.30}, dark = {0.14, 0.48, 0.18}, range = 4 },
        { id = "p4", name = "Delta", gx = 8, gy = 3,
          color = {0.78, 0.62, 0.18}, dark = {0.52, 0.40, 0.10}, range = 3 },
    }
end

function M.spawnUnit(def)
    return { id = def.id, name = def.name, gx = def.gx, gy = def.gy,
        px = def.gx, py = def.gy, fx = def.gx, fy = def.gy, map = "over",
        color = def.color, dark = def.dark, range = def.range, path = {}, t = 0 }
end

function M.spawnAll()
    G.units = {}
    for _, def in ipairs(G.roster) do G.units[#G.units + 1] = M.spawnUnit(def) end
    G.activeIdx = 1
end

function M.active() return G.units[G.activeIdx] end

function M.unitAt(x, y, ignore)
    -- only units on the visible map collide/select.
    for _, u in ipairs(G.units) do
        if u ~= ignore and u.map == G.map and u.gx == x and u.gy == y then return u end
    end
    return nil
end

-- ---------- queries (Dijkstra; water costs 2, key: y * 100 + x) ----------
function M.findPath(unit, tx, ty)
    if not Board.inBounds(tx, ty) or Board.isBlocked(tx, ty) then return nil end
    if M.unitAt(tx, ty, unit) then return nil end
    local startK = unit.gy * 100 + unit.gx
    local best = { [startK] = 0 }
    local prev = { [startK] = false }
    local queue = { {unit.gx, unit.gy, 0} }
    local head = 1
    while head <= #queue do
        local cx, cy, c = queue[head][1], queue[head][2], queue[head][3]
        head = head + 1
        if c > (best[cy * 100 + cx] or math.huge) then goto next end
        if cx == tx and cy == ty then
            local path = {}
            local k = ty * 100 + tx
            while k do
                table.insert(path, 1, { k % 100, math.floor(k / 100) })
                k = prev[k]
            end
            return path
        end
        for _, d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
            local nx, ny = cx + d[1], cy + d[2]
            local k = ny * 100 + nx
            if Board.inBounds(nx, ny) and not Board.isBlocked(nx, ny) and not M.unitAt(nx, ny, unit) then
                local nc = c + Board.tileCost(nx, ny)
                if best[k] == nil or nc < best[k] then
                    best[k] = nc
                    prev[k] = cy * 100 + cx
                    queue[#queue + 1] = {nx, ny, nc}
                end
            end
        end
        ::next::
    end
    return nil
end

function M.pathCost(path)
    local cost = 0
    for i = 2, #path do cost = cost + Board.tileCost(path[i][1], path[i][2]) end
    return cost
end

function M.reachable(unit)
    -- cost-limited Dijkstra: water eats 2 range per tile
    local seen = { [unit.gy * 100 + unit.gx] = 0 }
    local queue = { {unit.gx, unit.gy, 0} }
    local head = 1
    while head <= #queue do
        local cx, cy, dist = queue[head][1], queue[head][2], queue[head][3]
        head = head + 1
        if dist > (seen[cy * 100 + cx] or math.huge) then goto cont end
        for _, d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
            local nx, ny = cx + d[1], cy + d[2]
            local k = ny * 100 + nx
            if Board.inBounds(nx, ny) and not Board.isBlocked(nx, ny) and not M.unitAt(nx, ny, unit) then
                local nd = dist + Board.tileCost(nx, ny)
                if nd <= unit.range and (seen[k] == nil or nd < seen[k]) then
                    seen[k] = nd
                    queue[#queue + 1] = {nx, ny, nd}
                end
            end
        end
        ::cont::
    end
    seen[unit.gy * 100 + unit.gx] = nil
    return seen
end

-- ---------- orders ----------
function M.orderMove(unit, tx, ty)
    if #unit.path > 0 then G.pushLog(unit.name .. ": still moving...") return end
    local path = M.findPath(unit, tx, ty)
    if not path then G.pushLog(unit.name .. ": no path to " .. tx .. "," .. ty) return end
    local cost = M.pathCost(path)
    if cost > unit.range then
        G.pushLog(unit.name .. ": too far (" .. cost .. " > " .. unit.range .. ")")
        return
    end
    table.remove(path, 1) -- drop start tile
    unit.path = path
    unit.t = 0
    unit.fx, unit.fy = unit.gx, unit.gy
end

function M.stepMove(unit, dx, dy)
    if #unit.path > 0 then return end
    local nx, ny = unit.gx + dx, unit.gy + dy
    if not Board.inBounds(nx, ny) or Board.isBlocked(nx, ny) or M.unitAt(nx, ny, unit) then return end
    unit.path = { {nx, ny} }
    unit.t = 0
    unit.fx, unit.fy = unit.gx, unit.gy
end

-- per-frame reach cache + hover path preview (drives range wash + dots)
function M.updateQueries()
    local actU = M.active()
    if actU and actU.map == G.map and #actU.path == 0 then G.cachedReach = M.reachable(actU) else G.cachedReach = {} end
    G.hoverPath = {}
    if G.hover and actU and actU.map == G.map and #actU.path == 0 and G.cachedReach[G.hover[2]*100+G.hover[1]] then
        local p = M.findPath(actU, G.hover[1], G.hover[2])
        if p then for i = 2, #p do G.hoverPath[#G.hoverPath+1] = p[i] end end
    end
end

-- pawn glide: fixed-time segments with smoothstep easing.
-- u.fx/fy = segment start tile, u.t counts 0 -> STEP_TIME, px/py derived.
function M.updateGlide(dt, onStep)
    for _, u in ipairs(G.units) do
        -- units on the other map are frozen until viewed again.
        if u.map ~= G.map then goto frozen end
        if #u.path > 0 then
            u.t = u.t + dt
            local step = u.path[1]
            local k = math.min(1, u.t / G.STEP_TIME)
            local e = k * k * (3 - 2 * k) -- smoothstep: ease in-out
            u.px = u.fx + (step[1] - u.fx) * e
            u.py = u.fy + (step[2] - u.fy) * e
            if k >= 1 then
                u.gx, u.gy = step[1], step[2]
                u.fx, u.fy = step[1], step[2]
                table.remove(u.path, 1)
                u.t = 0
                G.squash[u.id] = 1
                local pcx, pcy = Board.tileToScreen(u.gx, u.gy, 0)
                G.puffs[#G.puffs+1] = { x = pcx, y = pcy, r = 4, a = 0.5 }
                if #u.path == 0 then G.pushLog(u.name .. " -> " .. u.gx .. "," .. u.gy) end
                if onStep then onStep(u) end
            end
        else
            u.px, u.py = u.gx, u.gy
            u.fx, u.fy = u.gx, u.gy
        end
        ::frozen::
    end
end

return M

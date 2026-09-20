-- Isometric Grid Lab — Love2D remake.
-- 10x10 extruded block field, pawn units with BFS click-to-move,
-- hover lift tweens, range highlight, pan/zoom camera.
-- LÖVE 11.x (0-1 colors, love.load / love.update(dt) / love.draw).

local GRID = 10
local TILE_W, TILE_H = 64, 32
local HALF_W, HALF_H = TILE_W / 2, TILE_H / 2
local BLOCK_H = 26      -- pixel height of one block level
local LIFT_PX = 10      -- hover lift in pixels
local STEP_TIME = 0.14  -- seconds per path step

local W, H = 1280, 800
local originX, originY = 0, 0
local camX, camY, zoom = 0, 0, 1
local MIN_ZOOM, MAX_ZOOM = 0.45, 2.5

-- Heights: 0 = normal, 2 = stone pillar (blocked)
local heights = {}
local blocked = {}
for y = 1, GRID do
    heights[y] = {}
    for x = 1, GRID do heights[y][x] = 0 end
end
local pillars = { {5,5}, {5,6}, {6,5} }
for _, p in ipairs(pillars) do
    heights[p[2]][p[1]] = 2
    blocked[p[2] * 100 + p[1]] = true
end

local units = {
    { id = "p1", name = "Alpha", gx = 3, gy = 3, px = 3, py = 3,
      color = {0.90, 0.34, 0.18}, dark = {0.62, 0.20, 0.10}, range = 4, path = {}, t = 0 },
    { id = "p2", name = "Bravo", gx = 8, gy = 8, px = 8, py = 8,
      color = {0.18, 0.53, 0.89}, dark = {0.10, 0.35, 0.64}, range = 3, path = {}, t = 0 },
}
local activeIdx = 1
local hover = nil
local lift = {}   -- "x,y" -> current lift px (tweened)
local log = {}
local dust = {}   -- ambient particles {x,y,vx,vy,r,a,ph}
local puffs = {}  -- move landing puffs {x,y,r,a}
local cachedReach = {}
local hoverPath = {}
local zoomTarget = 1
local squash = {} -- unit id -> squash timer
local selAnim = 1 -- 0 on selection change -> eases to 1
local state = "menu" -- "menu" | "game"
local menuScreen = "main" -- "main" | "modes" | "settings"
local menuIdx = 1
local gameMode = "classic" -- "classic" | "skirmish" | "sandbox"

local fontTitle, fontHead, fontBody, fontSmall

local C = {
    bg       = {0.10, 0.11, 0.14},
    glow     = {0.23, 0.42, 0.75, 0.10},
    top      = {0.93, 0.90, 0.82},
    topAlt   = {0.87, 0.83, 0.72},
    topEdge  = {1.00, 0.99, 0.95},
    north    = {0.66, 0.61, 0.50},
    west     = {0.47, 0.43, 0.34},
    grout    = {0.05, 0.05, 0.07},
    stone    = {0.30, 0.30, 0.33},
    stoneN   = {0.22, 0.22, 0.25},
    stoneW   = {0.15, 0.15, 0.18},
    hover    = {0.62, 0.85, 0.58},
    hoverN   = {0.42, 0.62, 0.40},
    hoverW   = {0.30, 0.46, 0.29},
    range    = {0.36, 0.66, 0.37, 0.35},
    select   = {0.35, 0.82, 1.00},
    selGlow  = {0.35, 0.82, 1.00, 0.16},
    selInk   = {0.75, 0.92, 1.00},
    panel    = {0.07, 0.08, 0.11, 0.92},
    panelLn  = {0.36, 0.66, 0.37, 0.55},
    ink      = {0.92, 0.93, 0.90},
    muted    = {0.55, 0.58, 0.60},
    accent   = {0.45, 0.78, 0.46},
    shadow   = {0, 0, 0, 0.30},
    rim      = {1.00, 0.97, 0.88, 0.85},
    rangeWash= {0.36, 0.66, 0.37, 0.14},
    pathDot  = {1.00, 0.95, 0.60, 0.90},
    pillarTop= {0.42, 0.42, 0.46},
    pillarHi = {0.55, 0.55, 0.60},
}

-- ---------- iso math ----------
local function tileToScreen(gx, gy, z)
    z = z or 0
    return originX + camX + (gx - gy) * HALF_W * zoom,
           originY + camY + ((gx + gy) * HALF_H - z) * zoom
end

local function screenToTile(sx, sy)
    local dx = (sx - originX - camX) / zoom
    local dy = (sy - originY - camY) / zoom
    local fx = (dy / HALF_H + dx / HALF_W) / 2
    local fy = (dy / HALF_H - dx / HALF_W) / 2
    -- nudge toward tile centers (tiles drawn centered on integer coords)
    return math.floor(fx + 0.5) + 1, math.floor(fy + 0.5) + 1
end

local function inBounds(x, y) return x >= 1 and y >= 1 and x <= GRID and y <= GRID end
local function isBlocked(x, y) return blocked[y * 100 + x] == true end
local function unitAt(x, y, ignore)
    for _, u in ipairs(units) do
        if u ~= ignore and u.gx == x and u.gy == y then return u end
    end
    return nil
end

-- ---------- movement system ----------
local function findPath(unit, tx, ty)
    if not inBounds(tx, ty) or isBlocked(tx, ty) then return nil end
    if unitAt(tx, ty, unit) then return nil end
    -- key encoding: y * 100 + x everywhere (decode: x = k % 100, y = floor(k / 100))
    local startK = unit.gy * 100 + unit.gx
    local prev = { [startK] = false }
    local queue = { {unit.gx, unit.gy} }
    local head = 1
    while head <= #queue do
        local cx, cy = queue[head][1], queue[head][2]
        head = head + 1
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
            if inBounds(nx, ny) and prev[k] == nil
                and not isBlocked(nx, ny) and not unitAt(nx, ny, unit) then
                prev[k] = cy * 100 + cx
                queue[#queue + 1] = {nx, ny}
            end
        end
    end
    return nil
end

local function reachable(unit)
    local seen = { [unit.gy * 100 + unit.gx] = 0 }
    local queue = { {unit.gx, unit.gy, 0} }
    local head = 1
    while head <= #queue do
        local cx, cy, dist = queue[head][1], queue[head][2], queue[head][3]
        head = head + 1
        if dist < unit.range then
            for _, d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
                local nx, ny = cx + d[1], cy + d[2]
                local k = ny * 100 + nx
                if inBounds(nx, ny) and seen[k] == nil
                    and not isBlocked(nx, ny) and not unitAt(nx, ny, unit) then
                    seen[k] = dist + 1
                    queue[#queue + 1] = {nx, ny, dist + 1}
                end
            end
        end
    end
    seen[unit.gy * 100 + unit.gx] = nil
    return seen
end

local function pushLog(msg)
    table.insert(log, 1, msg)
    while #log > 6 do table.remove(log) end
end

local function orderMove(unit, tx, ty)
    if #unit.path > 0 then pushLog(unit.name .. ": still moving...") return end
    local path = findPath(unit, tx, ty)
    if not path then pushLog(unit.name .. ": no path to " .. tx .. "," .. ty) return end
    if #path - 1 > unit.range then
        pushLog(unit.name .. ": too far (" .. (#path - 1) .. " > " .. unit.range .. ")")
        return
    end
    table.remove(path, 1) -- drop start tile
    unit.path = path
    unit.t = 0
    unit.fx, unit.fy = unit.gx, unit.gy
end

local function stepMove(unit, dx, dy)
    if #unit.path > 0 then return end
    local nx, ny = unit.gx + dx, unit.gy + dy
    if not inBounds(nx, ny) or isBlocked(nx, ny) or unitAt(nx, ny, unit) then return end
    unit.path = { {nx, ny} }
    unit.t = 0
    unit.fx, unit.fy = unit.gx, unit.gy
end

-- ---------- drawing ----------
local function diamond(cx, cy, w, h)
    return { cx, cy - h / 2, cx + w / 2, cy, cx, cy + h / 2, cx - w / 2, cy }
end

local function shade(col, f) return {col[1]*f, col[2]*f, col[3]*f, col[4] or 1} end

local function aoFactor(gx, gy)
    local f = 1.0
    for _, d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
        local nx, ny = gx+d[1], gy+d[2]
        if inBounds(nx, ny) and heights[ny][nx] > 0 then f = f - 0.12 end
    end
    if gx == 1 or gy == 1 or gx == GRID or gy == GRID then f = f - 0.06 end
    return math.max(0.6, f)
end

local function drawBlock(gx, gy, time)
    local hgt = heights[gy][gx]
    local k = gx .. "," .. gy
    local l = lift[k] or 0
    local z = hgt * BLOCK_H + l
    local cx, cy = tileToScreen(gx, gy, z)
    local w, hh = TILE_W * zoom, TILE_H * zoom
    local stone = (hgt > 0)
    local hov = hover and hover[1] == gx and hover[2] == gy

    -- side faces: flat default colors
    local top = diamond(cx, cy, w, hh)
    local baseDrop = (stone and (hgt * BLOCK_H) or BLOCK_H * 0.9 + 6) * zoom
    local lx, ly = cx - w / 2, cy
    local bx, by = cx, cy + hh / 2
    local rx, ry = cx + w / 2, cy
    local nCol = stone and C.stoneN or C.north
    local wCol = stone and C.stoneW or C.west
    if hov and not stone then nCol, wCol = C.hoverN, C.hoverW end
    love.graphics.setColor(wCol)
    love.graphics.polygon("fill", { lx, ly, bx, by, bx, by + baseDrop, lx, ly + baseDrop })
    love.graphics.setColor(nCol)
    love.graphics.polygon("fill", { rx, ry, bx, by, bx, by + baseDrop, rx, ry + baseDrop })

    -- top face: flat default color
    local tCol
    if stone then tCol = C.stone
    elseif hov then tCol = C.hover
    elseif (gx + gy) % 2 == 0 then tCol = C.top else tCol = C.topAlt end
    love.graphics.setColor(tCol)
    love.graphics.polygon("fill", top)
    love.graphics.setColor(0.25, 0.23, 0.18, stone and 0.6 or 0.35)
    love.graphics.setLineWidth(1)
    love.graphics.polygon("line", top)

    if stone then
        -- bevel + crack + glow dot marks blocked
        love.graphics.setColor(C.pillarHi)
        love.graphics.polygon("line", diamond(cx, cy, w - 10*zoom, hh - 5*zoom))
        love.graphics.setColor(0, 0, 0, 0.35)
        love.graphics.line(cx - 6*zoom, cy - 4*zoom, cx + 2*zoom, cy + 1*zoom, cx - 2*zoom, cy + 5*zoom)
        local gl = 0.5 + 0.5 * math.sin(time*3 + gx + gy)
        love.graphics.setColor(1, 0.35, 0.3, 0.5 + 0.3*gl)
        love.graphics.circle("fill", cx, cy, 3*zoom)
    end

    -- range wash (cached): quiet desaturated teal
    if cachedReach[gy * 100 + gx] and not stone then
        love.graphics.setColor(0.30, 0.55, 0.52, 0.10)
        love.graphics.polygon("fill", top)
        love.graphics.setColor(0.30, 0.60, 0.55, 0.50)
        love.graphics.setLineWidth(1)
        love.graphics.polygon("line", diamond(cx, cy, w - 8*zoom, hh - 4*zoom))
        love.graphics.circle("fill", cx, cy, 1.8*zoom)
    end

    -- hover path preview dots in selection cyan
    for _, pk in ipairs(hoverPath) do
        if pk[1] == gx and pk[2] == gy then
            love.graphics.setColor(C.select)
            love.graphics.circle("fill", cx, cy, 3.2*zoom)
            love.graphics.setColor(0,0,0,0.35)
            love.graphics.circle("line", cx, cy, 3.2*zoom)
        end
    end

    -- selection: static inset diamond + soft glow + corner ticks
    local act = units[activeIdx]
    if act and act.gx == gx and act.gy == gy and #act.path == 0 then
        local pop = 1 + (1 - selAnim) * 0.10
        local iw, ih = (w - 4*zoom)*pop, (hh - 2*zoom)*pop
        love.graphics.setColor(C.selGlow)
        love.graphics.setLineWidth(5)
        love.graphics.polygon("line", diamond(cx, cy, iw + 6*zoom, ih + 3*zoom))
        love.graphics.setColor(C.select)
        love.graphics.setLineWidth(1.5)
        love.graphics.polygon("line", diamond(cx, cy, iw, ih))
        -- corner ticks
        local d = diamond(cx, cy, iw, ih)
        love.graphics.setLineWidth(3)
        for i = 1, 4 do
            local x1, y1 = d[i*2-1], d[i*2]
            local nx, ny = d[(i%4)*2+1], d[(i%4)*2+2]
            local mx1, my1 = x1 + (nx-x1)*0.12, y1 + (ny-y1)*0.12
            local mx2, my2 = nx + (x1-nx)*0.12, ny + (y1-ny)*0.12
            love.graphics.line(x1, y1, mx1, my1)
            love.graphics.line(nx, ny, mx2, my2)
        end
        love.graphics.setLineWidth(1)
    end
end

local function drawPawn(u)
    -- smooth grid position -> screen (stand on block top)
    local hgt = heights[u.gy] and heights[u.gy][u.gx] or 0
    local k = u.gx .. "," .. u.gy
    local l = lift[k] or 0
    local moving = #u.path > 0
    local hop = moving and math.sin(math.min(1, u.t / STEP_TIME) * math.pi) * 4 or 0
    local sq = squash[u.id] or 0
    local sx, sy = 1 + sq * 0.25, 1 - sq * 0.18
    local cx, cy = tileToScreen(u.px, u.py, hgt * BLOCK_H + l + hop)
    local s = zoom
    local active = (units[activeIdx] == u)

    -- ground shadow scales with hop/lift
    local shScale = 1 - math.min(0.35, (hop + l) * 0.02)
    love.graphics.setColor(C.shadow)
    love.graphics.ellipse("fill", cx, cy + 2 * s, 15 * s * shScale, 6 * s * shScale)

    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.scale(sx * s, sy * s)
    love.graphics.translate(-cx, -cy)
    -- drop shadow duplicate of body
    local bw, bh = 13, 22
    love.graphics.setColor(0, 0, 0, 0.25)
    love.graphics.polygon("fill", { cx-bw/2+2, cy-2, cx-4+2, cy-4-bh+3, cx+4+2, cy-4-bh+3, cx+bw/2+2, cy-2 })
    -- base
    love.graphics.setColor(u.dark)
    love.graphics.ellipse("fill", cx, cy - 2, 13, 5.5)
    love.graphics.setColor(u.color)
    love.graphics.ellipse("fill", cx, cy - 4, 13, 5.5)
    -- body (two-tone flat)
    love.graphics.setColor(u.dark)
    love.graphics.polygon("fill", { cx - bw / 2, cy - 4, cx - 4, cy - 4 - bh,
                                    cx + 4, cy - 4 - bh, cx + bw / 2, cy - 4 })
    love.graphics.setColor(u.color)
    love.graphics.polygon("fill", { cx - 4, cy - 4, cx - 1, cy - 4 - bh,
                                    cx + 4, cy - 4 - bh, cx + 5, cy - 4 })
    -- collar + head
    love.graphics.setColor(u.dark)
    love.graphics.ellipse("fill", cx, cy - 4 - bh, 7, 3)
    love.graphics.setColor(u.color)
    love.graphics.circle("fill", cx, cy - 12 - bh, 8.5)
    -- rim light arc on head right side
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.setLineWidth(1.6)
    love.graphics.arc("line", "open", cx, cy - 12 - bh, 8.5, -0.9, 0.7)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 0.55)
    love.graphics.circle("fill", cx - 2.5, cy - 15 - bh, 2)
    love.graphics.pop()

    if active then
        -- base ring in selection cyan + nameplate pill
        love.graphics.setColor(C.select)
        love.graphics.setLineWidth(2)
        love.graphics.ellipse("line", cx, cy - 2 * s, 16 * s, 7 * s)
        love.graphics.setLineWidth(1)
        local bob = math.sin(love.timer.getTime() * 2) * 2
        local nw, nh = 64 * zoom, 18 * zoom
        local nx, ny = cx - nw/2, cy - (46 + 12) * s + bob
        love.graphics.setColor(0.05, 0.07, 0.10, 0.92)
        love.graphics.rectangle("fill", nx, ny, nw, nh, 5, 5)
        love.graphics.setColor(C.select)
        love.graphics.rectangle("line", nx, ny, nw, nh, 5, 5)
        love.graphics.setFont(fontSmall)
        love.graphics.setColor(C.selInk)
        love.graphics.printf(u.name:upper(), nx, ny + 3*zoom, nw, "center")
        love.graphics.setLineWidth(1)
    end
end

local function drawBackdrop(time)
    love.graphics.setColor(C.bg)
    love.graphics.rectangle("fill", 0, 0, W, H)
    -- breathing glow bands
    local breathe = 1 + 0.04 * math.sin(time * 0.8)
    love.graphics.setColor(C.glow)
    love.graphics.circle("fill", W * 0.5, H * 0.52, 330 * breathe)
    love.graphics.setColor(0.23, 0.42, 0.75, 0.06)
    love.graphics.circle("fill", W * 0.5, H * 0.52, 230 * breathe)
    -- faint blueprint grid
    love.graphics.setColor(1, 1, 1, 0.035)
    for x = 40, W, 80 do love.graphics.line(x, 0, x, H) end
    for y = 40, H, 80 do love.graphics.line(0, y, W, y) end
    -- drifting dust (additive)
    love.graphics.setBlendMode("add")
    for _, p in ipairs(dust) do
        love.graphics.setColor(0.5, 0.65, 0.9, p.a * (0.6 + 0.4 * math.sin(time * 2 + p.ph)))
        love.graphics.circle("fill", p.x, p.y, p.r)
    end
    love.graphics.setBlendMode("alpha")
end

local function drawBoardShadow()
    local cx = originX + camX
    local bottomY = originY + camY + GRID * HALF_H * 2 -- screen y of far tile
    local w = GRID * HALF_W * 2 + 10 * zoom
    local h = GRID * HALF_H * 2 + 6 * zoom
    local cy = bottomY - h / 2 + 34 * zoom -- peek out below the board
    -- soft 3-layer shadow
    love.graphics.setColor(0, 0, 0, 0.10)
    love.graphics.polygon("fill", diamond(cx, cy, w + 48 * zoom, h + 24 * zoom))
    love.graphics.setColor(0, 0, 0, 0.15)
    love.graphics.polygon("fill", diamond(cx, cy, w + 24 * zoom, h + 12 * zoom))
    love.graphics.setColor(0, 0, 0, 0.22)
    love.graphics.polygon("fill", diamond(cx, cy, w, h))
end

local function drawPanel()
    local pw, ph = 264, 300
    local px, py = W - pw - 32, 32
    love.graphics.setColor(C.panel)
    love.graphics.rectangle("fill", px, py, pw, ph, 6, 6)
    love.graphics.setColor(C.panelLn)
    love.graphics.rectangle("line", px, py, pw, ph, 6, 6)

    local lx = px + 20
    love.graphics.setFont(fontHead)
    love.graphics.setColor(C.accent)
    love.graphics.print("TILE INSPECTOR", lx, py + 16)

    love.graphics.setFont(fontBody)
    local row = py + 52
    local function kv(k, v, vc)
        love.graphics.setColor(C.muted) love.graphics.print(k, lx, row)
        love.graphics.setColor(vc or C.ink) love.graphics.print(v, lx + 96, row)
        row = row + 30
    end
    kv("GRID", GRID .. "x" .. GRID)
    if hover and inBounds(hover[1], hover[2]) then
        kv("HOVER", hover[1] .. ", " .. hover[2])
    else kv("HOVER", "--") end
    local a = units[activeIdx]
    kv("ACTIVE", a.name .. "  " .. a.gx .. "," .. a.gy, C.selInk)
    kv("RANGE", tostring(a.range))
    kv("ZOOM", math.floor(zoom * 100 + 0.5) .. "%")

    love.graphics.setFont(fontSmall)
    love.graphics.setColor(C.muted)
    love.graphics.print("UNITS  (click / TAB)", lx, row + 4)
    row = row + 24
    for i, u in ipairs(units) do
        local sel = (i == activeIdx)
        love.graphics.setColor(u.color)
        love.graphics.circle("fill", lx + 6, row + 6, 5)
        love.graphics.setColor(sel and C.accent or C.ink)
        love.graphics.print((sel and "> " or "   ") .. u.name .. "  " .. u.gx .. "," .. u.gy, lx + 16, row)
        row = row + 20
    end
end

local function drawHUD()
    love.graphics.setFont(fontTitle)
    love.graphics.setColor(C.ink)
    love.graphics.print("ISOMETRIC GRID LAB", 36, 30)
    love.graphics.setFont(fontSmall)
    love.graphics.setColor(C.muted)
    love.graphics.print("10 x 10 BLOCK FIELD  /  LOVE2D REMAKE", 36, 64)
    love.graphics.setColor(C.accent)
    love.graphics.rectangle("fill", 36, 86, 42, 3)

    love.graphics.setFont(fontSmall)
    love.graphics.setColor(C.muted)
    love.graphics.print("CLICK unit select / tile move      WASD step      TAB cycle      WHEEL zoom      RIGHT-DRAG pan      R reset", 36, H - 60)
    local y = H - 40
    for i, m in ipairs(log) do
        love.graphics.setColor(C.muted)
        love.graphics.print(m, 36, y - (i - 1) * 16)
    end

    if hover and inBounds(hover[1], hover[2]) then
        local mx, my = love.mouse.getPosition()
        love.graphics.setFont(fontSmall)
        love.graphics.setColor(C.panel)
        love.graphics.rectangle("fill", mx + 14, my - 36, 104, 26, 4, 4)
        love.graphics.setColor(C.panelLn)
        love.graphics.rectangle("line", mx + 14, my - 36, 104, 26, 4, 4)
        love.graphics.setColor(C.ink)
        love.graphics.print(string.format("TILE %d, %d", hover[1], hover[2]), mx + 24, my - 29)
    end
end

-- ---------- love callbacks ----------
function love.load()
    love.window.setMode(W, H, { resizable = true, vsync = 1 })
    love.graphics.setBackgroundColor(C.bg)
    fontTitle = love.graphics.newFont("assets/fonts/LiberationSans-Regular.ttf", 28)
    fontHead  = love.graphics.newFont("assets/fonts/LiberationSans-Regular.ttf", 13)
    fontBody  = love.graphics.newFont("assets/fonts/JetBrainsMonoNerdFont-Regular.ttf", 14)
    fontSmall = love.graphics.newFont("assets/fonts/JetBrainsMonoNerdFont-Regular.ttf", 11)
    originX = W / 2
    originY = H / 2 - GRID * HALF_H + 24
    for i = 1, 40 do
        dust[i] = { x = math.random() * W, y = math.random() * H,
            vx = 6 + math.random() * 14, vy = -4 - math.random() * 8,
            r = 1 + math.random() * 1.8, a = 0.10 + math.random() * 0.15, ph = math.random() * 6.28 }
    end
    pushLog("ready — click a pawn, then a tile")
end

function love.resize(w, h)
    W, H = w, h
    originX = W / 2
    originY = H / 2 - GRID * HALF_H + 24
end

-- Keep the board findable: the camera is clamped every frame (and after
-- every pan/zoom) so the board's bounding box always overlaps the viewport
-- by at least VMIN pixels. Without this, zoom-to-cursor on an off-board
-- point (panel, HUD, empty corner) walks the board away, and unbounded
-- pan/zoom then strands it off-screen with only R to recover.
-- World bounds of the field (tiles + pawn/pillar overhang): x in [-340,340],
-- y in [-40,380].
local function clampCamera()
    local VMIN = 150
    local x0, x1, y0, y1 = -340, 340, -40, 380
    camX = math.max(VMIN - originX - x1 * zoom,
           math.min(W - VMIN - originX - x0 * zoom, camX))
    camY = math.max(VMIN - originY - y1 * zoom,
           math.min(H - VMIN - originY - y0 * zoom, camY))
end

local function syncViewport()
    local w, h = love.graphics.getDimensions()
    if w ~= W or h ~= H then
        W, H = w, h
        originX = W / 2
        originY = H / 2 - GRID * HALF_H + 24
    end
end

function love.update(dt)
    syncViewport() -- tiling WMs resize without resize events; poll every frame
    -- smooth zoom toward target
    zoom = zoom + (zoomTarget - zoom) * math.min(1, dt * 10)
    if math.abs(zoom - zoomTarget) < 0.001 then zoom = zoomTarget end
    selAnim = math.min(1, selAnim + dt * 6)
    -- camera pan (held keys)
    local sp = 420 * dt
    if love.keyboard.isDown("w", "up") then camY = camY - sp end
    if love.keyboard.isDown("s", "down") then camY = camY + sp end
    -- NOTE: A/D double as pawn step when a unit is idle; pan with arrows or right-drag.
    if love.keyboard.isDown("left") then camX = camX - sp end
    if love.keyboard.isDown("right") then camX = camX + sp end
    clampCamera()

    -- hover pick
    local mx, my = love.mouse.getPosition()
    local tx, ty = screenToTile(mx, my)
    hover = inBounds(tx, ty) and { tx, ty } or nil

    -- cache reach once per frame; hover path preview
    local actU = units[activeIdx]
    if actU and #actU.path == 0 then cachedReach = reachable(actU) else cachedReach = {} end
    hoverPath = {}
    if hover and actU and #actU.path == 0 and cachedReach[hover[2]*100+hover[1]] then
        local p = findPath(actU, hover[1], hover[2])
        if p then for i = 2, #p do hoverPath[#hoverPath+1] = p[i] end end
    end

    -- dust drift
    for _, p in ipairs(dust) do
        p.x = p.x + p.vx * dt; p.y = p.y + p.vy * dt
        if p.x > W + 10 then p.x = -10 end
        if p.y < -10 then p.y, p.x = H + 10, math.random() * W end
    end
    -- squash decay + puff fade
    for id, v in pairs(squash) do squash[id] = math.max(0, v - dt * 6) end
    for i = #puffs, 1, -1 do
        local pf = puffs[i]; pf.r = pf.r + 60*dt; pf.a = pf.a - dt*1.8
        if pf.a <= 0 then table.remove(puffs, i) end
    end

    -- lift tweens
    for y = 1, GRID do
        for x = 1, GRID do
            local k = x .. "," .. y
            local target = (hover and hover[1] == x and hover[2] == y) and LIFT_PX or 0
            local cur = lift[k] or 0
            cur = cur + (target - cur) * math.min(1, dt * 12)
            if math.abs(cur - target) < 0.1 then cur = target end
            lift[k] = cur
        end
    end

    -- pawn glide along queued paths: fixed-time segments with smoothstep easing.
    -- u.fx/fy = segment start tile, u.t counts 0 -> STEP_TIME, px/py derived.
    for _, u in ipairs(units) do
        if #u.path > 0 then
            u.t = u.t + dt
            local step = u.path[1]
            local k = math.min(1, u.t / STEP_TIME)
            local e = k * k * (3 - 2 * k) -- smoothstep: ease in-out
            u.px = u.fx + (step[1] - u.fx) * e
            u.py = u.fy + (step[2] - u.fy) * e
            if k >= 1 then
                u.gx, u.gy = step[1], step[2]
                u.fx, u.fy = step[1], step[2]
                table.remove(u.path, 1)
                u.t = 0
                squash[u.id] = 1
                local pcx, pcy = tileToScreen(u.gx, u.gy, 0)
                puffs[#puffs+1] = { x = pcx, y = pcy, r = 4, a = 0.5 }
                if #u.path == 0 then pushLog(u.name .. " -> " .. u.gx .. "," .. u.gy) end
            end
        else
            u.px, u.py = u.gx, u.gy
            u.fx, u.fy = u.gx, u.gy
        end
    end
end

local function menuItems()
    if menuScreen == "main" then return { "START", "SETTINGS", "EXIT" }
    elseif menuScreen == "modes" then return { "CLASSIC — 10x10 standard", "SKIRMISH — long range", "SANDBOX — free move", "BACK" }
    else return { "VOLUME: ON", "BACK" } end
end

local function drawMenu(time)
    -- full-screen menu: own backdrop, no board behind
    drawBackdrop(time)
    -- big title left, menu right
    local cx = W / 2
    love.graphics.setFont(fontTitle)
    love.graphics.setColor(C.ink)
    love.graphics.printf("ISOMETRIC GRID LAB", 0, H * 0.22, W, "center")
    love.graphics.setFont(fontSmall)
    love.graphics.setColor(C.muted)
    local sub = menuScreen == "modes" and "CHOOSE GAME MODE" or menuScreen == "settings" and "SETTINGS" or "10 x 10 BLOCK FIELD"
    love.graphics.printf(sub, 0, H * 0.22 + 40, W, "center")
    love.graphics.setColor(C.select)
    love.graphics.rectangle("fill", cx - 21, H * 0.22 + 62, 42, 3)

    local items = menuItems()
    love.graphics.setFont(fontBody)
    local startY = H * 0.42
    for i, label in ipairs(items) do
        local sel = (i == menuIdx)
        local iy = startY + (i - 1) * 48
        if sel then
            love.graphics.setColor(C.select[1], C.select[2], C.select[3], 0.22)
            love.graphics.rectangle("fill", cx - 170, iy - 8, 340, 36, 6, 6)
        end
        love.graphics.setColor(sel and C.selInk or C.muted)
        love.graphics.printf((sel and "> " or "") .. label, cx - 170, iy, 340, "center")
    end
    love.graphics.setFont(fontSmall)
    love.graphics.setColor(C.muted)
    love.graphics.printf("UP/DOWN + ENTER  /  CLICK  /  ESC", 0, H - 60, W, "center")
    if menuScreen == "main" then
        love.graphics.printf("MODE: " .. gameMode:upper(), 0, H - 40, W, "center")
    end
end

function love.draw()
    local time = love.timer.getTime()
    if state == "menu" then
        drawMenu(time)
        return
    end
    drawBackdrop(time)
    -- board (painter's order: back rows first)
    love.graphics.push()
    drawBoardShadow()
    for s = 2, GRID * 2 do
        for gx = 1, GRID do
            local gy = s - gx
            if gy >= 1 and gy <= GRID then drawBlock(gx, gy, time) end
        end
        -- pawns whose tile-sum == s draw right after their row band
        for _, u in ipairs(units) do
            if u.gx + u.gy == s then drawPawn(u) end
        end
    end
    -- landing puffs
    for _, pf in ipairs(puffs) do
        love.graphics.setColor(1, 1, 1, pf.a * 0.5)
        love.graphics.circle("line", pf.x, pf.y, pf.r)
    end
    love.graphics.pop()
    drawHUD()
    drawPanel()
end

local function applyMode(m)
    gameMode = m
    if m == "skirmish" then
        units[1].range, units[2].range = 6, 5
    elseif m == "sandbox" then
        units[1].range, units[2].range = 99, 99
    else
        units[1].range, units[2].range = 4, 3
    end
    pushLog("mode: " .. m)
end

local function activateMenu()
    local n = #menuItems()
    if menuScreen == "main" then
        if menuIdx == 1 then menuScreen, menuIdx = "modes", 1
        elseif menuIdx == 2 then menuScreen, menuIdx = "settings", 1
        else love.event.quit() end
    elseif menuScreen == "modes" then
        if menuIdx == 1 then applyMode("classic"); state = "game"
        elseif menuIdx == 2 then applyMode("skirmish"); state = "game"
        elseif menuIdx == 3 then applyMode("sandbox"); state = "game"
        else menuScreen, menuIdx = "main", 1 end
    else
        menuScreen, menuIdx = "main", 1
    end
end

local function menuHit(x, y)
    local items = menuItems()
    local cx = W / 2
    local startY = H * 0.42
    for i = 1, #items do
        local iy = startY + (i - 1) * 48
        if x >= cx - 170 and x <= cx + 170 and y >= iy - 8 and y <= iy + 28 then
            return i
        end
    end
    return nil
end

function love.mousepressed(x, y, button)
    if state == "menu" then
        if button == 1 then
            local hit = menuHit(x, y)
            if hit then menuIdx = hit; activateMenu() end
        end
        return
    end
    if button == 1 then
        local tx, ty = screenToTile(x, y)
        if not inBounds(tx, ty) then return end
        local hit = unitAt(tx, ty)
        if hit then
            for i, u in ipairs(units) do
                if u == hit then activeIdx = i end
            end
            selAnim = 0
            pushLog("selected " .. hit.name)
        else
            orderMove(units[activeIdx], tx, ty)
        end
    elseif button == 2 then
        love._panning = true
    end
end

function love.mousereleased(_, _, button)
    if button == 2 then love._panning = false end
end

function love.mousemoved(_, _, dx, dy)
    if love._panning then camX, camY = camX + dx, camY + dy; clampCamera() end
end

function love.wheelmoved(_, y)
    local f = y > 0 and 1.1 or 0.9
    local nz = math.max(MIN_ZOOM, math.min(MAX_ZOOM, zoomTarget * f))
    if nz == zoomTarget then return end
    local mx, my = love.mouse.getPosition()
    -- Zoom at cursor only when the cursor is over the board; otherwise
    -- zoom toward the viewport center so empty corners/panel can't
    -- walk the grid away.
    local tx, ty = screenToTile(mx, my)
    local ax, ay = mx, my
    if not inBounds(tx, ty) then ax, ay = W / 2, H / 2 end
    local r = nz / zoomTarget
    camX = ax - originX - (ax - originX - camX) * r
    camY = ay - originY - (ay - originY - camY) * r
    zoomTarget = nz
    clampCamera()
end

function love.keypressed(key)
    if state == "menu" then
        local n = #menuItems()
        if key == "up" or key == "w" then menuIdx = ((menuIdx - 2) % n) + 1
        elseif key == "down" or key == "s" then menuIdx = (menuIdx % n) + 1
        elseif key == "return" or key == "space" then activateMenu()
        elseif key == "escape" then
            if menuScreen ~= "main" then menuScreen, menuIdx = "main", 1
            else love.event.quit() end
        end
        return
    end
    local a = units[activeIdx]
    if key == "tab" then
        activeIdx = activeIdx % #units + 1
        selAnim = 0
        pushLog("selected " .. units[activeIdx].name)
    elseif key == "r" then camX, camY, zoom, zoomTarget = 0, 0, 1, 1
    elseif key == "escape" then state = "menu"; menuIdx = 1
    elseif a and #a.path == 0 then
        if key == "w" then stepMove(a, -1, 0)
        elseif key == "s" then stepMove(a, 1, 0)
        elseif key == "a" then stepMove(a, 0, -1)
        elseif key == "d" then stepMove(a, 0, 1) end
    end
end

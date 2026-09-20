-- render.lua — all drawing. Read-only: never mutates game state.
-- Deps: state (G), board (iso math, bounds), units (unitAt).
local G = require("state")
local Board = require("board")
local Units = require("units")
local M = {}

local function diamond(cx, cy, w, h)
    return { cx, cy - h / 2, cx + w / 2, cy, cx, cy + h / 2, cx - w / 2, cy }
end

-- deterministic 0..1 hash per tile (replaces (gx+gy)%2 parity variation)
local function hash2(x, y)
    local h = math.sin(x * 12.9898 + y * 78.233) * 43758.5453
    return h - math.floor(h)
end

local function shade(col, f) return {col[1]*f, col[2]*f, col[3]*f, col[4] or 1} end

function M.drawBlock(gx, gy, time)
    local C = G.C
    local hgt = G.heights[gy][gx]
    local ter = G.terrain[gy] and G.terrain[gy][gx] or "default"
    local isWater = (ter == "water")
    local k = gx .. "," .. gy
    local l = G.lift[k] or 0
    local z = hgt * G.BLOCK_H + l - (isWater and 6 or 0)
    local cx, cy = Board.tileToScreen(gx, gy, z)
    local w, hh = G.TILE_W * G.zoom, G.TILE_H * G.zoom
    local stone = (hgt > 0)
    local hov = G.hover and G.hover[1] == gx and G.hover[2] == gy

    -- side faces: flat default colors (water: deep blue pair, shop: timber pair)
    local isWall = (ter == "shopwall")
    local isShopFloor = (ter == "shopfloor" or ter == "shopdoor")
    local top = diamond(cx, cy, w, hh)
    local baseDrop = (stone and (hgt * G.BLOCK_H) or G.BLOCK_H * 0.9 + 6) * G.zoom
    local lx, ly = cx - w / 2, cy
    local bx, by = cx, cy + hh / 2
    local rx, ry = cx + w / 2, cy
    local nCol = isWall and C.shopN or stone and C.stoneN or isWater and C.waterN or C.north
    local wCol = isWall and C.shopW or stone and C.stoneW or isWater and C.waterW or C.west
    if hov and not stone and not isWater then nCol, wCol = C.hoverN, C.hoverW end
    love.graphics.setColor(wCol)
    love.graphics.polygon("fill", { lx, ly, bx, by, bx, by + baseDrop, lx, ly + baseDrop })
    love.graphics.setColor(nCol)
    love.graphics.polygon("fill", { rx, ry, bx, by, bx, by + baseDrop, rx, ry + baseDrop })

    -- top face: hash-varied flat color (±3%, no parity checkerboard)
    local hTop = hash2(gx, gy)
    local tCol
    if isWall then tCol = (hov and C.hover or shade(C.shopTop, 0.97 + hTop * 0.06))
    elseif isShopFloor then tCol = (hov and C.hover or shade(C.shopFloor, 0.97 + hTop * 0.06))
    elseif stone then tCol = C.stone
    elseif hov then tCol = C.hover
    elseif isWater then tCol = C.waterTop
    elseif ter == "grass" then tCol = shade(C.grassTop, 0.97 + hTop * 0.06)
    elseif ter == "tall" then tCol = shade(C.tallTop, 0.97 + hTop * 0.06)
    else tCol = shade(C.top, 0.97 + hTop * 0.06) end
    love.graphics.setColor(tCol)
    love.graphics.polygon("fill", top)
    love.graphics.setColor(0.25, 0.23, 0.18, stone and 0.6 or 0.35)
    love.graphics.setLineWidth(1)
    love.graphics.polygon("line", top)
    if not hov then
        -- topEdge rim light on NE edges only (top vertex -> right vertex)
        love.graphics.setColor(C.topEdge[1], C.topEdge[2], C.topEdge[3], 0.6)
        love.graphics.line(cx, cy - hh / 2, cx + w / 2, cy)
    end

    if not stone and not isWater and not hov then
        -- speckle: 3 1px (zoom-scaled) dots at hashed offsets, never centered
        love.graphics.setColor(tCol[1] * 0.85, tCol[2] * 0.85, tCol[3] * 0.85, 0.5)
        for i = 1, 3 do
            local ox = (hash2(gx * 3 + i * 11, gy * 7 + i) - 0.5) * 24 * G.zoom
            local oy = (hash2(gx * 5 + i, gy * 3 + i * 13) - 0.5) * 10 * G.zoom
            love.graphics.circle("fill", cx + ox, cy + oy, 1 * G.zoom)
        end
    end

    if stone then
        if isWall then
            -- timber trim instead of the crack: inset cream line
            love.graphics.setColor(C.topEdge[1], C.topEdge[2], C.topEdge[3], 0.5)
            love.graphics.polygon("line", diamond(cx, cy, w - 10*G.zoom, hh - 5*G.zoom))
        else
            -- bevel + crack marks blocked (no glow dot: it read as an enemy marker)
            love.graphics.setColor(C.pillarHi)
            love.graphics.polygon("line", diamond(cx, cy, w - 10*G.zoom, hh - 5*G.zoom))
            love.graphics.setColor(0, 0, 0, 0.35)
            love.graphics.line(cx - 6*G.zoom, cy - 4*G.zoom, cx + 2*G.zoom, cy + 1*G.zoom, cx - 2*G.zoom, cy + 5*G.zoom)
        end
    end

    if ter == "grass" or ter == "tall" then
        -- tapered triangle blades at hashed positions, per-blade sway phase
        local isTall = (ter == "tall")
        local baseCol = isTall and C.tallBlade or C.grassBlade
        local tipCol = isTall and C.tallTip or C.grassTip
        local n = 5 + math.floor(hash2(gx * 3 + 1, gy * 3 + 7) * 3)
        if isTall then n = 8 + math.floor(hash2(gx * 3 + 1, gy * 3 + 7) * 3) end
        if isTall then
            -- smaller dark inset diamond (no full wash) so dodge tiles read dense
            love.graphics.setColor(C.tallInset)
            love.graphics.polygon("fill", diamond(cx, cy, w - 14 * G.zoom, hh - 7 * G.zoom))
        end
        for i = 1, n do
            local h1 = hash2(gx * 7 + i * 13, gy * 5 + i * 3)
            local h2 = hash2(gx * 5 + i * 7, gy * 11 + i)
            local h3 = hash2(gx * 13 + i, gy * 7 + i * 5)
            local ox = (h1 - 0.5) * 24 * G.zoom
            local by = cy + (h2 - 0.5) * 10 * G.zoom
            local bh = isTall and (9 + h3 * 5) * G.zoom or (4 + h3 * 3) * G.zoom
            local sw = math.sin(time * 2 + gx * 1.7 + gy + i * 1.3) * G.zoom
            local ax, ay = cx + ox + sw, by - bh
            love.graphics.setColor(baseCol)
            love.graphics.polygon("fill", { cx + ox - G.zoom, by, cx + ox + G.zoom, by, ax, ay })
            -- lighter tip over the top third
            local t = 0.33
            local mx, my = ax + (cx + ox - ax) * t, ay + (by - ay) * t
            love.graphics.setColor(tipCol)
            love.graphics.polygon("fill", { ax, ay, mx - 0.5 * G.zoom, my, mx + 0.5 * G.zoom, my })
        end
    end

    if isShopFloor then
        -- plank grooves along the x axis (top->left edge to right->bottom edge)
        love.graphics.setColor(C.shopFloor[1] * 0.78, C.shopFloor[2] * 0.78, C.shopFloor[3] * 0.78, 0.8)
        for _, f in ipairs({0.28, 0.5, 0.72}) do
            love.graphics.line(
                cx + (lx - cx) * f, (cy - hh / 2) + (ly - (cy - hh / 2)) * f,
                rx + (bx - rx) * f, ry + (by - ry) * f)
        end
        if ter == "shopdoor" then
            -- threshold mat
            love.graphics.setColor(C.shopBoard[1], C.shopBoard[2], C.shopBoard[3], 0.85)
            love.graphics.polygon("fill", diamond(cx, cy, w - 26 * G.zoom, hh - 13 * G.zoom))
        end
        local rugRec = (G.map == "shop" and G.maps) and G.maps.shop or nil
        if rugRec and rugRec.rug and rugRec.rug[1] == gx and rugRec.rug[2] == gy then
            -- hearth rug on the center floor tile
            love.graphics.setColor(C.shopRug)
            love.graphics.polygon("fill", diamond(cx, cy, w - 20 * G.zoom, hh - 10 * G.zoom))
            love.graphics.setColor(C.shopRug[1] * 0.7, C.shopRug[2] * 0.7, C.shopRug[3] * 0.7, 1)
            love.graphics.polygon("line", diamond(cx, cy, w - 20 * G.zoom, hh - 10 * G.zoom))
        end
    end

    if isWater then
        -- sky mirror: lighter upper half of the diamond
        love.graphics.setColor(C.waterHi[1], C.waterHi[2], C.waterHi[3], 0.45)
        love.graphics.polygon("fill", { cx, cy - hh / 2, cx + w / 2, cy, cx, cy })
        -- sun streak: animated thin highlight
        local sx = math.sin(time * 1.5 + gx + gy) * 6 * G.zoom
        love.graphics.setColor(1, 1, 1, 0.55)
        love.graphics.setLineWidth(1.5)
        love.graphics.line(cx - 10 * G.zoom + sx, cy + 1 * G.zoom, cx + 8 * G.zoom + sx, cy + 1 * G.zoom)
        love.graphics.setColor(1, 1, 1, 0.25)
        love.graphics.line(cx - 6 * G.zoom - sx, cy + 5 * G.zoom, cx + 6 * G.zoom - sx, cy + 5 * G.zoom)
        love.graphics.setLineWidth(1)
        -- neighbor echo: smudge below adjacent mountains/pawns
        for _, d in ipairs({{0,-1},{-1,0},{1,0}}) do
            local nx, ny = gx + d[1], gy + d[2]
            if nx >= 1 and ny >= 1 and nx <= G.GRID and ny <= G.GRID then
                local echo = (G.heights[ny] and G.heights[ny][nx] or 0) > 0 or Units.unitAt(nx, ny) ~= nil
                if echo then
                    love.graphics.setColor(0, 0, 0, 0.15)
                    love.graphics.line(cx - 2 * G.zoom, cy - 4 * G.zoom, cx - 2 * G.zoom, cy + 6 * G.zoom)
                end
                break
            end
        end
    end

    -- pawn mirror: flipped faded silhouette of pawns on tiles toward screen-top
    if isWater then
        for _, d in ipairs({{0,-1},{-1,0},{1,0},{0,1}}) do
            local nx, ny = gx + d[1], gy + d[2]
            if nx >= 1 and ny >= 1 and nx <= G.GRID and ny <= G.GRID then
                local u = Units.unitAt(nx, ny)
                if u then
                    local fade = d[2] == 1 and 0.10 or 0.22
                    love.graphics.setColor(u.color[1], u.color[2], u.color[3], fade)
                    love.graphics.polygon("fill", {
                        cx - 5 * G.zoom, cy + 2 * G.zoom,
                        cx + 5 * G.zoom, cy + 2 * G.zoom,
                        cx + 7 * G.zoom, cy + 12 * G.zoom,
                        cx - 7 * G.zoom, cy + 12 * G.zoom })
                    love.graphics.setColor(1, 1, 1, fade * 0.7)
                    love.graphics.circle("fill", cx, cy + 13 * G.zoom, 4 * G.zoom)
                end
            end
        end
    end

    if ter == "spawn" or ter == "finish" then
        if ter == "finish" then
            -- hole: dark inset diamond with rim edge
            love.graphics.setColor(C.holeDark)
            love.graphics.polygon("fill", diamond(cx, cy + 1 * G.zoom, w - 22 * G.zoom, hh - 11 * G.zoom))
            love.graphics.setColor(C.rim)
            love.graphics.setLineWidth(1)
            love.graphics.polygon("line", diamond(cx, cy + 1 * G.zoom, w - 22 * G.zoom, hh - 11 * G.zoom))
        else
            love.graphics.setColor(C.selGlow)
            love.graphics.polygon("fill", diamond(cx, cy, w - 8 * G.zoom, hh - 4 * G.zoom))
        end
        -- flag pole + pennant
        local px, py = cx + 8 * G.zoom, cy - 2 * G.zoom
        love.graphics.setColor(C.flagPole)
        love.graphics.setLineWidth(2)
        love.graphics.line(px, py, px, py - 22 * G.zoom)
        love.graphics.setLineWidth(1)
        if ter == "finish" then
            love.graphics.setColor(1.0, 0.85, 0.30)
        else
            love.graphics.setColor(C.select)
        end
        love.graphics.polygon("fill", { px, py - 22 * G.zoom, px + 12 * G.zoom, py - 18 * G.zoom, px, py - 14 * G.zoom })
    end

    -- range wash (cached): quiet desaturated teal
    if G.cachedReach[gy * 100 + gx] and not stone then
        love.graphics.setColor(0.30, 0.55, 0.52, 0.10)
        love.graphics.polygon("fill", top)
        love.graphics.setColor(0.30, 0.60, 0.55, 0.50)
        love.graphics.setLineWidth(1)
        love.graphics.polygon("line", diamond(cx, cy, w - 8*G.zoom, hh - 4*G.zoom))
        love.graphics.circle("fill", cx, cy, 1.8*G.zoom)
    end

    -- hover path preview dots in selection cyan
    for _, pk in ipairs(G.hoverPath) do
        if pk[1] == gx and pk[2] == gy then
            love.graphics.setColor(C.select)
            love.graphics.circle("fill", cx, cy, 3.2*G.zoom)
            love.graphics.setColor(0,0,0,0.35)
            love.graphics.circle("line", cx, cy, 3.2*G.zoom)
        end
    end

    -- selection: static inset diamond + soft glow + corner ticks
    local act = G.units[G.activeIdx]
    if act and act.gx == gx and act.gy == gy and #act.path == 0 then
        local pop = 1 + (1 - G.selAnim) * 0.10
        local iw, ih = (w - 4*G.zoom)*pop, (hh - 2*G.zoom)*pop
        love.graphics.setColor(C.selGlow)
        love.graphics.setLineWidth(5)
        love.graphics.polygon("line", diamond(cx, cy, iw + 6*G.zoom, ih + 3*G.zoom))
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

function M.drawPawn(u)
    local C = G.C
    -- smooth grid position -> screen (stand on block top)
    local hgt = G.heights[u.gy] and G.heights[u.gy][u.gx] or 0
    local k = u.gx .. "," .. u.gy
    local l = G.lift[k] or 0
    local moving = #u.path > 0
    local hop = moving and math.sin(math.min(1, u.t / G.STEP_TIME) * math.pi) * 4 or 0
    local sq = G.squash[u.id] or 0
    local sx, sy = 1 + sq * 0.25, 1 - sq * 0.18
    local cx, cy = Board.tileToScreen(u.px, u.py, hgt * G.BLOCK_H + l + hop)
    local s = G.zoom
    local active = (G.units[G.activeIdx] == u)

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
        local nw, nh = 64 * G.zoom, 18 * G.zoom
        local nx, ny = cx - nw/2, cy - (46 + 12) * s + bob
        love.graphics.setColor(0.05, 0.07, 0.10, 0.92)
        love.graphics.rectangle("fill", nx, ny, nw, nh, 5, 5)
        love.graphics.setColor(C.select)
        love.graphics.rectangle("line", nx, ny, nw, nh, 5, 5)
        love.graphics.setFont(G.fontSmall)
        love.graphics.setColor(C.selInk)
        love.graphics.printf(u.name:upper(), nx, ny + 3*G.zoom, nw, "center")
        love.graphics.setLineWidth(1)
    end
end

function M.drawBackdrop(time)
    local C = G.C
    love.graphics.setColor(C.bg)
    love.graphics.rectangle("fill", 0, 0, G.W, G.H)
    -- warm breathing hearth-glow (replaces the old blue bands)
    local breathe = 1 + 0.04 * math.sin(time * 0.8)
    love.graphics.setColor(C.glowWarm)
    love.graphics.circle("fill", G.W * 0.5, G.H * 0.52, 330 * breathe)
    love.graphics.setColor(C.glowDeep)
    love.graphics.circle("fill", G.W * 0.5, G.H * 0.52, 230 * breathe)
    -- topographic contour rings around the board center
    love.graphics.setColor(C.contour)
    love.graphics.setLineWidth(1)
    for i = 1, 3 do
        local r = (150 + i * 90) * (1 + 0.01 * math.sin(time * 0.5 + i))
        love.graphics.circle("line", G.W * 0.5, G.H * 0.52, r)
    end
    -- faint warm grid
    love.graphics.setColor(C.gridLn)
    for x = 40, G.W, 80 do love.graphics.line(x, 0, x, G.H) end
    for y = 40, G.H, 80 do love.graphics.line(0, y, G.W, y) end
    -- drifting embers (additive)
    love.graphics.setBlendMode("add")
    for _, p in ipairs(G.dust) do
        love.graphics.setColor(C.dust[1], C.dust[2], C.dust[3], p.a * (0.6 + 0.4 * math.sin(time * 2 + p.ph)))
        love.graphics.circle("fill", p.x, p.y, p.r)
    end
    love.graphics.setBlendMode("alpha")
    -- vignette: darkened edges so the board sits in a pool of light
    love.graphics.setColor(0, 0, 0, 0.28)
    local vw, vh = G.W * 0.06, G.H * 0.08
    love.graphics.rectangle("fill", 0, 0, G.W, vh)
    love.graphics.rectangle("fill", 0, G.H - vh, G.W, vh)
    love.graphics.rectangle("fill", 0, 0, vw, G.H)
    love.graphics.rectangle("fill", G.W - vw, 0, vw, G.H)
end

function M.drawBoardShadow()
    local cx = G.originX + G.camX
    local bottomY = G.originY + G.camY + G.GRID * G.HALF_H * 2 -- screen y of far tile
    local w = G.GRID * G.HALF_W * 2 + 10 * G.zoom
    local h = G.GRID * G.HALF_H * 2 + 6 * G.zoom
    local cy = bottomY - h / 2 + 34 * G.zoom -- peek out below the board
    -- soft 3-layer shadow
    love.graphics.setColor(0, 0, 0, 0.10)
    love.graphics.polygon("fill", diamond(cx, cy, w + 48 * G.zoom, h + 24 * G.zoom))
    love.graphics.setColor(0, 0, 0, 0.15)
    love.graphics.polygon("fill", diamond(cx, cy, w + 24 * G.zoom, h + 12 * G.zoom))
    love.graphics.setColor(0, 0, 0, 0.22)
    love.graphics.polygon("fill", diamond(cx, cy, w, h))
end

function M.drawPanel()
    local C = G.C
    local pw, ph = 264, 372
    local px, py = G.W - pw - 32, 32
    love.graphics.setColor(C.panel)
    love.graphics.rectangle("fill", px, py, pw, ph, 6, 6)
    love.graphics.setColor(C.panelLn)
    love.graphics.rectangle("line", px, py, pw, ph, 6, 6)

    local lx = px + 20
    love.graphics.setFont(G.fontHead)
    love.graphics.setColor(C.accent)
    love.graphics.print("TILE INSPECTOR", lx, py + 16)

    love.graphics.setFont(G.fontBody)
    local row = py + 52
    local function kv(k, v, vc)
        love.graphics.setColor(C.muted) love.graphics.print(k, lx, row)
        love.graphics.setColor(vc or C.ink) love.graphics.print(v, lx + 96, row)
        row = row + 30
    end
    kv("GRID", G.GRID .. "x" .. G.GRID)
    if G.hover and Board.inBounds(G.hover[1], G.hover[2]) then
        kv("HOVER", G.hover[1] .. ", " .. G.hover[2])
        kv("TER", G.terrain[G.hover[2]][G.hover[1]]:upper())
    else kv("HOVER", "--") end
    local a = G.units[G.activeIdx]
    kv("ACTIVE", a.name .. "  " .. a.gx .. "," .. a.gy, C.selInk)
    kv("RANGE", tostring(a.range))
    kv("ZOOM", math.floor(G.zoom * 100 + 0.5) .. "%")
    if G.gameMode == "run" then kv("LEVEL", G.runLevel .. "  #" .. G.runSeed, C.accent) end

    love.graphics.setFont(G.fontSmall)
    love.graphics.setColor(C.muted)
    love.graphics.print("UNITS  (click / TAB)", lx, row + 4)
    row = row + 24
    for i, u in ipairs(G.units) do
        local sel = (i == G.activeIdx)
        local away = (u.map ~= G.map)
        love.graphics.setColor(u.color)
        love.graphics.circle("fill", lx + 6, row + 6, 5)
        love.graphics.setColor(sel and C.accent or C.ink)
        local tag = away and ((G.map == "shop" and "  (outside)") or "  (in shop)") or ""
        love.graphics.print((sel and "> " or "   ") .. u.name .. "  " .. u.gx .. "," .. u.gy .. tag, lx + 16, row)
        row = row + 20
    end
end

function M.drawHUD()
    local C = G.C
    love.graphics.setFont(G.fontTitle)
    love.graphics.setColor(C.ink)
    love.graphics.print("ISOMETRIC GRID LAB", 36, 30)
    love.graphics.setFont(G.fontSmall)
    love.graphics.setColor(C.muted)
    love.graphics.print(G.GRID .. " x " .. G.GRID .. " BLOCK FIELD  /  LOVE2D REMAKE", 36, 64)
    love.graphics.setColor(C.accent)
    love.graphics.rectangle("fill", 36, 86, 42, 3)

    love.graphics.setFont(G.fontSmall)
    love.graphics.setColor(C.muted)
    love.graphics.print("CLICK unit select / tile move   WASD step   TAB cycle " ..
        "  WHEEL zoom   RIGHT-DRAG pan   R reset", 36, G.H - 60)
    local y = G.H - 40
    for i, m in ipairs(G.log) do
        love.graphics.setColor(C.muted)
        love.graphics.print(m, 36, y - (i - 1) * 16)
    end

    if G.hover and Board.inBounds(G.hover[1], G.hover[2]) then
        local mx, my = love.mouse.getPosition()
        love.graphics.setFont(G.fontSmall)
        love.graphics.setColor(C.panel)
        love.graphics.rectangle("fill", mx + 14, my - 36, 104, 26, 4, 4)
        love.graphics.setColor(C.panelLn)
        love.graphics.rectangle("line", mx + 14, my - 36, 104, 26, 4, 4)
        love.graphics.setColor(C.ink)
        love.graphics.print(string.format("TILE %d, %d", G.hover[1], G.hover[2]), mx + 24, my - 29)
    end
end

-- door marker: single post + hanging board over the shop entrance
-- ("SHOP" on the overworld) or the room door ("EXIT" inside).
function M.drawShopMarkers()
    local C = G.C
    local z = G.zoom
    local label, tx, ty = nil, nil, nil
    if G.map == "shop" and G.maps and G.maps.shop then
        label = "EXIT"
        tx, ty = G.maps.shop.door[1], G.maps.shop.door[2]
    elseif G.map ~= "shop" and G.shopOver then
        label = "SHOP"
        tx, ty = G.shopOver[1], G.shopOver[2]
    end
    if not label then return end
    local cx, cy = Board.tileToScreen(tx, ty, Board.tileTopZ(tx, ty))
    local topY = cy - 30 * z
    love.graphics.setColor(C.flagPole)
    love.graphics.setLineWidth(3 * z)
    love.graphics.line(cx, cy - 2 * z, cx, topY)
    love.graphics.setLineWidth(1)
    local bw, bh = 46 * z, 14 * z
    love.graphics.setColor(C.shopBoard)
    love.graphics.rectangle("fill", cx - bw / 2, topY, bw, bh, 3 * z, 3 * z)
    love.graphics.setColor(C.topEdge[1], C.topEdge[2], C.topEdge[3], 0.35)
    love.graphics.rectangle("line", cx - bw / 2, topY, bw, bh, 3 * z, 3 * z)
    love.graphics.setFont(G.fontSmall)
    love.graphics.setColor(C.ink)
    love.graphics.printf(label, cx - bw / 2, topY + 2 * z, bw, "center")
end

-- board pass in painter's order (diagonal bands s = gx+gy)
function M.drawBoard(time)
    love.graphics.push()
    M.drawBoardShadow()
    for s = 2, G.GRID * 2 do
        for gx = 1, G.GRID do
            local gy = s - gx
            if gy >= 1 and gy <= G.GRID then M.drawBlock(gx, gy, time) end
        end
        -- pawns whose tile-sum == s draw right after their row band
        for _, u in ipairs(G.units) do
            if u.map == G.map and u.gx + u.gy == s then M.drawPawn(u) end
        end
    end
    M.drawShopMarkers()
    -- landing puffs
    for _, pf in ipairs(G.puffs) do
        love.graphics.setColor(1, 1, 1, pf.a * 0.5)
        love.graphics.circle("line", pf.x, pf.y, pf.r)
    end
    love.graphics.pop()
end

return M

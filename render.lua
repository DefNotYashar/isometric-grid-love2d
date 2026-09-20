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
    elseif ter == "grass" or ter == "meadow" or ter == "flower" then
        local variant = math.floor(hash2(gx * 1.31 + 7.7, gy * 2.17 + 3.1) * 4)
        local base = C.grassTop
        if ter == "meadow" then base = C.meadowTop
        elseif ter == "flower" then base = C.flowerTop
        elseif variant == 1 then base = C.grassTop2
        elseif variant == 2 then base = C.grassTop3 end
        tCol = shade(base, 0.96 + hTop * 0.08)
    elseif ter == "tall" then tCol = shade(C.tallTop, 0.96 + hTop * 0.08)
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

    if ter == "grass" or ter == "meadow" or ter == "flower" or ter == "tall" then
        -- lush meadow renderer: mottled sod + dense swaying blades +
        -- per-variant decor (tuft / short crop / clover / blossoms / reeds)
        local isTall = (ter == "tall")
        local isMeadow = (ter == "meadow")
        local isFlower = (ter == "flower")
        local variant = math.floor(hash2(gx * 1.31 + 7.7, gy * 2.17 + 3.1) * 4)
        local baseCol, tipCol = C.grassBlade, C.grassTip
        if isTall then baseCol, tipCol = C.tallBlade, C.tallTip
        elseif isMeadow then baseCol, tipCol = C.meadowBlade, C.meadowTip end

        if isTall then
            -- dark inset sod so dodge thickets read dense
            love.graphics.setColor(C.tallInset)
            love.graphics.polygon("fill", diamond(cx, cy, w - 14 * G.zoom, hh - 7 * G.zoom))
        end
        -- mossy mottling: 3 soft patches, alternating dark/light
        for i = 1, 3 do
            local mx = cx + (hash2(gx * 3 + i * 11, gy * 7 + i) - 0.5) * 30 * G.zoom
            local my = cy + (hash2(gx * 5 + i, gy * 3 + i * 13) - 0.5) * 13 * G.zoom
            local mr = (4.5 + hash2(gx + i * 7, gy + i * 3) * 5) * G.zoom
            if i % 2 == 0 then
                love.graphics.setColor(1, 1, 1, 0.08)
            else
                love.graphics.setColor(C.mossPatch[1], C.mossPatch[2], C.mossPatch[3], 0.22)
            end
            love.graphics.ellipse("fill", mx, my, mr, mr * 0.5)
        end

        -- blade count per kind: grass 11-14, meadow 12-15, flower 9-12, tall 15-18
        local hb = hash2(gx * 3 + 1, gy * 3 + 7)
        local n
        if isTall then n = 15 + math.floor(hb * 4)
        elseif isMeadow then n = 12 + math.floor(hb * 4)
        elseif isFlower then n = 9 + math.floor(hb * 4)
        else n = 11 + math.floor(hb * 4) end
        -- variant 0 tufts cluster toward the middle, others spread out
        local spread = (variant == 0 and not isTall) and 14 or 26
        for i = 1, n do
            local h1 = hash2(gx * 7 + i * 13, gy * 5 + i * 3)
            local h2 = hash2(gx * 5 + i * 7, gy * 11 + i)
            local h3 = hash2(gx * 13 + i, gy * 7 + i * 5)
            local ox = (h1 - 0.5) * spread * G.zoom
            local byy = cy + (h2 - 0.5) * 11 * G.zoom
            local bh
            if isTall then bh = (10 + h3 * 7) * G.zoom
            elseif variant == 1 then bh = (3.5 + h3 * 2.5) * G.zoom
            else bh = (5 + h3 * 4.5) * G.zoom end
            local bw = (0.9 + h2 * 0.7) * G.zoom
            local sw = math.sin(time * 2.2 + gx * 1.7 + gy * 0.9 + i * 1.3) * 1.6 * G.zoom
            local ax, ay = cx + ox + sw, byy - bh
            local bf = 0.85 + h3 * 0.4
            love.graphics.setColor(baseCol[1] * bf, baseCol[2] * bf, baseCol[3] * bf, 1)
            love.graphics.polygon("fill", { cx + ox - bw, byy, cx + ox + bw, byy, ax, ay })
            -- lighter tip over the top 40%
            local t = 0.40
            local qx, qy = ax + (cx + ox - ax) * t, ay + (byy - ay) * t
            love.graphics.setColor(tipCol)
            love.graphics.polygon("fill", { ax, ay, qx - bw * 0.45, qy, qx + bw * 0.45, qy })
            -- seed plumes on every third tall blade
            if isTall and i % 3 == 0 then
                love.graphics.setColor(C.seedHead)
                love.graphics.ellipse("fill", ax, ay - 1 * G.zoom, 1.6 * G.zoom, 2.4 * G.zoom)
            end
        end

        -- clover clusters on variant 2 (rounded leaves, not blades)
        if variant == 2 and not isTall then
            for i = 1, 3 do
                local h1 = hash2(gx * 9 + i * 5, gy * 4 + i * 17)
                local h2 = hash2(gx * 4 + i * 19, gy * 9 + i * 3)
                local px = cx + (h1 - 0.5) * 26 * G.zoom
                local py = cy + (h2 - 0.5) * 12 * G.zoom
                local lr = 2.1 * G.zoom
                local lf = 0.9 + h1 * 0.3
                love.graphics.setColor(C.cloverLeaf[1] * lf, C.cloverLeaf[2] * lf, C.cloverLeaf[3] * lf, 1)
                love.graphics.circle("fill", px - lr * 0.7, py - lr * 0.4, lr)
                love.graphics.circle("fill", px + lr * 0.7, py - lr * 0.4, lr)
                love.graphics.circle("fill", px, py + lr * 0.6, lr)
            end
        end

        -- blossoms on flower tiles + variant-3 grass tiles
        local blooms = 0
        if isFlower then blooms = 3 + math.floor(hash2(gx * 7, gy * 13) * 2)
        elseif variant == 3 and not isTall then blooms = 2 end
        for i = 1, blooms do
            local h1 = hash2(gx * 11 + i * 23, gy * 6 + i * 11)
            local h2 = hash2(gx * 6 + i * 5, gy * 13 + i * 29)
            local h3 = hash2(gx * 17 + i * 3, gy * 3 + i * 7)
            local px = cx + (h1 - 0.5) * 24 * G.zoom
            local py = cy + (h2 - 0.5) * 11 * G.zoom - 4 * G.zoom
            -- stem
            love.graphics.setColor(baseCol)
            love.graphics.setLineWidth(1)
            love.graphics.line(px, py + 5 * G.zoom, px, py)
            -- petals
            local petal = C.bloomWhite
            if h3 < 0.33 then petal = C.bloomYellow
            elseif h3 < 0.66 then petal = C.bloomPink end
            local pr = 2.0 * G.zoom
            love.graphics.setColor(petal)
            love.graphics.circle("fill", px - pr * 0.8, py, pr * 0.75)
            love.graphics.circle("fill", px + pr * 0.8, py, pr * 0.75)
            love.graphics.circle("fill", px, py - pr * 0.8, pr * 0.75)
            love.graphics.circle("fill", px, py + pr * 0.8, pr * 0.75)
            love.graphics.setColor(C.bloomYellow[1] * 0.9, C.bloomYellow[2] * 0.9, C.bloomYellow[3] * 0.9)
            if petal == C.bloomYellow then love.graphics.setColor(C.bloomWhite) end
            love.graphics.circle("fill", px, py, pr * 0.55)
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

function M.drawPawn(u, time)
    if u.team == "enemy" then
        if u.kind == "archer" then return M.drawSkeleton(u, time) end
        return M.drawSlime(u, time)
    end
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

-- Skeleton archer: bone pawn with a skull face and a held bow.
-- Same ground rules as pawns (shadow, hop, squash, active ring).
function M.drawSkeleton(u, time)
    local C = G.C
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

    local shScale = 1 - math.min(0.35, (hop + l) * 0.02)
    love.graphics.setColor(C.shadow)
    love.graphics.ellipse("fill", cx, cy + 2 * s, 15 * s * shScale, 6 * s * shScale)

    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.scale(sx * s, sy * s)
    love.graphics.translate(-cx, -cy)
    local bw, bh = 13, 22
    -- base
    love.graphics.setColor(u.dark)
    love.graphics.ellipse("fill", cx, cy - 2, 13, 5.5)
    love.graphics.setColor(u.color)
    love.graphics.ellipse("fill", cx, cy - 4, 13, 5.5)
    -- ribcage body (two-tone flat)
    love.graphics.setColor(u.dark)
    love.graphics.polygon("fill", { cx - bw / 2, cy - 4, cx - 4, cy - 4 - bh,
                                    cx + 4, cy - 4 - bh, cx + bw / 2, cy - 4 })
    love.graphics.setColor(u.color)
    love.graphics.polygon("fill", { cx - 4, cy - 4, cx - 1, cy - 4 - bh,
                                    cx + 4, cy - 4 - bh, cx + 5, cy - 4 })
    -- ribs
    love.graphics.setColor(u.dark)
    love.graphics.setLineWidth(1)
    for i = 1, 3 do
        local ry = cy - 8 - i * 5
        love.graphics.line(cx - 5, ry, cx + 5, ry)
    end
    -- skull + sockets
    love.graphics.setColor(u.color)
    love.graphics.circle("fill", cx, cy - 12 - bh, 8.5)
    love.graphics.setColor(0.10, 0.12, 0.14)
    love.graphics.circle("fill", cx - 3, cy - 13 - bh, 2.2)
    love.graphics.circle("fill", cx + 3, cy - 13 - bh, 2.2)
    love.graphics.circle("fill", cx, cy - 8 - bh, 1.2)
    -- bow: arc + string on the right side
    love.graphics.setColor(C.flagPole)
    love.graphics.setLineWidth(2)
    love.graphics.arc("line", "open", cx + 12, cy - 14, 10, -1.2, 1.2)
    love.graphics.setLineWidth(1)
    love.graphics.line(cx + 12 + 10 * math.cos(-1.2), cy - 14 + 10 * math.sin(-1.2),
                       cx + 12 + 10 * math.cos(1.2), cy - 14 + 10 * math.sin(1.2))
    love.graphics.pop()

    if active then
        love.graphics.setColor(C.select)
        love.graphics.setLineWidth(2)
        love.graphics.ellipse("line", cx, cy - 2 * s, 16 * s, 7 * s)
        love.graphics.setLineWidth(1)
        local bob = math.sin(love.timer.getTime() * 2) * 2
        local nw, nh = 64 * G.zoom, 18 * G.zoom
        local nx, ny = cx - nw / 2, cy - (46 + 12) * s + bob
        love.graphics.setColor(0.05, 0.07, 0.10, 0.92)
        love.graphics.rectangle("fill", nx, ny, nw, nh, 5, 5)
        love.graphics.setColor(C.select)
        love.graphics.rectangle("line", nx, ny, nw, nh, 5, 5)
        love.graphics.setFont(G.fontSmall)
        love.graphics.setColor(C.selInk)
        love.graphics.printf(u.name:upper(), nx, ny + 3 * G.zoom, nw, "center")
        love.graphics.setLineWidth(1)
    end
end

-- Slime blob: squash-stretch dome with idle wobble, glossy highlight,
-- dark lower band, two eyes. Same ground rules as pawns (shadow, hop).
function M.drawSlime(u, time)
    local C = G.C
    local hgt = G.heights[u.gy] and G.heights[u.gy][u.gx] or 0
    local k = u.gx .. "," .. u.gy
    local l = G.lift[k] or 0
    local moving = #u.path > 0
    local hop = moving and math.sin(math.min(1, u.t / G.STEP_TIME) * math.pi) * 4 or 0
    local sq = G.squash[u.id] or 0
    -- idle wobble, per-unit phase from the id so slimes don't sync
    local ph = 0
    for i = 1, #u.id do ph = ph + u.id:byte(i) end
    local wob = math.sin((time or 0) * 5 + ph) * 0.05
    local sx, sy = 1 + sq * 0.3 + wob, 1 - sq * 0.2 - wob
    local cx, cy = Board.tileToScreen(u.px, u.py, hgt * G.BLOCK_H + l + hop)
    local s = G.zoom
    local active = (G.units[G.activeIdx] == u)

    local shScale = 1 - math.min(0.35, (hop + l) * 0.02)
    love.graphics.setColor(C.shadow)
    love.graphics.ellipse("fill", cx, cy + 2 * s, 15 * s * shScale, 6 * s * shScale)

    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.scale(sx * s, sy * s)
    love.graphics.translate(-cx, -cy)
    -- base puddle
    love.graphics.setColor(u.dark)
    love.graphics.ellipse("fill", cx, cy - 2, 14, 5.5)
    -- dome body
    love.graphics.setColor(u.color)
    love.graphics.ellipse("fill", cx, cy - 9, 12, 10)
    -- dark lower band
    love.graphics.setColor(u.dark)
    love.graphics.ellipse("fill", cx, cy - 4, 9.5, 4)
    -- glossy highlight upper-left
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.ellipse("fill", cx - 4.5, cy - 13, 3.6, 2.4)
    -- eyes + sparkles
    love.graphics.setColor(0.10, 0.12, 0.14)
    love.graphics.circle("fill", cx - 3.5, cy - 10, 1.9)
    love.graphics.circle("fill", cx + 3.5, cy - 10, 1.9)
    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.circle("fill", cx - 4, cy - 10.6, 0.7)
    love.graphics.circle("fill", cx + 3, cy - 10.6, 0.7)
    love.graphics.pop()

    if active then
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
    -- soft vertical grade: cooler shadow up top, warm pool around the board
    local strips = 24
    for i = 1, strips do
        local t = (i - 1) / (strips - 1)
        -- darken top, lift the middle where the board sits
        local lift = math.sin(t * math.pi) * 0.035
        love.graphics.setColor(0.02, 0.025, 0.02, 0.10 * (1 - t) - lift * 0.4)
        love.graphics.rectangle("fill", 0, (i - 1) * G.H / strips, G.W, G.H / strips + 1)
        if lift > 0 then
            love.graphics.setColor(C.glowCore[1], C.glowCore[2], C.glowCore[3], lift * 0.35)
            love.graphics.rectangle("fill", 0, (i - 1) * G.H / strips, G.W, G.H / strips + 1)
        end
    end
    -- layered hearth-glow: wide warm halo + deep core + hot center
    local breathe = 1 + 0.04 * math.sin(time * 0.8)
    local cx, cy = G.W * 0.5, G.H * 0.52
    love.graphics.setColor(C.glowWarm)
    love.graphics.circle("fill", cx, cy, 360 * breathe)
    love.graphics.setColor(C.glowDeep)
    love.graphics.circle("fill", cx, cy, 240 * breathe)
    love.graphics.setColor(C.glowCore)
    love.graphics.circle("fill", cx, cy, 130 * breathe)
    -- topographic contour rings around the board center
    love.graphics.setColor(C.contour)
    love.graphics.setLineWidth(1)
    for i = 1, 3 do
        local r = (150 + i * 90) * (1 + 0.01 * math.sin(time * 0.5 + i))
        love.graphics.circle("line", cx, cy, r)
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
    -- smooth vignette: feathered edges so the board sits in a pool of light
    local steps = 7
    for i = 1, steps do
        local t = i / steps
        local a = 0.055 * (1 - t) + 0.005
        love.graphics.setColor(C.vignette[1], C.vignette[2], C.vignette[3], a)
        local m = (steps - i) * 9
        love.graphics.setLineWidth(10)
        love.graphics.rectangle("line", m, m, G.W - m * 2, G.H - m * 2)
    end
    love.graphics.setLineWidth(1)
    love.graphics.setColor(C.vignette[1], C.vignette[2], C.vignette[3], 0.22)
    love.graphics.rectangle("fill", 0, 0, G.W, 3)
    love.graphics.rectangle("fill", 0, G.H - 3, G.W, 3)
    love.graphics.rectangle("fill", 0, 0, 3, G.H)
    love.graphics.rectangle("fill", G.W - 3, 0, 3, G.H)
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

-- Unit card (left side): medallion bust, name/rank, status pill, beveled
-- HP + MANA bars, purse, collapsible inset stat cells.
function M.drawPortrait()
    local C = G.C
    local a = G.units[G.activeIdx]
    if not a then G.statsToggle = nil return end
    local st = a.stats or {}
    local isFoe = (a.team == "enemy")
    local teamCol = isFoe and C.floatDmg or C.accent
    local showPurse = not isFoe
    local cw = 296
    -- content: header 12 + medallion zone + bars + purse + stats head + cells
    local off = showPurse and 154 or 134
    local chh = 12 + off + 22 + (G.showStats and 100 or 0) + 12
    local bx, by = 32, 150
    -- card body
    love.graphics.setColor(C.panel)
    love.graphics.rectangle("fill", bx, by, cw, chh, 8, 8)
    -- team strip across the top
    love.graphics.setColor(teamCol)
    love.graphics.rectangle("fill", bx + 3, by + 3, cw - 6, 5, 2, 2)
    love.graphics.setColor(C.panelLn)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", bx, by, cw, chh, 8, 8)
    love.graphics.setLineWidth(1)

    local lx = bx + 20
    local row = by + 12
    -- medallion: team-glow outer ring, dark sticker ring, deep fill
    local mx, my, mr = lx + 32, row + 44, 34
    love.graphics.setColor(a.color[1], a.color[2], a.color[3], 0.45)
    love.graphics.setLineWidth(6)
    love.graphics.circle("line", mx, my, mr + 3)
    love.graphics.setColor(C.ring)
    love.graphics.setLineWidth(4)
    love.graphics.circle("line", mx, my, mr)
    love.graphics.setColor(C.barBg)
    love.graphics.circle("fill", mx, my, mr - 3)
    love.graphics.setLineWidth(1)
    -- bust, scaled up into the medallion (anchor: visual mass center)
    local cx, feet = lx + 10, row + 64
    love.graphics.push()
    love.graphics.translate(mx, my)
    love.graphics.scale(1.35, 1.35)
    love.graphics.translate(-cx, -(feet - 12))
    if isFoe then
        if a.kind == "archer" then
            -- skull bust: bone dome, dark sockets, jaw band
            love.graphics.setColor(C.shadow)
            love.graphics.ellipse("fill", cx, feet, 11, 4.5)
            love.graphics.setColor(a.color)
            love.graphics.circle("fill", cx, feet - 14, 10)
            love.graphics.setColor(a.dark)
            love.graphics.ellipse("fill", cx, feet - 4, 8, 3.4)
            love.graphics.setColor(0.10, 0.12, 0.14)
            love.graphics.circle("fill", cx - 3.6, feet - 15, 2.1)
            love.graphics.circle("fill", cx + 3.6, feet - 15, 2.1)
            love.graphics.setColor(1, 1, 1, 0.5)
            love.graphics.ellipse("fill", cx - 4, feet - 19, 3, 2)
        else
        love.graphics.setColor(C.shadow)
        love.graphics.ellipse("fill", cx, feet, 11, 4.5)
        love.graphics.setColor(a.dark)
        love.graphics.ellipse("fill", cx, feet - 2, 12, 5)
        love.graphics.setColor(a.color)
        love.graphics.ellipse("fill", cx, feet - 9, 10.5, 9)
        love.graphics.setColor(a.dark)
        love.graphics.ellipse("fill", cx, feet - 4, 8.5, 3.6)
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.ellipse("fill", cx - 4, feet - 13, 3.2, 2.2)
        love.graphics.setColor(0.10, 0.12, 0.14)
        love.graphics.circle("fill", cx - 3, feet - 10, 1.7)
        love.graphics.circle("fill", cx + 3, feet - 10, 1.7)
        end
    else
        love.graphics.setColor(C.shadow)
        love.graphics.ellipse("fill", cx, feet, 11, 4.5)
        love.graphics.setColor(a.dark)
        love.graphics.polygon("fill", { cx - 9, feet - 2, cx - 3, feet - 18,
                                        cx + 3, feet - 18, cx + 9, feet - 2 })
        love.graphics.setColor(a.color)
        love.graphics.polygon("fill", { cx - 3, feet - 2, cx - 1, feet - 18,
                                        cx + 3, feet - 18, cx + 4, feet - 2 })
        love.graphics.setColor(a.dark)
        love.graphics.ellipse("fill", cx, feet - 18, 5.5, 2.2)
        love.graphics.setColor(a.color)
        love.graphics.circle("fill", cx, feet - 25, 8)
        love.graphics.setColor(1, 1, 1, 0.55)
        love.graphics.circle("fill", cx - 2, feet - 27, 1.8)
    end
    love.graphics.pop()
    -- name + position + status pill
    local tx = lx + 78
    love.graphics.setFont(G.fontTitle)
    love.graphics.setColor(C.selInk)
    love.graphics.print(a.name:upper(), tx, row)
    love.graphics.setFont(G.fontSmall)
    love.graphics.setColor(C.muted)
    local sub = a.gx .. ", " .. a.gy .. "  ·  RNG " .. tostring(a.range)
    if isFoe then sub = sub .. "  ·  ENEMY" end
    love.graphics.print(sub, tx, row + 34)
    local status, scol
    if isFoe then status, scol = "enemy turn", C.floatDmg
    elseif a.acted then status, scol = "spent", C.muted
    elseif a.moved then status, scol = "attack or pass", C.accent
    else status, scol = "ready", C.accent end
    love.graphics.setColor(C.barBg)
    love.graphics.rectangle("fill", tx - 8, row + 52, 148, 20, 10, 10)
    love.graphics.setColor(scol)
    love.graphics.rectangle("line", tx - 8, row + 52, 148, 20, 10, 10)
    love.graphics.setColor(scol)
    love.graphics.print(status, tx, row + 55)
    -- beveled bars with shine + segment ticks (mana ticks = one bolt each)
    local function chunkBar(y, h, w, frac, fill, label, tickEvery, maxv)
        love.graphics.setColor(C.barBg)
        love.graphics.rectangle("fill", lx, y, w, h, 4, 4)
        local fw = w * math.max(0, math.min(1, frac))
        love.graphics.setColor(fill)
        love.graphics.rectangle("fill", lx, y, fw, h, 4, 4)
        if fw > 6 then
            love.graphics.setColor(1, 1, 1, 0.22)
            love.graphics.line(lx + 3, y + 2, lx + fw - 3, y + 2)
        end
        if tickEvery and maxv and maxv > tickEvery then
            love.graphics.setColor(C.ring[1], C.ring[2], C.ring[3], 0.7)
            local step = w / maxv * tickEvery
            local x = lx + step
            while x < lx + w - 1 do
                love.graphics.line(x, y + 2, x, y + h - 2)
                x = x + step
            end
        end
        love.graphics.setColor(C.ring[1], C.ring[2], C.ring[3], 0.8)
        love.graphics.rectangle("line", lx, y, w, h, 4, 4)
        love.graphics.setColor(C.ink)
        love.graphics.print(label, lx + 8, y + (h - 11) / 2)
    end
    local hf = (a.maxHP > 0) and (a.hp / a.maxHP) or 0
    chunkBar(row + 88, 20, 256, hf, hf < 0.35 and C.floatDmg or C.accent,
        "HP  " .. (a.hp or 0) .. " / " .. (a.maxHP or 0), 4, a.maxHP or 0)
    local mf = (a.maxMana > 0) and (a.mana / a.maxMana) or 0
    chunkBar(row + 112, 16, 256, mf, C.select,
        "MP  " .. (a.mana or 0) .. " / " .. (a.maxMana or 0),
        Units.BOLT_COST or 3, a.maxMana or 0)
    row = row + 132
    if showPurse then
        love.graphics.setFont(G.fontSmall)
        love.graphics.setColor(C.coin)
        love.graphics.print("PURSE  " .. (G.coins or 0) .. "c", lx, row)
        row = row + 20
    end
    row = row + 2

    -- stat grid: arrow toggles two rows of inset cells
    love.graphics.setFont(G.fontSmall)
    love.graphics.setColor(G.showStats and C.accent or C.muted)
    love.graphics.print((G.showStats and "▾ " or "▸ ") .. "STATS", lx, row)
    G.statsToggle = { x = lx - 4, y = row - 2, w = 150, h = 18 }
    row = row + 22
    if G.showStats then
        local function trio(k1, v1, k2, v2, k3, v3)
            local offs = { 0, 84, 168 }
            local ks, vs = { k1, k2, k3 }, { v1, v2, v3 }
            for i = 1, 3 do
                local cx0 = lx + offs[i]
                love.graphics.setColor(C.barBg)
                love.graphics.rectangle("fill", cx0, row, 80, 44, 4, 4)
                love.graphics.setColor(C.ring[1], C.ring[2], C.ring[3], 0.5)
                love.graphics.rectangle("line", cx0, row, 80, 44, 4, 4)
                love.graphics.setColor(C.muted)
                love.graphics.print(ks[i], cx0 + 8, row + 4)
                love.graphics.setFont(G.fontBody)
                love.graphics.setColor(C.ink)
                love.graphics.print(tostring(vs[i] or 0), cx0 + 8, row + 20)
                love.graphics.setFont(G.fontSmall)
            end
            row = row + 50
        end
        trio("VIG", st.vigor, "STR", st.strength, "DEX", st.dexterity)
        trio("LCK", st.luck, "SPD", st.speed, "CHA", st.charisma)
        row = row + 4
    end
end

-- Enemy intel panel on hover: name, kind, HP bar, threat readout,
-- mini stat grid + flavor bio. Pops beside the cursor, clamped inside
-- the viewport. Sets nothing (pure readout).
function M.drawEnemyPanel(foe, mx, my)
    local C = G.C
    local info = Units.bioOf(foe)
    local st = foe.stats or {}
    local w = 232
    love.graphics.setFont(G.fontSmall)
    local _, wrapped = G.fontSmall:getWrap(info.bio, w - 24)
    local hh = 122 + #wrapped * 13
    local x = mx + 16
    if x + w > G.W - 8 then x = mx - w - 16 end
    local y = my - 44
    if y + hh > G.H - 8 then y = G.H - 8 - hh end
    if y < 8 then y = 8 end
    love.graphics.setColor(C.panel)
    love.graphics.rectangle("fill", x, y, w, hh, 6, 6)
    love.graphics.setColor(foe.color)
    love.graphics.rectangle("fill", x + 3, y + 3, w - 6, 4, 2, 2)
    love.graphics.setColor(C.panelLn)
    love.graphics.rectangle("line", x, y, w, hh, 6, 6)
    love.graphics.setFont(G.fontBody)
    love.graphics.setColor(C.ink)
    love.graphics.print(foe.name:upper(), x + 12, y + 10)
    love.graphics.setFont(G.fontSmall)
    love.graphics.setColor(C.muted)
    love.graphics.print(foe.gx .. ", " .. foe.gy .. "  ·  " .. info.kind .. " · " .. info.style,
        x + 12, y + 30)
    -- HP bar
    local frac = (foe.maxHP > 0) and (foe.hp / foe.maxHP) or 0
    love.graphics.setColor(C.barBg)
    love.graphics.rectangle("fill", x + 12, y + 48, w - 24, 12, 3, 3)
    love.graphics.setColor(frac < 0.35 and C.floatDmg or C.accent)
    love.graphics.rectangle("fill", x + 12, y + 48, (w - 24) * frac, 12, 3, 3)
    love.graphics.setColor(C.ink)
    love.graphics.print("HP " .. (foe.hp or 0) .. "/" .. (foe.maxHP or 0), x + 18, y + 48)
    -- threat readout
    love.graphics.setColor(C.floatDmg)
    love.graphics.print(info.threat, x + 12, y + 66)
    -- mini stat grid
    local names = { "VIG", "STR", "DEX", "LCK", "SPD", "CHA" }
    local vals = { st.vigor, st.strength, st.dexterity, st.luck, st.speed, st.charisma }
    for i = 1, 6 do
        local c3 = (i - 1) % 3
        local r2 = math.floor((i - 1) / 3)
        local sx = x + 12 + c3 * ((w - 24) / 3)
        love.graphics.setColor(C.muted)
        love.graphics.print(names[i], sx, y + 84 + r2 * 15)
        love.graphics.setColor(C.ink)
        love.graphics.print(tostring(vals[i] or 0), sx + 34, y + 84 + r2 * 15)
    end
    -- bio
    love.graphics.setColor(C.selInk)
    love.graphics.printf(info.bio, x + 12, y + 116, w - 24)
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
    love.graphics.print("CLICK select / move / attack   WASD step   TAB cycle   SPACE end turn",
        36, G.H - 60)
    love.graphics.print("Q bolt   C stats   RIGHT-DRAG pan   ARROWS pan   R reset",
        36, G.H - 44)
    local y = G.H - 84
    for i, m in ipairs(G.log) do
        love.graphics.setColor(C.muted)
        love.graphics.print(m, 36, y - (i - 1) * 16)
    end

    if G.hover and Board.inBounds(G.hover[1], G.hover[2]) then
        local mx, my = love.mouse.getPosition()
        local foe = Units.unitAt(G.hover[1], G.hover[2])
        if foe and foe.team == "enemy" then
            M.drawEnemyPanel(foe, mx, my)
        else
            love.graphics.setFont(G.fontSmall)
            love.graphics.setColor(C.panel)
            love.graphics.rectangle("fill", mx + 14, my - 36, 150, 26, 4, 4)
            love.graphics.setColor(C.panelLn)
            love.graphics.rectangle("line", mx + 14, my - 36, 150, 26, 4, 4)
            love.graphics.setColor(C.ink)
            love.graphics.print(string.format("TILE %d, %d", G.hover[1], G.hover[2]), mx + 24, my - 29)
        end
    end

    M.drawTurnBox()
    M.drawTurnBar()
end

-- turn indicator + BOLT / END TURN buttons (bottom-right).
-- Sets G.boltBtn / G.nextBtn (screen-space rects) for the input hit-test.
function M.drawTurnBox()
    local C = G.C
    local bw, bh = 216, 102
    local bx, by = G.W - bw - 32, G.H - bh - 32
    local a = G.units[G.activeIdx]
    love.graphics.setColor(C.panel)
    love.graphics.rectangle("fill", bx, by, bw, bh, 6, 6)
    love.graphics.setColor(C.panelLn)
    love.graphics.rectangle("line", bx, by, bw, bh, 6, 6)
    love.graphics.setFont(G.fontHead)
    love.graphics.setColor(C.accent)
    love.graphics.print("ROUND " .. (G.round or 1), bx + 14, by + 8)
    love.graphics.setFont(G.fontSmall)
    love.graphics.setColor(C.muted)
    local who = "--"
    if a then
        who = a.name:upper() .. (a.team == "enemy" and "  [ENEMY]" or "")
        if a.acted then who = who .. "  (done)" end
    end
    love.graphics.print(who, bx + 14, by + 28)
    local mx, my = love.mouse.getPosition()
    -- firebolt button (heroes only, grey when unaffordable/spent)
    local canBolt = a and a.team ~= "enemy" and not a.acted
        and (a.mana or 0) >= (Units.BOLT_COST or 3)
    local lb = { x = bx + 12, y = by + 46, w = bw - 24, h = 20 }
    G.boltBtn = lb
    local bhot = mx >= lb.x and mx <= lb.x + lb.w and my >= lb.y and my <= lb.y + lb.h
    if G.castMode then
        love.graphics.setColor(C.select)
        love.graphics.rectangle("fill", lb.x, lb.y, lb.w, lb.h, 4, 4)
        love.graphics.setColor(C.panel)
    elseif canBolt then
        love.graphics.setColor(bhot and C.select or C.panelLn)
        love.graphics.rectangle(bhot and "fill" or "line", lb.x, lb.y, lb.w, lb.h, 4, 4)
        love.graphics.setColor(bhot and C.panel or C.selInk)
    else
        love.graphics.setColor(C.muted)
        love.graphics.rectangle("line", lb.x, lb.y, lb.w, lb.h, 4, 4)
        love.graphics.setColor(C.muted)
    end
    love.graphics.printf("BOLT (" .. (Units.BOLT_COST or 3) .. ")", lb.x, lb.y + 4, lb.w, "center")
    -- end turn button
    local bb = { x = bx + 12, y = by + 70, w = bw - 24, h = 22 }
    G.nextBtn = bb
    local mx, my = love.mouse.getPosition()
    local hot = mx >= bb.x and mx <= bb.x + bb.w and my >= bb.y and my <= bb.y + bb.h
    love.graphics.setColor(hot and C.select or C.panelLn)
    love.graphics.rectangle(hot and "fill" or "line", bb.x, bb.y, bb.w, bb.h, 4, 4)
    love.graphics.setColor(hot and C.panel or C.selInk)
    love.graphics.printf("END TURN", bb.x, bb.y + 5, bb.w, "center")
end

-- Initiative strip across the top: portrait chips in turn order starting
-- at the current unit and wrapping (the loop), round badge on the left.
-- Current chip is ringed + named, acted chips are dimmed with a check,
-- off-map units ghosted, the AI-acting enemy pulses.
function M.drawTurnBar()
    local C = G.C
    if not G.turnOrder or #G.turnOrder == 0 then return end
    -- full loop from the queue position, wrapping around
    local seq = {}
    local n = #G.turnOrder
    for i = 0, n - 1 do
        local id = G.turnOrder[(G.turnPos - 1 + i) % n + 1]
        local idx = Units.indexOfId(id)
        if idx and G.units[idx] then seq[#seq + 1] = G.units[idx] end
    end
    if #seq == 0 then return end

    local step, y = 64, 44
    local totalW = #seq * step
    -- centered block: chips in order around screen center, round badge
    -- on the left of the first chip
    local bw0, bh0, gap0 = 56, 32, 14
    local x0 = G.W / 2 - totalW / 2 + step / 2
    local cur = G.units[G.activeIdx]
    local pulse = 0.5 + 0.5 * math.sin(love.timer.getTime() * 6)

    -- backdrop pill so the bar reads over the board at any size
    local lastR = 27
    local pbx0 = x0 - step / 2 - gap0 - bw0 - 12
    local pbx1 = x0 + totalW - step / 2 + lastR + 12
    love.graphics.setColor(C.panel)
    love.graphics.rectangle("fill", pbx0, y - 36, pbx1 - pbx0, 104, 10, 10)
    love.graphics.setColor(C.panelLn)
    love.graphics.rectangle("line", pbx0, y - 36, pbx1 - pbx0, 104, 10, 10)

    -- connector line through the chips
    love.graphics.setColor(C.muted[1], C.muted[2], C.muted[3], 0.4)
    love.graphics.setLineWidth(3)
    love.graphics.line(x0, y, x0 + totalW - step, y)
    love.graphics.setLineWidth(1)

    -- round badge, left of the first chip
    local bx = x0 - step / 2 - gap0 - bw0
    love.graphics.setColor(C.barBg)
    love.graphics.rectangle("fill", bx, y - bh0 / 2, bw0, bh0, 8, 8)
    love.graphics.setColor(C.panelLn)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", bx, y - bh0 / 2, bw0, bh0, 8, 8)
    love.graphics.setLineWidth(1)
    love.graphics.setFont(G.fontHead)
    love.graphics.setColor(C.accent)
    love.graphics.printf("R" .. (G.round or 1), bx, y - 8, bw0, "center")

    for i, u in ipairs(seq) do
        local cx = x0 + (i - 1) * step
        local isCur = (u == cur)
        local r = isCur and 27 or 22
        local ghost = (u.map ~= G.map)
        local alpha = ghost and 0.35 or 1
        local function col(c, a)
            return { c[1], c[2], c[3], (a or 1) * alpha }
        end
        if u.team == "enemy" then
            if u.kind == "archer" then
                -- skull-face chip: bone face, dark rim + sockets
                love.graphics.setColor(col(u.dark))
                love.graphics.circle("fill", cx, y, r)
                love.graphics.setColor(col(u.color))
                love.graphics.circle("fill", cx, y, r - 3)
                love.graphics.setColor(col({0.10, 0.12, 0.14}))
                love.graphics.circle("fill", cx - r * 0.28, y - r * 0.08, r * 0.17)
                love.graphics.circle("fill", cx + r * 0.28, y - r * 0.08, r * 0.17)
                love.graphics.setColor(col({1, 1, 1}, 0.5))
                love.graphics.circle("fill", cx - r * 0.3, y - r * 0.4, r * 0.13)
            else
            -- slime-face chip
            love.graphics.setColor(col(u.color))
            love.graphics.circle("fill", cx, y, r)
            love.graphics.setColor(col(u.dark))
            love.graphics.ellipse("fill", cx, y + r * 0.35, r - 4, (r - 4) * 0.55)
            love.graphics.setColor(col({0.10, 0.12, 0.14}))
            love.graphics.circle("fill", cx - r * 0.28, y - r * 0.1, r * 0.16)
            love.graphics.circle("fill", cx + r * 0.28, y - r * 0.1, r * 0.16)
            love.graphics.setColor(col({1, 1, 1}, 0.6))
            love.graphics.circle("fill", cx - r * 0.3, y - r * 0.42, r * 0.14)
            end
        else
            -- pawn chip: dark rim, color face, highlight dot
            love.graphics.setColor(col(u.dark))
            love.graphics.circle("fill", cx, y, r)
            love.graphics.setColor(col(u.color))
            love.graphics.circle("fill", cx, y, r - 3)
            love.graphics.setColor(col({1, 1, 1}, 0.55))
            love.graphics.circle("fill", cx - r * 0.25, y - r * 0.3, r * 0.16)
        end
        -- mini HP bar
        local frac = (u.maxHP > 0) and (u.hp / u.maxHP) or 0
        love.graphics.setColor(col(C.barBg))
        love.graphics.rectangle("fill", cx - 20, y + r + 4, 40, 6, 3, 3)
        love.graphics.setColor(col(frac < 0.35 and C.floatDmg or C.accent))
        love.graphics.rectangle("fill", cx - 20, y + r + 4, 40 * frac, 6, 3, 3)
        -- acted check
        if u.acted then
            love.graphics.setColor(0, 0, 0, 0.55 * alpha)
            love.graphics.circle("fill", cx, y, r)
            love.graphics.setFont(G.fontBody)
            love.graphics.setColor(C.ink[1], C.ink[2], C.ink[3], alpha)
            love.graphics.printf("✓", cx - 12, y - 9, 24, "center")
        end
        -- current ring + name; AI-acting enemy pulses
        if isCur then
            local acting = G.ai and G.ai.id == u.id
            love.graphics.setColor(C.select[1], C.select[2], C.select[3],
                acting and (0.5 + 0.5 * pulse) or 1)
            love.graphics.setLineWidth(4)
            love.graphics.circle("line", cx, y, r + 4)
            love.graphics.setLineWidth(1)
            love.graphics.setFont(G.fontHead)
            love.graphics.setColor(C.selInk[1], C.selInk[2], C.selInk[3], alpha)
            love.graphics.printf(u.name:upper(), cx - 70, y + r + 12, 140, "center")
        end
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
            if u.map == G.map and u.gx + u.gy == s then M.drawPawn(u, time) end
        end
    end
    M.drawShopMarkers()
    -- arrows in flight (recomputed per frame so they track the camera):
    -- shaft with motion trail + head, arcing over the board.
    for _, a in ipairs(G.arrows) do
        local k = math.min(1, a.t / a.dur)
        local x0, y0 = Board.tileToScreen(a.fx, a.fy, 30)
        local x1, y1 = Board.tileToScreen(a.tx, a.ty, 30)
        local function along(e)
            return x0 + (x1 - x0) * e, y0 + (y1 - y0) * e - math.sin(e * math.pi) * 22
        end
        local px, py = along(k)
        local qx, qy = along(math.max(0, k - 0.15))
        love.graphics.setColor(0.92, 0.88, 0.76, 0.95)
        love.graphics.setLineWidth(2.5)
        love.graphics.line(qx, qy, px, py)
        love.graphics.setLineWidth(1)
        local dx, dy = px - qx, py - qy
        local len = math.sqrt(dx * dx + dy * dy)
        if len > 0.01 then
            dx, dy = dx / len, dy / len
            local bx, by = px - dx * 9, py - dy * 9
            love.graphics.setColor(C.coin)
            love.graphics.polygon("fill", { px, py,
                bx - dy * 4, by + dx * 4, bx + dy * 4, by - dx * 4 })
        end
    end
    -- landing puffs
    for _, pf in ipairs(G.puffs) do
        love.graphics.setColor(1, 1, 1, pf.a * 0.5)
        love.graphics.circle("line", pf.x, pf.y, pf.r)
    end
    -- floating combat text: big pop-in numbers (recomputed per frame
    -- so they track the camera). Crits render larger with a wobble.
    love.graphics.setFont(G.fontTitle)
    for _, f in ipairs(G.floats) do
        local k = f.t / f.life
        local hgt = (G.heights[f.gy] and G.heights[f.gy][f.gx]) or 0
        local cx, cy = Board.tileToScreen(f.gx, f.gy, hgt * G.BLOCK_H + 18)
        cy = cy - k * 34
        if f.big then cx = cx + math.sin(f.t * 45) * 4 * (1 - k) end
        local pop = 1 + 1.4 * math.max(0, 1 - f.t / 0.22)
        local s = pop * (f.big and 1.25 or 1)
        local a = math.min(1, (1 - k) * 2)
        love.graphics.push()
        love.graphics.translate(cx, cy)
        love.graphics.scale(s, s)
        love.graphics.setColor(0, 0, 0, 0.75 * a)
        love.graphics.printf(f.txt, -58, -14, 120, "center")
        love.graphics.setColor(f.col[1], f.col[2], f.col[3], a)
        love.graphics.printf(f.txt, -60, -16, 120, "center")
        love.graphics.pop()
    end
    love.graphics.pop()
end

-- win cinematic (G.win set, phases "zoom"/"rewards"): impact flash,
-- shockwave rings off the hero, a popping CLEARED! title, sliding
-- letterbox bars — then the exact-rewards card (kills / coins / +maxHP).
-- Zoom phase shows a progress bar; rewards phase waits on NEXT.
-- Sets G.winNextBtn (screen-space rect) for the input hit-test.
function M.drawWin()
    local C = G.C
    local w = G.win
    if not w or w.phase == "upgrade" then G.winNextBtn = nil return end
    local tt = w.t or 0
    if w.phase == "zoom" then
        -- impact flash: warm bloom off the final kill, decaying fast
        local fa = 0.4 * math.max(0, 1 - tt / 0.7)
        if fa > 0.003 then
            love.graphics.setColor(1.0, 0.95, 0.80, fa)
            love.graphics.rectangle("fill", 0, 0, G.W, G.H)
        end
        -- shockwave rings expanding off the hero (gold, then green echo)
        local hero0 = G.units[1]
        if hero0 and hero0.map == G.map then
            local h0 = (G.heights[hero0.gy] and G.heights[hero0.gy][hero0.gx]) or 0
            local hx, hy = Board.tileToScreen(hero0.px, hero0.py, h0 * G.BLOCK_H)
            local e1 = math.min(1, tt / 1.1)
            if e1 > 0 and e1 < 1 then
                love.graphics.setColor(C.coin[1], C.coin[2], C.coin[3], (1 - e1) * 0.55)
                love.graphics.setLineWidth(4)
                love.graphics.circle("line", hx, hy, 30 + e1 * 300)
                love.graphics.setLineWidth(1)
            end
            local e2 = math.min(1, math.max(0, (tt - 0.3) / 1.1))
            if e2 > 0 and e2 < 1 then
                love.graphics.setColor(C.accent[1], C.accent[2], C.accent[3], (1 - e2) * 0.45)
                love.graphics.setLineWidth(2)
                love.graphics.circle("line", hx, hy, 20 + e2 * 220)
                love.graphics.setLineWidth(1)
            end
        end
        -- title pop: CLEARED! slams in over the push-in
        local ta = math.min(1, math.max(0, (tt - 0.25) / 0.35))
        if ta > 0 then
            local pop = 1 + 0.6 * math.max(0, 1 - (tt - 0.25) / 0.3)
            local rise = math.min(1, (tt - 0.25) / 0.6) * 12
            love.graphics.push()
            love.graphics.translate(G.W / 2, G.H * 0.22 - rise)
            love.graphics.scale(pop, pop)
            love.graphics.setFont(G.fontTitle)
            love.graphics.setColor(0, 0, 0, 0.75 * ta)
            love.graphics.printf("CLEARED!", -298, -14, 600, "center")
            love.graphics.setColor(C.coin[1], C.coin[2], C.coin[3], ta)
            love.graphics.printf("CLEARED!", -300, -16, 600, "center")
            love.graphics.pop()
        end
    end
    local fade = math.min(1, tt / 0.4 + (w.phase == "rewards" and 1 or 0))
    love.graphics.setColor(0, 0, 0, 0.35 * fade)
    love.graphics.rectangle("fill", 0, 0, G.W, G.H)
    local bw, bh = 380, 248
    local bx, by = (G.W - bw) / 2, G.H * 0.58
    love.graphics.setColor(C.panel[1], C.panel[2], C.panel[3], 0.95 * fade)
    love.graphics.rectangle("fill", bx, by, bw, bh, 8, 8)
    love.graphics.setColor(C.panelLn[1], C.panelLn[2], C.panelLn[3], fade)
    love.graphics.rectangle("line", bx, by, bw, bh, 8, 8)
    love.graphics.setFont(G.fontTitle)
    love.graphics.setColor(C.coin[1], C.coin[2], C.coin[3], fade)
    love.graphics.printf("LEVEL " .. (w.level or 1) .. " CLEARED", bx, by + 16, bw, "center")
    love.graphics.setFont(G.fontBody)
    love.graphics.setColor(C.ink[1], C.ink[2], C.ink[3], fade)
    local hero = G.units[1]
    love.graphics.printf((hero and hero.name:upper() or "HERO") .. "  ·  " ..
        (w.kills or 0) .. " KILLS", bx, by + 56, bw, "center")
    love.graphics.setFont(G.fontBody)
    love.graphics.setColor(C.coin[1], C.coin[2], C.coin[3], fade)
    love.graphics.printf("+" .. (w.coins or 0) .. " COINS  (purse " .. (G.coins or 0) .. "c)",
        bx, by + 84, bw, "center")
    love.graphics.setColor(C.floatHeal[1], C.floatHeal[2], C.floatHeal[3], fade)
    love.graphics.printf("+" .. (w.hp or 0) .. " MAX HP  ·  HP + MANA RESTORED",
        bx, by + 110, bw, "center")
    if w.phase == "rewards" then
        -- NEXT button into the upgrade screen
        local nb = { x = bx + 40, y = by + 148, w = bw - 80, h = 34 }
        G.winNextBtn = nb
        local mx, my = love.mouse.getPosition()
        local hot = mx >= nb.x and mx <= nb.x + nb.w and my >= nb.y and my <= nb.y + nb.h
        love.graphics.setColor(hot and C.select or C.panelLn)
        love.graphics.rectangle(hot and "fill" or "line", nb.x, nb.y, nb.w, nb.h, 4, 4)
        love.graphics.setColor(hot and C.panel or C.selInk)
        love.graphics.printf("NEXT → UPGRADES", nb.x, nb.y + 8, nb.w, "center")
        love.graphics.setFont(G.fontSmall)
        love.graphics.setColor(C.muted[1], C.muted[2], C.muted[3], fade)
        love.graphics.printf("SPACE / ENTER", bx, by + 192, bw, "center")
    else
        G.winNextBtn = nil
        -- progress through the zoom beat
        local k = math.min(1, (w.t or 0) / (w.dur or 1))
        love.graphics.setColor(C.barBg[1], C.barBg[2], C.barBg[3], fade)
        love.graphics.rectangle("fill", bx + 40, by + 148, bw - 80, 10, 5, 5)
        love.graphics.setColor(C.accent[1], C.accent[2], C.accent[3], fade)
        love.graphics.rectangle("fill", bx + 40, by + 148, (bw - 80) * k, 10, 5, 5)
        love.graphics.setFont(G.fontSmall)
        love.graphics.setColor(C.muted[1], C.muted[2], C.muted[3], fade)
        love.graphics.printf("…", bx, by + 168, bw, "center")
    end
    -- letterbox: cinema bars slide in with the zoom, hold behind the card
    local lb = 70 * math.min(1, tt / 0.5)
    if lb > 0.5 then
        love.graphics.setColor(0.02, 0.02, 0.03, 1)
        love.graphics.rectangle("fill", 0, 0, G.W, lb)
        love.graphics.rectangle("fill", 0, G.H - lb, G.W, lb)
    end
end

-- UPGRADE SCREEN (full screen, own backdrop — not a panel over the board).
-- Skeleton only: rows come from Units.upgradeDefs() (currently placeholders
-- awaiting your spec — no invented effects). Sets G.upgSlotBtns /
-- G.upgDescendBtn (screen-space rects) for the input hit-test.
function M.drawUpgrade(time)
    local C = G.C
    local w = G.win
    M.drawBackdrop(time or 0)
    local cx = G.W / 2
    love.graphics.setFont(G.fontTitle)
    love.graphics.setColor(C.ink)
    love.graphics.printf("UPGRADES", 0, G.H * 0.10, G.W, "center")
    love.graphics.setFont(G.fontSmall)
    love.graphics.setColor(C.muted)
    love.graphics.printf("LEVEL " .. ((w and w.level) or G.runLevel) .. " CLEARED — SPEND YOUR COINS",
        0, G.H * 0.10 + 40, G.W, "center")
    love.graphics.setColor(C.select)
    love.graphics.rectangle("fill", cx - 21, G.H * 0.10 + 62, 42, 3)

    -- purse + hero strip
    local hero = G.units[1]
    love.graphics.setFont(G.fontBody)
    love.graphics.setColor(C.coin)
    love.graphics.printf("PURSE: " .. (G.coins or 0) .. "c", cx - 300, G.H * 0.24, 600, "center")
    if hero then
        love.graphics.setFont(G.fontSmall)
        love.graphics.setColor(C.muted)
        love.graphics.printf(hero.name:upper() .. "  ·  HP " .. (hero.hp or 0) .. "/" ..
            (hero.maxHP or 0) .. "  ·  MP " .. (hero.mana or 0) .. "/" .. (hero.maxMana or 0),
            cx - 300, G.H * 0.24 + 24, 600, "center")
    end

    -- upgrade rows (skeleton slots — real upgrades to be specified)
    local defs = Units.upgradeDefs and Units.upgradeDefs() or {}
    if #defs == 0 then
        love.graphics.setFont(G.fontBody)
        love.graphics.setColor(C.muted)
        love.graphics.printf("UPGRADE SLOTS EMPTY — TELL ME WHAT TO ADD", cx - 300, G.H * 0.36, 600, "center")
    end
    G.upgSlotBtns = {}
    local mx, my = love.mouse.getPosition()
    local y0 = G.H * 0.42
    for i = 1, math.max(3, #defs) do
        local def = defs[i]
        local ry = y0 + (i - 1) * 76
        local rw, rh = 520, 64
        local rx = cx - rw / 2
        love.graphics.setColor(C.panel)
        love.graphics.rectangle("fill", rx, ry, rw, rh, 6, 6)
        love.graphics.setColor(C.panelLn)
        love.graphics.rectangle("line", rx, ry, rw, rh, 6, 6)
        love.graphics.setFont(G.fontHead)
        love.graphics.setColor(C.accent)
        love.graphics.print(def and def.name or ("SLOT " .. i), rx + 14, ry + 8)
        love.graphics.setFont(G.fontSmall)
        love.graphics.setColor(C.muted)
        love.graphics.print(def and def.desc or "awaiting spec — locked", rx + 14, ry + 30)
        local bb = { x = rx + rw - 150, y = ry + 17, w = 136, h = 30 }
        G.upgSlotBtns[i] = bb
        local locked = (not def) or (def.cost and (G.coins or 0) < def.cost)
        local hot = mx >= bb.x and mx <= bb.x + bb.w and my >= bb.y and my <= bb.y + bb.h
        if locked then
            love.graphics.setColor(C.muted)
            love.graphics.rectangle("line", bb.x, bb.y, bb.w, bb.h, 4, 4)
            love.graphics.setColor(C.muted)
        else
            love.graphics.setColor(hot and C.select or C.panelLn)
            love.graphics.rectangle(hot and "fill" or "line", bb.x, bb.y, bb.w, bb.h, 4, 4)
            love.graphics.setColor(hot and C.panel or C.selInk)
        end
        love.graphics.printf(def and ("BUY " .. (def.cost or 0) .. "c") or "LOCKED",
            bb.x, bb.y + 7, bb.w, "center")
    end

    -- descend into the next grid
    local db = { x = cx - 170, y = y0 + 3 * 76 + 16, w = 340, h = 38 }
    G.upgDescendBtn = db
    local hot = mx >= db.x and mx <= db.x + db.w and my >= db.y and my <= db.y + db.h
    love.graphics.setColor(hot and C.select or C.panelLn)
    love.graphics.rectangle(hot and "fill" or "line", db.x, db.y, db.w, db.h, 4, 4)
    love.graphics.setColor(hot and C.panel or C.selInk)
    love.graphics.setFont(G.fontBody)
    love.graphics.printf("DESCEND → LEVEL " .. (((w and w.level) or G.runLevel) + 1),
        db.x, db.y + 9, db.w, "center")
end

-- game-over overlay (G.state == "over"): board stays visible behind.
function M.drawGameOver()
    local C = G.C
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", 0, 0, G.W, G.H)
    local bw, bh = 380, 150
    local bx, by = (G.W - bw) / 2, (G.H - bh) / 2
    love.graphics.setColor(C.panel)
    love.graphics.rectangle("fill", bx, by, bw, bh, 8, 8)
    love.graphics.setColor(C.panelLn)
    love.graphics.rectangle("line", bx, by, bw, bh, 8, 8)
    love.graphics.setFont(G.fontTitle)
    love.graphics.setColor(C.floatDmg)
    love.graphics.printf("PARTY WIPED", bx, by + 20, bw, "center")
    love.graphics.setFont(G.fontBody)
    love.graphics.setColor(C.ink)
    love.graphics.printf("ROUND " .. (G.round or 1) .. "  —  LEVEL " .. G.runLevel, bx, by + 62, bw, "center")
    love.graphics.setFont(G.fontSmall)
    love.graphics.setColor(C.muted)
    love.graphics.printf("CLICK anywhere to return to menu", bx, by + 100, bw, "center")
end

return M

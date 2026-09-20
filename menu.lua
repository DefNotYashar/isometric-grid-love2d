-- menu.lua — menu screens + run/flow transitions.
-- Deps: state (G), board, units, render (backdrop only).
local G = require("state")
local Board = require("board")
local Units = require("units")
local Render = require("render")
local M = {}
local Knight = require("assets.units.knight")

function M.items()
    if G.menuScreen == "main" then return { "START", "SETTINGS", "EXIT" }
    elseif G.menuScreen == "modes" then return {
        "START RUN", "FREE PLAY — move & explore", "BACK" }
    elseif G.menuScreen == "select" then
        local items = {}
        for _, def in ipairs(G.roster) do items[#items + 1] = def.name:upper() end
        items[#items + 1] = "BACK"
        return items
    elseif G.menuScreen == "path_choice" then
        return { "NORMAL PATH", "ELITE PATH", "BACK" }
    else return { M.volumeLabel(), "BACK" } end
end

-- settings: music volume 0..10, shown as a text bar (ASCII-safe).
function M.volumeLabel()
    local v = math.max(0, math.min(10, G.volume or 8))
    return "VOLUME: [" .. string.rep("#", v) .. string.rep("-", 10 - v)
        .. "] " .. (v * 10) .. "%"
end

function M.adjustVolume(d, wrap)
    local v = math.max(0, math.min(10, G.volume or 8)) + d
    if wrap then v = v % 11 end
    G.volume = math.max(0, math.min(10, v))
end

function M.draw(time)
    local C = G.C
    -- full-screen menu: own backdrop, no board behind
    Render.drawBackdrop(time)
    -- shop phase
    if G.phase == "shop" then
        M.drawShop(time)
        return
    end
    -- big title left, menu right
    local cx = G.W / 2
    love.graphics.setFont(G.fontTitle)
    love.graphics.setColor(C.ink)
    love.graphics.printf("ISOMETRIC GRID LAB", 0, G.H * 0.22, G.W, "center")
    love.graphics.setFont(G.fontSmall)
    love.graphics.setColor(C.muted)
    local sub
    if G.menuScreen == "modes" then sub = "CHOOSE HOW TO PLAY"
    elseif G.menuScreen == "select" then
        sub = "CHOOSE YOUR PAWN"
    elseif G.menuScreen == "path_choice" then
        sub = "CHOOSE YOUR PATH"
    elseif G.menuScreen == "settings" then sub = "SETTINGS"
    else sub = "10 x 10 BLOCK FIELD" end
    love.graphics.printf(sub, 0, G.H * 0.22 + 40, G.W, "center")
    love.graphics.setColor(C.select)
    love.graphics.rectangle("fill", cx - 21, G.H * 0.22 + 62, 42, 3)

    if G.menuScreen == "select" then
        M.drawSelect(time)
        return
    end
    if G.menuScreen == "path_choice" then
        M.drawPathChoice(time)
        return
    end
    local items = M.items()
    love.graphics.setFont(G.fontBody)
    local startY = G.H * 0.42
    for i, label in ipairs(items) do
        local sel = (i == G.menuIdx)
        local iy = startY + (i - 1) * 48
        if sel then
            love.graphics.setColor(C.select[1], C.select[2], C.select[3], 0.22)
            love.graphics.rectangle("fill", cx - 170, iy - 8, 340, 36, 6, 6)
        end
        if G.menuScreen == "select" and G.roster[i] then
            love.graphics.setColor(G.roster[i].color)
            love.graphics.circle("fill", cx - 130, iy + 10, 10)
            love.graphics.setColor(G.roster[i].dark)
            love.graphics.circle("line", cx - 130, iy + 10, 10)
        end
        love.graphics.setColor(sel and C.selInk or C.muted)
        love.graphics.printf((sel and "> " or "") .. label, cx - 170, iy, 340, "center")
    end
    love.graphics.setFont(G.fontSmall)
    love.graphics.setColor(C.muted)
    love.graphics.printf("UP/DOWN + ENTER  /  CLICK  /  ESC", 0, G.H - 60, G.W, "center")
    if G.menuScreen == "main" then
        love.graphics.printf("MODE: " .. G.gameMode:upper(), 0, G.H - 40, G.W, "center")
    end
end

-- ---------- pawn select carousel ----------
-- Circular pool: left/right wraps around the roster with a slide
-- animation (driven by wall time passed into draw). Hit rects for the
-- arrows / confirm / back are set here for the input layer.
M.selPrev, M.selDir, M.selT0 = nil, 1, -9
M.selLeft, M.selRight, M.selConfirm, M.selBack = nil, nil, nil, nil

local function withAlpha(c, a) return { c[1], c[2], c[3], (c[4] or 1) * a } end

-- full-body bust (shadow + legs + arms + torso + head). Clipped by stencil to medallion.
local function drawBust(def, x, feetY, s, alpha)
    local col, dark = withAlpha(def.color, alpha), withAlpha(def.dark, alpha)
    love.graphics.setColor(0, 0, 0, 0.30 * alpha)
    love.graphics.ellipse("fill", x, feetY, 11 * s, 4.5 * s)
    -- legs
    love.graphics.setColor(dark)
    love.graphics.ellipse("fill", x - 3 * s, feetY - 3 * s, 3 * s, 1.8 * s)
    love.graphics.ellipse("fill", x + 3 * s, feetY - 3 * s, 3 * s, 1.8 * s)
    love.graphics.setColor(col)
    love.graphics.rectangle("fill", x - 5 * s, feetY - 12 * s, 3.4 * s, 9 * s, 1 * s, 1 * s)
    love.graphics.rectangle("fill", x + 1.6 * s, feetY - 12 * s, 3.4 * s, 9 * s, 1 * s, 1 * s)
    -- arms with hands
    love.graphics.setColor(dark)
    love.graphics.rectangle("fill", x - 11 * s, feetY - 24 * s, 2.8 * s, 10 * s, 1 * s, 1 * s)
    love.graphics.rectangle("fill", x + 8.2 * s, feetY - 24 * s, 2.8 * s, 10 * s, 1 * s, 1 * s)
    love.graphics.circle("fill", x - 9.5 * s, feetY - 14 * s, 2 * s)
    love.graphics.circle("fill", x + 9.5 * s, feetY - 14 * s, 2 * s)
    love.graphics.setColor(dark)
    love.graphics.polygon("fill", { x - 9 * s, feetY - 12 * s, x - 5 * s, feetY - 26 * s,
                                    x + 5 * s, feetY - 26 * s, x + 9 * s, feetY - 12 * s })
    love.graphics.setColor(col)
    love.graphics.polygon("fill", { x - 5 * s, feetY - 12 * s, x - 2 * s, feetY - 26 * s,
                                    x + 2 * s, feetY - 26 * s, x + 5 * s, feetY - 12 * s })
    love.graphics.setColor(dark)
    love.graphics.ellipse("fill", x, feetY - 26 * s, 5.5 * s, 2.2 * s)
    love.graphics.setColor(col)
    love.graphics.circle("fill", x, feetY - 34 * s, 8 * s)
    love.graphics.setColor(1, 1, 1, 0.5 * alpha)
    love.graphics.setLineWidth(1.6 * s)
    love.graphics.arc("line", "open", x, feetY - 34 * s, 8 * s, -0.9, 0.7)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 0.55 * alpha)
    love.graphics.circle("fill", x - 2 * s, feetY - 36 * s, 1.8 * s)
end

function M.switchSelect(d)
    local n = #G.roster
    if n == 0 then return end
    local old = G.menuIdx
    local new = ((old - 1 + d) % n) + 1
    if new == old then return end
    M.selPrev, M.selDir, M.selT0 = old, d, love.timer.getTime()
    G.menuIdx = new
end

function M.confirmSelect()
    if G.menuIdx <= #G.roster then M.startRun(G.menuIdx) end
end

function M.clickSelect(x, y)
    local function hit(r) return r and x >= r.x and x <= r.x + r.w
        and y >= r.y and y <= r.y + r.h end
    if hit(M.selLeft) then M.switchSelect(-1)
    elseif hit(M.selRight) then M.switchSelect(1)
    elseif hit(M.selConfirm) then M.confirmSelect()
    elseif hit(M.selBack) then G.menuScreen, G.menuIdx = "modes", 1 end
end

function M.clickPathChoice(x, y)
    local function hit(r) return r and x >= r.x and x <= r.x + r.w
        and y >= r.y and y <= r.y + r.h end
    if M.pathChoiceBtns then
        for _, btn in ipairs(M.pathChoiceBtns) do
            if hit(btn) then
                M.confirmPathChoice(btn.type)
                return
            end
        end
    end
    if hit(M.pathChoiceBack) then
        G.menuScreen, G.menuIdx = "main", 1
    end
end

function M.confirmPathChoice(pathType)
    G.runPathChoice = pathType -- "normal" or "elite"
    G.menuScreen = "game" -- will be handled by nextLevel
    -- Continue to next level with chosen path
    M.nextLevel()
end

function M.drawSelect(time)
    local C = G.C
    local cx = G.W / 2
    local n = #G.roster
    local def = G.roster[G.menuIdx]
    if not def then return end

    -- circle pool: selected always center large, others on receding ring behind
    local k = math.min(1, math.max(0, (time - M.selT0) / 0.34))
    local e = 1 - (1 - k) * (1 - k) * (1 - k)
    local my = G.H * 0.40
    local BIG_R, BIG_S = 110, 4.0
    local SMALL_R, SMALL_S = 62, 1.85
    local ring_rx, ring_ry = 220, 68  -- ellipse radius for background chars

    -- compute old selected position during transition
    local oldDef = (k < 1 and M.selPrev) and G.roster[M.selPrev] or nil
    local oldAng = 0
    if oldDef then
        oldAng = M.selDir * (1 - e) * (2 * math.pi / n)
    end

    -- collect non-selected characters on the ring (sorted back->front)
    local ringItems = {}
    for i = 1, n do
        if i ~= G.menuIdx then
            local ang = (i - G.menuIdx) * (2 * math.pi / n) + oldAng
            local ca, sa = math.cos(ang), math.sin(ang)
            local px = cx + ca * ring_rx
            local py = my + sa * ring_ry * 0.6
            local depth = 0.5 + 0.5 * sa  -- 0..1 (front = 1)
            local R = SMALL_R
            local scale = SMALL_S
            local a = 0.26 + 0.30 * depth
            table.insert(ringItems, { idx = i, def = G.roster[i], px = px, py = py, depth = depth, R = R, scale = scale, a = a })
        end
    end
    table.sort(ringItems, function(a, b) return a.depth < b.depth end)

    -- draw background ring items (back to front)
    for _, it in ipairs(ringItems) do
        local R = it.R
        local scale = it.scale
        local a = it.a
        -- pedestal oval
        love.graphics.setColor(0, 0, 0, 0.12 * a)
        love.graphics.ellipse("fill", it.px, it.py + R * 0.85, R * 0.85, R * 0.24)
        -- medallion
        love.graphics.setColor(withAlpha(it.def.color, 0.38 * a))
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", it.px, it.py, R + 2)
        love.graphics.setColor(withAlpha(C.ring, a))
        love.graphics.setLineWidth(1)
        love.graphics.circle("line", it.px, it.py, R)
        love.graphics.setColor(withAlpha(C.barBg, a))
        love.graphics.circle("fill", it.px, it.py, R - 2)
        love.graphics.setLineWidth(1)
        -- stencil clip
        love.graphics.stencil(function() love.graphics.circle("fill", it.px, it.py, R - 2) end, "replace", 1)
        love.graphics.setStencilTest("greater", 0)
        local feetY = it.py + 32
        if it.def.kind == "knight" then
            Knight.drawBust(it.px, feetY, it.def.color, it.def.dark, scale)
        else
            drawBust(it.def, it.px, feetY, scale, a)
        end
        love.graphics.setStencilTest()
    end

    -- draw old selected sliding out (if transitioning)
    if oldDef then
        local ca = math.cos(oldAng)
        local sa = math.sin(oldAng)
        local outPx = cx + ca * ring_rx
        local outPy = my + sa * ring_ry * 0.6
        local outR = SMALL_R
        local outScale = SMALL_S
        local outA = 1 - e
        local outDepth = 0.35 + 0.35 * sa
        love.graphics.setColor(0, 0, 0, 0.12 * outA)
        love.graphics.ellipse("fill", outPx, outPy + outR * 0.85, outR * 0.85, outR * 0.24)
        love.graphics.setColor(withAlpha(oldDef.color, 0.38 * outA))
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", outPx, outPy, outR + 2)
        love.graphics.setColor(withAlpha(C.ring, outA))
        love.graphics.setLineWidth(1)
        love.graphics.circle("line", outPx, outPy, outR)
        love.graphics.setColor(withAlpha(C.barBg, outA))
        love.graphics.circle("fill", outPx, outPy, outR - 2)
        love.graphics.setLineWidth(1)
        love.graphics.stencil(function() love.graphics.circle("fill", outPx, outPy, outR - 2) end, "replace", 1)
        love.graphics.setStencilTest("greater", 0)
        local feetY = outPy + 32
        if oldDef.kind == "knight" then
            Knight.drawBust(outPx, feetY, oldDef.color, oldDef.dark, outScale)
        else
            drawBust(oldDef, outPx, feetY, outScale, outA)
        end
        love.graphics.setStencilTest()
    end

    -- selected character always centered, drawn last
    do
        local R = BIG_R
        local scale = BIG_S
        local a = 1
        love.graphics.setColor(0, 0, 0, 0.22 * a)
        love.graphics.ellipse("fill", cx, my + R * 0.85, R * 0.95, R * 0.28)
        love.graphics.setColor(withAlpha(def.color, 0.48 * a))
        love.graphics.setLineWidth(6)
        love.graphics.circle("line", cx, my, R + 3)
        love.graphics.setColor(C.ring)
        love.graphics.setLineWidth(4)
        love.graphics.circle("line", cx, my, R)
        love.graphics.setColor(C.barBg)
        love.graphics.circle("fill", cx, my, R - 3)
        love.graphics.setLineWidth(1)
        love.graphics.setColor(def.color[1], def.color[2], def.color[3], 0.16)
        love.graphics.circle("fill", cx, my, R + 12)
        love.graphics.stencil(function() love.graphics.circle("fill", cx, my, R - 3) end, "replace", 1)
        love.graphics.setStencilTest("greater", 0)
        local feetY = my + 72
        if def.kind == "knight" then
            Knight.drawBust(cx, feetY, def.color, def.dark, scale)
        else
            drawBust(def, cx, feetY, scale, a)
        end
        love.graphics.setStencilTest()
        love.graphics.setColor(C.select[1], C.select[2], C.select[3], 0.95)
        love.graphics.circle("fill", cx, my + R + 16, 3)
    end

    -- arrows
    local mx, myy = love.mouse.getPosition()
    love.graphics.setFont(G.fontTitle)
    local function arrow(r, label)
        local hot = r and mx >= r.x and mx <= r.x + r.w and myy >= r.y and myy <= r.y + r.h
        love.graphics.setColor(hot and C.select or C.muted)
        love.graphics.printf(label, r.x, r.y, r.w, "center")
    end
    M.selLeft = { x = cx - 220, y = my - 28, w = 56, h = 56 }
    M.selRight = { x = cx + 164, y = my - 28, w = 56, h = 56 }
    arrow(M.selLeft, "◀")
    arrow(M.selRight, "▶")
    -- name + pool position + dots
    love.graphics.setFont(G.fontTitle)
    love.graphics.setColor(C.selInk)
    love.graphics.printf(def.name:upper(), cx - 200, my + 92, 400, "center")
    love.graphics.setFont(G.fontSmall)
    love.graphics.setColor(C.muted)
    love.graphics.printf(G.menuIdx .. " / " .. n, cx - 200, my + 126, 400, "center")
    for i = 1, n do
        local dx = cx + (i - (n + 1) / 2) * 22
        if i == G.menuIdx then
            love.graphics.setColor(C.select)
            love.graphics.circle("fill", dx, my + 152, 5)
        else
            love.graphics.setColor(C.muted)
            love.graphics.circle("line", dx, my + 152, 4)
        end
    end
    -- derived line + stat cells
    local st = def.stats or {}
    love.graphics.setFont(G.fontBody)
    love.graphics.setColor(C.ink)
    love.graphics.printf("HP " .. ((st.vigor or 0) * 4) .. "  ·  MP " .. ((st.charisma or 0) * 3) ..
        "  ·  RNG " .. tostring(st.speed or 0), cx - 200, my + 168, 400, "center")
    local function cell(x, y, label, val)
        love.graphics.setColor(C.panel)
        love.graphics.rectangle("fill", x, y, 76, 42, 4, 4)
        love.graphics.setColor(C.panelLn)
        love.graphics.rectangle("line", x, y, 76, 42, 4, 4)
        love.graphics.setFont(G.fontSmall)
        love.graphics.setColor(C.muted)
        love.graphics.print(label, x + 8, y + 4)
        love.graphics.setFont(G.fontBody)
        love.graphics.setColor(C.ink)
        love.graphics.print(tostring(val or 0), x + 8, y + 19)
    end
    local sy = my + 196
    local labels = { "VIG", "STR", "DEX", "LCK", "SPD", "CHA" }
    local vals = { st.vigor, st.strength, st.dexterity, st.luck, st.speed, st.charisma }
    for i = 1, 6 do
        local col3, row2 = (i - 1) % 3, math.floor((i - 1) / 3)
        cell(cx - 122 + col3 * 84, sy + row2 * 50, labels[i], vals[i])
    end
    -- confirm + back
    local byy = sy + 112
    M.selConfirm = { x = cx - 110, y = byy, w = 220, h = 40 }
    local hot = mx >= M.selConfirm.x and mx <= M.selConfirm.x + M.selConfirm.w
        and myy >= M.selConfirm.y and myy <= M.selConfirm.y + M.selConfirm.h
    love.graphics.setColor(hot and C.select or C.panelLn)
    love.graphics.rectangle(hot and "fill" or "line",
        M.selConfirm.x, M.selConfirm.y, M.selConfirm.w, M.selConfirm.h, 4, 4)
    love.graphics.setColor(hot and C.panel or C.selInk)
    love.graphics.setFont(G.fontBody)
    love.graphics.printf("START RUN", M.selConfirm.x, M.selConfirm.y + 10, M.selConfirm.w, "center")
    M.selBack = { x = cx - 60, y = byy + 50, w = 120, h = 26 }
    love.graphics.setFont(G.fontSmall)
    love.graphics.setColor(C.muted)
    love.graphics.printf("‹ BACK", M.selBack.x, M.selBack.y + 5, M.selBack.w, "center")
    love.graphics.setFont(G.fontSmall)
    love.graphics.setColor(C.muted)
    love.graphics.printf("◀ ▶ / CLICK — SWITCH   ENTER — CONFIRM   ESC — BACK",
        0, G.H - 60, G.W, "center")
end

-- Path choice screen: after level 2, choose Normal or Elite for level 3
function M.drawPathChoice(time)
    local C = G.C
    local cx = G.W / 2
    local my = G.H * 0.40

    -- Description
    love.graphics.setFont(G.fontBody)
    love.graphics.setColor(C.ink)
    love.graphics.printf("You have cleared 2 levels.", cx - 300, my - 60, 600, "center")
    love.graphics.setFont(G.fontSmall)
    love.graphics.setColor(C.muted)
    love.graphics.printf("Choose the difficulty for Level 3:", cx - 300, my - 20, 600, "center")
    love.graphics.setColor(C.accent)
    love.graphics.printf("Level 4 follows your choice. Level 5 is always a BOSS.", cx - 300, my + 10, 600, "center")

    -- Options with descriptions
    local options = {
        { label = "NORMAL PATH", desc = "Standard enemies, varied terrain", color = C.accent },
        { label = "ELITE PATH", desc = "Tougher enemies, complex maps", color = C.floatDmg },
    }

    local optY = my + 50
    local optGap = 80
    M.pathChoiceBtns = {}
    M.pathChoiceDesc = {}

    for i, opt in ipairs(options) do
        local iy = optY + (i - 1) * optGap
        local sel = (i == G.menuIdx)
        local iw, ih = 400, 56
        local ix = cx - iw / 2

        -- Background
        love.graphics.setColor(sel and {opt.color[1], opt.color[2], opt.color[3], 0.18} or C.panel)
        love.graphics.rectangle("fill", ix, iy, iw, ih, 8, 8)
        love.graphics.setColor(sel and opt.color or C.panelLn)
        love.graphics.rectangle("line", ix, iy, iw, ih, 8, 8)

        -- Label
        love.graphics.setFont(G.fontBody)
        love.graphics.setColor(sel and C.selInk or C.ink)
        love.graphics.printf(opt.label, ix, iy + 8, iw, "center")

        -- Description
        love.graphics.setFont(G.fontSmall)
        love.graphics.setColor(C.muted)
        love.graphics.printf(opt.desc, ix + 20, iy + 30, iw - 40, "center")

        -- Store button rect for click handling
        M.pathChoiceBtns[i] = { x = ix, y = iy, w = iw, h = ih, type = i == 1 and "normal" or "elite" }
    end

    -- Back button
    local by = optY + #options * optGap + 20
    M.pathChoiceBack = { x = cx - 60, y = by, w = 120, h = 30 }
    local mx, myy = love.mouse.getPosition()
    local hot = mx >= M.pathChoiceBack.x and mx <= M.pathChoiceBack.x + M.pathChoiceBack.w
        and myy >= M.pathChoiceBack.y and myy <= M.pathChoiceBack.y + M.pathChoiceBack.h
    love.graphics.setColor(hot and C.select or C.muted)
    love.graphics.rectangle(hot and "fill" or "line", M.pathChoiceBack.x, M.pathChoiceBack.y, M.pathChoiceBack.w, M.pathChoiceBack.h, 4, 4)
    love.graphics.setColor(hot and C.panel or C.selInk)
    love.graphics.setFont(G.fontBody)
    love.graphics.printf("BACK", M.pathChoiceBack.x, M.pathChoiceBack.y + 6, M.pathChoiceBack.w, "center")

    -- Hint
    love.graphics.setFont(G.fontSmall)
    love.graphics.setColor(C.muted)
    love.graphics.printf("UP/DOWN + ENTER  /  CLICK  /  ESC", 0, G.H - 60, G.W, "center")
end

function M.hit(x, y)
    local items = M.items()
    local cx = G.W / 2
    local startY = G.H * 0.42
    for i = 1, #items do
        local iy = startY + (i - 1) * 48
        if x >= cx - 170 and x <= cx + 170 and y >= iy - 8 and y <= iy + 28 then
            return i
        end
    end
    return nil
end

function M.startRun(idx)
    G.gameMode = "run"
    G.runLevel = 1

    -- Load first level from forest/normal pool
    local LevelSelector = require("systems.level_selector")
    local LevelLoader = require("systems.level_loader")
    local EncounterSelector = require("systems.encounter_selector")
    local EncounterLoader = require("systems.encounter_loader")
    local Board = require("board")
    local Units = require("units")

    local levelId = LevelSelector.select("forest", "normal")
    local level = LevelLoader.load("forest", "normal", levelId)
    Board.loadLevel(level)

    local encounterId = EncounterSelector.select("forest", "normal")
    local encounter = EncounterLoader.load("forest", "normal", encounterId)

    -- fixed zoomed-in framing: big boards pull back, standard sits close
    if (G.GRID or 10) >= 15 then G.zoom, G.zoomTarget = 1.5, 1.5
    else G.zoom, G.zoomTarget = 2.1, 2.1 end
    G.camX, G.camY = 0, 0

    -- Spawn player at first player spawn
    local playerSpawn = G.playerSpawns[1]
    G.units = { Units.spawnUnit(G.roster[idx]) }
    G.units[1].gx, G.units[1].gy = playerSpawn.x, playerSpawn.y
    G.units[1].px, G.units[1].py = playerSpawn.x, playerSpawn.y
    G.units[1].fx, G.units[1].fy = playerSpawn.x, playerSpawn.y
    G.activeIdx = 1
    G.round, G.wiped = 1, false
    G.coins, G.levelKills, G.levelCoins, G.levelHp, G.win = 0, 0, 0, 0, nil

    -- Spawn enemies from encounter
    Units.spawnEncounterEnemies(encounter)
    Units.buildTurnOrder()
    local a = Units.active()
    if a and a.team == "enemy" then Units.enemyTurn(a) end
    G.state = "game"
    G.pushLog("run started — " .. G.units[1].name .. " / " .. levelId .. " + " .. encounterId)
end

function M.nextLevel()
    local LevelSelector = require("systems.level_selector")
    local LevelLoader = require("systems.level_loader")
    local EncounterSelector = require("systems.encounter_selector")
    local EncounterLoader = require("systems.encounter_loader")
    local Board = require("board")
    local Units = require("units")

    G.runLevel = G.runLevel + 1

    -- Determine level type based on runLevel and path choice
    local levelType = "normal"
    local encounterType = "normal"

    if G.runLevel == 3 then
        -- After level 2, show path choice
        if not G.runPathChoice then
            G.menuScreen = "path_choice"
            G.menuIdx = 1
            G.state = "menu"
            G.win = nil
            G.pushLog("Choose your path for Level 3...")
            return
        end
        levelType = G.runPathChoice
        encounterType = G.runPathChoice
    elseif G.runLevel == 4 then
        -- Level 4 uses the same path choice
        levelType = G.runPathChoice or "normal"
        encounterType = G.runPathChoice or "normal"
    elseif G.runLevel >= 5 then
        -- Level 5+ always boss
        levelType = "boss"
        encounterType = "boss"
    end

    local levelId = LevelSelector.select("forest", levelType)
    local level = LevelLoader.load("forest", levelType, levelId)
    Board.loadLevel(level)

    local encounterId = EncounterSelector.select("forest", encounterType)
    local encounter = EncounterLoader.load("forest", encounterType, encounterId)

    -- fresh framing for the new grid (transition zoomed in close)
    if (G.GRID or 10) >= 15 then G.zoom, G.zoomTarget = 1.5, 1.5
    else G.zoom, G.zoomTarget = 2.1, 2.1 end
    G.camX, G.camY = 0, 0
    G.win = nil
    G.winNextBtn, G.upgDescendBtn, G.upgSlotBtns = nil, nil, nil
    G.arrows = {}
    Units.clearEnemies()
    local u = G.units[1]
    u.map = "over"
    local playerSpawn = G.playerSpawns[1]
    u.gx, u.gy = playerSpawn.x, playerSpawn.y
    u.px, u.py, u.fx, u.fy = u.gx, u.gy, u.gx, u.gy
    u.path, u.t = {}, 0
    u.moved, u.attacked, u.acted = false, false, false
    u.hp, u.mana = u.maxHP, u.maxMana -- descend fully restores the party
    G.round = 1
    G.levelKills, G.levelCoins, G.levelHp = 0, 0, 0
    Units.spawnEncounterEnemies(encounter)
    Units.buildTurnOrder()
    G.pushLog("LEVEL " .. G.runLevel .. " — " .. levelId .. " + " .. encounterId .. " — party restored")
end

-- Win flow: "zoom" (slow cinematic push onto the hero: impact flash,
-- shockwave rings, letterbox, ~2.6 s) → "rewards" (card waits for NEXT
-- click) → "upgrade" (full screen, skeleton rows) → nextLevel() on DESCEND.
-- Input locks while G.win is set.
M.WIN_DUR = 2.6

function M.beginWin()
    if G.win then return end
    Units.grantRoundReward()
    local hero = G.units[1]
    G.win = { t = 0, dur = M.WIN_DUR, phase = "zoom", level = G.runLevel,
        hero = hero and hero.id or nil,
        kills = G.levelKills or 0, coins = G.levelCoins or 0, hp = G.levelHp or 0 }
    G.castMode = false
    G.pushLog("LEVEL " .. G.runLevel .. " CLEARED — +" .. (G.levelCoins or 0) .. "c!")
end

-- Rewards card NEXT → full upgrade screen (stays until DESCEND).
function M.toUpgrade()
    if G.win and G.win.phase == "rewards" then
        G.win.phase = "upgrade"
        G.winNextBtn = nil
    end
end

function M.updateWin(dt)
    local w = G.win
    if not w or w.phase == "upgrade" then return end
    if w.phase == "rewards" then
        -- hold the close-up framing behind the card; no auto-advance.
        local Camera = require("camera")
        Camera.clampCamera()
        return
    end
    w.t = w.t + dt
    -- camera: slow cinematic push onto the hero with a gentle orbital
    -- drift so the frame feels alive while it closes in.
    local base = (G.GRID >= 15) and 1.5 or 2.1
    local goal = math.min(G.MAX_ZOOM, base + 0.85)
    local k = math.min(1, w.t / w.dur)
    local e -- easeInOutCubic: slow ends, flowing middle
    if k < 0.5 then e = 4 * k * k * k
    else local p = 2 * k - 2 e = 1 + p * p * p / 2 end
    G.zoom = base + (goal - base) * e
    G.zoomTarget = G.zoom
    local hero = G.units[1]
    if hero and hero.map == G.map then
        local hgt = (G.heights[hero.gy] and G.heights[hero.gy][hero.gx]) or 0
        local hx, hy = Board.tileToScreen(hero.px, hero.py, hgt * G.BLOCK_H)
        local ang = w.t * 1.4
        local tx, ty = G.W / 2 + math.cos(ang) * 26 * e, G.H * 0.42 + math.sin(ang) * 14 * e
        local f = math.min(1, dt * 2.5)
        G.camX, G.camY = G.camX + (tx - hx) * f, G.camY + (ty - hy) * f
    end
    local Camera = require("camera")
    Camera.clampCamera()
    if w.t >= w.dur then w.phase, G.winNextBtn = "rewards", nil end
end

function M.checkClear()
    -- win = clear all enemies -> zoom -> rewards -> upgrade -> shop -> next level
    if G.state ~= "game" or G.gameMode ~= "run" then return end
    if G.win then return end
    for _, e in ipairs(G.units) do
        if e.team == "enemy" and e.hp > 0 then return end
    end
    M.beginWin()
end

function M.checkFinish(u)
    M.checkClear()
end

-- ---------- shop phase (between rounds) ----------
local Gnome = require("assets.units.gnome")

function M.enterShop()
    G.phase = "shop"
    -- create shop room layout (8x8 timber room with rug)
    local n = 8
    G.heights, G.terrain, G.blocked = {}, {}, {}
    for y = 1, n do
        G.heights[y] = {}
        G.terrain[y] = {}
        for x = 1, n do G.heights[y][x] = 0; G.terrain[y][x] = "shopfloor" end
    end
    for x = 1, n do
        for _, y in ipairs({1, n}) do
            G.terrain[y][x] = "shopwall"; G.heights[y][x] = 1; G.blocked[y * 100 + x] = true
        end
    end
    for y = 1, n do
        for _, x in ipairs({1, n}) do
            G.terrain[y][x] = "shopwall"; G.heights[y][x] = 1; G.blocked[y * 100 + x] = true
        end
    end
    G.terrain[n][4] = "shopdoor"
    G.heights[n][4] = 0
    G.blocked[n * 100 + 4] = nil
    G.GRID = n
    G.map = "shop"
    -- spawn shopkeeper at counter (tile 4,2)
    G.shop.keeper = Units.spawnUnit({
        id = "shopkeep", name = "GRIZZLE", gx = 4, gy = 2,
        color = {0.85, 0.65, 0.18}, dark = {0.55, 0.40, 0.10},
        kind = "shopkeep", team = "neutral", stats = {vigor=5,strength=3,dexterity=2,luck=3,speed=2,charisma=4}
    })
    G.shop.keeper.px, G.shop.keeper.py = 4, 2
    G.shop.keeper.fx, G.shop.keeper.fy = 4, 2
    G.shop.keeper.map = "shop"
    -- place hero at entrance (tile 4,7)
    local hero = G.units[1]
    hero.gx, hero.gy = 4, 7
    hero.px, hero.py = 4, 7
    hero.fx, hero.fy = 4, 7
    hero.map = "shop"
    hero.path, hero.t = {}, 0
    hero.moved, hero.attacked, hero.acted = false, false, false
    hero.hp, hero.mana = hero.maxHP, hero.maxMana -- shop restores fully
    -- camera framing
    G.zoom, G.zoomTarget = 2.1, 2.1
    G.camX, G.camY = 0, 0
    G.shop.items = {}
    G.shop.leaveBtn = nil
    G.pushLog("Welcome to Grizzle's Emporium!")
end

function M.leaveShop()
    G.phase = "play"
    M.nextLevel()
end

function M.drawShop(time)
    local C = G.C
    Render.drawBackdrop(time)
    Render.drawBoard(time)
    if G.shop.keeper then Gnome.drawGnome(G.shop.keeper, time, G, Board, C) end
    local hero = G.units[1]
    if hero then
        if hero.kind == "knight" then Knight.drawKnight(hero, time, G, Board, C)
        else Render.drawPawn(hero, time) end
    end
    -- title
    local cx = G.W / 2
    love.graphics.setFont(G.fontTitle)
    love.graphics.setColor(C.ink)
    love.graphics.printf("GRIZZLE'S EMPORIUM", 0, 20, G.W, "center")
    love.graphics.setColor(C.select)
    love.graphics.rectangle("fill", cx - 100, 52, 200, 2)
    love.graphics.setFont(G.fontSmall)
    love.graphics.setColor(C.muted)
    love.graphics.printf("WASD / CLICK move  •  ESC leave", 0, 60, G.W, "center")
    -- leave button
    local lw, lh = 200, 40
    local lx = cx - lw / 2
    local ly = G.H - 80
    G.shop.leaveBtn = { x = lx, y = ly, w = lw, h = lh }
    local mx, my = love.mouse.getPosition()
    local hot = mx >= lx and mx <= lx + lw and my >= ly and my <= ly + lh
    love.graphics.setColor(hot and C.select or C.panelLn)
    love.graphics.rectangle(hot and "fill" or "line", lx, ly, lw, lh, 6, 6)
    love.graphics.setColor(hot and C.panel or C.selInk)
    love.graphics.setFont(G.fontBody)
    love.graphics.printf("LEAVE SHOP", lx, ly + 10, lw, "center")
end

function M.updateShop(dt)
    Units.updateGlide(dt, function(u)
        -- shop: never consume move, keep unlimited
        if G.phase == "shop" and u == G.units[1] then u.moved, u.attacked, u.acted = false, false, false end
    end)
    -- squash decay + lift/hover (main.lua skips Input.updateAmbient in shop)
    for id, v in pairs(G.squash) do G.squash[id] = math.max(0, v - dt * 6) end
    for y = 1, G.GRID do for x = 1, G.GRID do
        local k = x .. "," .. y
        local target = (G.hover and G.hover[1]==x and G.hover[2]==y) and 10 or 0
        local cur = G.lift[k] or 0
        cur = cur + (target - cur) * math.min(1, dt*12)
        if math.abs(cur-target) < 0.1 then cur = target end
        G.lift[k] = cur
    end end
    -- hover pick + queries
    local mx, my = love.mouse.getPosition()
    local tx, ty = Board.pickTile(mx, my)
    G.hover = (tx~=nil) and {tx,ty} or nil
    Units.updateQueries()
end

function M.tryShopMove(unit, dx, dy)
    if #unit.path > 0 then return end
    local nx, ny = unit.gx + dx, unit.gy + dy
    if nx < 1 or ny < 1 or nx > G.GRID or ny > G.GRID then return end
    if Board.isBlocked(nx, ny) then return end
    if G.shop.keeper and G.shop.keeper.gx == nx and G.shop.keeper.gy == ny then return end
    -- unlimited moves: temporarily clear gating flags
    local om, oa, oc = unit.moved, unit.attacked, unit.acted
    unit.moved, unit.attacked, unit.acted = false, false, false
    Units.orderMove(unit, nx, ny)
    -- keep unlimited: clear flags again after queuing (updateGlide will not set moved for shop)
    if #unit.path > 0 then unit.moved, unit.attacked, unit.acted = false, false, false
    else unit.moved, unit.attacked, unit.acted = om, oa, oc end
end

function M.shopMousepressed(x, y, button)
    if button ~= 1 then return end
    if G.shop.leaveBtn and x >= G.shop.leaveBtn.x and x <= G.shop.leaveBtn.x + G.shop.leaveBtn.w
        and y >= G.shop.leaveBtn.y and y <= G.shop.leaveBtn.y + G.shop.leaveBtn.h then
        M.leaveShop()
        return
    end
    local gx, gy = Board.pickTile(x, y)
    if gx and gy and not Board.isBlocked(gx, gy) then
        local hero = G.units[1]
        if hero and #hero.path == 0 then
            if G.shop.keeper and G.shop.keeper.gx == gx and G.shop.keeper.gy == gy then return end
            local om, oa, oc = hero.moved, hero.attacked, hero.acted
            hero.moved, hero.attacked, hero.acted = false, false, false
            Units.orderMove(hero, gx, gy)
            if #hero.path > 0 then hero.moved, hero.attacked, hero.acted = false, false, false
            else hero.moved, hero.attacked, hero.acted = om, oa, oc end
        end
    end
end

function M.shopKeypressed(key)
    if key == "escape" then M.leaveShop(); return end
    local hero = G.units[1]
    if not hero or #hero.path > 0 then return end
    if key == "w" then M.tryShopMove(hero, -1, 0)
    elseif key == "s" then M.tryShopMove(hero, 1, 0)
    elseif key == "a" then M.tryShopMove(hero, 0, -1)
    elseif key == "d" then M.tryShopMove(hero, 0, 1) end
end

function M.applyMode(m)
    -- free play restores the classic static board; run spawns via startRun()
    if m == "run" then return end
    G.gameMode = m
    Board.setSize(10)
    G.zoom, G.zoomTarget = 2.1, 2.1
    G.camX, G.camY = 0, 0
    Board.clearBoard()
    for _, p in ipairs(G.pillars) do
        G.heights[p[2]][p[1]] = 2
        G.blocked[p[2] * 100 + p[1]] = true
    end
    G.spawnTile, G.finishTile = {1, 1}, {G.GRID, G.GRID}
    Board.paintFreeMeadow()
    Units.spawnAll()
    G.pushLog("mode: " .. m)
end

function M.activate()
    if G.menuScreen == "main" then
        if G.menuIdx == 1 then G.menuScreen, G.menuIdx = "modes", 1
        elseif G.menuIdx == 2 then G.menuScreen, G.menuIdx = "settings", 1
        else love.event.quit() end
    elseif G.menuScreen == "modes" then
        if G.menuIdx == 1 then G.menuScreen, G.menuIdx = "select", 1
        elseif G.menuIdx == 2 then M.applyMode("free"); G.state = "game"
        else G.menuScreen, G.menuIdx = "main", 1 end
    elseif G.menuScreen == "select" then
        if G.menuIdx <= #G.roster then M.startRun(G.menuIdx)
        else G.menuScreen, G.menuIdx = "modes", 1 end
    elseif G.menuScreen == "settings" then
        -- click the volume row to step up (wraps to mute); BACK leaves.
        if G.menuIdx == 1 then M.adjustVolume(1, true)
        else G.menuScreen, G.menuIdx = "main", 1 end
    else
        G.menuScreen, G.menuIdx = "main", 1
    end
end

-- menu key handling. Returns true (consumed).
function M.keypressed(key)
    if G.phase == "shop" then
        M.shopKeypressed(key)
        return true
    end
    if G.menuScreen == "select" then
        -- carousel: left/right wraps the pool, ENTER confirms.
        if key == "left" or key == "a" or key == "up" then M.switchSelect(-1)
        elseif key == "right" or key == "d" or key == "down" then M.switchSelect(1)
        elseif key == "return" or key == "space" then M.confirmSelect()
        elseif key == "escape" then G.menuScreen, G.menuIdx = "modes", 1 end
        return true
    end
    if G.menuScreen == "path_choice" then
        local n = #M.items()
        if key == "up" or key == "w" then G.menuIdx = ((G.menuIdx - 2) % n) + 1
        elseif key == "down" or key == "s" then G.menuIdx = (G.menuIdx % n) + 1
        elseif key == "return" or key == "space" then
            if G.menuIdx <= 2 then M.confirmPathChoice(G.menuIdx == 1 and "normal" or "elite")
            else G.menuScreen, G.menuIdx = "main", 1 end
        elseif key == "escape" then G.menuScreen, G.menuIdx = "main", 1 end
        return true
    end
    local n = #M.items()
    if G.menuScreen == "settings" then
        -- up/down move, left/right (or A/D) tune the volume row,
        -- ENTER steps it up, ESC leaves.
        if key == "up" or key == "w" then G.menuIdx = ((G.menuIdx - 2) % n) + 1
        elseif key == "down" or key == "s" then G.menuIdx = (G.menuIdx % n) + 1
        elseif key == "left" or key == "a" then
            if G.menuIdx == 1 then M.adjustVolume(-1) end
        elseif key == "right" or key == "d" then
            if G.menuIdx == 1 then M.adjustVolume(1) end
        elseif key == "return" or key == "space" then M.activate()
        elseif key == "escape" then G.menuScreen, G.menuIdx = "main", 1 end
        return true
    end
    if key == "up" or key == "w" then G.menuIdx = ((G.menuIdx - 2) % n) + 1
    elseif key == "down" or key == "s" then G.menuIdx = (G.menuIdx % n) + 1
    elseif key == "return" or key == "space" then M.activate()
    elseif key == "escape" then
        if G.menuScreen ~= "main" then G.menuScreen, G.menuIdx = "main", 1
        else love.event.quit() end
    end
    return true
end

return M

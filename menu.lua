-- menu.lua — menu screens + run/flow transitions.
-- Deps: state (G), board, units, render (backdrop only).
local G = require("state")
local Board = require("board")
local Units = require("units")
local Render = require("render")
local M = {}

function M.items()
    if G.menuScreen == "main" then return { "START", "SETTINGS", "EXIT" }
    elseif G.menuScreen == "modes" then return {
        "START RUN", "FREE PLAY — move & explore", "BACK" }
    elseif G.menuScreen == "select" then
        local items = {}
        for _, def in ipairs(G.roster) do items[#items + 1] = def.name:upper() end
        items[#items + 1] = "BACK"
        return items
    else return { "VOLUME: ON", "BACK" } end
end

function M.draw(time)
    local C = G.C
    -- full-screen menu: own backdrop, no board behind
    Render.drawBackdrop(time)
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
    elseif G.menuScreen == "settings" then sub = "SETTINGS"
    else sub = "10 x 10 BLOCK FIELD" end
    love.graphics.printf(sub, 0, G.H * 0.22 + 40, G.W, "center")
    love.graphics.setColor(C.select)
    love.graphics.rectangle("fill", cx - 21, G.H * 0.22 + 62, 42, 3)

    if G.menuScreen == "select" then
        M.drawSelect(time)
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

-- big pawn bust (mirrors the in-game pawn look): shadow, base,
-- two-tone body, collar, head, highlight. (x, feetY) anchor, s scale.
local function drawBust(def, x, feetY, s, alpha)
    local col, dark = withAlpha(def.color, alpha), withAlpha(def.dark, alpha)
    love.graphics.setColor(0, 0, 0, 0.30 * alpha)
    love.graphics.ellipse("fill", x, feetY, 11 * s, 4.5 * s)
    love.graphics.setColor(dark)
    love.graphics.polygon("fill", { x - 9 * s, feetY - 2 * s, x - 3 * s, feetY - 18 * s,
                                    x + 3 * s, feetY - 18 * s, x + 9 * s, feetY - 2 * s })
    love.graphics.setColor(col)
    love.graphics.polygon("fill", { x - 3 * s, feetY - 2 * s, x - 1 * s, feetY - 18 * s,
                                    x + 3 * s, feetY - 18 * s, x + 4 * s, feetY - 2 * s })
    love.graphics.setColor(dark)
    love.graphics.ellipse("fill", x, feetY - 18 * s, 5.5 * s, 2.2 * s)
    love.graphics.setColor(col)
    love.graphics.circle("fill", x, feetY - 25 * s, 8 * s)
    love.graphics.setColor(1, 1, 1, 0.5 * alpha)
    love.graphics.setLineWidth(1.6 * s)
    love.graphics.arc("line", "open", x, feetY - 25 * s, 8 * s, -0.9, 0.7)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 0.55 * alpha)
    love.graphics.circle("fill", x - 2 * s, feetY - 27 * s, 1.8 * s)
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

function M.drawSelect(time)
    local C = G.C
    local cx = G.W / 2
    local n = #G.roster
    local def = G.roster[G.menuIdx]
    if not def then return end
    -- carousel animation: old slides out, new slides in (ease-out)
    local k = math.min(1, math.max(0, (time - M.selT0) / 0.28))
    local e = 1 - (1 - k) * (1 - k) * (1 - k)
    local showing = (k >= 1 or not M.selPrev)
    local items = {}
    if showing then items[1] = { def = def, off = 0, a = 1 }
    else
        local prev = G.roster[M.selPrev]
        if prev then items[#items + 1] = { def = prev, off = -M.selDir * e * 320, a = 1 - k } end
        items[#items + 1] = { def = def, off = M.selDir * (1 - e) * 320, a = math.min(1, 0.3 + k) }
    end
    local my = G.H * 0.40
    for _, it in ipairs(items) do
        local px = cx + it.off
        -- medallion: team-glow outer ring, dark sticker ring, deep fill
        love.graphics.setColor(withAlpha(it.def.color, 0.45 * it.a))
        love.graphics.setLineWidth(6)
        love.graphics.circle("line", px, my, 73)
        love.graphics.setColor(withAlpha(C.ring, it.a))
        love.graphics.setLineWidth(4)
        love.graphics.circle("line", px, my, 70)
        love.graphics.setColor(withAlpha(C.barBg, it.a))
        love.graphics.circle("fill", px, my, 67)
        love.graphics.setLineWidth(1)
        drawBust(it.def, px, my + 42, 2.4, it.a)
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

function M.startRun(idx, size)
    G.gameMode = "run"
    size = size or 10
    Board.generateMap(1, size)
    -- fixed zoomed-in framing: big boards pull back, standard sits close
    if (G.GRID or 10) >= 15 then G.zoom, G.zoomTarget = 1.3, 1.3
    else G.zoom, G.zoomTarget = 1.8, 1.8 end
    G.camX, G.camY = 0, 0
    G.units = { Units.spawnUnit(G.roster[idx]) }
    G.units[1].gx, G.units[1].gy = G.spawnTile[1], G.spawnTile[2]
    G.units[1].px, G.units[1].py = G.spawnTile[1], G.spawnTile[2]
    G.units[1].fx, G.units[1].fy = G.spawnTile[1], G.spawnTile[2]
    G.activeIdx = 1
    G.round, G.wiped = 1, false
    G.coins, G.levelKills, G.levelCoins, G.levelHp, G.win = 0, 0, 0, 0, nil
    Units.spawnRunEnemies(2)
    Units.buildTurnOrder()
    local a = Units.active()
    if a and a.team == "enemy" then Units.enemyTurn(a) end
    G.state = "game"
    G.pushLog("run started — " .. G.units[1].name .. " / lv1 seed " .. G.runSeed)
end

function M.nextLevel()
    Board.generateMap(G.runLevel + 1, G.GRID)
    -- fresh framing for the new grid (transition zoomed in close)
    if (G.GRID or 10) >= 15 then G.zoom, G.zoomTarget = 1.3, 1.3
    else G.zoom, G.zoomTarget = 1.8, 1.8 end
    G.camX, G.camY = 0, 0
    G.win = nil
    G.winNextBtn, G.upgDescendBtn, G.upgSlotBtns = nil, nil, nil
    G.arrows = {}
    Units.clearEnemies()
    local u = G.units[1]
    u.map = "over"
    u.gx, u.gy = G.spawnTile[1], G.spawnTile[2]
    u.px, u.py, u.fx, u.fy = u.gx, u.gy, u.gx, u.gy
    u.path, u.t = {}, 0
    u.moved, u.acted = false, false
    u.hp, u.mana = u.maxHP, u.maxMana -- descend fully restores the party
    G.round = 1
    G.levelKills, G.levelCoins, G.levelHp = 0, 0, 0
    Units.spawnRunEnemies(2)
    Units.buildTurnOrder()
    G.pushLog("LEVEL " .. G.runLevel .. " — seed " .. G.runSeed .. " — party restored")
end

-- Win flow: "zoom" (slow cinematic push onto the hero: impact flash,
-- shockwave rings, letterbox, ~2.6 s) → "rewards" (card waits for NEXT
-- click) → "upgrade" (full screen, skeleton rows) → nextLevel() on DESCEND.
-- Input locks while G.win is set.
M.WIN_DUR = 2.6

function M.beginWin()
    if G.win then return end
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
    local base = (G.GRID >= 15) and 1.3 or 1.8
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
    -- win = clear all enemies on the overworld -> transition, then next round.
    if G.state ~= "game" or G.gameMode ~= "run" or G.map ~= "over" then return end
    if G.win then return end
    for _, e in ipairs(G.units) do
        if e.team == "enemy" and e.hp > 0 then return end
    end
    M.beginWin()
end

function M.checkFinish(u)
    Board.checkShop(u)
    M.checkClear()
end

function M.applyMode(m)
    -- free play restores the classic static board; run spawns via startRun()
    if m == "run" then return end
    G.gameMode = m
    Board.setSize(10)
    G.zoom, G.zoomTarget = 1.8, 1.8
    G.camX, G.camY = 0, 0
    Board.clearBoard()
    for _, p in ipairs(G.pillars) do
        G.heights[p[2]][p[1]] = 2
        G.blocked[p[2] * 100 + p[1]] = true
    end
    G.spawnTile, G.finishTile = {1, 1}, {G.GRID, G.GRID}
    Board.paintFreeMeadow()
    Board.setupFreeShop()
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
    else
        G.menuScreen, G.menuIdx = "main", 1
    end
end

-- menu key handling. Returns true (consumed).
function M.keypressed(key)
    if G.menuScreen == "select" then
        -- carousel: left/right wraps the pool, ENTER confirms.
        if key == "left" or key == "a" or key == "up" then M.switchSelect(-1)
        elseif key == "right" or key == "d" or key == "down" then M.switchSelect(1)
        elseif key == "return" or key == "space" then M.confirmSelect()
        elseif key == "escape" then G.menuScreen, G.menuIdx = "modes", 1 end
        return true
    end
    local n = #M.items()
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

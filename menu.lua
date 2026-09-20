-- menu.lua — menu screens + run/flow transitions.
-- Deps: state (G), board, units, render (backdrop only).
local G = require("state")
local Board = require("board")
local Units = require("units")
local Render = require("render")
local M = {}

-- pending map size for the run being set up (10 standard, 15 big).
M.pendingSize = 10

function M.items()
    if G.menuScreen == "main" then return { "START", "SETTINGS", "EXIT" }
    elseif G.menuScreen == "modes" then return {
        "START A RUN — 10x10", "START BIG RUN — 15x15",
        "FREE PLAY — move & explore", "BACK" }
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
        sub = "CHOOSE YOUR PAWN — " .. (M.pendingSize >= 15 and "15x15 BIG" or "10x10")
    elseif G.menuScreen == "settings" then sub = "SETTINGS"
    else sub = "10 x 10 BLOCK FIELD" end
    love.graphics.printf(sub, 0, G.H * 0.22 + 40, G.W, "center")
    love.graphics.setColor(C.select)
    love.graphics.rectangle("fill", cx - 21, G.H * 0.22 + 62, 42, 3)

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
    size = size or M.pendingSize or 10
    Board.generateMap(1, size)
    -- fit big boards: 15x15 at full zoom crowds the panel
    if (G.GRID or 10) >= 15 then G.zoom, G.zoomTarget = 0.8, 0.8
    else G.zoom, G.zoomTarget = 1, 1 end
    G.camX, G.camY = 0, 0
    G.units = { Units.spawnUnit(G.roster[idx]) }
    G.units[1].gx, G.units[1].gy = G.spawnTile[1], G.spawnTile[2]
    G.units[1].px, G.units[1].py = G.spawnTile[1], G.spawnTile[2]
    G.units[1].fx, G.units[1].fy = G.spawnTile[1], G.spawnTile[2]
    G.activeIdx = 1
    G.selAnim = 0
    G.state = "game"
    G.pushLog("run started — " .. G.units[1].name .. " / lv1 seed " .. G.runSeed)
end

function M.nextLevel()
    Board.generateMap(G.runLevel + 1, G.GRID)
    local u = G.units[1]
    u.map = "over"
    u.gx, u.gy = G.spawnTile[1], G.spawnTile[2]
    u.px, u.py, u.fx, u.fy = u.gx, u.gy, u.gx, u.gy
    u.path, u.t = {}, 0
    G.pushLog("LEVEL " .. G.runLevel .. " — seed " .. G.runSeed)
end

function M.checkFinish(u)
    Board.checkShop(u)
    if G.map == "over" and G.gameMode == "run" and #u.path == 0
        and u.gx == G.finishTile[1] and u.gy == G.finishTile[2] then
        G.pushLog(u.name .. " descended!")
        M.nextLevel()
    end
end

function M.applyMode(m)
    -- free play restores the classic static board; run spawns via startRun()
    if m == "run" then return end
    G.gameMode = m
    Board.setSize(10)
    G.zoom, G.zoomTarget = 1, 1
    G.camX, G.camY = 0, 0
    Board.clearBoard()
    for _, p in ipairs(G.pillars) do
        G.heights[p[2]][p[1]] = 2
        G.blocked[p[2] * 100 + p[1]] = true
    end
    G.spawnTile, G.finishTile = {1, 1}, {G.GRID, G.GRID}
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
        if G.menuIdx == 1 then M.pendingSize = 10; G.menuScreen, G.menuIdx = "select", 1
        elseif G.menuIdx == 2 then M.pendingSize = 15; G.menuScreen, G.menuIdx = "select", 1
        elseif G.menuIdx == 3 then M.applyMode("free"); G.state = "game"
        else G.menuScreen, G.menuIdx = "main", 1 end
    elseif G.menuScreen == "select" then
        if G.menuIdx <= #G.roster then M.startRun(G.menuIdx, M.pendingSize)
        else G.menuScreen, G.menuIdx = "modes", 1 end
    else
        G.menuScreen, G.menuIdx = "main", 1
    end
end

-- menu key handling. Returns true (consumed).
function M.keypressed(key)
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

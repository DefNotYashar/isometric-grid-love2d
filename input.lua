-- input.lua — love input callbacks + per-frame hover/ambient updates.
-- Deps: state (G), board, units, camera, menu.
local G = require("state")
local Board = require("board")
local Units = require("units")
local Camera = require("camera")
local Menu = require("menu")
local M = {}

function M.updatePick()
    -- hover pick (height-aware: matches the visible top diamonds)
    local mx, my = love.mouse.getPosition()
    local tx, ty = Board.pickTile(mx, my)
    G.hover = (tx ~= nil) and { tx, ty } or nil
    Units.updateQueries()
end

function M.updateAmbient(dt)
    -- dust drift
    for _, p in ipairs(G.dust) do
        p.x = p.x + p.vx * dt; p.y = p.y + p.vy * dt
        if p.x > G.W + 10 then p.x = -10 end
        if p.y < -10 then p.y, p.x = G.H + 10, math.random() * G.W end
    end
    -- squash decay + puff fade
    for id, v in pairs(G.squash) do G.squash[id] = math.max(0, v - dt * 6) end
    for i = #G.puffs, 1, -1 do
        local pf = G.puffs[i]; pf.r = pf.r + 60*dt; pf.a = pf.a - dt*1.8
        if pf.a <= 0 then table.remove(G.puffs, i) end
    end

    -- lift tweens
    for y = 1, G.GRID do
        for x = 1, G.GRID do
            local k = x .. "," .. y
            local target = (G.hover and G.hover[1] == x and G.hover[2] == y) and G.LIFT_PX or 0
            local cur = G.lift[k] or 0
            cur = cur + (target - cur) * math.min(1, dt * 12)
            if math.abs(cur - target) < 0.1 then cur = target end
            G.lift[k] = cur
        end
    end
end

function M.mousepressed(x, y, button)
    if G.state == "menu" then
        if button == 1 then
            local hit = Menu.hit(x, y)
            if hit then G.menuIdx = hit; Menu.activate() end
        end
        return
    end
    if button == 1 then
        local tx, ty = Board.pickTile(x, y)
        if tx == nil then return end
        local hit = Units.unitAt(tx, ty)
        if hit then
            for i, u in ipairs(G.units) do
                if u == hit then G.activeIdx = i end
            end
            G.selAnim = 0
            G.pushLog("selected " .. hit.name)
        else
            Units.orderMove(G.units[G.activeIdx], tx, ty)
        end
    elseif button == 2 then
        love._panning = true
    end
end

function M.mousereleased(_, _, button)
    if button == 2 then love._panning = false end
end

function M.mousemoved(_, _, dx, dy)
    if love._panning then G.camX, G.camY = G.camX + dx, G.camY + dy; Camera.clampCamera() end
end

function M.wheelmoved(_, y)
    local f = y > 0 and 1.1 or 0.9
    local nz = math.max(G.MIN_ZOOM, math.min(G.MAX_ZOOM, G.zoomTarget * f))
    if nz == G.zoomTarget then return end
    local mx, my = love.mouse.getPosition()
    -- Zoom at cursor only when the cursor is over the board; otherwise
    -- zoom toward the viewport center so empty corners/panel can't
    -- walk the grid away.
    local tx, ty = Board.pickTile(mx, my)
    local ax, ay = mx, my
    if tx == nil then ax, ay = G.W / 2, G.H / 2 end
    local r = nz / G.zoomTarget
    G.camX = ax - G.originX - (ax - G.originX - G.camX) * r
    G.camY = ay - G.originY - (ay - G.originY - G.camY) * r
    G.zoomTarget = nz
    Camera.clampCamera()
end

function M.keypressed(key)
    if G.state == "menu" then return Menu.keypressed(key) end
    local a = G.units[G.activeIdx]
    if key == "tab" then
        -- cycle units on the visible map only.
        for _ = 1, #G.units do
            G.activeIdx = G.activeIdx % #G.units + 1
            if G.units[G.activeIdx].map == G.map then break end
        end
        G.selAnim = 0
        G.pushLog("selected " .. G.units[G.activeIdx].name)
    elseif key == "r" then Camera.reset()
    elseif key == "escape" then G.state = "menu"; G.menuIdx = 1
    elseif a and #a.path == 0 then
        if key == "w" then Units.stepMove(a, -1, 0)
        elseif key == "s" then Units.stepMove(a, 1, 0)
        elseif key == "a" then Units.stepMove(a, 0, -1)
        elseif key == "d" then Units.stepMove(a, 0, 1) end
    end
end

return M

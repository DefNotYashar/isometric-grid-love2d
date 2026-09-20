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
    -- squash decay + puff fade + floats rise
    for id, v in pairs(G.squash) do G.squash[id] = math.max(0, v - dt * 6) end
    for i = #G.puffs, 1, -1 do
        local pf = G.puffs[i]; pf.r = pf.r + 60*dt; pf.a = pf.a - dt*1.8
        if pf.a <= 0 then table.remove(G.puffs, i) end
    end
    for i = #G.floats, 1, -1 do
        local f = G.floats[i]; f.t = f.t + dt
        if f.t >= f.life then table.remove(G.floats, i) end
    end
    for i = #G.arrows, 1, -1 do
        local a = G.arrows[i]; a.t = a.t + dt
        if a.t >= a.dur then table.remove(G.arrows, i) end
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
            if G.menuScreen == "select" then Menu.clickSelect(x, y)
            else
                local hit = Menu.hit(x, y)
                if hit then G.menuIdx = hit; Menu.activate() end
            end
        end
        return
    end
    if G.phase == "shop" then
        if button == 1 then Menu.shopMousepressed(x, y, button) end
        return
    end
    if G.state == "over" then
        -- game over: any click returns to the menu.
        G.state, G.menuScreen, G.menuIdx = "menu", "main", 1
        return
    end
    if G.win then
        -- win flow locks board input: rewards waits on NEXT, upgrade
        -- screen has its own buttons, zoom phase ignores clicks.
        if button == 1 then
            if G.win.phase == "rewards" then
                local nb = G.winNextBtn
                if nb and x >= nb.x and x <= nb.x + nb.w
                    and y >= nb.y and y <= nb.y + nb.h then
                    Menu.toUpgrade()
                end
            elseif G.win.phase == "upgrade" then
                local db = G.upgDescendBtn
                if db and x >= db.x and x <= db.x + db.w
                    and y >= db.y and y <= db.y + db.h then
                    Menu.nextLevel()
                    return
                end
                for i, bb in ipairs(G.upgSlotBtns or {}) do
                    if x >= bb.x and x <= bb.x + bb.w
                        and y >= bb.y and y <= bb.y + bb.h then
                        G.pushLog("slot " .. i .. " locked — awaiting spec")
                        return
                    end
                end
            end
        end
        return
    end
    if button == 1 then
        -- turn-box buttons first (screen-space rects set by render).
        -- While the enemy AI beat plays, board input locks; only the
        -- stats toggle (pure UI) stays live.
        if G.ai then
            local st = G.statsToggle
            if st and x >= st.x and x <= st.x + st.w and y >= st.y and y <= st.y + st.h then
                G.showStats = not G.showStats
            end
            return
        end
        local nb = G.nextBtn
        if nb and x >= nb.x and x <= nb.x + nb.w and y >= nb.y and y <= nb.y + nb.h then
            Units.endTurn()
            return
        end
        local bb = G.boltBtn
        if bb and x >= bb.x and x <= bb.x + bb.w and y >= bb.y and y <= bb.y + bb.h then
            M.toggleBolt()
            return
        end
        local st = G.statsToggle
        if st and x >= st.x and x <= st.x + st.w and y >= st.y and y <= st.y + st.h then
            G.showStats = not G.showStats
            return
        end
        local tx, ty = Board.pickTile(x, y)
        if tx == nil then return end
        local hit = Units.unitAt(tx, ty)
        if hit then
            if hit.team == "enemy" then
                -- clicking an enemy attacks (or bolts when armed); never selects.
                local act = G.units[G.activeIdx]
                if G.castMode then Units.orderCast(act, hit)
                else Units.orderAttack(act, hit) end
            else
                for i, u in ipairs(G.units) do
                    if u == hit then G.activeIdx = i end
                end
                Units.syncTurnPos()
                G.selAnim = 0
                G.pushLog("selected " .. hit.name)
            end
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
    -- zoom disabled: fixed camera distance (auto-fit only on map switch).
    return
end

function M.keypressed(key)
    if G.state == "menu" then return Menu.keypressed(key) end
    if G.phase == "shop" then return Menu.shopKeypressed(key) end
    if G.state == "over" then
        G.state, G.menuScreen, G.menuIdx = "menu", "main", 1
        return
    end
    if G.win then
        -- win flow: SPACE/ENTER advances, everything else locked.
        if key == "space" or key == "return" then
            if G.win.phase == "rewards" then Menu.toUpgrade()
            elseif G.win.phase == "upgrade" then Menu.nextLevel() end
        end
        return
    end
    local a = G.units[G.activeIdx]
    if key == "escape" then G.state = "menu"; G.menuIdx = 1 return end
    if key == "c" then G.showStats = not G.showStats return end
    if G.ai then return end -- enemy beat playing: board input locked
    if key == "tab" then
        -- cycle unacted heroes on the visible map (falls back to all heroes).
        if #G.turnOrder == 0 then Units.buildTurnOrder() end
        local function heroIdx(id)
            local idx = Units.indexOfId(id)
            local u = idx and G.units[idx]
            if u and u.team ~= "enemy" and u.map == G.map then return idx end
            return nil
        end
        local startPos, picked = G.turnPos, nil
        for _ = 1, #G.turnOrder do
            G.turnPos = G.turnPos % #G.turnOrder + 1
            local idx = heroIdx(G.turnOrder[G.turnPos])
            if idx and not G.units[idx].acted then picked = idx break end
        end
        if not picked then
            for _ = 1, #G.turnOrder do
                startPos = startPos % #G.turnOrder + 1
                local idx = heroIdx(G.turnOrder[startPos])
                if idx then picked = idx G.turnPos = startPos break end
            end
        end
        if picked then
            G.activeIdx = picked
            G.selAnim = 0
            G.pushLog("selected " .. G.units[picked].name)
        end
    elseif key == "space" then Units.endTurn()
    elseif key == "q" then M.toggleBolt()
    elseif key == "r" then Camera.reset()
    elseif a and #a.path == 0 then
        if key == "w" then Units.stepMove(a, -1, 0)
        elseif key == "s" then Units.stepMove(a, 1, 0)
        elseif key == "a" then Units.stepMove(a, 0, -1)
        elseif key == "d" then Units.stepMove(a, 0, 1) end
    end
end

-- Arm/cancel firebolt targeting for the active hero.
function M.toggleBolt()
    local a = G.units[G.activeIdx]
    if not a or a.team ~= "hero" or #a.path > 0 then return end
    if a.acted then G.pushLog(a.name .. ": already acted") return end
    if not G.castMode and (a.mana or 0) < Units.BOLT_COST then
        G.pushLog(a.name .. ": not enough mana") return
    end
    G.castMode = not G.castMode
    G.pushLog(G.castMode and (a.name .. ": bolt armed — click an enemy")
        or (a.name .. ": bolt cancelled"))
end

return M

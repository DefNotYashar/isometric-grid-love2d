-- menu.lua — menu screens + run/flow transitions.
-- Deps: state (G), board, units, render (backdrop only).
local G = require("state")
local Board = require("board")
local Units = require("units")
local Render = require("render")
local M = {}
local Knight = require("assets.units.knight")

-- ---------- navigation stack (single source of truth) ----------
function M.top() return G.menuStack[#G.menuStack] end
function M.push(screen)
    table.insert(G.menuStack, screen)
    G.menuScreen = screen
    G.menuIdx = 1
end
function M.pop()
    if #G.menuStack > 1 then table.remove(G.menuStack) end
    G.menuScreen = M.top()
    G.menuIdx = 1
end
function M.replace(screen)
    G.menuStack[#G.menuStack] = screen
    G.menuScreen = screen
    G.menuIdx = 1
end
function M.resetToMain()
    G.menuStack = { "main" }
    G.menuScreen, G.menuIdx = "main", 1
    G.state = "menu"
    G.phase = "play"
    G.paused = false
    G.win = nil
end
function M.syncSave()
    local SaveSystem = require("systems.save_system")
    SaveSystem.save()
end

-- ---------- admin: map listing ----------
M.adminFilter = "All"
M.adminSearch = ""
M.adminRows = {}   -- clickable rects, rebuilt each draw
M.adminButtons = {}

function M.listAllMaps()
    local t = {}
    for _, typ in ipairs({ "normal", "elite", "boss", "special" }) do
        local ok, files = pcall(love.filesystem.getDirectoryItems, "levels/forest/" .. typ)
        if ok and files then
            for _, f in ipairs(files) do
                if f:sub(-4) == ".lua" then
                    table.insert(t, { area = "forest", type = typ, id = f:sub(1, -5),
                        path = "levels/forest/" .. typ .. "/" .. f })
                end
            end
        end
    end
    table.sort(t, function(a, b)
        if a.type == b.type then return a.id < b.id end
        return a.type < b.type
    end)
    return t
end

function M.filteredMaps()
    local all = M.listAllMaps()
    local out = {}
    local q = (M.adminSearch or ""):lower()
    for _, m in ipairs(all) do
        local typeOk = (M.adminFilter == "All") or (m.type:lower() == M.adminFilter:lower())
        local searchOk = (q == "") or (m.id:lower():find(q, 1, true) ~= nil)
        if typeOk and searchOk then out[#out + 1] = m end
    end
    return out
end

function M.items()
    if G.menuScreen == "main" then return { "START", "LEVEL EDITOR", "SETTINGS", "EXIT" }
    elseif G.menuScreen == "modes" then return {
        "START RUN", "FREE PLAY — move & explore", "BACK" }
    elseif G.menuScreen == "select" then
        local items = { "KNIGHT" }
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
    G.settings = G.settings or { showAdmin = true, volume = 8 }
    G.settings.volume = G.volume
    M.syncSave()
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
    love.graphics.setFont(G.fontDisplay or G.fontTitle)
    love.graphics.setColor(C.ink)
    love.graphics.printf("ISOMETRIC GRID LAB", 0, G.H * 0.22, G.W, "center")
    love.graphics.setFont(G.fontSmall)
    love.graphics.setColor(C.muted)
    local sub
    if G.menuScreen == "modes" then sub = "CHOOSE HOW TO PLAY"
    elseif G.menuScreen == "select" then
        sub = "CHOOSE YOUR KNIGHT"
    elseif G.menuScreen == "path_choice" then
        sub = "CHOOSE YOUR PATH"
    elseif G.menuScreen == "settings" then sub = "SETTINGS"
    elseif G.menuScreen == "editor_admin" then sub = "LEVEL EDITOR — ALL SAVED MAPS"
    else sub = "10 x 10 BLOCK FIELD" end
    love.graphics.printf(sub, 0, G.H * 0.22 + 40, G.W, "center")
    love.graphics.setColor(C.select)
    love.graphics.rectangle("fill", cx - 21, G.H * 0.22 + 62, 42, 3)

    if G.menuScreen == "select" then
        M.drawSelect(time)
        return
    end
    if G.menuScreen == "editor_admin" then
        M.drawAdmin(time)
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

-- Single-knight select: arrows/dots pick a livery color; the color name
-- becomes the hero's in-game name. Other slots are locked teasers.
M.knightColors = {
    { name = "Crimson", color = {0.90, 0.34, 0.18} },
    { name = "Azure",   color = {0.18, 0.53, 0.89} },
    { name = "Verdant", color = {0.25, 0.72, 0.30} },
    { name = "Golden",  color = {0.78, 0.62, 0.18} },
    { name = "Violet",  color = {0.55, 0.35, 0.85} },
    { name = "Teal",    color = {0.20, 0.75, 0.75} },
    { name = "Rose",    color = {0.92, 0.45, 0.65} },
    { name = "Ash",     color = {0.62, 0.64, 0.70} },
}
M.sigil = "cross" -- "cross" | "diamond" | "skull"
M.sigilBtns = {}
M.colorIdx = 1
M.colorDots = {}
M.selKind = "knight" -- "knight" | "assassin" | "tank"
M.kindTabs = {}

local function knightDark(c)
    return { c[1] * 0.62, c[2] * 0.62, c[3] * 0.62 }
end

function M.selectedColor()
    return M.knightColors[((M.colorIdx - 1) % #M.knightColors) + 1]
end

function M.switchSelect(d)
    local n = #M.knightColors
    M.colorIdx = ((M.colorIdx - 1 + d) % n) + 1
    M.selT0 = love.timer.getTime()
end

function M.switchKind()
    local order = { "knight", "assassin", "tank" }
    for i, k in ipairs(order) do
        if k == M.selKind then
            M.selKind = order[(i % #order) + 1]
            M.selT0 = love.timer.getTime()
            return
        end
    end
    M.selKind = "knight"
end

function M.confirmSelect()
    if G.playSfx then G.playSfx("click", 0.8) end
    local c = M.selectedColor()
    local idx, kind = 1, "knight"
    if M.selKind == "assassin" then idx, kind = 5, "assassin"
    elseif M.selKind == "tank" then idx, kind = 6, "tank" end
    local def = G.roster[idx]
    if def then
        def.name = c.name
        def.color = c.color
        def.dark = knightDark(c.color)
        def.kind = kind
        def.sigil = M.sigil
    end
    M.startRun(idx)
end

function M.clickSelect(x, y)
    local function hit(r) return r and x >= r.x and x <= r.x + r.w
        and y >= r.y and y <= r.y + r.h end
    if hit(M.selLeft) then M.switchSelect(-1)
    elseif hit(M.selRight) then M.switchSelect(1)
    elseif hit(M.selConfirm) then M.confirmSelect()
    elseif hit(M.selBack) then M.pop() end
    for _, t in ipairs(M.kindTabs or {}) do
        if hit(t) then M.selKind = t.kind return end
    end
    for _, s in ipairs(M.sigilBtns or {}) do
        if hit(s) then M.sigil = s.sigil return end
    end
    for i, d in ipairs(M.colorDots or {}) do
        if hit(d) then M.colorIdx = i return end
    end
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
        -- BACK abandons the run to the main menu
        M.resetToMain()
    end
end

function M.confirmPathChoice(pathType)
    G.runPathChoice = pathType -- "normal" or "elite"
    M.pop() -- leave path_choice screen
    G.state = "game" -- back to the board
    -- Continue to next level with chosen path
    M.nextLevel()
end

function M.drawSelect(time)
    local C = G.C
    local cx = G.W / 2
    local my = G.H * 0.34
    -- class + livery: tabs pick knight/assassin, dots pick color (name follows)
    local sel = M.selectedColor()
    local col, dark = sel.color, knightDark(sel.color)
    local isAsn = (M.selKind == "assassin")
    local isTank = (M.selKind == "tank")
    local st = isAsn and Units.ASSASSIN_STATS
        or (isTank and Units.TANK_STATS or ((G.roster[1] and G.roster[1].stats) or {}))
    local BIG_R = 92
    local scale = 3.4
    local Assassin = require("assets.units.assassin")
    local Tank = require("assets.units.tank")

    -- pedestal oval
    love.graphics.setColor(0, 0, 0, 0.22)
    love.graphics.ellipse("fill", cx, my + BIG_R * 0.85, BIG_R * 0.95, BIG_R * 0.28)
    -- medallion ring in the livery color
    love.graphics.setColor(col[1], col[2], col[3], 0.55)
    love.graphics.setLineWidth(6)
    love.graphics.circle("line", cx, my, BIG_R + 3)
    love.graphics.setColor(C.ring)
    love.graphics.setLineWidth(4)
    love.graphics.circle("line", cx, my, BIG_R)
    love.graphics.setColor(C.barBg)
    love.graphics.circle("fill", cx, my, BIG_R - 3)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(col[1], col[2], col[3], 0.16)
    love.graphics.circle("fill", cx, my, BIG_R + 12)
    -- the hero (knight, assassin or tank bust in the chosen livery)
    love.graphics.stencil(function() love.graphics.circle("fill", cx, my, BIG_R - 3) end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)
    if isAsn then Assassin.drawBust(cx, my + 62, col, dark, scale, M.sigil)
    elseif isTank then Tank.drawBust(cx, my + 62, col, dark, scale, M.sigil)
    else Knight.drawBust(cx, my + 62, col, dark, scale, M.sigil) end
    love.graphics.setStencilTest()
    love.graphics.setColor(C.select[1], C.select[2], C.select[3], 0.95)
    love.graphics.circle("fill", cx, my + BIG_R + 16, 3)

    -- arrows (kept rects: selLeft/selRight for click + keys)
    local mx, myy = love.mouse.getPosition()
    love.graphics.setFont(G.fontTitle)
    local function arrow(r, label)
        local hot = r and mx >= r.x and mx <= r.x + r.w and myy >= r.y and myy <= r.y + r.h
        love.graphics.setColor(hot and C.select or C.muted)
        love.graphics.printf(label, r.x, r.y, r.w, "center")
    end
    M.selLeft = { x = cx - 220, y = my - 28, w = 56, h = 56 }
    M.selRight = { x = cx + 164, y = my - 28, w = 56, h = 56 }
    arrow(M.selLeft, "<")
    arrow(M.selRight, ">")
    -- livery name + color dots (clickable)
    love.graphics.setFont(G.fontTitle)
    love.graphics.setColor(C.selInk)
    love.graphics.printf(sel.name:upper(), cx - 200, my + 92, 400, "center")
    love.graphics.setFont(G.fontSmall)
    love.graphics.setColor(C.muted)
    love.graphics.printf("LIVERY  " .. M.colorIdx .. " / " .. #M.knightColors, cx - 200, my + 126, 400, "center")
    M.colorDots = {}
    local n = #M.knightColors
    for i = 1, n do
        local dx = cx + (i - (n + 1) / 2) * 30
        local c = M.knightColors[i]
        local r = { x = dx - 9, y = my + 146, w = 18, h = 18 }
        M.colorDots[i] = r
        if i == M.colorIdx then
            love.graphics.setColor(C.select)
            love.graphics.circle("fill", dx, my + 155, 9)
            love.graphics.setColor(c.color)
            love.graphics.circle("fill", dx, my + 155, 6)
        else
            love.graphics.setColor(c.color[1], c.color[2], c.color[3], 0.75)
            love.graphics.circle("fill", dx, my + 155, 6)
            love.graphics.setColor(C.muted)
            love.graphics.circle("line", dx, my + 155, 6)
        end
    end
    -- class tabs: KNIGHT | ASSASSIN | TANK (clickable, W/S also switches)
    M.kindTabs = {}
    do
        love.graphics.setFont(G.fontSmall)
        local tw, th = 96, 24
        local ty = my + 172
        local defs = { { kind = "knight", label = "KNIGHT" }, { kind = "assassin", label = "ASSASSIN" }, { kind = "tank", label = "TANK" } }
        for i, d in ipairs(defs) do
            local tx = cx - (3 * tw + 2 * 10) / 2 + (i - 1) * (tw + 10)
            local r = { x = tx, y = ty, w = tw, h = th, kind = d.kind }
            M.kindTabs[i] = r
            local sel2 = (M.selKind == d.kind)
            local mx2, myy2 = love.mouse.getPosition()
            local hot = mx2 >= tx and mx2 <= tx + tw and myy2 >= ty and myy2 <= ty + th
            if sel2 then
                love.graphics.setColor(col)
                love.graphics.rectangle("fill", tx, ty, tw, th, 4, 4)
                love.graphics.setColor(C.panel)
            else
                love.graphics.setColor(hot and C.select or C.panelLn)
                love.graphics.rectangle(hot and "fill" or "line", tx, ty, tw, th, 4, 4)
                love.graphics.setColor(hot and C.panel or C.selInk)
            end
            love.graphics.printf(d.label, tx, ty + 5, tw, "center")
        end
    end
    -- sigil picker: emblem worn on tabard / clasp / shield
    M.sigilBtns = {}
    do
        local ly = my + 202
        love.graphics.setFont(G.fontSmall)
        love.graphics.setColor(C.muted)
        love.graphics.printf("— SIGIL —", cx - 200, ly, 400, "center")
        local defs = { "cross", "diamond", "skull" }
        local bw, bh = 92, 24
        local by = ly + 18
        local mx3, myy3 = love.mouse.getPosition()
        for i, s in ipairs(defs) do
            local bx = cx + (i - 2) * (bw + 10) - bw / 2
            local r = { x = bx, y = by, w = bw, h = bh, sigil = s }
            M.sigilBtns[i] = r
            local sel3 = (M.sigil == s)
            local hot = mx3 >= bx and mx3 <= bx + bw and myy3 >= by and myy3 <= by + bh
            if sel3 then
                love.graphics.setColor(col)
                love.graphics.rectangle("fill", bx, by, bw, bh, 4, 4)
                love.graphics.setColor(C.panel)
            else
                love.graphics.setColor(hot and C.select or C.panelLn)
                love.graphics.rectangle(hot and "fill" or "line", bx, by, bw, bh, 4, 4)
                love.graphics.setColor(hot and C.panel or C.selInk)
            end
            love.graphics.printf(s:upper(), bx, by + 5, bw, "center")
        end
    end
    -- stat cells (no derived HP/MP/RNG line — stats speak for themselves)
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
    local sy = my + 282
    local labels = { "VIG", "STR", "DEX", "LCK", "SPD", "CHA" }
    local vals = { st.vigor, st.strength, st.dexterity, st.luck, st.speed, st.charisma }
    for i = 1, 6 do
        local col3, row2 = (i - 1) % 3, math.floor((i - 1) / 3)
        cell(cx - 122 + col3 * 84, sy + row2 * 50, labels[i], vals[i])
    end
    -- confirm + back
    local byy = sy + 104
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
    love.graphics.printf("◀ ▶ COLOR · W/S CLASS · CLICK ALL · ENTER CONFIRM · ESC BACK",
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
    love.graphics.printf("Level 4 follows your choice. Level 5 is the elite finale.", cx - 300, my + 10, 600, "center")

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
    else G.zoom, G.zoomTarget = 2.4, 2.4 end
    G.camX, G.camY = 0, 0

    -- Spawn player heroes (squad of 2) at the first player spawns
    local playerSpawns = G.playerSpawns or {}
    if type(idx) ~= "table" then idx = { idx } end
    G.units = {}
    G.squadSize = #idx
    for n, ridx in ipairs(idx) do
        local hero = Units.spawnUnit(G.roster[ridx])
        local ps = playerSpawns[n] or playerSpawns[1]
        hero.gx, hero.gy = ps.x, ps.y
        hero.px, hero.py = ps.x, ps.y
        hero.fx, hero.fy = ps.x, ps.y
        G.units[#G.units + 1] = hero
    end
    G.activeIdx = 1
    G.round, G.wiped = 1, false
    G.coins, G.levelKills, G.levelCoins, G.levelHp, G.win = 0, 0, 0, 0, nil

    -- Spawn enemies from encounter
    Units.spawnEncounterEnemies(encounter)
    Units.buildTurnOrder()
    local a = Units.active()
    if a and a.team == "enemy" then Units.enemyTurn(a) end
    G.state = "game"
    G.pushLog("run started — " .. G.units[1].name .. (G.squadSize > 1 and (" + " .. G.units[2].name) or "") .. " / " .. levelId .. " + " .. encounterId)
    Render.banner("LEVEL 1", levelId .. "  ·  " .. encounterId)
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
            M.push("path_choice")
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
        -- Level 5+ finale: boss arenas, elite packs (no bosses)
        levelType = "boss"
        encounterType = "elite"
    end

    local levelId = LevelSelector.select("forest", levelType)
    local level = LevelLoader.load("forest", levelType, levelId)
    Board.loadLevel(level)

    local encounterId = EncounterSelector.select("forest", encounterType)
    local encounter = EncounterLoader.load("forest", encounterType, encounterId)

    -- fresh framing for the new grid (transition zoomed in close)
    if (G.GRID or 10) >= 15 then G.zoom, G.zoomTarget = 1.5, 1.5
    else G.zoom, G.zoomTarget = 2.4, 2.4 end
    G.camX, G.camY = 0, 0
    G.win = nil
    G.winNextBtn, G.upgDescendBtn, G.upgSlotBtns = nil, nil, nil
    G.arrows = {}
    Units.clearEnemies()
    -- reposition + restore the whole squad at fresh player spawns
    do
        local hi = 0
        for _, u in ipairs(G.units) do
            if u.team ~= "enemy" then
                hi = hi + 1
                local ps = G.playerSpawns[hi] or G.playerSpawns[1]
                u.map = "over"
                u.gx, u.gy = ps.x, ps.y
                u.px, u.py, u.fx, u.fy = u.gx, u.gy, u.gx, u.gy
                u.path, u.t = {}, 0
                u.moved, u.attacked, u.acted = false, false, false
                u.hp, u.mana = u.maxHP, u.maxMana -- descend fully restores the party
            end
        end
    end
    G.round = 1
    G.levelKills, G.levelCoins, G.levelHp = 0, 0, 0
    Units.spawnEncounterEnemies(encounter)
    Units.buildTurnOrder()
    G.pushLog("LEVEL " .. G.runLevel .. " — " .. levelId .. " + " .. encounterId .. " — party restored")
    Render.banner("LEVEL " .. G.runLevel, levelId .. "  ·  " .. encounterId)
    if encounterType == "elite" and G.playSfx then
        G.playSfx("elite", 0.9)
    end
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
    if G.playSfx then G.playSfx("clear", 0.9) end
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
    local base = (G.GRID >= 15) and 1.5 or 2.4
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
    G.zoom, G.zoomTarget = 2.4, 2.4
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
    G.zoom, G.zoomTarget = 2.4, 2.4
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
        if G.menuIdx == 1 then M.push("modes")
        elseif G.menuIdx == 2 then M.push("editor_admin")
        elseif G.menuIdx == 3 then M.push("settings")
        else love.event.quit() end
    elseif G.menuScreen == "modes" then
        if G.menuIdx == 1 then M.push("select")
        elseif G.menuIdx == 2 then M.applyMode("free"); G.state = "game"
        else M.pop() end
    elseif G.menuScreen == "select" then
        if G.menuIdx == 1 then M.confirmSelect()
        else M.pop() end
    elseif G.menuScreen == "settings" then
        -- click the volume row to step up (wraps to mute); BACK leaves.
        if G.menuIdx == 1 then M.adjustVolume(1, true)
        else M.pop() end
    elseif G.menuScreen == "editor_admin" then
        M.pop()
    else
        M.pop()
    end
end

-- menu key handling. Returns true (consumed).
function M.keypressed(key)
    if G.phase == "shop" then
        M.shopKeypressed(key)
        return true
    end
    if G.menuScreen == "select" then
        -- left/right (or A/D) picks livery, up/down (or W/S) picks class,
        -- ENTER confirms.
        if key == "left" or key == "a" then M.switchSelect(-1)
        elseif key == "right" or key == "d" then M.switchSelect(1)
        elseif key == "up" or key == "w" or key == "down" or key == "s" then M.switchKind()
        elseif key == "return" or key == "space" then M.confirmSelect()
        elseif key == "escape" then M.pop() end
        return true
    end
    if G.menuScreen == "editor_admin" then
        if key == "escape" then M.pop()
        elseif key == "f" then M.cycleAdminFilter()
        elseif key == "n" then M.newMap()
        end
        return true
    end
    if G.menuScreen == "path_choice" then
        local n = #M.items()
        if key == "up" or key == "w" then G.menuIdx = ((G.menuIdx - 2) % n) + 1
        elseif key == "down" or key == "s" then G.menuIdx = (G.menuIdx % n) + 1
        elseif key == "return" or key == "space" then
            if G.menuIdx <= 2 then M.confirmPathChoice(G.menuIdx == 1 and "normal" or "elite")
            else M.resetToMain() end
        elseif key == "escape" then M.resetToMain() end
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
        elseif key == "escape" then M.pop() end
        return true
    end
    if key == "up" or key == "w" then G.menuIdx = ((G.menuIdx - 2) % n) + 1
    elseif key == "down" or key == "s" then G.menuIdx = (G.menuIdx % n) + 1
    elseif key == "return" or key == "space" then M.activate()
    elseif key == "escape" then
        if M.top() ~= "main" then M.pop()
        else love.event.quit() end
    end
    return true
end

-- ---------- pause overlay (in-game) ----------
M.pauseItems = { "RESUME", "SAVE & QUIT", "SETTINGS", "MAIN MENU" }
M.pauseIdx = 1
M.pauseBtns = {}

function M.pushPause()
    G.paused = true
    M.pauseIdx = 1
end
function M.popPause()
    G.paused = false
end
function M.pauseKeypressed(key)
    local n = #M.pauseItems
    if key == "up" or key == "w" then M.pauseIdx = ((M.pauseIdx - 2) % n) + 1
    elseif key == "down" or key == "s" then M.pauseIdx = (M.pauseIdx % n) + 1
    elseif key == "return" or key == "space" then M.activatePause()
    end
end
function M.activatePause()
    local sel = M.pauseItems[M.pauseIdx]
    if sel == "RESUME" then
        G.paused = false
    elseif sel == "SAVE & QUIT" then
        M.syncSave()
        G.paused = false
        M.resetToMain()
    elseif sel == "SETTINGS" then
        -- adjust volume in place with left/right; keep simple: step up
        M.adjustVolume(1, true)
    elseif sel == "MAIN MENU" then
        G.paused = false
        M.resetToMain()
    end
end
function M.clickPause(x, y)
    for i, b in ipairs(M.pauseBtns or {}) do
        if b and x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h then
            M.pauseIdx = i
            M.activatePause()
            return true
        end
    end
    return false
end
function M.drawPause(time)
    local C = G.C
    -- dim backdrop over board
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", 0, 0, G.W, G.H)
    local cx = G.W / 2
    local bw, bh = 320, 44
    local startY = G.H / 2 - (#M.pauseItems * 52) / 2
    love.graphics.setFont(G.fontTitle)
    love.graphics.setColor(C.ink)
    love.graphics.printf("PAUSED", 0, startY - 70, G.W, "center")
    love.graphics.setFont(G.fontBody)
    M.pauseBtns = {}
    local mx, my = love.mouse.getPosition()
    for i, label in ipairs(M.pauseItems) do
        local by = startY + (i - 1) * 52
        local bx = cx - bw / 2
        local hot = (i == M.pauseIdx) or (mx >= bx and mx <= bx + bw and my >= by and my <= by + bh)
        love.graphics.setColor(hot and C.select or C.panel)
        if hot then love.graphics.rectangle("fill", bx, by, bw, bh, 6, 6) end
        love.graphics.setColor(hot and C.panel or C.selInk)
        if not hot then love.graphics.setColor(C.panelLn) end
        love.graphics.rectangle(hot and "fill" or "line", bx, by, bw, bh, 6, 6)
        love.graphics.setColor(hot and C.panel or C.selInk)
        if not hot then love.graphics.setColor(C.muted) end
        if i == M.pauseIdx then love.graphics.setColor(C.selInk) end
        love.graphics.printf(label, bx, by + 12, bw, "center")
        M.pauseBtns[i] = { x = bx, y = by, w = bw, h = bh }
    end
    love.graphics.setFont(G.fontSmall)
    love.graphics.setColor(C.muted)
    love.graphics.printf("ESC — RESUME · VOL " .. (G.volume or 8) .. "/10 (SETTINGS steps volume)", 0, startY + #M.pauseItems * 52 + 10, G.W, "center")
end

-- ---------- editor admin ----------
function M.cycleAdminFilter()
    local order = { "All", "Normal", "Elite", "Boss" }
    for i, f in ipairs(order) do
        if f == M.adminFilter then
            M.adminFilter = order[(i % #order) + 1]
            return
        end
    end
    M.adminFilter = "All"
end
function M.newMap()
    local LevelEditor = require("systems.level_editor")
    local LevelLoader = nil
    -- create blank map in editor buffer, enter game state for editing
    local blank = {
        id = "custom_" .. os.time() % 100000,
        area = "forest", type = "normal",
        width = 10, height = 10,
        tiles = {}, heights = {},
        player_spawns = { { x = 2, y = 9 }, { x = 3, y = 9 } },
        enemy_spawns = { { x = 8, y = 2 }, { x = 9, y = 2 } },
        tags = { "forest", "custom" },
    }
    for y = 1, 10 do
        blank.tiles[y] = {}
        blank.heights[y] = {}
        for x = 1, 10 do blank.tiles[y][x] = "grass"; blank.heights[y][x] = 0 end
    end
    G.currentLevel = blank
    Board.loadLevel(blank)
    G.state = "game"
    G.zoom, G.zoomTarget = 2.4, 2.4
    G.camX, G.camY = 0, 0
    LevelEditor.enabled = true
    LevelEditor.mode = "terrain"
    LevelEditor.onExit = function(saved)
        G.state = "menu"
        M.replace("editor_admin")
    end
    LevelEditor.dirty = false
end
function M.editMap(map)
    local LevelLoader = require("systems.level_loader")
    local LevelValidator = require("systems.level_validator")
    local LevelEditor = require("systems.level_editor")
    -- Lenient load: broken maps must still open so they can be repaired.
    -- validateOrThrow would crash here; validate and report instead.
    local level = nil
    local path = "levels/" .. map.area .. "/" .. map.type .. "/" .. map.id .. ".lua"
    local chunk = love.filesystem.load(path)
    if chunk then
        local ok, data = pcall(chunk)
        if ok and data then
            level = LevelLoader.validate(data, map.area, map.type)
            local result = LevelValidator.validate(level)
            if not result.valid then
                G.pushLog("EDITING BROKEN MAP — fix these:")
                for _, e in ipairs(result.errors) do G.pushLog("  ERR: " .. e) end
            end
        end
    end
    if not level then
        G.pushLog("Cannot load " .. map.id)
        return
    end
    G.currentLevel = level
    Board.loadLevel(level)
    G.state = "game"
    G.zoom, G.zoomTarget = 2.4, 2.4
    G.camX, G.camY = 0, 0
    LevelEditor.enabled = true
    LevelEditor.mode = "terrain"
    LevelEditor.dirty = false
    LevelEditor.onExit = function(saved)
        G.state = "menu"
        M.replace("editor_admin")
    end
    G.pushLog("EDITING " .. map.id)
end
function M.testMap(map)
    local LevelLoader = require("systems.level_loader")
    local EncounterSelector = require("systems.encounter_selector")
    local EncounterLoader = require("systems.encounter_loader")
    local ok, level = pcall(LevelLoader.load, map.area, map.type, map.id)
    if not ok or not level then
        G.pushLog("Cannot TEST " .. map.id .. ": fails validation — EDIT it first")
        return
    end
    Board.loadLevel(level)
    G.gameMode = "run"
    G.runLevel = 1
    G.runPathChoice = (map.type == "elite") and "elite" or "normal"
    local etype = (map.type == "elite" or map.type == "boss") and "elite" or "normal"
    local encounterId = EncounterSelector.select("forest", etype)
    local encounter = EncounterLoader.load("forest", etype, encounterId)
    G.zoom, G.zoomTarget = 2.4, 2.4
    G.camX, G.camY = 0, 0
    local playerSpawn = G.playerSpawns[1]
    G.units = { Units.spawnUnit(G.roster[1]) }
    G.units[1].gx, G.units[1].gy = playerSpawn.x, playerSpawn.y
    G.units[1].px, G.units[1].py = playerSpawn.x, playerSpawn.y
    G.units[1].fx, G.units[1].fy = playerSpawn.x, playerSpawn.y
    G.activeIdx = 1
    G.round, G.wiped = 1, false
    G.coins, G.levelKills, G.levelCoins, G.levelHp, G.win = 0, 0, 0, 0, nil
    Units.spawnEncounterEnemies(encounter)
    Units.buildTurnOrder()
    G.state = "game"
    G.paused = false
    G.pushLog("TEST " .. map.id .. " + " .. encounterId)
    Render.banner("TEST", map.id .. "  ·  " .. encounterId)
end
function M.deleteMap(map)
    -- NOTE: love.filesystem.remove only deletes from the save dir, so this
    -- works for generated/custom maps (saved via editor) but not for
    -- source-bundled handcrafted maps.
    local ok = love.filesystem.remove(map.path)
    if ok then
        G.pushLog("DELETED " .. map.id)
    else
        G.pushLog("Cannot delete " .. map.id .. " (bundled map)")
    end
end
function M.drawAdmin(time)
    local C = G.C
    local cx = G.W / 2
    love.graphics.setFont(G.fontSmall)
    love.graphics.setColor(C.muted)
    love.graphics.printf("FILTER [F] " .. M.adminFilter .. " · [N]EW MAP · ESC BACK", 0, G.H * 0.22 + 62, G.W, "center")
    local maps = M.filteredMaps()
    local startY = G.H * 0.22 + 90
    local rowH = 34
    local maxRows = math.floor((G.H - startY - 80) / rowH)
    M.adminRows = {}
    M.adminButtons = {}
    love.graphics.setFont(G.fontSmall)
    for i = 1, math.min(#maps, maxRows) do
        local m = maps[i]
        local ry = startY + (i - 1) * rowH
        local rx = cx - 380
        local rw = 760
        love.graphics.setColor(C.panel)
        love.graphics.rectangle("fill", rx, ry, rw, rowH - 4, 4, 4)
        love.graphics.setColor(C.panelLn)
        love.graphics.rectangle("line", rx, ry, rw, rowH - 4, 4, 4)
        love.graphics.setColor(C.ink)
        love.graphics.print(m.type .. "/" .. m.id, rx + 10, ry + 8)
        -- buttons
        local btns = { "EDIT", "TEST", "DEL" }
        for j, b in ipairs(btns) do
            local bw, bh = 64, 22
            local bx = rx + rw - (4 - j) * (bw + 8)
            local by = ry + 4
            love.graphics.setColor(C.panelLn)
            love.graphics.rectangle("line", bx, by, bw, bh, 3, 3)
            love.graphics.setColor(C.muted)
            love.graphics.printf(b, bx, by + 4, bw, "center")
            M.adminButtons[#M.adminButtons + 1] = { x = bx, y = by, w = bw, h = bh, action = b, map = m }
        end
    end
    if #maps == 0 then
        love.graphics.setColor(C.muted)
        love.graphics.printf("No maps found.", 0, startY + 20, G.W, "center")
    end
    love.graphics.setColor(C.muted)
    love.graphics.printf("Click EDIT to open in editor · TEST for quick battle · DEL removes file", 0, G.H - 60, G.W, "center")
end
function M.clickAdmin(x, y)
    for _, b in ipairs(M.adminButtons or {}) do
        if x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h then
            if b.action == "EDIT" then M.editMap(b.map)
            elseif b.action == "TEST" then M.testMap(b.map)
            elseif b.action == "DEL" then M.deleteMap(b.map) end
            return true
        end
    end
    return false
end

return M

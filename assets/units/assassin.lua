-- assassin.lua — hooded dual-dagger skirmisher: cowl + mask, cloak,
-- team-color eyes/trim, twin daggers with slash animation on attack.
local M = {}
local Sigil = require("assets.units.sigil")

local STEEL_L = {0.82, 0.83, 0.88}
local STEEL_D = {0.38, 0.39, 0.44}
local INK     = {0.08, 0.08, 0.10}
local CLOAK   = {0.16, 0.16, 0.20}
local CLOAK_D = {0.10, 0.10, 0.13}

-- shared swing clock: set by Units.orderAttack (0.35 s slash window)
local function swingT(u)
    if not u.swingT then return nil end
    local t = love.timer.getTime() - u.swingT
    if t < 0 or t > 0.35 then return nil end
    return t / 0.35 -- 0..1 progress
end

-- screen side of the target: iso x-axis runs (gx - gy)
local function targetSide(u)
    local sx = (u.swingDx or 1) - (u.swingDy or 0)
    if sx >= 0 then return 1 end
    return -1
end

function M.drawAssassin(u, time, G, Board, C)
    local hgt = G.heights[u.gy] and G.heights[u.gy][u.gx] or 0
    local k = u.gx .. "," .. u.gy
    local l = G.lift[k] or 0
    local moving = #u.path > 0
    local hop = moving and math.sin(math.min(1, u.t / G.STEP_TIME) * math.pi) * 4 or 0
    local sq = G.squash[u.id] or 0
    local sx, sy = 1 + sq * 0.22, 1 - sq * 0.16
    local cx, cy = Board.tileToScreen(u.px, u.py, hgt * G.BLOCK_H + l + hop)
    local s = G.zoom

    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.scale(sx*s, sy*s)
    love.graphics.translate(-cx, -cy)

    local sw = swingT(u)
    local side = targetSide(u)
    local crouch = sw and math.sin(sw * math.pi) * 2 or 0

    -- legs: dark wraps
    love.graphics.setColor(CLOAK_D)
    love.graphics.rectangle("fill", cx-3.8, cy-11, 3, 8, 1, 1)
    love.graphics.rectangle("fill", cx+0.8, cy-11, 3, 8, 1, 1)
    -- cloak: flared trapezoid, team-color hem trim
    love.graphics.setColor(CLOAK)
    love.graphics.polygon("fill", {cx-6,cy-10+crouch, cx-3.6,cy-26, cx+3.6,cy-26, cx+6,cy-10+crouch})
    love.graphics.setColor(u.color)
    love.graphics.polygon("fill", {cx-6,cy-10+crouch, cx-4.6,cy-10+crouch, cx-3.2,cy-24, cx-4.2,cy-24})
    love.graphics.polygon("fill", {cx+6,cy-10+crouch, cx+4.6,cy-10+crouch, cx+3.2,cy-24, cx+4.2,cy-24})
    -- belt + buckle
    love.graphics.setColor(INK)
    love.graphics.rectangle("fill", cx-3.6, cy-16, 7.2, 1.6)
    love.graphics.setColor(STEEL_L)
    love.graphics.rectangle("fill", cx-1, cy-16, 2, 1.6)

    -- arms + twin daggers
    for _, sgn in ipairs({-1, 1}) do
        local ax = cx + sgn * 5.6
        love.graphics.setColor(CLOAK_D)
        love.graphics.rectangle("fill", ax - 1.1, cy-24, 2.2, 9, 1, 1)
        -- dagger: hilt + short blade, raised when swinging on this side
        local raise = (sw and sgn == side) and math.sin(sw * math.pi) * 10 or 0
        local hx, hy = ax, cy - 14 - raise
        love.graphics.setColor(INK)
        love.graphics.rectangle("fill", hx - 0.7, hy - 2, 1.4, 3)
        love.graphics.setColor(STEEL_L)
        love.graphics.rectangle("fill", hx - 0.6, hy - 9, 1.2, 7)
        love.graphics.setColor(u.color)
        love.graphics.circle("fill", hx, hy + 1.4, 1.1)
    end

    -- cloak clasp + chosen sigil at the throat
    love.graphics.setColor(INK)
    love.graphics.circle("fill", cx, cy - 24, 2.2)
    Sigil.draw(u.sigil or "cross", cx, cy - 24, 1.6, u.color)
    love.graphics.setColor(CLOAK)
    love.graphics.circle("fill", cx, cy-31, 6.4)
    love.graphics.polygon("fill", {cx-6.4,cy-31, cx-4.4,cy-25, cx+4.4,cy-25, cx+6.4,cy-31})
    love.graphics.setColor(CLOAK_D)
    love.graphics.ellipse("fill", cx, cy-29.5, 4.4, 3.6)
    -- glowing eyes (team color)
    love.graphics.setColor(u.color)
    love.graphics.circle("fill", cx - 1.8, cy-30, 1.1)
    love.graphics.circle("fill", cx + 1.8, cy-30, 1.1)
    -- hood peak
    love.graphics.setColor(CLOAK)
    love.graphics.polygon("fill", {cx-1.4,cy-37, cx+1.4,cy-37, cx,cy-40.5})

    -- slash swoosh on the target side while swinging
    if sw then
        local a = math.sin(sw * math.pi)
        love.graphics.setColor(1, 1, 1, 0.75 * a)
        love.graphics.setLineWidth(2.5)
        local bx = cx + side * 8
        love.graphics.arc("line", "open", bx, cy - 22, 9, -1.1 + sw * 1.4 * side, 1.1 + sw * 1.4 * side)
        love.graphics.setLineWidth(1)
    end

    love.graphics.pop()

    if G.units[G.activeIdx]==u then
        love.graphics.setColor(C.select)
        love.graphics.setLineWidth(2)
        love.graphics.ellipse("line", cx, cy-2*s, 16*s, 7*s)
        love.graphics.setLineWidth(1)
        local bob = math.sin(love.timer.getTime()*2)*2
        local nw,nh = 64*G.zoom,18*G.zoom
        local nx,ny = cx-nw/2, cy-60*s+bob
        love.graphics.setColor(0.05,0.07,0.10,0.92)
        love.graphics.rectangle("fill", nx, ny, nw, nh, 5,5)
        love.graphics.setColor(C.select)
        love.graphics.rectangle("line", nx, ny, nw, nh, 5,5)
        love.graphics.setFont(G.fontSmall)
        love.graphics.setColor(C.selInk)
        love.graphics.printf(u.name:upper(), nx, ny+3*G.zoom, nw, "center")
    end
end

function M.drawBust(cx, feet, color, dark, scale, sigil)
    scale = scale or 1
    sigil = sigil or "cross"
    love.graphics.setColor(dark[1]*0.5, dark[2]*0.5, dark[3]*0.5)
    love.graphics.ellipse("fill", cx, feet, 8*scale, 3.5*scale)
    -- cloak body + team hem
    love.graphics.setColor(CLOAK)
    love.graphics.polygon("fill", {cx-7*scale,feet-9*scale, cx-4*scale,feet-27*scale,
        cx+4*scale,feet-27*scale, cx+7*scale,feet-9*scale})
    love.graphics.setColor(color)
    love.graphics.polygon("fill", {cx-7*scale,feet-9*scale, cx-5.4*scale,feet-9*scale,
        cx-3.4*scale,feet-25*scale, cx-4.6*scale,feet-25*scale})
    love.graphics.polygon("fill", {cx+7*scale,feet-9*scale, cx+5.4*scale,feet-9*scale,
        cx+3.4*scale,feet-25*scale, cx+4.6*scale,feet-25*scale})
    -- daggers
    for _, sgn in ipairs({-1, 1}) do
        local hx = cx + sgn * 6.4 * scale
        love.graphics.setColor(INK)
        love.graphics.rectangle("fill", hx-0.7*scale, feet-16*scale, 1.4*scale, 3*scale)
        love.graphics.setColor(STEEL_L)
        love.graphics.rectangle("fill", hx-0.6*scale, feet-23*scale, 1.2*scale, 7*scale)
    end
    -- clasp + chosen sigil at the throat
    love.graphics.setColor(INK)
    love.graphics.circle("fill", cx, feet-25*scale, 2.4*scale)
    Sigil.draw(sigil, cx, feet-25*scale, 1.7*scale, color)
    -- hood + glowing eyes
    love.graphics.setColor(CLOAK)
    love.graphics.circle("fill", cx, feet-32*scale, 7*scale)
    love.graphics.setColor(CLOAK_D)
    love.graphics.ellipse("fill", cx, feet-30*scale, 4.8*scale, 3.8*scale)
    love.graphics.setColor(color)
    love.graphics.circle("fill", cx-2*scale, feet-30.4*scale, 1.2*scale)
    love.graphics.circle("fill", cx+2*scale, feet-30.4*scale, 1.2*scale)
    love.graphics.setColor(CLOAK)
    love.graphics.polygon("fill", {cx-1.6*scale,feet-38*scale, cx+1.6*scale,feet-38*scale, cx,feet-42*scale})
end

function M.drawChip(cx, y, r, color, dark, alpha)
    local function col(c,a) return {c[1],c[2],c[3],(a or 1)*(alpha or 1)} end
    -- dark cowl disc
    love.graphics.setColor(col(CLOAK_D))
    love.graphics.circle("fill", cx, y, r)
    love.graphics.setColor(col(CLOAK))
    love.graphics.circle("fill", cx, y, r-2.5)
    -- face shadow + glowing eyes
    love.graphics.setColor(col(INK))
    love.graphics.ellipse("fill", cx, y+1, r*0.5, r*0.42)
    love.graphics.setColor(col(color))
    love.graphics.circle("fill", cx-r*0.2, y, r*0.11)
    love.graphics.circle("fill", cx+r*0.2, y, r*0.11)
    -- crossed daggers hint
    love.graphics.setColor(col(STEEL_L, 0.9))
    love.graphics.setLineWidth(2)
    love.graphics.line(cx-r*0.45, y+r*0.5, cx+r*0.2, y-r*0.15)
    love.graphics.line(cx+r*0.45, y+r*0.5, cx-r*0.2, y-r*0.15)
    love.graphics.setLineWidth(1)
end

return M

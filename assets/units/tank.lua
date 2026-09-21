-- tank.lua — walking fortress: bulky plate, tower shield, warhammer.
-- Hammer raises + shockwave ring on attack (u.swingT window from orderAttack).
local M = {}
local Sigil = require("assets.units.sigil")

local STEEL_L = {0.80, 0.81, 0.85}
local STEEL_M = {0.55, 0.57, 0.62}
local STEEL_D = {0.33, 0.34, 0.38}
local STEEL_HI = {0.95, 0.96, 1.00}
local INK     = {0.10, 0.11, 0.13}
local BRASS   = {0.55, 0.42, 0.20}

function M.drawTank(u, time, G, Board, C)
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

    local sw = u.swingT and (love.timer.getTime() - u.swingT) or 99
    local swinging = sw >= 0 and sw < 0.35
    local k2 = swinging and math.sin((sw / 0.35) * math.pi) or 0
    local sxn = (u.swingDx or 1) - (u.swingDy or 0)
    local side = sxn >= 0 and 1 or -1

    -- legs: heavy sabatons + thick greaves
    love.graphics.setColor(STEEL_D)
    love.graphics.ellipse("fill", cx-3, cy-3, 3.4, 1.8)
    love.graphics.ellipse("fill", cx+3, cy-3, 3.4, 1.8)
    love.graphics.setColor(STEEL_M)
    love.graphics.rectangle("fill", cx-5, cy-12, 4, 9, 1, 1)
    love.graphics.rectangle("fill", cx+1, cy-12, 4, 9, 1, 1)
    love.graphics.setColor(STEEL_L)
    love.graphics.rectangle("fill", cx-5, cy-12, 1.4, 9, 1, 1)
    love.graphics.rectangle("fill", cx+1, cy-12, 1.4, 9, 1, 1)

    -- torso: barrel cuirass, rivets, team-color girth band
    love.graphics.setColor(STEEL_D)
    love.graphics.polygon("fill", {cx-7,cy-11, cx-5,cy-28, cx+5,cy-28, cx+7,cy-11})
    love.graphics.setColor(STEEL_M)
    love.graphics.polygon("fill", {cx-5.4,cy-12, cx-3.8,cy-27, cx+3.8,cy-27, cx+5.4,cy-12})
    love.graphics.setColor(u.color)
    love.graphics.rectangle("fill", cx-5.4, cy-19, 10.8, 2.4)
    love.graphics.setColor(STEEL_D)
    for _, rx in ipairs({-4, -1.4, 1.4, 4}) do
        love.graphics.circle("fill", cx + rx, cy - 14.5, 0.8)
        love.graphics.circle("fill", cx + rx, cy - 23.5, 0.8)
    end
    -- massive pauldrons
    for _, sgn in ipairs({-1, 1}) do
        love.graphics.setColor(STEEL_D)
        love.graphics.circle("fill", cx + sgn * 6.6, cy - 27, 3.6)
        love.graphics.setColor(STEEL_M)
        love.graphics.circle("fill", cx + sgn * 6.6, cy - 27.7, 3.6)
        love.graphics.setColor(STEEL_L)
        love.graphics.ellipse("fill", cx + sgn * 7.4, cy - 28.8, 2, 1.5)
    end

    -- tower shield on the left arm (team rim)
    love.graphics.setColor(STEEL_D)
    love.graphics.rectangle("fill", cx - 11.5, cy - 30, 6.4, 20, 2, 2)
    love.graphics.setColor(STEEL_M)
    love.graphics.rectangle("fill", cx - 11.5, cy - 30, 6.4, 17, 2, 2)
    love.graphics.setColor(u.color)
    love.graphics.rectangle("fill", cx - 11.5, cy - 30, 1.6, 20, 2, 2)
    love.graphics.rectangle("fill", cx - 11.5, cy - 13.5, 6.4, 2.2, 1, 1)
    love.graphics.setColor(STEEL_D)
    love.graphics.circle("fill", cx - 8.3, cy - 20, 2.6)
    -- chosen sigil on the shield face
    Sigil.draw(u.sigil or "cross", cx - 8.3, cy - 20, 1.9, u.color)

    -- warhammer in the right hand: haft + head, raised on swing
    do
        local hx = cx + side * 7
        local hy = cy - 15 - k2 * 10
        local ang = swinging and (-0.9 + (sw / 0.35) * 1.8 * side) or 0.12 * side
        love.graphics.push()
        love.graphics.translate(hx, hy)
        love.graphics.rotate(ang)
        love.graphics.setColor({0.35, 0.25, 0.15})
        love.graphics.rectangle("fill", -1, -14, 2, 15)
        love.graphics.setColor(STEEL_M)
        love.graphics.rectangle("fill", -3.4, -19, 6.8, 5, 1, 1)
        love.graphics.setColor(STEEL_L)
        love.graphics.rectangle("fill", -3.4, -19, 6.8, 1.6, 1, 1)
        love.graphics.setColor(BRASS)
        love.graphics.rectangle("fill", -1.2, 1, 2.4, 2)
        love.graphics.pop()
        -- shockwave ring at impact
        if swinging and k2 > 0.5 then
            love.graphics.setColor(1, 1, 1, 0.5 * k2)
            love.graphics.setLineWidth(2)
            love.graphics.ellipse("line", cx + side * 10, cy - 6, 12 * k2, 5 * k2)
            love.graphics.setLineWidth(1)
        end
    end

    -- helm: flat-topped great helm, narrow slit, team brow band
    love.graphics.setColor(STEEL_D)
    love.graphics.rectangle("fill", cx-6.5, cy-41, 13, 12, 2, 2)
    love.graphics.setColor(STEEL_M)
    love.graphics.rectangle("fill", cx-6.5, cy-41, 13, 9, 2, 2)
    love.graphics.setColor(u.color)
    love.graphics.rectangle("fill", cx-6.5, cy-38.5, 13, 2.4)
    love.graphics.setColor(STEEL_HI)
    love.graphics.rectangle("fill", cx-6, cy-40.5, 1.2, 8)
    love.graphics.setColor(INK)
    love.graphics.rectangle("fill", cx-4.5, cy-35, 9, 2.2, 1, 1)

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
    love.graphics.ellipse("fill", cx, feet, 10*scale, 4*scale)
    -- barrel torso + team band + rivets
    love.graphics.setColor(STEEL_D)
    love.graphics.polygon("fill", {cx-8*scale,feet-9*scale, cx-5.6*scale,feet-29*scale,
        cx+5.6*scale,feet-29*scale, cx+8*scale,feet-9*scale})
    love.graphics.setColor(STEEL_M)
    love.graphics.polygon("fill", {cx-6*scale,feet-10*scale, cx-4.2*scale,feet-28*scale,
        cx+4.2*scale,feet-28*scale, cx+6*scale,feet-10*scale})
    love.graphics.setColor(color)
    love.graphics.rectangle("fill", cx-6*scale, feet-20*scale, 12*scale, 2.6*scale)
    -- pauldrons
    for _, sgn in ipairs({-1, 1}) do
        love.graphics.setColor(STEEL_D)
        love.graphics.circle("fill", cx+sgn*7.4*scale, feet-28*scale, 3.8*scale)
        love.graphics.setColor(STEEL_M)
        love.graphics.circle("fill", cx+sgn*7.4*scale, feet-28.7*scale, 3.8*scale)
    end
    -- tower shield hint on the left + chosen sigil
    love.graphics.setColor(STEEL_D)
    love.graphics.rectangle("fill", cx-13*scale, feet-31*scale, 7*scale, 21*scale, 2*scale, 2*scale)
    love.graphics.setColor(color)
    love.graphics.rectangle("fill", cx-13*scale, feet-31*scale, 1.8*scale, 21*scale, 2*scale, 2*scale)
    love.graphics.setColor(STEEL_D)
    love.graphics.circle("fill", cx-9.5*scale, feet-20*scale, 2.8*scale)
    Sigil.draw(sigil, cx-9.5*scale, feet-20*scale, 2*scale, color)
    -- hammer head hint on the right
    love.graphics.setColor(STEEL_M)
    love.graphics.rectangle("fill", cx+8.4*scale, feet-34*scale, 7*scale, 5*scale, 1*scale, 1*scale)
    -- flat helm + team band + slit
    love.graphics.setColor(STEEL_D)
    love.graphics.rectangle("fill", cx-7.4*scale, feet-43*scale, 14.8*scale, 13*scale, 2*scale, 2*scale)
    love.graphics.setColor(STEEL_M)
    love.graphics.rectangle("fill", cx-7.4*scale, feet-43*scale, 14.8*scale, 10*scale, 2*scale, 2*scale)
    love.graphics.setColor(color)
    love.graphics.rectangle("fill", cx-7.4*scale, feet-40*scale, 14.8*scale, 2.6*scale)
    love.graphics.setColor(INK)
    love.graphics.rectangle("fill", cx-5*scale, feet-36*scale, 10*scale, 2.4*scale, 1*scale, 1*scale)
end

function M.drawChip(cx, y, r, color, dark, alpha)
    local function col(c,a) return {c[1],c[2],c[3],(a or 1)*(alpha or 1)} end
    -- bulky helm disc
    love.graphics.setColor(col(STEEL_D))
    love.graphics.circle("fill", cx, y, r)
    love.graphics.setColor(col(STEEL_M))
    love.graphics.circle("fill", cx, y, r-2.5)
    -- team band + slit
    love.graphics.setColor(col(color))
    love.graphics.rectangle("fill", cx-r, y-r*0.35, r*2, r*0.22)
    love.graphics.setColor(col(INK))
    love.graphics.rectangle("fill", cx-r*0.42, y+r*0.05, r*0.84, r*0.16, 2,2)
    -- shield tick
    love.graphics.setColor(col(STEEL_L, 0.9))
    love.graphics.rectangle("fill", cx-r*0.75, y-r*0.1, r*0.22, r*0.55, 1,1)
end

return M

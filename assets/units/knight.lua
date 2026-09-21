-- knight.lua — minimal knight: clean great-helm + slab cuirass.
local M = {}
local Sigil = require("assets.units.sigil")

local STEEL_L = {0.86, 0.87, 0.90}
local STEEL_M = {0.60, 0.62, 0.66}
local STEEL_D = {0.36, 0.37, 0.41}
local STEEL_HI = {0.95, 0.96, 1.00} -- specular edge
local INK     = {0.10, 0.11, 0.13}

function M.drawKnight(u, time, G, Board, C)
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

    -- legs: slightly tapered greaves
    love.graphics.setColor(STEEL_M)
    love.graphics.rectangle("fill", cx-4.2, cy-12, 3.4, 9, 1, 1)
    love.graphics.rectangle("fill", cx+0.8, cy-12, 3.4, 9, 1, 1)
    love.graphics.setColor(STEEL_L)
    love.graphics.rectangle("fill", cx-4.2, cy-12, 1.2, 9, 1, 1)
    love.graphics.rectangle("fill", cx+0.8, cy-12, 1.2, 9, 1, 1)
    love.graphics.setColor(STEEL_D)
    love.graphics.ellipse("fill", cx-2.5, cy-3, 2.8, 1.6)
    love.graphics.ellipse("fill", cx+2.5, cy-3, 2.8, 1.6)

    -- torso: slab cuirass with subtle bevel
    love.graphics.setColor(STEEL_D)
    love.graphics.polygon("fill", {cx-5.5,cy-12, cx-4,cy-27, cx+4,cy-27, cx+5.5,cy-12})
    love.graphics.setColor(STEEL_M)
    love.graphics.polygon("fill", {cx-4,cy-13, cx-3,cy-26, cx+3,cy-26, cx+4,cy-13})
    love.graphics.setColor(STEEL_L)
    love.graphics.polygon("fill", {cx-3,cy-14, cx-2.2,cy-25, cx-0.8,cy-25, cx-1.4,cy-14})
    -- team stripe (tabard) + chosen sigil in cream steel
    love.graphics.setColor(u.color)
    love.graphics.rectangle("fill", cx-1.4, cy-24, 2.8, 11)
    Sigil.draw(u.sigil or "cross", cx, cy-19, 2.2, STEEL_HI)

    -- arms: vambraces + gauntlets
    love.graphics.setColor(STEEL_M)
    love.graphics.rectangle("fill", cx-7, cy-25, 2.4, 10, 1, 1)
    love.graphics.rectangle("fill", cx+4.6, cy-25, 2.4, 10, 1, 1)
    love.graphics.setColor(STEEL_L)
    love.graphics.rectangle("fill", cx-7, cy-25, 0.9, 10, 1, 1)
    love.graphics.rectangle("fill", cx+4.6, cy-25, 0.9, 10, 1, 1)
    love.graphics.setColor(STEEL_D)
    love.graphics.circle("fill", cx-5.8, cy-14, 1.7)
    love.graphics.circle("fill", cx+5.8, cy-14, 1.7)

    -- arming sword in the right hand: rests point-down, swings on attack.
    -- u.swingT / swingDx / swingDy are set by Units.orderAttack (0.35 s window).
    do
        local sw = u.swingT and (love.timer.getTime() - u.swingT) or 99
        local swinging = sw >= 0 and sw < 0.35
        local k = swinging and math.sin((sw / 0.35) * math.pi) or 0
        local sx = (u.swingDx or 1) - (u.swingDy or 0)
        local side = sx >= 0 and 1 or -1
        local hx = cx + side * 5.8
        local hy = cy - 14 - k * 8
        -- blade (up when swinging, down at rest)
        love.graphics.setColor(STEEL_L)
        if swinging then
            love.graphics.rectangle("fill", hx - 1, hy - 16, 2, 13)
            love.graphics.polygon("fill", {hx - 1, hy - 16, hx + 1, hy - 16, hx, hy - 19})
        else
            love.graphics.rectangle("fill", hx - 1, hy - 2, 2, 13)
            love.graphics.polygon("fill", {hx - 1, hy + 11, hx + 1, hy + 11, hx, hy + 14})
        end
        -- guard + grip + pommel
        love.graphics.setColor({0.55, 0.42, 0.20})
        love.graphics.rectangle("fill", hx - 2.6, hy - 3, 5.2, 1.4)
        love.graphics.setColor(STEEL_D)
        love.graphics.rectangle("fill", hx - 0.8, hy - 2, 1.6, 3)
        love.graphics.circle("fill", hx, hy + 1.6, 1.1)
        -- swoosh arc while swinging
        if swinging then
            love.graphics.setColor(1, 1, 1, 0.7 * k)
            love.graphics.setLineWidth(2.5)
            love.graphics.arc("line", "open", cx + side * 9, cy - 22, 11,
                -1.2 + (sw / 0.35) * 1.6 * side, 1.2 + (sw / 0.35) * 1.6 * side)
            love.graphics.setLineWidth(1)
        end
    end

    -- pauldrons: lames suggestion
    love.graphics.setColor(STEEL_D)
    love.graphics.circle("fill", cx-5.4, cy-26, 2.8)
    love.graphics.setColor(STEEL_M)
    love.graphics.circle("fill", cx-5.4, cy-26.6, 2.8)
    love.graphics.setColor(STEEL_L)
    love.graphics.ellipse("fill", cx-6, cy-27.5, 1.6, 1.2)
    love.graphics.setColor(STEEL_D)
    love.graphics.circle("fill", cx+5.4, cy-26, 2.8)
    love.graphics.setColor(STEEL_M)
    love.graphics.circle("fill", cx+5.4, cy-26.6, 2.8)
    love.graphics.setColor(STEEL_L)
    love.graphics.ellipse("fill", cx+4.8, cy-27.5, 1.6, 1.2)

    -- gorget
    love.graphics.setColor(STEEL_D)
    love.graphics.ellipse("fill", cx, cy-27.2, 3.8, 1.8)
    love.graphics.setColor(STEEL_M)
    love.graphics.ellipse("fill", cx, cy-27.8, 3.8, 1.8)

    -- helm: great-helm whose whole face is a crusader cross (team color)
    love.graphics.setColor(STEEL_D)
    love.graphics.rectangle("fill", cx-6, cy-40, 12, 12, 2, 2)
    -- cross: vertical beam + horizontal beam across the face
    love.graphics.setColor(u.color)
    love.graphics.rectangle("fill", cx-2.2, cy-40, 4.4, 12, 1, 1)
    love.graphics.rectangle("fill", cx-6, cy-37.5, 12, 4.4, 1, 1)
    -- steel edge light on the cross
    love.graphics.setColor(STEEL_HI)
    love.graphics.rectangle("fill", cx-2.2, cy-40, 1.1, 12)
    love.graphics.rectangle("fill", cx-6, cy-37.5, 12, 1.1)
    -- visor slit cut across the lower beam
    love.graphics.setColor(INK)
    love.graphics.rectangle("fill", cx-4, cy-33.5, 8, 2, 1, 1)
    -- eye holes punched through the horizontal beam
    love.graphics.circle("fill", cx-3.6, cy-35.4, 1.3)
    love.graphics.circle("fill", cx+3.6, cy-35.4, 1.3)
    -- crest
    love.graphics.setColor(u.color)
    love.graphics.polygon("fill", {cx-1,cy-42,cx+1,cy-42,cx,cy-45})

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
    -- legs (full body)
    love.graphics.setColor(STEEL_M)
    love.graphics.rectangle("fill", cx-4.2*scale, feet-12*scale, 3.4*scale, 9*scale, 1*scale, 1*scale)
    love.graphics.rectangle("fill", cx+0.8*scale, feet-12*scale, 3.4*scale, 9*scale, 1*scale, 1*scale)
    love.graphics.setColor(STEEL_D)
    love.graphics.ellipse("fill", cx-2.5*scale, feet-3*scale, 2.8*scale, 1.6*scale)
    love.graphics.ellipse("fill", cx+2.5*scale, feet-3*scale, 2.8*scale, 1.6*scale)
    -- arms / gauntlets
    love.graphics.setColor(STEEL_M)
    love.graphics.rectangle("fill", cx-10*scale, feet-22*scale, 2.8*scale, 10*scale, 1*scale, 1*scale)
    love.graphics.rectangle("fill", cx+7.2*scale, feet-22*scale, 2.8*scale, 10*scale, 1*scale, 1*scale)
    love.graphics.setColor(STEEL_D)
    love.graphics.circle("fill", cx-8.6*scale, feet-12*scale, 1.8*scale)
    love.graphics.circle("fill", cx+8.6*scale, feet-12*scale, 1.8*scale)
    -- shoulders/pauldrons
    love.graphics.setColor(STEEL_D)
    love.graphics.circle("fill", cx-6*scale, feet-20*scale, 3*scale)
    love.graphics.circle("fill", cx+6*scale, feet-20*scale, 3*scale)
    love.graphics.setColor(STEEL_M)
    love.graphics.circle("fill", cx-6*scale, feet-20.6*scale, 3*scale)
    love.graphics.circle("fill", cx+6*scale, feet-20.6*scale, 3*scale)
    love.graphics.setColor(STEEL_L)
    love.graphics.ellipse("fill", cx-6.6*scale, feet-21.5*scale, 1.8*scale, 1.3*scale)
    love.graphics.ellipse("fill", cx+5.4*scale, feet-21.5*scale, 1.8*scale, 1.3*scale)
    -- upper torso + tabard + chosen sigil
    love.graphics.setColor(STEEL_M)
    love.graphics.rectangle("fill", cx-7*scale, feet-21*scale, 14*scale, 10*scale, 2*scale, 2*scale)
    love.graphics.setColor(color)
    love.graphics.rectangle("fill", cx-1.8*scale, feet-21*scale, 3.6*scale, 10*scale)
    Sigil.draw(sigil, cx, feet-16*scale, 2.4*scale, STEEL_HI)
    -- helm: whole face is a crusader cross (team color)
    love.graphics.setColor(STEEL_D)
    love.graphics.rectangle("fill", cx-7*scale, feet-37*scale, 14*scale, 14*scale, 2*scale, 2*scale)
    love.graphics.setColor(color)
    love.graphics.rectangle("fill", cx-2.4*scale, feet-37*scale, 4.8*scale, 14*scale, 1*scale, 1*scale)
    love.graphics.rectangle("fill", cx-7*scale, feet-34.5*scale, 14*scale, 4.8*scale, 1*scale, 1*scale)
    love.graphics.setColor(STEEL_HI)
    love.graphics.rectangle("fill", cx-2.4*scale, feet-37*scale, 1.2*scale, 14*scale)
    love.graphics.rectangle("fill", cx-7*scale, feet-34.5*scale, 14*scale, 1.2*scale)
    love.graphics.setColor(INK)
    love.graphics.rectangle("fill", cx-4.5*scale, feet-30.5*scale, 9*scale, 2*scale, 1*scale, 1*scale)
    -- eye holes through the horizontal beam
    love.graphics.circle("fill", cx-4*scale, feet-32.1*scale, 1.4*scale)
    love.graphics.circle("fill", cx+4*scale, feet-32.1*scale, 1.4*scale)
    love.graphics.setColor(color)
    love.graphics.polygon("fill", {cx-1*scale,feet-39*scale,cx+1*scale,feet-39*scale,cx,feet-42*scale})
end

function M.drawChip(cx, y, r, color, dark, alpha)
    local function col(c,a) return {c[1],c[2],c[3],(a or 1)*(alpha or 1)} end
    love.graphics.setColor(col(STEEL_D))
    love.graphics.circle("fill", cx, y, r)
    love.graphics.setColor(col(STEEL_M))
    love.graphics.circle("fill", cx, y, r-2.5)
    love.graphics.setColor(col(STEEL_L))
    love.graphics.ellipse("fill", cx-r*0.12, y-r*0.18, r*0.4, r*0.32)
    -- helm face: full crusader cross (team color) with eye holes
    love.graphics.setColor(col(color))
    love.graphics.rectangle("fill", cx-r*0.12, y-r*0.55, r*0.24, r*1.1, 1,1)
    love.graphics.rectangle("fill", cx-r*0.45, y-r*0.35, r*0.9, r*0.24, 1,1)
    love.graphics.setColor(col(INK))
    love.graphics.circle("fill", cx-r*0.26, y-r*0.23, r*0.09)
    love.graphics.circle("fill", cx+r*0.26, y-r*0.23, r*0.09)
    love.graphics.rectangle("fill", cx-r*0.4, y+r*0.28, r*0.8, r*0.14, 2,2)
    love.graphics.setColor(col(color))
    love.graphics.circle("fill", cx+r*0.5, y-r*0.6, r*0.14)
end

return M
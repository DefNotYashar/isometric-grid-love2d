-- knight.lua — minimal knight: clean great-helm + slab cuirass.
local M = {}

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

    local shScale = 1 - math.min(0.35, (hop + l) * 0.02)
    love.graphics.setColor(C.shadow)
    love.graphics.ellipse("fill", cx, cy + 2*s, 13*s*shScale, 5.5*s*shScale)

    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.scale(sx*s, sy*s)
    love.graphics.translate(-cx, -cy)

    -- base disc (team)
    love.graphics.setColor(u.dark)
    love.graphics.ellipse("fill", cx, cy-2, 11, 5)
    love.graphics.setColor(u.color)
    love.graphics.ellipse("fill", cx, cy-4, 11, 5)

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
    -- team stripe (tabard)
    love.graphics.setColor(u.color)
    love.graphics.rectangle("fill", cx-1.4, cy-24, 2.8, 11)

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

    -- helm: great-helm + visor slot + specular edge
    love.graphics.setColor(STEEL_D)
    love.graphics.rectangle("fill", cx-6, cy-40, 12, 12, 2, 2)
    love.graphics.setColor(STEEL_M)
    love.graphics.rectangle("fill", cx-6, cy-40, 12, 10, 2, 2)
    love.graphics.setColor(STEEL_L)
    love.graphics.rectangle("fill", cx-6, cy-40, 3, 10, 2, 2)
    love.graphics.setColor(STEEL_HI)
    love.graphics.rectangle("fill", cx-5.5, cy-39.5, 1, 9)
    love.graphics.setColor(INK)
    love.graphics.rectangle("fill", cx-4, cy-35, 8, 2, 1, 1)
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

function M.drawBust(cx, feet, color, dark, scale)
    scale = scale or 1
    love.graphics.setColor(dark[1]*0.5, dark[2]*0.5, dark[3]*0.5)
    love.graphics.ellipse("fill", cx, feet, 8*scale, 3.5*scale)
    -- shoulders/pauldrons
    love.graphics.setColor(STEEL_D)
    love.graphics.circle("fill", cx-6*scale, feet-11*scale, 3*scale)
    love.graphics.circle("fill", cx+6*scale, feet-11*scale, 3*scale)
    love.graphics.setColor(STEEL_M)
    love.graphics.circle("fill", cx-6*scale, feet-11.6*scale, 3*scale)
    love.graphics.circle("fill", cx+6*scale, feet-11.6*scale, 3*scale)
    love.graphics.setColor(STEEL_L)
    love.graphics.ellipse("fill", cx-6.6*scale, feet-12.5*scale, 1.8*scale, 1.3*scale)
    love.graphics.ellipse("fill", cx+5.4*scale, feet-12.5*scale, 1.8*scale, 1.3*scale)
    -- upper torso + tabard
    love.graphics.setColor(STEEL_M)
    love.graphics.rectangle("fill", cx-7*scale, feet-12*scale, 14*scale, 10*scale, 2*scale, 2*scale)
    love.graphics.setColor(color)
    love.graphics.rectangle("fill", cx-1.8*scale, feet-12*scale, 3.6*scale, 10*scale)
    -- helm
    love.graphics.setColor(STEEL_D)
    love.graphics.rectangle("fill", cx-7*scale, feet-28*scale, 14*scale, 14*scale, 2*scale, 2*scale)
    love.graphics.setColor(STEEL_M)
    love.graphics.rectangle("fill", cx-7*scale, feet-28*scale, 14*scale, 11*scale, 2*scale, 2*scale)
    love.graphics.setColor(STEEL_L)
    love.graphics.rectangle("fill", cx-7*scale, feet-28*scale, 3*scale, 11*scale, 2*scale, 2*scale)
    love.graphics.setColor(STEEL_HI)
    love.graphics.rectangle("fill", cx-6.5*scale, feet-27.5*scale, 1*scale, 10*scale)
    love.graphics.setColor(INK)
    love.graphics.rectangle("fill", cx-4.5*scale, feet-22*scale, 9*scale, 2*scale, 1*scale, 1*scale)
    -- crest
    love.graphics.setColor(color)
    love.graphics.polygon("fill", {cx-1*scale,feet-30*scale,cx+1*scale,feet-30*scale,cx,feet-33*scale})
end

function M.drawChip(cx, y, r, color, dark, alpha)
    local function col(c,a) return {c[1],c[2],c[3],(a or 1)*(alpha or 1)} end
    love.graphics.setColor(col(STEEL_D))
    love.graphics.circle("fill", cx, y, r)
    love.graphics.setColor(col(STEEL_M))
    love.graphics.circle("fill", cx, y, r-2.5)
    love.graphics.setColor(col(STEEL_L))
    love.graphics.ellipse("fill", cx-r*0.12, y-r*0.18, r*0.4, r*0.32)
    love.graphics.setColor(col(INK))
    love.graphics.rectangle("fill", cx-r*0.4, y-1, r*0.8, r*0.18, 2,2)
    love.graphics.setColor(col(color))
    love.graphics.circle("fill", cx+r*0.5, y-r*0.6, r*0.14)
end

return M
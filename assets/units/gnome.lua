-- gnome.lua — greedy gnome shopkeeper: pointy hat, beard, coin pouch, greedy grin.
local M = {}

local STEEL_D = {0.36, 0.37, 0.41}
local STEEL_M = {0.60, 0.62, 0.66}
local STEEL_L = {0.86, 0.87, 0.90}
local STEEL_HI = {0.95, 0.96, 1.00}
local HAT     = {0.85, 0.65, 0.18}  -- gold-ish pointy hat
local HAT_D   = {0.55, 0.40, 0.10}
local BEARD   = {0.35, 0.28, 0.20}
local SKIN    = {0.92, 0.78, 0.62}
local SKIN_D  = {0.70, 0.58, 0.44}
local POUCH   = {0.95, 0.82, 0.20}
local INK     = {0.10, 0.11, 0.13}

function M.drawGnome(u, time, G, Board, C)
    local hgt = G.heights[u.gy] and G.heights[u.gy][u.gx] or 0
    local k = u.gx .. "," .. u.gy
    local l = G.lift[k] or 0
    local cx, cy = Board.tileToScreen(u.px, u.py, hgt * G.BLOCK_H + l)
    local s = G.zoom

    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.scale(s, s)
    love.graphics.translate(-cx, -cy)

    -- base disc (neutral team)
    love.graphics.setColor(BEARD)
    love.graphics.ellipse("fill", cx, cy - 2, 11, 5)
    love.graphics.setColor(SKIN)
    love.graphics.ellipse("fill", cx, cy - 4, 11, 5)

    -- legs: short, stout
    love.graphics.setColor(STEEL_D)
    love.graphics.rectangle("fill", cx - 4, cy - 10, 3.2, 7, 1, 1)
    love.graphics.rectangle("fill", cx + 0.8, cy - 10, 3.2, 7, 1, 1)
    love.graphics.setColor(STEEL_M)
    love.graphics.rectangle("fill", cx - 4, cy - 10, 1, 7, 1, 1)
    love.graphics.rectangle("fill", cx + 0.8, cy - 10, 1, 7, 1, 1)
    love.graphics.setColor(STEEL_L)
    love.graphics.ellipse("fill", cx - 2.4, cy - 3, 2.4, 1.4)
    love.graphics.ellipse("fill", cx + 2.4, cy - 3, 2.4, 1.4)

    -- torso: round belly
    love.graphics.setColor(STEEL_D)
    love.graphics.polygon("fill", {cx - 6, cy - 10, cx - 4, cy - 24, cx + 4, cy - 24, cx + 6, cy - 10})
    love.graphics.setColor(STEEL_M)
    love.graphics.polygon("fill", {cx - 4, cy - 11, cx - 3, cy - 23, cx + 3, cy - 23, cx + 4, cy - 11})
    love.graphics.setColor(STEEL_L)
    love.graphics.polygon("fill", {cx - 2.5, cy - 12, cx - 1.5, cy - 22, cx + 1.5, cy - 22, cx + 2.5, cy - 12})

    -- belt + coin pouch (greedy touch)
    love.graphics.setColor(BEARD)
    love.graphics.rectangle("fill", cx - 5.5, cy - 12.5, 11, 2, 1, 1)
    love.graphics.setColor(POUCH)
    love.graphics.circle("fill", cx + 3.5, cy - 11.5, 2.2)
    love.graphics.setColor(HAT_D)
    love.graphics.circle("fill", cx + 3.5, cy - 11.5, 1.2)

    -- arms: crossed or hands on belly
    love.graphics.setColor(STEEL_M)
    love.graphics.rectangle("fill", cx - 7.5, cy - 22, 2.2, 8, 1, 1)
    love.graphics.rectangle("fill", cx + 5.3, cy - 22, 2.2, 8, 1, 1)
    love.graphics.setColor(STEEL_L)
    love.graphics.rectangle("fill", cx - 7.5, cy - 22, 0.8, 8, 1, 1)
    love.graphics.rectangle("fill", cx + 5.3, cy - 22, 0.8, 8, 1, 1)
    love.graphics.setColor(STEEL_D)
    love.graphics.circle("fill", cx - 6.4, cy - 13, 1.5)
    love.graphics.circle("fill", cx + 6.4, cy - 13, 1.5)

    -- pauldrons: small
    love.graphics.setColor(STEEL_M)
    love.graphics.circle("fill", cx - 5.2, cy - 23, 2.2)
    love.graphics.circle("fill", cx + 5.2, cy - 23, 2.2)

    -- head
    love.graphics.setColor(SKIN_D)
    love.graphics.ellipse("fill", cx, cy - 29, 7.5, 6)
    love.graphics.setColor(SKIN)
    love.graphics.ellipse("fill", cx, cy - 30, 7.5, 6)

    -- beard
    love.graphics.setColor(BEARD)
    love.graphics.ellipse("fill", cx, cy - 25, 6.5, 4)
    love.graphics.ellipse("fill", cx - 3, cy - 23, 2.5, 3)
    love.graphics.ellipse("fill", cx + 3, cy - 23, 2.5, 3)

    -- greedy eyes (narrow, smirking)
    love.graphics.setColor(INK)
    love.graphics.ellipse("fill", cx - 2.5, cy - 31, 1.8, 0.8)
    love.graphics.ellipse("fill", cx + 2.5, cy - 31, 1.8, 0.8)
    -- pupils
    love.graphics.circle("fill", cx - 2.5, cy - 31, 0.6)
    love.graphics.circle("fill", cx + 2.5, cy - 31, 0.6)
    -- smirk
    love.graphics.setLineWidth(1.5)
    love.graphics.arc("line", "open", cx, cy - 27, 2.5, 0.2, 2.9)
    love.graphics.setLineWidth(1)

    -- pointy hat (greedy gold)
    love.graphics.setColor(HAT_D)
    love.graphics.polygon("fill", {cx - 9, cy - 30, cx + 9, cy - 30, cx, cy - 46})
    love.graphics.setColor(HAT)
    love.graphics.polygon("fill", {cx - 8, cy - 30, cx + 8, cy - 30, cx, cy - 44})
    love.graphics.setColor(HAT_D)
    love.graphics.rectangle("fill", cx - 8.5, cy - 30, 17, 2.5, 1, 1)
    -- hat tip bob
    local bob = math.sin(time * 2.5) * 1.2
    love.graphics.setColor(HAT)
    love.graphics.polygon("fill", {cx - 1.5, cy - 44 + bob, cx + 1.5, cy - 44 + bob, cx, cy - 48 + bob})
    -- coin glint on hat brim
    love.graphics.setColor(POUCH)
    love.graphics.circle("fill", cx - 4, cy - 30.5, 1.2)

    love.graphics.pop()

    -- no active ring for neutral shopkeeper
end

function M.drawBust(cx, feet, color, dark, scale)
    scale = scale or 1
    -- shadow
    love.graphics.setColor(0, 0, 0, 0.3 * scale)
    love.graphics.ellipse("fill", cx, feet, 8 * scale, 3.5 * scale)
    -- shoulders
    love.graphics.setColor(STEEL_M)
    love.graphics.circle("fill", cx - 6 * scale, feet - 11 * scale, 3 * scale)
    love.graphics.circle("fill", cx + 6 * scale, feet - 11 * scale, 3 * scale)
    love.graphics.setColor(STEEL_L)
    love.graphics.ellipse("fill", cx - 6.6 * scale, feet - 12.5 * scale, 1.8 * scale, 1.3 * scale)
    love.graphics.ellipse("fill", cx + 5.4 * scale, feet - 12.5 * scale, 1.8 * scale, 1.3 * scale)
    -- torso + belt+pouch hint
    love.graphics.setColor(STEEL_M)
    love.graphics.rectangle("fill", cx - 7 * scale, feet - 12 * scale, 14 * scale, 10 * scale, 2 * scale, 2 * scale)
    love.graphics.setColor(POUCH)
    love.graphics.circle("fill", cx + 3.5 * scale, feet - 11.5 * scale, 2.2 * scale)
    -- head + beard
    love.graphics.setColor(SKIN)
    love.graphics.ellipse("fill", cx, feet - 28 * scale, 7.5 * scale, 6 * scale)
    love.graphics.setColor(BEARD)
    love.graphics.ellipse("fill", cx, feet - 24 * scale, 6.5 * scale, 4 * scale)
    -- eyes
    love.graphics.setColor(INK)
    love.graphics.ellipse("fill", cx - 2.5 * scale, feet - 29 * scale, 1.8 * scale, 0.8 * scale)
    love.graphics.ellipse("fill", cx + 2.5 * scale, feet - 29 * scale, 1.8 * scale, 0.8 * scale)
    -- hat
    love.graphics.setColor(HAT)
    love.graphics.polygon("fill", {cx - 8 * scale, feet - 28 * scale, cx + 8 * scale, feet - 28 * scale, cx, feet - 44 * scale})
    love.graphics.setColor(HAT_D)
    love.graphics.rectangle("fill", cx - 8.5 * scale, feet - 28 * scale, 17 * scale, 2.5 * scale, 1 * scale, 1 * scale)
    -- coin glint
    love.graphics.setColor(POUCH)
    love.graphics.circle("fill", cx - 4 * scale, feet - 28.5 * scale, 1.2 * scale)
end

function M.drawChip(cx, y, r, color, dark, alpha)
    local function col(c, a) return {c[1], c[2], c[3], (a or 1) * (alpha or 1)} end
    -- hat silhouette
    love.graphics.setColor(col(HAT_D))
    love.graphics.polygon("fill", {cx - r * 0.8, y, cx + r * 0.8, y, cx, y - r * 1.5})
    love.graphics.setColor(col(HAT))
    love.graphics.polygon("fill", {cx - r * 0.7, y, cx + r * 0.7, y, cx, y - r * 1.3})
    -- face/beard
    love.graphics.setColor(col(SKIN))
    love.graphics.circle("fill", cx, y + r * 0.1, r * 0.7)
    love.graphics.setColor(col(BEARD))
    love.graphics.ellipse("fill", cx, y + r * 0.35, r * 0.6, r * 0.35)
    -- eyes
    love.graphics.setColor(col(INK))
    love.graphics.ellipse("fill", cx - r * 0.25, y - r * 0.05, r * 0.18, r * 0.1)
    love.graphics.ellipse("fill", cx + r * 0.25, y - r * 0.05, r * 0.18, r * 0.1)
    -- coin glint
    love.graphics.setColor(col(POUCH))
    love.graphics.circle("fill", cx + r * 0.5, y - r * 0.6, r * 0.14)
end

return M
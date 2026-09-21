-- sigil.lua — tiny emblem painter shared by all hero classes.
-- shape: "cross" | "diamond" | "skull". (cx, cy) center, s half-size.
local M = {}

local INK = {0.10, 0.11, 0.13}

function M.draw(shape, cx, cy, s, col)
    love.graphics.setColor(col)
    if shape == "diamond" then
        love.graphics.polygon("fill", {cx, cy - s, cx + s * 0.7, cy, cx, cy + s, cx - s * 0.7, cy})
    elseif shape == "skull" then
        love.graphics.circle("fill", cx, cy - s * 0.1, s * 0.62)
        love.graphics.setColor(INK)
        love.graphics.circle("fill", cx - s * 0.22, cy - s * 0.2, s * 0.16)
        love.graphics.circle("fill", cx + s * 0.22, cy - s * 0.2, s * 0.16)
    else -- cross
        love.graphics.rectangle("fill", cx - s * 0.28, cy - s, s * 0.56, s * 2)
        love.graphics.rectangle("fill", cx - s * 0.8, cy - s * 0.55, s * 1.6, s * 0.5)
    end
end

return M

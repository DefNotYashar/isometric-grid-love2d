-- level_debug.lua — debug view for level inspection
local G = require("state")
local Board = require("board")
local M = {}

M.enabled = false

-- Local diamond helper (same as render.lua)
local function diamond(cx, cy, w, h)
    return { cx, cy - h, cx + w, cy, cx, cy + h, cx - w, cy }
end

function M.toggle()
    M.enabled = not M.enabled
end

function M.draw()
    if not M.enabled then return end

    local level = G.currentLevel
    if not level then return end

    local C = G.C
    local font = G.fontSmall

    -- Draw level info panel
    local x, y = 10, 10
    local w, h = 280, 180

    love.graphics.setFont(font)
    love.graphics.setColor(C.panel)
    love.graphics.rectangle("fill", x, y, w, h, 6, 6)
    love.graphics.setColor(C.panelLn)
    love.graphics.rectangle("line", x, y, w, h, 6, 6)

    local line = y + 8
    local function info(label, value)
        love.graphics.setColor(C.muted)
        love.graphics.print(label, x + 10, line)
        love.graphics.setColor(C.ink)
        love.graphics.print(tostring(value), x + 120, line)
        line = line + 16
    end

    info("Level ID:", level.id)
    info("Area:", level.area)
    info("Type:", level.type)
    info("Size:", level.width .. "x" .. level.height)
    info("Player spawns:", #(level.player_spawns or {}))
    info("Enemy spawns:", #(level.enemy_spawns or {}))
    info("Tags:", table.concat(level.tags or {}, ", "))

    -- Draw grid overlay with spawn markers
    M.drawGridOverlay()
end

function M.drawGridOverlay()
    local level = G.currentLevel
    if not level then return end

    local C = G.C

    for gy = 1, level.height do
        for gx = 1, level.width do
            local cx, cy = Board.tileToScreen(gx, gy, Board.tileTopZ(gx, gy))
            local w, h = G.TILE_W * G.zoom, G.TILE_H * G.zoom

            -- Check if player spawn
            local isPlayerSpawn = false
            for _, s in ipairs(level.player_spawns or {}) do
                if s.x == gx and s.y == gy then isPlayerSpawn = true break end
            end

            -- Check if enemy spawn
            local isEnemySpawn = false
            for _, s in ipairs(level.enemy_spawns or {}) do
                if s.x == gx and s.y == gy then isEnemySpawn = true break end
            end

            -- Check if blocked
            local blocked = (level.heights[gy] and level.heights[gy][gx] or 0) >= 2
            local isWater = level.tiles[gy][gx] == "water"

            if isPlayerSpawn then
                love.graphics.setColor(C.accent)
                love.graphics.setLineWidth(3)
                love.graphics.polygon("line", diamond(cx, cy, w - 4, h - 4))
                love.graphics.setColor(C.accent[1], C.accent[2], C.accent[3], 0.3)
                love.graphics.polygon("fill", diamond(cx, cy, w - 4, h - 4))
            elseif isEnemySpawn then
                love.graphics.setColor(C.floatDmg)
                love.graphics.setLineWidth(3)
                love.graphics.polygon("line", diamond(cx, cy, w - 4, h - 4))
                love.graphics.setColor(C.floatDmg[1], C.floatDmg[2], C.floatDmg[3], 0.3)
                love.graphics.polygon("fill", diamond(cx, cy, w - 4, h - 4))
            elseif blocked then
                love.graphics.setColor(1, 0, 0, 0.3)
                love.graphics.polygon("fill", diamond(cx, cy, w - 8, h - 8))
            elseif isWater then
                love.graphics.setColor(0, 0.5, 1, 0.2)
                love.graphics.polygon("fill", diamond(cx, cy, w - 8, h - 8))
            end
        end
    end
    love.graphics.setLineWidth(1)
end

-- Text representation for console logging
function M.textRepresentation(level)
    level = level or G.currentLevel
    if not level then return "No level loaded" end

    local lines = {}
    table.insert(lines, "=== " .. level.id .. " (" .. level.area .. "/" .. level.type .. ") ===")
    table.insert(lines, "Size: " .. level.width .. "x" .. level.height)
    table.insert(lines, "Tags: " .. table.concat(level.tags or {}, ", "))

    -- Legend: P = player spawn, E = enemy spawn, # = blocked, ~ = water, . = walkable
    for y = 1, level.height do
        local line = ""
        for x = 1, level.width do
            local isPlayer = false
            for _, s in ipairs(level.player_spawns or {}) do if s.x == x and s.y == y then isPlayer = true break end end
            local isEnemy = false
            for _, s in ipairs(level.enemy_spawns or {}) do if s.x == x and s.y == y then isEnemy = true break end end
            local blocked = (level.heights[y] and level.heights[y][x] or 0) >= 2
            local isWater = level.tiles[y][x] == "water"

            if isPlayer then line = line .. "P"
            elseif isEnemy then line = line .. "E"
            elseif blocked then line = line .. "#"
            elseif isWater then line = line .. "~"
            else line = line .. "." end
        end
        table.insert(lines, line)
    end

    return table.concat(lines, "\n")
end

function M.printLevel(level)
    print(M.textRepresentation(level))
end

return M
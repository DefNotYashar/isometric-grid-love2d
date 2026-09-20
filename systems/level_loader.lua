-- level_loader.lua — loads level definitions from Lua files
-- Returns a runtime level table with validated data
local LevelValidator = require("systems.level_validator")
local M = {}

-- Load a level by ID (e.g., "forest_001") from the levels/ folder structure
-- area = "forest", type = "normal" | "elite" | "special" | "boss"
function M.load(area, type, levelId)
    local path = "levels/" .. area .. "/" .. type .. "/" .. levelId .. ".lua"
    local chunk = love.filesystem.load(path)
    if not chunk then
        error("Level not found: " .. path)
    end
    local data = chunk()
    LevelValidator.validateOrThrow(data)
    return M.validate(data, area, type)
end

-- Validate level data and return runtime level
function M.validate(data, area, type)
    local errors = {}
    local warnings = {}

    -- Required fields
    if not data.id then table.insert(errors, "missing id") end
    if not data.width then table.insert(errors, "missing width") end
    if not data.height then table.insert(errors, "missing height") end
    if not data.tiles then table.insert(errors, "missing tiles") end
    if not data.player_spawns then table.insert(errors, "missing player_spawns") end
    if not data.enemy_spawns then table.insert(errors, "missing enemy_spawns") end
    if not data.tags then data.tags = {} end -- optional, default empty

    if #errors > 0 then
        error("Level validation failed for " .. (data.id or "unknown") .. ":\n  " .. table.concat(errors, "\n  "))
    end

    -- Validate dimensions match tiles
    if data.tiles then
        if #data.tiles ~= data.height then
            table.insert(errors, "tiles height (" .. #data.tiles .. ") != height (" .. data.height .. ")")
        else
            for y, row in ipairs(data.tiles) do
                if #row ~= data.width then
                    table.insert(errors, "row " .. y .. " width (" .. #row .. ") != width (" .. data.width .. ")")
                end
            end
        end
    end

    -- Validate heights if present
    if data.heights then
        if #data.heights ~= data.height then
            table.insert(errors, "heights height mismatch")
        else
            for y, row in ipairs(data.heights) do
                if #row ~= data.width then
                    table.insert(errors, "heights row " .. y .. " width mismatch")
                end
            end
        end
    end

    -- Validate spawn positions
    local function validateSpawns(spawns, name)
        if not spawns or #spawns == 0 then
            table.insert(errors, name .. " has no spawn positions")
            return
        end
        for i, s in ipairs(spawns) do
            if not s.x or not s.y then
                table.insert(errors, name .. "[" .. i .. "] missing x or y")
            elseif s.x < 1 or s.x > data.width or s.y < 1 or s.y > data.height then
                table.insert(errors, name .. "[" .. i .. "] out of bounds: " .. s.x .. "," .. s.y)
            end
        end
    end
    validateSpawns(data.player_spawns, "player_spawns")
    validateSpawns(data.enemy_spawns, "enemy_spawns")

    -- Check for duplicate spawn positions
    local seen = {}
    for _, s in ipairs(data.player_spawns) do
        local k = s.y * 100 + s.x
        if seen[k] then table.insert(warnings, "duplicate player spawn at " .. s.x .. "," .. s.y) end
        seen[k] = true
    end
    for _, s in ipairs(data.enemy_spawns) do
        local k = s.y * 100 + s.x
        if seen[k] then table.insert(warnings, "duplicate enemy spawn at " .. s.x .. "," .. s.y) end
        seen[k] = true
    end

    if #errors > 0 then
        error("Level validation failed for " .. data.id .. ":\n  " .. table.concat(errors, "\n  "))
    end

    -- Build runtime level
    local level = {
        id = data.id,
        area = area,
        type = type,
        width = data.width,
        height = data.height,
        tiles = data.tiles,
        heights = data.heights or M.defaultHeights(data.width, data.height),
        player_spawns = data.player_spawns,
        enemy_spawns = data.enemy_spawns,
        tags = data.tags,
    }

    -- Print warnings
    for _, w in ipairs(warnings) do
        print("[LevelLoader] WARNING: " .. w .. " in " .. data.id)
    end

    return level
end

function M.defaultHeights(w, h)
    local heights = {}
    for y = 1, h do
        heights[y] = {}
        for x = 1, w do heights[y][x] = 0 end
    end
    return heights
end

-- Get list of available level IDs for an area/type
function M.listLevels(area, type)
    local path = "levels/" .. area .. "/" .. type
    local files = love.filesystem.getDirectoryItems(path)
    local levels = {}
    for _, f in ipairs(files) do
        if f:match("%.lua$") then
            table.insert(levels, f:sub(1, -5)) -- strip .lua
        end
    end
    return levels
end

return M
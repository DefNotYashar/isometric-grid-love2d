-- level_pool.lua — manages level pools by area and battle type
local LevelLoader = require("systems.level_loader")
local M = {}

-- Pool structure: { forest = { normal = {"forest_001", ...}, elite = {...}, boss = {...} } }
M.pools = {}

-- Initialize pools by scanning the levels/ directory
function M.init()
    local areas = love.filesystem.getDirectoryItems("levels")
    for _, area in ipairs(areas) do
        local areaPath = "levels/" .. area
        if love.filesystem.getInfo(areaPath, "directory") then
            M.pools[area] = {}
            local types = love.filesystem.getDirectoryItems(areaPath)
            for _, type in ipairs(types) do
                local typePath = areaPath .. "/" .. type
                if love.filesystem.getInfo(typePath, "directory") then
                    M.pools[area][type] = LevelLoader.listLevels(area, type)
                end
            end
        end
    end
end

-- Get available level IDs for area + type
function M.get(area, type)
    if not M.pools[area] then M.init() end
    return M.pools[area] and M.pools[area][type] or {}
end

-- Get all types available for an area
function M.getTypes(area)
    if not M.pools[area] then M.init() end
    local types = {}
    if M.pools[area] then
        for t, _ in pairs(M.pools[area]) do table.insert(types, t) end
    end
    return types
end

return M
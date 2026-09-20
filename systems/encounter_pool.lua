-- encounter_pool.lua — manages encounter pools by area and battle type
local EncounterLoader = require("systems.encounter_loader")
local M = {}

M.pools = {}

function M.init()
    local areas = love.filesystem.getDirectoryItems("encounters")
    for _, area in ipairs(areas) do
        local areaPath = "encounters/" .. area
        if love.filesystem.getInfo(areaPath, "directory") then
            M.pools[area] = {}
            local types = love.filesystem.getDirectoryItems(areaPath)
            for _, type in ipairs(types) do
                local typePath = areaPath .. "/" .. type
                if love.filesystem.getInfo(typePath, "directory") then
                    M.pools[area][type] = EncounterLoader.listEncounters(area, type)
                end
            end
        end
    end
end

function M.get(area, type)
    if not M.pools[area] then M.init() end
    return M.pools[area] and M.pools[area][type] or {}
end

return M
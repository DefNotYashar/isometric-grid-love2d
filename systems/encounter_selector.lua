-- encounter_selector.lua — selects an encounter from a pool
local EncounterPool = require("systems.encounter_pool")
local M = {}

function M.select(area, type)
    local pool = EncounterPool.get(area, type)
    if #pool == 0 then
        error("No encounters in pool: " .. area .. " / " .. type)
    end
    return pool[math.random(1, #pool)]
end

return M
-- level_selector.lua — selects a level from a pool with recent-level avoidance
local LevelPool = require("systems.level_pool")
local M = {}

-- Track recently used levels per area+type to avoid repeats
M.recent = {} -- { "forest_normal" = { "forest_003", "forest_001" } }
M.maxRecent = 3 -- remember last 3

-- Select a level from the pool
-- area: "forest", type: "normal" | "elite" | "special" | "boss"
-- filter: optional { required = {"tag1", ...}, forbidden = {"tag2", ...} }
function M.select(area, type, filter)
    local pool = LevelPool.get(area, type)
    if #pool == 0 then
        error("No levels in pool: " .. area .. " / " .. type)
    end

    -- Load and filter levels by tags if filter provided
    local LevelLoader = require("systems.level_loader")
    local candidates = {}
    for _, id in ipairs(pool) do
        local level = LevelLoader.load(area, type, id)
        if M.matchesFilter(level, filter) then
            table.insert(candidates, id)
        end
    end

    if #candidates == 0 then
        -- Fallback: no filter matches, use full pool
        candidates = pool
    end

    if #candidates == 1 then
        return candidates[1]
    end

    local key = area .. "_" .. type
    local recent = M.recent[key] or {}

    -- Filter out recently used levels
    local filtered = {}
    for _, id in ipairs(candidates) do
        local isRecent = false
        for _, r in ipairs(recent) do
            if r == id then isRecent = true break end
        end
        if not isRecent then table.insert(filtered, id) end
    end

    -- If all levels are recent, use filtered candidates
    if #filtered == 0 then
        filtered = candidates
    end

    -- Random selection
    local selected = filtered[math.random(1, #filtered)]

    -- Update recent history
    M.recent[key] = recent
    table.insert(M.recent[key], 1, selected)
    while #M.recent[key] > M.maxRecent do
        table.remove(M.recent[key])
    end

    return selected
end

function M.matchesFilter(level, filter)
    if not filter then return true end
    local tags = level.tags or {}

    if filter.required then
        for _, req in ipairs(filter.required) do
            local found = false
            for _, t in ipairs(tags) do if t == req then found = true break end end
            if not found then return false end
        end
    end

    if filter.forbidden then
        for _, forbid in ipairs(filter.forbidden) do
            for _, t in ipairs(tags) do if t == forbid then return false end end
        end
    end

    return true
end

-- Reset recent history (e.g., new run)
function M.reset(area, type)
    if area and type then
        M.recent[area .. "_" .. type] = nil
    else
        M.recent = {}
    end
end

return M
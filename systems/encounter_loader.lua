-- encounter_loader.lua — loads encounter definitions (enemy compositions)
local M = {}

function M.load(area, type, encounterId)
    local path = "encounters/" .. area .. "/" .. type .. "/" .. encounterId .. ".lua"
    local chunk = love.filesystem.load(path)
    if not chunk then
        error("Encounter not found: " .. path)
    end
    local data = chunk()
    return M.validate(data, area, type)
end

function M.validate(data, area, type)
    local errors = {}

    if not data.id then table.insert(errors, "missing id") end
    if not data.enemies then table.insert(errors, "missing enemies") end
    if data.enemies and #data.enemies == 0 then table.insert(errors, "enemies list empty") end

    if #errors > 0 then
        error("Encounter validation failed for " .. (data.id or "unknown") .. ":\n  " .. table.concat(errors, "\n  "))
    end

    return {
        id = data.id,
        area = area,
        type = type,
        enemies = data.enemies, -- list of enemy template IDs: "slime", "skeleton", etc.
    }
end

function M.listEncounters(area, type)
    local path = "encounters/" .. area .. "/" .. type
    local files = love.filesystem.getDirectoryItems(path)
    local encounters = {}
    for _, f in ipairs(files) do
        if f:match("%.lua$") then
            table.insert(encounters, f:sub(1, -5))
        end
    end
    return encounters
end

return M
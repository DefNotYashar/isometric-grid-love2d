-- save_system.lua — persist settings and run progress
local G = require("state")
local M = {}

M.filename = "save.lua"

function M.save()
    local data = {
        version = 1,
        settings = G.settings,
        progress = G.progress or { highestLevel = 0, completedRuns = 0, totalKills = 0, totalCoins = 0 },
        meta = { lastRun = os.time(), playtime = (G.meta and G.meta.playtime) or 0 }
    }
    local content = "return " .. M.serialize(data)
    love.filesystem.write(M.filename, content)
end

function M.load()
    if not love.filesystem.getInfo(M.filename) then return false end
    local chunk = love.filesystem.load(M.filename)
    if not chunk then return false end
    local ok, data = pcall(chunk)
    if not ok or not data then return false end
    G.settings = data.settings or { showAdmin = true, volume = 8 }
    G.progress = data.progress or { highestLevel = 0, completedRuns = 0, totalKills = 0, totalCoins = 0 }
    G.meta = data.meta or { lastRun = os.time(), playtime = 0 }
    return true
end

function M.reset()
    G.settings = { showAdmin = true, volume = 8 }
    G.progress = { highestLevel = 0, completedRuns = 0, totalKills = 0, totalCoins = 0 }
    G.meta = { lastRun = os.time(), playtime = 0 }
    love.filesystem.remove(M.filename)
end

function M.recordRunResult(won, level, path, kills, coins)
    G.progress = G.progress or { highestLevel = 0, completedRuns = 0, totalKills = 0, totalCoins = 0 }
    G.progress.totalKills = (G.progress.totalKills or 0) + (kills or 0)
    G.progress.totalCoins = (G.progress.totalCoins or 0) + (coins or 0)
    if won then
        G.progress.completedRuns = (G.progress.completedRuns or 0) + 1
        if level > (G.progress.highestLevel or 0) then G.progress.highestLevel = level end
    end
    M.save()
end

-- Simple serialization for Lua tables
function M.serialize(t, indent)
    indent = indent or 0
    local sp = string.rep("  ", indent)
    if type(t) ~= "table" then
        if type(t) == "string" then return string.format("%q", t) end
        return tostring(t)
    end
    local lines = { "{" }
    for k, v in pairs(t) do
        local key = type(k) == "string" and "[" .. string.format("%q", k) .. "]" or "[" .. k .. "]"
        lines[#lines + 1] = sp .. "  " .. key .. " = " .. M.serialize(v, indent + 1) .. ","
    end
    lines[#lines + 1] = sp .. "}"
    return table.concat(lines, "\n")
end

return M
-- level_validator.lua — validates level data thoroughly
local M = {}

-- Validate a level and return { valid = true/false, errors = {...}, warnings = {...} }
function M.validate(level)
    local errors = {}
    local warnings = {}

    -- 1. Grid dimensions
    if not level.width or not level.height then
        table.insert(errors, "Missing width/height")
    elseif level.width < 5 or level.height < 5 then
        table.insert(errors, "Grid too small (min 5x5)")
    elseif level.width > 20 or level.height > 20 then
        table.insert(warnings, "Grid larger than 20x20 may have performance issues")
    end

    -- 2. Tiles exist and match dimensions
    if not level.tiles then
        table.insert(errors, "Missing tiles")
    else
        if #level.tiles ~= level.height then
            table.insert(errors, "tiles height (" .. #level.tiles .. ") != height (" .. level.height .. ")")
        else
            for y, row in ipairs(level.tiles) do
                if #row ~= level.width then
                    table.insert(errors, "Row " .. y .. " width (" .. #row .. ") != width (" .. level.width .. ")")
                end
                for x, tile in ipairs(row) do
                    if not M.isValidTile(tile) then
                        table.insert(errors, "Invalid tile at " .. x .. "," .. y .. ": " .. tostring(tile))
                    end
                end
            end
        end
    end

    -- 3. Heights match dimensions (if present)
    if level.heights then
        if #level.heights ~= level.height then
            table.insert(errors, "heights height mismatch")
        else
            for y, row in ipairs(level.heights) do
                if #row ~= level.width then
                    table.insert(errors, "heights row " .. y .. " width mismatch")
                end
                for x, h in ipairs(row) do
                    if type(h) ~= "number" or h < 0 or h > 2 then
                        table.insert(errors, "Invalid height at " .. x .. "," .. y .. ": " .. tostring(h))
                    end
                end
            end
        end
    end

    -- 4. Player spawns exist and are valid
    if not level.player_spawns or #level.player_spawns == 0 then
        table.insert(errors, "No player spawn positions")
    else
        for i, s in ipairs(level.player_spawns) do
            if not M.validateSpawn(s, level, "player_spawns[" .. i .. "]") then
                table.insert(errors, "Invalid player spawn " .. i)
            end
        end
    end

    -- 5. Enemy spawns exist and are valid
    if not level.enemy_spawns or #level.enemy_spawns == 0 then
        table.insert(errors, "No enemy spawn positions")
    else
        for i, s in ipairs(level.enemy_spawns) do
            if not M.validateSpawn(s, level, "enemy_spawns[" .. i .. "]") then
                table.insert(errors, "Invalid enemy spawn " .. i)
            end
        end
    end

    -- 6. No duplicate spawn positions
    local seen = {}
    if level.player_spawns then
        for _, s in ipairs(level.player_spawns) do
            local k = s.y * 100 + s.x
            if seen[k] then table.insert(warnings, "Duplicate spawn at " .. s.x .. "," .. s.y) end
            seen[k] = true
        end
    end
    if level.enemy_spawns then
        for _, s in ipairs(level.enemy_spawns) do
            local k = s.y * 100 + s.x
            if seen[k] then table.insert(warnings, "Duplicate spawn at " .. s.x .. "," .. s.y) end
            seen[k] = true
        end
    end

    -- 7. Spawn walkability (not blocked by height >= 2 or water)
    if level.player_spawns and level.heights then
        for _, s in ipairs(level.player_spawns) do
            local h = level.heights[s.y] and level.heights[s.y][s.x] or 0
            local t = level.tiles[s.y] and level.tiles[s.y][s.x] or "default"
            if h >= 2 then
                table.insert(errors, "Player spawn at " .. s.x .. "," .. s.y .. " is blocked (height " .. h .. ")")
            elseif t == "water" then
                table.insert(warnings, "Player spawn at " .. s.x .. "," .. s.y .. " is on water")
            end
        end
    end
    if level.enemy_spawns and level.heights then
        for _, s in ipairs(level.enemy_spawns) do
            local h = level.heights[s.y] and level.heights[s.y][s.x] or 0
            local t = level.tiles[s.y] and level.tiles[s.y][s.x] or "default"
            if h >= 2 then
                table.insert(errors, "Enemy spawn at " .. s.x .. "," .. s.y .. " is blocked (height " .. h .. ")")
            elseif t == "water" then
                table.insert(warnings, "Enemy spawn at " .. s.x .. "," .. s.y .. " is on water")
            end
        end
    end

    -- 8. Sufficient walkable space
    local walkable = M.countWalkable(level)
    local maxUnits = (#level.player_spawns or 0) + (#level.enemy_spawns or 0)
    if walkable < maxUnits then
        table.insert(errors, "Only " .. walkable .. " walkable tiles for " .. maxUnits .. " potential units")
    elseif walkable < maxUnits * 2 then
        table.insert(warnings, "Only " .. walkable .. " walkable tiles for " .. maxUnits .. " units (cramped)")
    end

    -- 9. Connectivity: player area can reach enemy area
    if level.player_spawns and level.enemy_spawns and level.tiles and level.heights then
        local connected, msg = M.checkConnectivity(level)
        if not connected then
            table.insert(errors, "Connectivity: " .. msg)
        end
    end

    -- 10. Minimum distance between player and enemy regions
    if level.player_spawns and level.enemy_spawns then
        local minDist = math.huge
        for _, ps in ipairs(level.player_spawns) do
            for _, es in ipairs(level.enemy_spawns) do
                local d = math.abs(ps.x - es.x) + math.abs(ps.y - es.y)
                if d < minDist then minDist = d end
            end
        end
        if minDist < 3 then
            table.insert(warnings, "Player and enemy spawns very close (min dist " .. minDist .. ")")
        end
    end

    return {
        valid = #errors == 0,
        errors = errors,
        warnings = warnings,
    }
end

function M.isValidTile(tile)
    local valid = {
        "default", "grass", "meadow", "flower", "tall",
        "water", "mountain", "shopwall", "shopfloor", "shopdoor", "spawn", "finish"
    }
    for _, v in ipairs(valid) do if v == tile then return true end end
    return false
end

function M.validateSpawn(s, level, name)
    if not s.x or not s.y then return false end
    if s.x < 1 or s.x > level.width or s.y < 1 or s.y > level.height then return false end
    return true
end

function M.countWalkable(level)
    local count = 0
    for y = 1, level.height do
        for x = 1, level.width do
            local h = (level.heights and level.heights[y] and level.heights[y][x]) or 0
            local t = level.tiles[y][x]
            if h < 2 and t ~= "water" then
                count = count + 1
            end
        end
    end
    return count
end

-- BFS from player spawns to check if enemy spawns are reachable
function M.checkConnectivity(level)
    -- Build blocked map
    local blocked = {}
    for y = 1, level.height do
        for x = 1, level.width do
            local h = level.heights[y][x]
            local t = level.tiles[y][x]
            if h >= 2 or t == "water" then
                blocked[y * 100 + x] = true
            end
        end
    end

    -- Multi-source BFS from all player spawns
    local queue = {}
    local visited = {}
    for _, s in ipairs(level.player_spawns) do
        local k = s.y * 100 + s.x
        if not blocked[k] then
            queue[#queue + 1] = { x = s.x, y = s.y }
            visited[k] = true
        end
    end

    local dirs = {{1,0},{-1,0},{0,1},{0,-1}}
    local head = 1
    while head <= #queue do
        local cur = queue[head]
        head = head + 1
        for _, d in ipairs(dirs) do
            local nx, ny = cur.x + d[1], cur.y + d[2]
            local k = ny * 100 + nx
            if nx >= 1 and ny >= 1 and nx <= level.width and ny <= level.height
                and not blocked[k] and not visited[k] then
                visited[k] = true
                queue[#queue + 1] = { x = nx, y = ny }
            end
        end
    end

    -- Check if any enemy spawn is reachable
    for _, s in ipairs(level.enemy_spawns) do
        if visited[s.y * 100 + s.x] then
            return true, "Player can reach enemy area"
        end
    end

    return false, "Enemy spawns unreachable from player spawns"
end

-- Quick validation for loader (throws on error)
function M.validateOrThrow(level)
    local result = M.validate(level)
    if not result.valid then
        error("Level validation failed:\n  " .. table.concat(result.errors, "\n  "))
    end
    for _, w in ipairs(result.warnings) do
        print("[LevelValidator] WARNING: " .. w)
    end
    return true
end

return M
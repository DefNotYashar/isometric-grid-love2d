-- level_generator.lua — procedural level generator (Phase 19)
-- Creates candidate 10×10 tactical maps with clustered terrain, validates, saves
local G = require("state")
local Board = require("board")
local LevelValidator = require("systems.level_validator")
local M = {}

-- Configuration
M.config = {
    width = 10,
    height = 10,
    water_density = 0.10,
    mountain_density = 0.08,
    tall_grass_density = 0.15,
    obstacle_density = 0.10,
    min_player_distance = 5,
    min_walkable_tiles = 50,
    water_clusters = 2,
    water_cluster_size = { 4, 12 },
    mountain_clusters = 2,
    mountain_cluster_size = { 3, 8 },
    tall_grass_clusters = 3,
    tall_grass_cluster_size = { 4, 10 },
}

-- Seeded RNG (LCG Park-Miller)
local function makeRng(seed)
    local s = (seed % 2147483646) + 1
    local function nextF()
        s = (s * 48271) % 2147483647
        return s / 2147483647
    end
    return {
        f = nextF,
        int = function(a, b) return a + math.floor(nextF() * ((b - a) + 1)) end,
        chance = function(p) return nextF() < p end,
        pick = function(t) return t[1 + math.floor(nextF() * #t)] end,
    }
end

-- Generate a complete level from seed
function M.generate(seed, config)
    config = config or M.config
    local rng = makeRng(seed)
    local w, h = config.width, config.height

    local level = {
        id = "generated_" .. seed,
        seed = seed,
        area = "forest",
        type = "normal",
        width = w,
        height = h,
        tiles = {},
        heights = {},
        player_spawns = {},
        enemy_spawns = {},
        tags = { "forest", "generated" },
    }

    -- 1. Base grid: all grass (walkable)
    for y = 1, h do
        level.tiles[y] = {}
        level.heights[y] = {}
        for x = 1, w do
            level.tiles[y][x] = "grass"
            level.heights[y][x] = 0
        end
    end

    -- 2. Generate terrain clusters
    M.generateClusters(level, "water", config.water_clusters, config.water_cluster_size, rng)
    M.generateClusters(level, "mountain", config.mountain_clusters, config.mountain_cluster_size, rng)
    M.generateClusters(level, "tall", config.tall_grass_clusters, config.tall_grass_cluster_size, rng)

    -- 3. Add some terrain variety (meadow/flower patches on grass)
    M.addTerrainVariety(level, rng)

    -- 4. Generate spawn regions
    M.generateSpawnRegions(level, rng, config.min_player_distance)

    -- 5. Ensure spawns are on walkable tiles
    M.fixSpawnWalkability(level)

    return level
end

-- Cluster-based generation: grow from seed point
function M.generateClusters(level, terrainType, clusterCount, sizeRange, rng)
    local w, h = level.width, level.height

    for c = 1, clusterCount do
        -- Find valid seed position
        local attempts = 0
        local sx, sy
        repeat
            sx = rng.int(1, w)
            sy = rng.int(1, h)
            attempts = attempts + 1
        until attempts > 100 or (level.tiles[sy][sx] == "grass" and level.heights[sy][sx] == 0)

        if attempts > 100 then break end

        local targetSize = rng.int(sizeRange[1], sizeRange[2])
        local grown = 0
        local queue = { { sx, sy } }
        local seen = { [sy * 100 + sx] = true }

        while #queue > 0 and grown < targetSize do
            local cx, cy = queue[1][1], queue[1][2]
            table.remove(queue, 1)

            -- Can place here?
            if cx >= 1 and cy >= 1 and cx <= w and cy <= h then
                local canPlace = false
                if terrainType == "water" then
                    canPlace = (level.tiles[cy][cx] ~= "mountain" and level.heights[cy][cx] == 0)
                elseif terrainType == "mountain" then
                    canPlace = (level.tiles[cy][cx] ~= "water" and level.heights[cy][cx] == 0)
                elseif terrainType == "tall" then
                    canPlace = (level.tiles[cy][cx] ~= "water" and level.tiles[cy][cx] ~= "mountain" and level.heights[cy][cx] == 0)
                end

                if canPlace then
                    level.tiles[cy][cx] = terrainType
                    if terrainType == "mountain" then level.heights[cy][cx] = 2 end
                    grown = grown + 1

                    -- Add neighbors to queue
                    for _, d in ipairs({ {1,0}, {-1,0}, {0,1}, {0,-1} }) do
                        local nx, ny = cx + d[1], cy + d[2]
                        if nx >= 1 and ny >= 1 and nx <= w and ny <= h and not seen[ny * 100 + nx] then
                            if rng.chance(0.6) then
                                seen[ny * 100 + nx] = true
                                table.insert(queue, { nx, ny })
                            end
                        end
                    end
                end
            end
        end
    end
end

-- Add meadow/flower variety on grass tiles
function M.addTerrainVariety(level, rng)
    for y = 1, level.height do
        for x = 1, level.width do
            if level.tiles[y][x] == "grass" and rng.chance(0.15) then
                level.tiles[y][x] = rng.pick({ "meadow", "flower" })
            end
        end
    end
end

-- Generate opposing spawn regions
function M.generateSpawnRegions(level, rng, minDistance)
    local w, h = level.width, level.height

    -- Player region: bottom area
    local playerRegion = { x1 = 1, y1 = h - 3, x2 = 4, y2 = h }
    -- Enemy region: top area
    local enemyRegion = { x1 = w - 3, y1 = 1, x2 = w, y2 = 4 }

    -- Ensure minimum distance between regions
    local centerPlayer = { x = (playerRegion.x1 + playerRegion.x2) / 2, y = (playerRegion.y1 + playerRegion.y2) / 2 }
    local centerEnemy = { x = (enemyRegion.x1 + enemyRegion.x2) / 2, y = (enemyRegion.y1 + enemyRegion.y2) / 2 }
    local dist = math.abs(centerPlayer.x - centerEnemy.x) + math.abs(centerPlayer.y - centerEnemy.y)

    if dist < minDistance then
        -- Adjust enemy region upward
        enemyRegion.y1 = math.max(1, enemyRegion.y1 - (minDistance - dist))
        enemyRegion.y2 = math.max(4, enemyRegion.y2 - (minDistance - dist))
    end

    -- Pick spawn positions within regions
    level.player_spawns = M.pickSpawnsInRegion(level, playerRegion, 4, rng)
    level.enemy_spawns = M.pickSpawnsInRegion(level, enemyRegion, 6, rng)
end

function M.pickSpawnsInRegion(level, region, count, rng)
    local candidates = {}
    for y = region.y1, region.y2 do
        for x = region.x1, region.x2 do
            if x >= 1 and x <= level.width and y >= 1 and y <= level.height then
                table.insert(candidates, { x = x, y = y })
            end
        end
    end

    -- Shuffle
    for i = #candidates, 2, -1 do
        local j = rng.int(1, i)
        candidates[i], candidates[j] = candidates[j], candidates[i]
    end

    local spawns = {}
    for i = 1, math.min(count, #candidates) do
        table.insert(spawns, candidates[i])
    end
    return spawns
end

-- Ensure spawns are on walkable tiles
function M.fixSpawnWalkability(level)
    local function isWalkable(x, y)
        return level.heights[y][x] < 2 and level.tiles[y][x] ~= "water"
    end

    local function fixSpawns(spawns)
        for _, s in ipairs(spawns) do
            if not isWalkable(s.x, s.y) then
                -- Search nearby for walkable
                for dy = -2, 2 do
                    for dx = -2, 2 do
                        local nx, ny = s.x + dx, s.y + dy
                        if nx >= 1 and ny >= 1 and nx <= level.width and ny <= level.height then
                            if isWalkable(nx, ny) then
                                s.x, s.y = nx, ny
                                goto next_spawn
                            end
                        end
                    end
                end
                ::next_spawn::
            end
        end
    end

    fixSpawns(level.player_spawns)
    fixSpawns(level.enemy_spawns)
end

-- Validate using existing validator
function M.validate(level)
    return LevelValidator.validate(level)
end

-- Save level to file
function M.saveLevel(level, path)
    local content = M.generateLevelFile(level)
    return love.filesystem.write(path, content)
end

-- Generate level file content
function M.generateLevelFile(level)
    local lines = {}
    table.insert(lines, "-- " .. level.id .. " — procedurally generated (seed " .. level.seed .. ")")
    table.insert(lines, "return {")
    table.insert(lines, '    id = "' .. level.id .. '",')
    table.insert(lines, "    width = " .. level.width .. ",")
    table.insert(lines, "    height = " .. level.height .. ",")
    table.insert(lines, "")
    table.insert(lines, "    tiles = {")
    for y = 1, level.height do
        local row = "        { "
        for x = 1, level.width do
            row = row .. '"' .. level.tiles[y][x] .. '"'
            if x < level.width then row = row .. ", " end
        end
        row = row .. " }"
        if y < level.height then row = row .. "," end
        table.insert(lines, row)
    end
    table.insert(lines, "    },")
    table.insert(lines, "")
    table.insert(lines, "    heights = {")
    for y = 1, level.height do
        local row = "        { "
        for x = 1, level.width do
            row = row .. level.heights[y][x]
            if x < level.width then row = row .. ", " end
        end
        row = row .. " }"
        if y < level.height then row = row .. "," end
        table.insert(lines, row)
    end
    table.insert(lines, "    },")
    table.insert(lines, "")
    table.insert(lines, "    player_spawns = {")
    for i, s in ipairs(level.player_spawns) do
        table.insert(lines, '        { x = ' .. s.x .. ', y = ' .. s.y .. ' },')
    end
    table.insert(lines, "    },")
    table.insert(lines, "")
    table.insert(lines, "    enemy_spawns = {")
    for i, s in ipairs(level.enemy_spawns) do
        table.insert(lines, '        { x = ' .. s.x .. ', y = ' .. s.y .. ' },')
    end
    table.insert(lines, "    },")
    table.insert(lines, "")
    table.insert(lines, "    tags = {")
    for i, t in ipairs(level.tags) do
        table.insert(lines, '        "' .. t .. '",')
    end
    table.insert(lines, "    },")
    table.insert(lines, "}")
    return table.concat(lines, "\n")
end

-- Batch generate candidates
function M.generateBatch(count, config)
    count = count or 100
    local saved = 0
    local results = {}

    for i = 1, count do
        local seed = math.random(1, 999999)
        local level = M.generate(seed, config)
        local result = M.validate(level)

        if result.valid then
            local path = "levels/forest/normal/" .. level.id .. ".lua"
            local ok = M.saveLevel(level, path)
            if ok then
                saved = saved + 1
                table.insert(results, { seed = seed, valid = true, path = path })
            else
                table.insert(results, { seed = seed, valid = true, saved = false })
            end
        else
            table.insert(results, { seed = seed, valid = false, errors = result.errors })
        end
    end

    return {
        total = count,
        saved = saved,
        results = results,
    }
end

return M
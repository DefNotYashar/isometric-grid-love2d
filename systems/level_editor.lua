-- level_editor.lua — in-game level editor (toggle with F2)
-- Allows painting terrain, placing spawns, editing tags, validating, saving
local G = require("state")
local Board = require("board")
local LevelValidator = require("systems.level_validator")
local M = {}

M.enabled = false
M.mode = "terrain" -- "terrain", "player_spawn", "enemy_spawn", "height", "tags", "generator"
M.selectedTerrain = "grass"
M.selectedHeight = 0
M.hoverTile = nil
M.genSeed = 12345
M.genConfig = {
    water_density = 0.10,
    mountain_density = 0.08,
    tall_grass_density = 0.15,
    min_walkable_tiles = 50,
}

-- Local diamond helper (same as render.lua)
local function diamond(cx, cy, w, h)
    return { cx, cy - h, cx + w, cy, cx, cy + h, cx - w, cy }
end

local TERRAIN_TYPES = {
    "default", "grass", "meadow", "flower", "tall", "water", "mountain"
}

local HEIGHTS = { 0, 1, 2 }

function M.toggle()
    M.enabled = not M.enabled
    if M.enabled then
        G.pushLog("EDITOR ON — F2 to exit, TAB to cycle mode, 1-7 terrain, H height")
        -- Initialize editor state from current level
        if G.currentLevel then
            M.selectedTerrain = G.currentLevel.tiles[1][1] or "grass"
        end
    else
        G.pushLog("EDITOR OFF")
    end
end

function M.cycleMode()
    local modes = { "terrain", "player_spawn", "enemy_spawn", "height", "tags", "generator" }
    for i, m in ipairs(modes) do
        if m == M.mode then
            M.mode = modes[(i % #modes) + 1]
            G.pushLog("Mode: " .. M.mode)
            break
        end
    end
end

function M.keypressed(key)
    if not M.enabled then return false end

    if key == "f2" then
        M.toggle()
        return true
    end
    if key == "tab" then
        M.cycleMode()
        return true
    end
    if key == "escape" then
        M.toggle()
        return true
    end

    -- Terrain selection (1-7)
    local terrainKeys = { "1", "2", "3", "4", "5", "6", "7" }
    for i, k in ipairs(terrainKeys) do
        if key == k and TERRAIN_TYPES[i] then
            M.selectedTerrain = TERRAIN_TYPES[i]
            G.pushLog("Terrain: " .. M.selectedTerrain)
            return true
        end
    end

    -- Height selection (h + 0/1/2)
    if key == "h" then
        -- Cycle height on next number key
        M.heightCycle = true
        return true
    end
    if M.heightCycle and (key == "0" or key == "1" or key == "2") then
        M.selectedHeight = tonumber(key)
        G.pushLog("Height: " .. M.selectedHeight)
        M.heightCycle = false
        return true
    end

    -- Save level
    if key == "s" and love.keyboard.isDown("lctrl") then
        M.saveLevel()
        return true
    end

    -- Validate level
    if key == "v" then
        M.validateLevel()
        return true
    end

    -- Generator controls (when in generator mode)
    if M.mode == "generator" then
        -- Generate with current seed
        if key == "g" then
            M.generateLevel()
            return true
        end
        -- Generate with random seed
        if key == "r" then
            M.genSeed = math.random(1, 999999)
            M.generateLevel()
            return true
        end
        -- Save generated level
        if key == "s" and love.keyboard.isDown("lctrl") then
            M.saveGeneratedLevel()
            return true
        end
        -- Batch generate
        if key == "b" then
            M.batchGenerate()
            return true
        end
    end

    -- Clear spawns
    if key == "c" and love.keyboard.isDown("lctrl") then
        if M.mode == "player_spawn" then
            G.currentLevel.player_spawns = {}
            G.pushLog("Cleared player spawns")
        elseif M.mode == "enemy_spawn" then
            G.currentLevel.enemy_spawns = {}
            G.pushLog("Cleared enemy spawns")
        end
        return true
    end

    -- Add tag
    if key == "t" then
        local tag = "custom"
        -- In a real editor, this would prompt for input
        table.insert(G.currentLevel.tags, tag)
        G.pushLog("Added tag: " .. tag)
        return true
    end

    return false
end

function M.mousepressed(x, y, button)
    if not M.enabled then return false end
    if button ~= 1 then return false end

    local tx, ty = Board.pickTile(x, y)
    if not tx or not Board.inBounds(tx, ty) then return false end

    if not G.currentLevel then
        G.pushLog("No level loaded to edit")
        return false
    end

    if M.mode == "terrain" then
        G.currentLevel.tiles[ty][tx] = M.selectedTerrain
        -- Auto-set height for mountain
        if M.selectedTerrain == "mountain" then
            G.currentLevel.heights[ty][tx] = 2
        elseif M.selectedTerrain == "water" then
            G.currentLevel.heights[ty][tx] = 0
        end
        -- Reload level to update rendering
        Board.loadLevel(G.currentLevel)
        return true
    elseif M.mode == "height" then
        G.currentLevel.heights[ty][tx] = M.selectedHeight
        Board.loadLevel(G.currentLevel)
        return true
    elseif M.mode == "player_spawn" then
        -- Add or remove player spawn
        local found = false
        for i, s in ipairs(G.currentLevel.player_spawns) do
            if s.x == tx and s.y == ty then
                table.remove(G.currentLevel.player_spawns, i)
                found = true
                G.pushLog("Removed player spawn at " .. tx .. "," .. ty)
                break
            end
        end
        if not found then
            table.insert(G.currentLevel.player_spawns, { x = tx, y = ty })
            G.pushLog("Added player spawn at " .. tx .. "," .. ty)
        end
        return true
    elseif M.mode == "enemy_spawn" then
        -- Add or remove enemy spawn
        local found = false
        for i, s in ipairs(G.currentLevel.enemy_spawns) do
            if s.x == tx and s.y == ty then
                table.remove(G.currentLevel.enemy_spawns, i)
                found = true
                G.pushLog("Removed enemy spawn at " .. tx .. "," .. ty)
                break
            end
        end
        if not found then
            table.insert(G.currentLevel.enemy_spawns, { x = tx, y = ty })
            G.pushLog("Added enemy spawn at " .. tx .. "," .. ty)
        end
        return true
    elseif M.mode == "tags" then
        -- Toggle tag on tile (for future region tagging)
        local tag = "region_" .. tx .. "_" .. ty
        local found = false
        for i, t in ipairs(G.currentLevel.tags) do
            if t == tag then
                table.remove(G.currentLevel.tags, i)
                found = true
                break
            end
        end
        if not found then
            table.insert(G.currentLevel.tags, tag)
        end
        G.pushLog("Toggled tag: " .. tag)
        return true
    end

    return false
end

function M.update(dt)
    if not M.enabled then return end
    local mx, my = love.mouse.getPosition()
    M.hoverTile = { Board.pickTile(mx, my) }
end

function M.draw()
    if not M.enabled then return end

    local C = G.C
    local font = G.fontSmall

    -- Editor UI panel
    local x, y = 10, 10
    local w, h = 320, 280

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
        love.graphics.print(tostring(value), x + 130, line)
        line = line + 18
    end

    info("MODE:", M.mode:upper())
    info("TERRAIN:", M.selectedTerrain .. " (1-7)")
    info("HEIGHT:", M.selectedHeight .. " (H+0/1/2)")
    info("HOVER:", M.hoverTile and (M.hoverTile[1] .. "," .. M.hoverTile[2]) or "none")

    line = line + 10
    love.graphics.setColor(C.accent)
    love.graphics.print("CONTROLS:", x + 10, line)
    line = line + 18
    love.graphics.setColor(C.muted)
    local controls = {
        "F2 - Toggle Editor",
        "TAB - Cycle Mode",
        "1-7 - Select Terrain",
        "H + 0/1/2 - Set Height",
        "Click - Paint/Place",
        "Ctrl+C - Clear Spawns",
        "V - Validate",
        "Ctrl+S - Save",
        "T - Add Tag",
        "ESC - Exit Editor",
    }
    for _, c in ipairs(controls) do
        love.graphics.print("  " .. c, x + 10, line)
        line = line + 14
    end

    -- Draw hover highlight on tile
    if M.hoverTile and M.hoverTile[1] then
        local tx, ty = M.hoverTile[1], M.hoverTile[2]
        local cx, cy = Board.tileToScreen(tx, ty, Board.tileTopZ(tx, ty))
        local tw, th = G.TILE_W * G.zoom, G.TILE_H * G.zoom
        love.graphics.setColor(C.select[1], C.select[2], C.select[3], 0.5)
        love.graphics.setLineWidth(3)
        love.graphics.polygon("line", diamond(cx, cy, tw - 4, th - 4))
        love.graphics.setLineWidth(1)
    end

    -- Draw spawn markers
    if G.currentLevel then
        for _, s in ipairs(G.currentLevel.player_spawns or {}) do
            local cx, cy = Board.tileToScreen(s.x, s.y, Board.tileTopZ(s.x, s.y))
            love.graphics.setColor(C.accent)
            love.graphics.setLineWidth(3)
            love.graphics.circle("line", cx, cy, 20 * G.zoom)
            love.graphics.setLineWidth(1)
        end
        for _, s in ipairs(G.currentLevel.enemy_spawns or {}) do
            local cx, cy = Board.tileToScreen(s.x, s.y, Board.tileTopZ(s.x, s.y))
            love.graphics.setColor(C.floatDmg)
            love.graphics.setLineWidth(3)
            love.graphics.circle("line", cx, cy, 20 * G.zoom)
            love.graphics.setLineWidth(1)
        end
    end

    -- Generator mode UI
    if M.mode == "generator" then
        M.drawGeneratorUI()
    end
end

function M.validateLevel()
    if not G.currentLevel then
        G.pushLog("No level to validate")
        return
    end
    local result = LevelValidator.validate(G.currentLevel)
    if result.valid then
        G.pushLog("VALID: Level passes all checks")
    else
        G.pushLog("INVALID: " .. #result.errors .. " errors")
        for _, e in ipairs(result.errors) do
            G.pushLog("  ERR: " .. e)
        end
    end
    for _, w in ipairs(result.warnings) do
        G.pushLog("  WARN: " .. w)
    end
end

function M.saveLevel()
    if not G.currentLevel then
        G.pushLog("No level to save")
        return
    end

    -- Validate first
    local result = LevelValidator.validate(G.currentLevel)
    if not result.valid then
        G.pushLog("Cannot save: validation failed")
        for _, e in ipairs(result.errors) do
            G.pushLog("  ERR: " .. e)
        end
        return
    end

    -- Generate Lua file content
    local content = M.generateLevelFile(G.currentLevel)
    local path = "levels/" .. G.currentLevel.area .. "/" .. G.currentLevel.type .. "/" .. G.currentLevel.id .. ".lua"

    local success = love.filesystem.write(path, content)
    if success then
        G.pushLog("SAVED: " .. path)
    else
        G.pushLog("SAVE FAILED: " .. path)
    end
end

function M.generateLevelFile(level)
    local lines = {}
    table.insert(lines, "-- " .. level.id .. " — edited via level editor")
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

function M.createNewLevel(id, area, type, width, height)
    width = width or 10
    height = height or 10
    local level = {
        id = id,
        area = area or "forest",
        type = type or "normal",
        width = width,
        height = height,
        tiles = {},
        heights = {},
        player_spawns = {},
        enemy_spawns = {},
        tags = { area or "forest" },
    }
    for y = 1, height do
        level.tiles[y] = {}
        level.heights[y] = {}
        for x = 1, width do
            level.tiles[y][x] = "default"
            level.heights[y][x] = 0
        end
    end
    -- Default spawns
    level.player_spawns = { { x = 2, y = height - 1 }, { x = 3, y = height - 1 }, { x = 2, y = height }, { x = 3, y = height } }
    level.enemy_spawns = { { x = width - 1, y = 2 }, { x = width, y = 2 }, { x = width - 1, y = 3 }, { x = width, y = 3 } }
    return level
end

-- Generator functions
local LevelGenerator = require("systems.level_generator")

function M.generateLevel()
    if not G.currentLevel then
        G.pushLog("No level loaded")
        return
    end
    G.pushLog("Generating level with seed " .. M.genSeed .. "...")
    local level = LevelGenerator.generate(M.genSeed, M.genConfig)
    -- Apply to current level
    G.currentLevel.tiles = level.tiles
    G.currentLevel.heights = level.heights
    G.currentLevel.player_spawns = level.player_spawns
    G.currentLevel.enemy_spawns = level.enemy_spawns
    G.currentLevel.id = level.id
    G.currentLevel.seed = level.seed
    G.currentLevel.tags = level.tags
    -- Reload board
    Board.loadLevel(G.currentLevel)
    -- Validate
    local result = LevelValidator.validate(G.currentLevel)
    if result.valid then
        G.pushLog("GENERATED: Valid level (seed " .. M.genSeed .. ")")
    else
        G.pushLog("GENERATED: " .. #result.errors .. " errors")
        for _, e in ipairs(result.errors) do G.pushLog("  ERR: " .. e) end
    end
end

function M.saveGeneratedLevel()
    if not G.currentLevel then
        G.pushLog("No level to save")
        return
    end
    -- Validate first
    local result = LevelValidator.validate(G.currentLevel)
    if not result.valid then
        G.pushLog("Cannot save: validation failed")
        for _, e in ipairs(result.errors) do G.pushLog("  ERR: " .. e) end
        return
    end
    local content = M.generateLevelFile(G.currentLevel)
    local path = "levels/" .. G.currentLevel.area .. "/" .. G.currentLevel.type .. "/" .. G.currentLevel.id .. ".lua"
    local success = love.filesystem.write(path, content)
    if success then
        G.pushLog("SAVED: " .. path)
    else
        G.pushLog("SAVE FAILED: " .. path)
    end
end

function M.batchGenerate()
    G.pushLog("Batch generating 50 levels...")
    local result = LevelGenerator.generateBatch(50, M.genConfig)
    G.pushLog("Batch complete: " .. result.saved .. " / " .. result.total .. " saved")
end

function M.drawGeneratorUI()
    local C = G.C
    local font = G.fontSmall
    local x, y = 350, 10
    local w, h = 300, 320

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
        love.graphics.print(tostring(value), x + 150, line)
        line = line + 18
    end

    love.graphics.setColor(C.accent)
    love.graphics.print("PROCEDURAL GENERATOR", x + 10, line)
    line = line + 22

    info("SEED:", M.genSeed)
    info("WATER:", math.floor(M.genConfig.water_density * 100) .. "%")
    info("MOUNTAINS:", math.floor(M.genConfig.mountain_density * 100) .. "%")
    info("TALL GRASS:", math.floor(M.genConfig.tall_grass_density * 100) .. "%")
    info("MIN WALKABLE:", M.genConfig.min_walkable_tiles)

    line = line + 10
    love.graphics.setColor(C.accent)
    love.graphics.print("CONTROLS:", x + 10, line)
    line = line + 18
    love.graphics.setColor(C.muted)
    local controls = {
        "G - Generate (current seed)",
        "R - Generate (random seed)",
        "Ctrl+S - Save level",
        "B - Batch generate (50)",
        "TAB - Exit generator mode",
        "ESC - Exit editor",
    }
    for _, c in ipairs(controls) do
        love.graphics.print("  " .. c, x + 10, line)
        line = line + 14
    end

    -- Validation status
    if G.currentLevel then
        local result = LevelValidator.validate(G.currentLevel)
        line = line + 10
        love.graphics.setColor(result.valid and C.accent or C.floatDmg)
        love.graphics.print(result.valid and "VALIDATION: PASS" or "VALIDATION: FAIL", x + 10, line)
        if not result.valid then
            for _, e in ipairs(result.errors) do
                line = line + 14
                love.graphics.setColor(C.floatDmg)
                love.graphics.print("  " .. e, x + 10, line)
            end
        end
    end
end

return M
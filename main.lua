-- Isometric Grid Lab — Love2D remake.
-- Wiring only (spec 001): modules own every system, love.* callbacks
-- delegate. See AGENTS.md for conventions, .specify/specs/001-module-split
-- for the split spec/plan/tasks.
-- LÖVE 11.x (0-1 colors, love.load / love.update(dt) / love.draw).
local G = require("state")
local Board = require("board")
local Units = require("units")
local Render = require("render")
local Menu = require("menu")
local Camera = require("camera")
local Input = require("input")

-- ---------- audio: menu + in-game music (seamless crossfade) ----------
local menuMusic, gameMusic = nil, nil
local menuGain, gameGain = 0, 0 -- per-track fade 0..1, ramped every frame
local FADE_RATE = 1.4 -- gain per second (~0.7 s crossfade)

local function loadMusic(path)
    if love.filesystem.getInfo(path) then
        local s = love.audio.newSource(path, "stream")
        s:setLooping(true)
        return s
    end
end

-- ---------- footstep SFX (by unit.kind + terrain) ----------
local stepSnd = {}
local STEP_TERRAIN = {
    grass = "grass", meadow = "grass", flower = "grass", tall = "grass",
    water = "water", default = "dirt", shopfloor = "dirt", shopdoor = "dirt",
}

local function playStep(unit, terrain)
    local kind = unit.kind or "hero"
    local s = stepSnd[kind]
    -- slime/skeleton use their own sounds regardless of terrain
    if not s then
        local surface = STEP_TERRAIN[terrain] or "dirt"
        s = stepSnd[surface]
    end
    if not s then return end
    -- clone so rapid steps overlap instead of cutting off
    local c = s:clone()
    c:setPitch(0.92 + math.random() * 0.16)
    local vol = ((G.volume or 8) / 10) * (kind == "hero" and 0.55 or 0.45)
    c:setVolume(vol)
    c:play()
end

-- ---------- love callbacks ----------
function love.load()
    Camera.initWindow()
    love.graphics.setBackgroundColor(G.C.bg)
    G.fontTitle = love.graphics.newFont("assets/fonts/LiberationSans-Regular.ttf", 28)
    G.fontHead  = love.graphics.newFont("assets/fonts/LiberationSans-Regular.ttf", 13)
    G.fontBody  = love.graphics.newFont("assets/fonts/JetBrainsMonoNerdFont-Regular.ttf", 14)
    G.fontSmall = love.graphics.newFont("assets/fonts/JetBrainsMonoNerdFont-Regular.ttf", 11)
    G.initBoard()
    Board.paintFreeMeadow()
    G.roster = Units.defaultRoster()
    Units.spawnAll()
    for i = 1, 40 do
        G.dust[i] = { x = math.random() * G.W, y = math.random() * G.H,
            vx = 6 + math.random() * 14, vy = -4 - math.random() * 8,
            r = 1 + math.random() * 1.8, a = 0.10 + math.random() * 0.15, ph = math.random() * 6.28 }
    end
    G.pushLog("ready — click a pawn, then a tile")
    -- music: menu loop + in-game loop (played per state, volume from settings)
    menuMusic = loadMusic("assets/audio/menu_lofi_loop.wav")
    gameMusic = loadMusic("assets/audio/game_lofi_loop.wav")
    -- footsteps: short static SFX, triggered from the glide via G.playStep
    for _, surface in ipairs({ "dirt", "grass", "water" }) do
        local path = "assets/audio/step_" .. surface .. ".wav"
        if love.filesystem.getInfo(path) then
            stepSnd[surface] = love.audio.newSource(path, "static")
        end
    end
    G.playStep = playStep
    -- enemy-specific step SFX (by unit.kind)
    for _, kind in ipairs({ "slime", "skeleton" }) do
        local path = "assets/audio/step_" .. kind .. ".wav"
        if love.filesystem.getInfo(path) then
            stepSnd[kind] = love.audio.newSource(path, "static")
        end
    end
end

function love.resize(w, h)
    Camera.syncViewport()
end

function love.update(dt)
    Camera.syncViewport() -- tiling WMs resize without resize events; poll every frame
    Camera.updateZoom(dt)
    G.selAnim = math.min(1, G.selAnim + dt * 6)
    
    -- shop phase handling
    if G.phase == "shop" then
        Menu.updateShop(dt)
        -- music continues in shop
        local master = (G.volume or 8) / 10
        if gameMusic then
            if gameGain <= 0 then gameGain = 1 end
            if not gameMusic:isPlaying() then gameMusic:play() end
            gameMusic:setVolume(gameGain * master)
        end
        return
    end
    
    if not G.win then Camera.pollPanKeys(dt) end -- cinematic drives the camera
    Input.updatePick()
    Input.updateAmbient(dt)
    if G.state ~= "over" then Units.updateGlide(dt, Menu.checkFinish) end
    Units.updateAI(dt) -- gated internally on game state; drives queued enemy beats
    if G.win then Menu.updateWin(dt) -- win cinematic: zoom on hero, then swap
    else Menu.checkClear() end -- kills land via attacks, not steps: poll win
    
    -- Level editor update
    local LevelEditor = require("systems.level_editor")
    LevelEditor.update(dt)
    
    -- music: crossfade between menu and game tracks on state changes
    -- (no hard cuts); master volume follows the settings screen (0..10).
    local wantMenu = (G.state == "menu")
    local master = (G.volume or 8) / 10
    local fadeDt = math.min(dt, 0.1)
    if wantMenu then
        menuGain = math.min(1, menuGain + fadeDt * FADE_RATE)
        gameGain = math.max(0, gameGain - fadeDt * FADE_RATE)
    else
        gameGain = math.min(1, gameGain + fadeDt * FADE_RATE)
        menuGain = math.max(0, menuGain - fadeDt * FADE_RATE)
    end
    if menuMusic then
        if menuGain > 0 and not menuMusic:isPlaying() then menuMusic:play() end
        if menuGain <= 0 and menuMusic:isPlaying() then menuMusic:stop() end
        menuMusic:setVolume(menuGain * master)
    end
    if gameMusic then
        if gameGain > 0 and not gameMusic:isPlaying() then gameMusic:play() end
        if gameGain <= 0 and gameMusic:isPlaying() then gameMusic:stop() end
        gameMusic:setVolume(gameGain * master)
    end
end

function love.draw()
    local time = love.timer.getTime()
    if G.state == "menu" then
        Menu.draw(time)
        return
    end
    if G.phase == "shop" then
        Menu.drawShop(time)
        return
    end
    if G.win and G.win.phase == "upgrade" then
        Render.drawUpgrade(time)
        return
    end
    Render.drawBackdrop(time)
    Render.drawBoard(time)
    Render.drawHUD()
    Render.drawPortrait()
    if G.win then Render.drawWin() end
    if G.state == "over" then Render.drawGameOver() end
    -- Level editor draw (on top of everything)
    local LevelEditor = require("systems.level_editor")
    LevelEditor.draw()
end

function love.mousepressed(x, y, button)
    Input.mousepressed(x, y, button)
end

function love.mousereleased(_, _, button)
    Input.mousereleased(_, _, button)
end

function love.mousemoved(_, _, dx, dy)
    Input.mousemoved(_, _, dx, dy)
end

function love.wheelmoved(_, y)
    Input.wheelmoved(_, y)
end

function love.keypressed(key)
    Input.keypressed(key)
end

function love.errorhandler(msg)
    local trace = debug.traceback("Error: " .. tostring(msg), 2)
    pcall(function()
        local dir = love.filesystem.getSaveDirectory()
        love.filesystem.write("crash.log", trace .. "\n")
        -- also try absolute path fallback
        io.open("/tmp/love_crash.log","w"):write(trace):close()
    end)
    return trace
end

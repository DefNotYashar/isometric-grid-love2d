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
end

function love.resize(w, h)
    Camera.syncViewport()
end

function love.update(dt)
    Camera.syncViewport() -- tiling WMs resize without resize events; poll every frame
    Camera.updateZoom(dt)
    G.selAnim = math.min(1, G.selAnim + dt * 6)
    if not G.win then Camera.pollPanKeys(dt) end -- cinematic drives the camera
    Input.updatePick()
    Input.updateAmbient(dt)
    if G.state ~= "over" then Units.updateGlide(dt, Menu.checkFinish) end
    Units.updateAI(dt) -- gated internally on game state; drives queued enemy beats
    if G.win then Menu.updateWin(dt) -- win cinematic: zoom on hero, then swap
    else Menu.checkClear() end -- kills land via attacks, not steps: poll win
end

function love.draw()
    local time = love.timer.getTime()
    if G.state == "menu" then
        Menu.draw(time)
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

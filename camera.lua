-- camera.lua — viewport, pan/zoom. Deps: state (G) only.
local G = require("state")
local M = {}

function M.initWindow()
    love.window.setMode(G.W, G.H, { resizable = true, vsync = 1 })
    G.originX = G.W / 2
    G.originY = G.H / 2 - G.GRID * G.HALF_H * G.zoom + 24
end

function M.syncViewport()
    local w, h = love.graphics.getDimensions()
    if w ~= G.W or h ~= G.H then G.W, G.H = w, h end
    -- recentered every frame (cheap): the board stays centered as the
    -- fixed zoom steps up and through the win-cinematic push-in.
    G.originX = G.W / 2
    G.originY = G.H / 2 - G.GRID * G.HALF_H * G.zoom + 24
end

-- Keep the board findable: the camera is clamped every frame (and after
-- every pan/zoom) so the board's bounding box always overlaps the viewport
-- by at least VMIN pixels. Without this, zoom-to-cursor on an off-board
-- point (panel, HUD, empty corner) walks the board away, and unbounded
-- pan/zoom then strands it off-screen with only R to recover.
-- World bounds scale with grid size: x in ±((N-1)*32+52),
-- y in [-40, N*32+60] (tiles + pawn/pillar overhang).
function M.clampCamera()
    local VMIN = 150
    local N = G.GRID
    local x0, x1 = -((N - 1) * 32 + 52), ((N - 1) * 32 + 52)
    local y0, y1 = -40, N * 32 + 60
    G.camX = math.max(VMIN - G.originX - x1 * G.zoom,
             math.min(G.W - VMIN - G.originX - x0 * G.zoom, G.camX))
    G.camY = math.max(VMIN - G.originY - y1 * G.zoom,
             math.min(G.H - VMIN - G.originY - y0 * G.zoom, G.camY))
end

function M.updateZoom(dt)
    -- smooth zoom toward target
    G.zoom = G.zoom + (G.zoomTarget - G.zoom) * math.min(1, dt * 10)
    if math.abs(G.zoom - G.zoomTarget) < 0.001 then G.zoom = G.zoomTarget end
end

function M.pollPanKeys(dt)
    -- camera pan (held keys)
    local sp = 420 * dt
    if love.keyboard.isDown("w", "up") then G.camY = G.camY - sp end
    if love.keyboard.isDown("s", "down") then G.camY = G.camY + sp end
    -- NOTE: A/D double as pawn step when a unit is idle; pan with arrows or right-drag.
    if love.keyboard.isDown("left") then G.camX = G.camX - sp end
    if love.keyboard.isDown("right") then G.camX = G.camX + sp end
    M.clampCamera()
end

function M.reset() G.camX, G.camY = 0, 0 end

return M

# Isometric Grid Lab (LÖVE 11.5)

10×10 isometric block field with pawn units. Click a pawn, click a tile, it walks there.

## Run

```sh
cd isometric-grid-love2d
love .
```

Requires LÖVE 11.x (`love --version`). No dependencies, no build step.
`conf.lua` pins window 1280×800, resizable, vsync. Game adapts to any window
size (viewport is re-polled every frame — tiling WMs resize without events).

## Files

| File | Purpose |
|---|---|
| `main.lua` | Wiring only: `love.*` callbacks delegate to modules (~80 lines) |
| `state.lua` | Shared `G` table: constants, board, units, fx, palette |
| `board.lua` | Iso math, picking, procedural gen, shop teleport rooms |
| `units.lua` | Roster, Dijkstra movement/orders, pawn glide |
| `render.lua` | All drawing (blocks, pawns, HUD, panel, shop markers) |
| `menu.lua` | Menu screens + run/flow transitions |
| `camera.lua` | Viewport, pan/zoom, clamping |
| `input.lua` | Input callbacks + hover/ambient updates |
| `conf.lua` | LÖVE config: identity, version `"11.5"`, window |
| `assets/fonts/` | `LiberationSans-Regular.ttf` (titles), `JetBrainsMonoNerdFont-Regular.ttf` (HUD) |

## Controls

| Input | Action |
|---|---|
| Left click pawn | Select unit |
| Left click tile | Order selected unit to move (BFS path, capped by unit range) |
| W A S D | Step selected unit one tile (grid N/S/W/E, not camera) |
| Tab | Cycle units on the visible map |
| Arrow keys | Pan camera |
| Right-drag | Pan camera |
| Mouse wheel | Zoom at cursor (0.45×–2.5×) |
| R | Reset camera |
| Esc | Back to menu (quit from the main menu) |

## Coordinate conventions (read before editing)

- **Grid:** 1-indexed Lua tables. `heights[y][x]`, `x` = column (screen right-down axis), `y` = row (screen left-down axis). Displayed to the player as `x, y`.
- **Blocked key:** `blocked[y * 100 + x] = true`. Pillars at (5,5), (5,6), (6,5) with `heights = 2`.
- **Units** store integer `gx, gy` (logical tile) plus float `px, py` (smooth render position). Never render from `gx` directly — `px/py` glide toward path steps in `love.update`.
- **Iso projection:** `tileToScreen(gx,gy,z)` → `ox + (gx-gy)*32*zoom`, `oy + ((gx+gy)*16 - z)*zoom`. Tiles are drawn centered on integer coords. `screenToTile` inverts at the z=0 plane and rounds to nearest; `pickTile` refines it with per-tile top-diamond tests (mirrors `drawBlock` z incl. heights, water offset, hover lift) and returns the frontmost hit.
- **Heights** are in block levels; pixels = `level * BLOCK_H` (26). Blocked pillars render 2 levels tall.

## Systems

- **Movement (`findPath`, `reachable`, `orderMove`, `stepMove`):** orthogonal BFS only. Avoids blocked tiles and tiles occupied by other units. Tile keys are `y * 100 + x` everywhere (decode `x = k % 100, y = floor(k / 100)`). `orderMove` rejects paths longer than `unit.range` and orders while already moving. `unit.path` is a queue of `{x, y}` steps; each step is a fixed `STEP_TIME` (0.14 s) segment from `fx,fy` with smoothstep easing, `px/py` purely derived — never exponential approach, never snap thresholds. New units need `fx, fy` fields (or they default from `gx, gy` when idle).
- **Rendering (painter's order):** `love.draw` iterates diagonal bands `s = gx+gy` from 2 to 20, drawing blocks then any pawn whose tile-sum equals `s`. This keeps nearer blocks/pawns overlapping farther ones correctly.
- **Blocks (`drawBlock`):** top diamond + two extruded side faces (north = mid tone, west = darkest; light comes from screen-right). Per-tile hover lift is tweened in the `lift["x,y"]` table toward `LIFT_PX` (10 px).
- **Pawns (`drawPawn`):** flat two-tone silhouette — ground shadow ellipse, base, trapezoid body (`color` + `dark`), collar, head, one matte highlight dot. Active pawn gets a pulsing ring. Add new units by appending to the `units` table: `{ id, name, gx, gy, px, py, map="over", color={r,g,b}, dark={r,g,b}, range=n, path={}, t=0 }`.
- **Camera:** `camX/camY` offset + `zoom`, applied inside `tileToScreen`. `originX/originY` recenter from `syncViewport()`. Wheel sets `zoomTarget` (smooth-lerped in `love.update`); anchor is the cursor when over the board, viewport center otherwise. `clampCamera()` runs every frame and after pan/zoom events, using grid-scaled world bounds so the board always overlaps the viewport by ≥150 px — the grid can never be lost. `R` resets.
- **Shop (run maps):** one "shopdoor" entrance tile on the overworld (`G.shopOver`); stepping on it teleports the unit into a separate 8x8 room (`G.maps.shop`, door/rug/spawn record), room door teleports back out. `Board.checkShop` runs in the glide onStep chain (clears path); `switchMap` stashes/swaps board tables + resets fx/camera. Units carry `u.map`; off-map units are frozen, unselectable, untabable.

## Palette (`C` table)

Dark slate backdrop (`bg` 0.08,0.085,0.11), cream block tops (`top`), green accents (`accent` 0.45,0.78,0.46) for selection/range/HUD. All LÖVE 11 colors are 0–1 floats. Keep new colors in the `C` table, not inline.

## Verified working

- `luajit -bl main.lua` syntax check passes.
- Ran headless 8 s with empty error log; framebuffer screenshots verified: full board fits, panel renders, pawns/pillars/highlights correct at 941×506 tiled size.
- Screenshot probe method: temporarily append a frame counter in `love.update` calling `love.graphics.captureScreenshot("probe.png")` (save-dir path, not absolute), run, then revert. Save dir: `~/.local/share/love/isometric-grid-love2d/`.

## Known limitations / next hooks

- No persistence or audio. No diagonal movement. No combat/HP (React prototype's `units.js` had an `hp` field — not ported).
- `reachable()` is cached once per frame (`cachedReach`) — fine at 10×10, re-check if the grid grows.
- `love._panning` is a throwaway global for right-drag state.

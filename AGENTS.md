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
| `render.lua` | All drawing (blocks, pawns, HUD, portrait, shop markers) |
| `menu.lua` | Menu screens + run/flow transitions |
| `camera.lua` | Viewport, pan/zoom, clamping |
| `input.lua` | Input callbacks + hover/ambient updates |
| `conf.lua` | LÖVE config: identity, version `"11.5"`, window |
| `assets/fonts/` | `LiberationSans-Regular.ttf` (titles), `JetBrainsMonoNerdFont-Regular.ttf` (HUD) |

## Controls

| Input | Action |
|---|---|
| Left click pawn | Select ally (syncs turn-queue position) |
| Left click tile | Order selected unit to move (BFS path, capped by unit range) |
| Left click enemy | Default attack (melee, must be orthogonally adjacent) |
| W A S D | Step selected unit one tile (grid N/S/W/E, not camera) |
| Tab | Cycle unacted allies in initiative order, visible map only |
| Space / END TURN button | End the active unit's turn |
| Q / BOLT button | Arm firebolt targeting (3 mana, range 3, click an enemy) |
| C / STATS arrow | Collapse or expand the portrait stat block |
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
- **Pawns (`drawPawn`):** flat two-tone silhouette — ground shadow ellipse, base, trapezoid body (`color` + `dark`), collar, head, one matte highlight dot. Active pawn gets a pulsing ring. Enemies: slimes (`drawSlime`, move 1 / dmg 1 / HP 4) and skeleton archers (`drawSkeleton`: bone body, skull, bow; move 4 / bow 5 dmg @ rng 3 / HP 10). Add new units via roster defs in `units.lua` (`{ id, name, gx, gy, color, dark, stats={...} }`); `spawnUnit` derives `maxHP/hp` (`maxHP` override or `vigor×4`), `maxMana/mana` (`charisma×3`), `range` (`move` override or `speed`). `u.kind` drives look + AI (`slime`/`archer`/`hero`).
- **Stats:** `u.stats` holds the six base stats. STR = melee damage, DEX = +2% dodge each, LUCK = 3% crit chance each (x1.5), CHA = firebolt damage + mana. A unit card (left side) shows the active unit: team strip, medallion bust, name, status pill, beveled HP/MANA bars, purse, collapsible inset stat cells.
- **Camera:** `camX/camY` offset + fixed `zoom` (1.8 standard/shop, 1.3 big; no user zoom), applied inside `tileToScreen`. `originX/originY` recenter every frame in `syncViewport()` (originY is zoom-aware so the board stays centered). `clampCamera()` runs every frame and after pan events, using grid-scaled world bounds so the board always overlaps the viewport by ≥150 px — the grid can never be lost. `R` resets pan.
- **Shop (run maps):** one "shopdoor" entrance tile on the overworld (`G.shopOver`); stepping on it teleports the unit into a separate 8x8 room (`G.maps.shop`, door/rug/spawn record), room door teleports back out. `Board.checkShop` runs in the glide onStep chain (clears path); `switchMap` stashes/swaps board tables + resets fx/camera. Units carry `u.map`; off-map units are frozen, unselectable, untabable.
- **Turns (`G.turnOrder`, `G.turnPos`, `G.round`):** unit ids sorted by Speed desc (roster order breaks ties), rebuilt on every spawn path (also clears queued `G.ai`). Each round every unit gets one move (sets `moved`) plus exactly one attack — melee OR bolt OR archer shot, all set `acted`. Heroes hold selection after acting — the player advances with END TURN/Space only; enemies auto-pass. `advanceTurn` selects the next unacted on-map unit; when all acted, `newRound` clears flags and `G.round` increments. Tab cycles unacted allies; click-select syncs via `syncTurnPos`.
- **Enemy pacing (`G.ai`, `AI_THINK` 0.55s, `AI_STRIKE` 0.45s):** `enemyTurn` only queues `{id, phase, t}`; `Units.updateAI(dt)` (called from `love.update`) walks think → move → strike beats, then resolves exactly one attack. Board input (move/attack/select/Tab/Space/Q/WASD/buttons) locks while `G.ai` is set; Esc/C/stats-toggle stay live.
- **Turn bar (`drawTurnBar`):** top-center initiative strip on a backdrop pill, queue order from current unit wrapping the full loop, round badge `Rn` on the left. Big portrait chips (pawn / slime / skull faces), mini HP bars, current ringed + named, acted dimmed with ✓, off-map ghosted, AI-acting enemy pulses.
- **Actions:** default attack is melee only (Manhattan distance 1), damage = attacker Strength (min 1). Skeleton archers shoot at range 1–3 (`orderRanged`, dmg 5) with a flying arrow projectile (`G.arrows`, drawn arcing in `drawBoard`). Tall grass + DEX feed dodge (cap 75%), LUCK feeds crits. Firebolt costs 3 mana, range 3, damage = 2 + Charisma. Clicking an enemy attacks — enemies are never selectable. Hovering an enemy opens an intel panel (name, HP, threat readout, stat grid, bio via `Units.bioOf`). Kills give +1 maxHP, heal 2, and coins. Units carry `team` (`hero`/`enemy`).
- **Stakes:** clearing all enemies triggers the win cinematic (slow zoom on hero → rewards card → upgrade screen → next level); party wipe shows a game-over screen (any click returns to menu). Entering the shop or descending fully restores HP/mana. Run enemies scale with level (count 2→4, archers join lv2+, +1 vigor/strength per 2 levels).
- **Enemy AI (`enemyTurn`):** slimes close to adjacent and strike; archers hold at bow range (move toward the nearest hero only when out of range) and shoot. Runs automatically on the enemy's turn.

## Palette (`C` table)

Dark slate backdrop (`bg` 0.08,0.085,0.11), cream block tops (`top`), green accents (`accent` 0.45,0.78,0.46) for selection/range/HUD. All LÖVE 11 colors are 0–1 floats. Keep new colors in the `C` table, not inline.

## Verified working

- `luajit -bl main.lua` syntax check passes.
- Ran headless 8 s with empty error log; framebuffer screenshots verified: full board fits, portrait renders, pawns/pillars/highlights correct at 941×506 tiled size.
- Screenshot probe method: temporarily append a frame counter in `love.update` calling `love.graphics.captureScreenshot("probe.png")` (save-dir path, not absolute), run, then revert. Save dir: `~/.local/share/love/isometric-grid-love2d/`.

## Known limitations / next hooks

- No persistence or audio. No diagonal movement.
- `reachable()` is cached once per frame (`cachedReach`) — fine at 10×10, re-check if the grid grows.
- `love._panning` is a throwaway global for right-drag state.

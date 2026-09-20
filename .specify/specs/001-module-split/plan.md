# Plan 001 — Module split

## Design
Shared-state pattern: `state.lua` returns table `G` holding all mutable
state + constants. Every module `require`s `state` (sibling files in the
LÖVE source dir, so `require("board")` resolves) and reads/writes
`G.field` at use time. Pure draw functions stay function-identical,
only identifier prefixes change (`heights` → `G.heights`,
`tileToScreen(` → `Iso.tileToScreen(` where iso math moves).

Four scout agents already mapped exact line ranges and cross-deps
(see session notes); module contents follow their drafts with one
adjustment: iso math (`tileToScreen`/`screenToTile`) lives in
`board.lua` (needs GRID/HALF/camera at call time → pass via G).

## Module contents
| File | Owns |
|---|---|
| `state.lua` | `G` table: constants, palette `C`, all mutable state, `pushLog` |
| `board.lua` | heights/blocked/pillars/terrain/run gen, `tileCost`, `dodgeChanceAt`, `inBounds`, `isBlocked`, iso math |
| `units.lua` | roster, `spawnUnit`, unit list, `unitAt`, Dijkstra `findPath`/`pathCost`/`reachable`, `orderMove`/`stepMove`, glide update |
| `render.lua` | `C` reads, diamond/shade, `drawBlock`, `drawPawn`, backdrop, shadow, panel, HUD |
| `menu.lua` | menu screens/items/draw/hit/activate, `startRun`, `nextLevel`, `checkFinish`, `applyMode` |
| `camera.lua` | W/H/origin/cam/zoom, clamp, viewport sync, zoom lerp, pan poll, reset |
| `input.lua` | hover pick, reach/path cache, ambient tweens, all love input callbacks |
| `main.lua` | `require`s, `G` init, `love.load/resize/update/draw/*` delegation |

## Risks
- Value-copy of scalars in module locals → mitigated by constitution
  rule 3 (always `G.field`).
- Transcription drift in big draw functions → mitigated by copying
  bodies verbatim and running the verification gates.

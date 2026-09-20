# Spec 001 — Split `main.lua` monolith into modules

## Problem
`main.lua` (~1175 lines) holds every system: constants, palette, board
procgen, units, Dijkstra movement, all rendering, menu/flow, camera,
input, and `love.*` callbacks. Any game work risks cross-system edits.

## Goal
Separate every module/system into its own file with clean boundaries,
keeping the code (and game) behaving byte-identically.

## Scope
- New files: `state.lua`, `board.lua`, `units.lua`, `render.lua`,
  `menu.lua`, `camera.lua`, `input.lua`.
- `main.lua` becomes wiring: build `G`, `require` modules, delegate
  `love.load/update/draw/*` callbacks.
- No gameplay, visual, or input changes. No new features.
- `conf.lua`, `assets/`, AGENTS.md conventions untouched.

## Acceptance criteria
1. Each system lives in exactly one module per the constitution's
   dependency diagram.
2. `luajit -bl` passes on all files.
3. Headless 8 s `love .` run leaves an empty error log.
4. Manual smoke: menu → select pawn → run map renders with terrain,
   free play spawns 4 pawns, click-move / WASD / Tab / pan / zoom work.

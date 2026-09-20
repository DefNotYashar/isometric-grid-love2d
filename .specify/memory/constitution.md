# Constitution — Isometric Grid Lab (LÖVE 11.5)

Principles every change must uphold. Spec-driven: no code without a
spec entry; no merge without verification.

## 1. Behavior preservation
Refactors must not change gameplay, rendering, or input behavior.
Coordinate conventions are frozen (see AGENTS.md): 1-indexed grid,
`heights[y][x]`, blocked key `y*100+x`, `px/py` glide derived from
`fx/fy` with smoothstep over fixed `STEP_TIME`.

## 2. Module boundaries
One system per module, single direction of dependencies:

```
state (shared table G, no deps)
board (map data + procgen; deps: state constants)
units (roster + Dijkstra movement; deps: board)
render (all drawing, read-only; deps: state, board, units refs via G)
menu (flow: modes/select/run levels; deps: board, units)
camera (viewport/pan/zoom; deps: state only)
input (callbacks + per-frame pick; deps: camera, menu, units)
main (wiring + love.* callbacks only)
```

Render never mutates game state. Camera never touches units/terrain.

## 3. Shared state discipline
Mutable scalars live in `G` and are ALWAYS accessed as `G.field`
at use time — never cached in module-level locals (Lua numbers copy
by value). Table rebinds (`units = {...}`, `blocked = {}`) must write
`G.units` / `G.blocked` so all readers stay live.

## 4. Verification gates
- `luajit -bl` passes on every `.lua` file.
- Headless `love .` run shows an empty error log.
- `main.lua` keeps the AGENTS.md contract (controls, iso math,
  painter's order, palette in `C`).

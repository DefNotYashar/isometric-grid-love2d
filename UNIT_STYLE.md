# Unit Art Style Guide — Method & Pipeline

## Scope
Applies to every new unit module in `assets/units/`. The goal is visual coherence at 1.5×–2.5× zoom on a 10×10 isometric grid, with the same sprite used for board, portrait medallion, and turn-bar chip.

---

## 1. Coordinate Contract (must match exactly)

| Function | Signature | Anchor | Notes |
|---|---|---|---|
| `drawKnight(u, time, G, Board, C)` | board sprite | feet at `cx, cy` | `Board.tileToScreen(px, py, z)`; respect `G.zoom`, `hop`, `squash`, `G.lift` |
| `drawBust(cx, feet, color, dark, scale)` | portrait medallion | `feet` = visual bottom of bust | `scale` defaults to `1`; select screen passes `~3.2` |
| `drawChip(cx, y, r, color, dark, alpha)` | turn-bar chip | center `cx, y` | `r` = 22–27 px; `alpha` for off-map ghosting |

**Never** change anchor semantics or add extra required params.

---

## 2. Palette Discipline

* **Local constants only** — no inline `{r,g,b}` in drawing code.
* 3–4 steel tones per unit: `DARK`, `MID`, `LIGHT`, optional `HI` (specular 1-pixel edge).
* One **team accent** = `u.color` (tabard stripe, crest, chip dot). Never recolor full armor.
* Shared neutrals: `INK` (visor/slots), `CHAIN` (mail), `LEATHER` (straps).
* Pull backdrop/UI colors from `G.C` (shadow, select, panel, etc.) — never hard-code.

```lua
local STEEL_D = {0.36,0.37,0.41}
local STEEL_M = {0.60,0.62,0.66}
local STEEL_L = {0.86,0.87,0.90}
local STEEL_HI= {0.95,0.96,1.00}
local INK     = {0.10,0.11,0.13}
```

---

## 3. Layer Order (draw back → front)

1. Ground shadow (ellipse, scales with hop/lift)
2. `push()` → translate/scale for squash → `translate(-cx,-cy)`
3. Base disc (team ring)
4. Legs/feet
5. Torso (cuirass → bevel → tabard stripe)
6. Arms (vambrace → gauntlet)
7. Pauldrons (2–3 tone lames)
8. Gorget/neck
9. Helm/head (visors, breaths, crest)
10. `pop()`
11. Active ring + nameplate (uses `C.select`, `G.fontSmall`)

---

## 4. Minimalist Shape Language

* **Flat geometric primitives only** — `rectangle`, `polygon`, `ellipse`, `circle`, `arc`, `line`.
* No curves beyond `ellipse`/`arc`. No images, no meshes, no shaders.
* Silhouette readable at 18 px chip: great-helm block, slab cuirass, stick limbs.
* Detail budget: **≤ 35 draw calls** per `drawKnight` (count with `love.graphics.getStats().drawcalls`).

---

## 5. Animation Hooks (read-only)

| Variable | Source | Use |
|---|---|---|
| `hop` | `math.sin(progress)*4` | vertical bob while moving |
| `sq` | `G.squash[id]` | horizontal stretch / vertical squash |
| `time` | arg | idle sway, crest bob, specular shimmer |
| `G.zoom` | camera | uniform scale for everything |

Do **not** create new timers or state.

---

## 6. Portrait & Chip Parity

* `drawBust` must be an **exact visual subset** of `drawKnight` — same helm, same pauldrons, same tabard stripe, same crest.
* `drawChip` = helm face only (steel disc + visor line + crest dot) at `r` radius.
* Select screen passes `scale ≈ 3.2`; medallion ring radius ≈ 85 × scale/2.4.

---

## 7. Adding a New Unit

1. Create `assets/units/<name>.lua` returning table with the three functions above.
2. Register in `units.lua` roster: `{ id="...", name="...", kind="<name>", color={...}, dark={...}, stats={...} }`.
3. `render.lua:331` `drawPawn` and `render.lua:705` `drawPortrait` already dispatch by `u.kind` — no edits needed.
4. Turn-bar `render.lua:1060` dispatches by `u.kind` — no edits needed.
5. Verify: `luajit -bl assets/units/<name>.lua` + headless `love .` 3 s probe screenshot.

---

## 8. Performance Checklist

* [ ] Zero allocations in draw functions (reuse tables or inline).
* [ ] No `math.random` — deterministic hash only.
* [ ] Draw calls ≤ 35 (board), ≤ 18 (bust), ≤ 6 (chip).
* [ ] Works at `G.zoom = 0.45 … 2.5` without clipping.

---

## 9. Review Checklist (before merge)

* [ ] Silhouette recognizable at chip size (22 px).
* [ ] Team color only on tabard/crest/dot — armor stays steel.
* [ ] Portrait matches board sprite 1:1 (helm, pauldrons, tabard).
* [ ] Active ring + nameplate unchanged.
* [ ] No hard-coded colors outside local palette + `G.C`.
* [ ] `luajit -bl` clean, headless run clean.
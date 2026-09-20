# Tasks 001 — Module split

- [x] T1 Constitution written (`.specify/memory/constitution.md`)
- [x] T2 Spec written (`spec.md`)
- [x] T3 Plan written (`plan.md`)
- [x] T4 Scout agents map line ranges + drafts (board / units / render / menu-camera-input)
- [ ] T5 Write `state.lua` + `board.lua`
- [ ] T6 Write `units.lua`
- [ ] T7 Write `render.lua`
- [ ] T8 Write `menu.lua` + `camera.lua` + `input.lua`
- [ ] T9 Rewrite `main.lua` as glue
- [ ] T10 `luajit -bl` on all files + fix errors
- [ ] T11 Headless run, empty error log
- [x] T12 Converge: all acceptance criteria met (8/8 syntax, headless
  8 s empty error log, menu screenshot verified, probe reverted).
  Notes: dropped dead `shade`/`aoFactor` helpers; `love.resize`
  delegates to `Camera.syncViewport` (equivalent); finish hook injected
  as `Units.updateGlide(dt, Menu.checkFinish)` to avoid a menu↔units
  require cycle.
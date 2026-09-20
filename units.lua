-- units.lua — roster, Dijkstra movement, orders, pawn glide.
-- Deps: state (G), board. No love.* calls.
-- The step-completion hook (finish check) is injected by the caller:
--   Units.updateGlide(dt, onStep) — main passes Menu.checkFinish.
local G = require("state")
local Board = require("board")
local M = {}

-- ---------- roster ----------
-- stats: vigor (maxHP = vigor*4), strength, dexterity, luck,
--   speed (tiles per move = range; turn order, fastest first),
--   charisma (maxMana = mana start = charisma*3).
-- Pawn colors are cosmetic; every pawn starts with the same stat block.
local PAWN_STATS = { vigor = 3, strength = 3, dexterity = 3, luck = 3,
                     speed = 3, charisma = 3 }

function M.defaultRoster()
    return {
        { id = "p1", name = "Alpha", gx = 3, gy = 3,
          color = {0.90, 0.34, 0.18}, dark = {0.62, 0.20, 0.10},
          kind = "knight", stats = PAWN_STATS },
        { id = "p2", name = "Bravo", gx = 8, gy = 8,
          color = {0.18, 0.53, 0.89}, dark = {0.10, 0.35, 0.64},
          kind = "knight", stats = PAWN_STATS },
        { id = "p3", name = "Charlie", gx = 3, gy = 8,
          color = {0.25, 0.72, 0.30}, dark = {0.14, 0.48, 0.18},
          kind = "knight", stats = PAWN_STATS },
        { id = "p4", name = "Delta", gx = 8, gy = 3,
          color = {0.78, 0.62, 0.18}, dark = {0.52, 0.40, 0.10},
          kind = "knight", stats = PAWN_STATS },
    }
end

-- ---------- upgrades (skeleton) ----------
-- Upgrade screen rows. Intentionally EMPTY — real upgrades to be specified
-- by you (no invented effects). Row shape when you spec them:
--   { id = "vig1", name = "VIGOR +1", desc = "+4 maxHP", cost = 10,
--     apply = function(hero) hero.stats.vigor = hero.stats.vigor + 1 end }
-- Screen + buy flow already wired; just fill this list.
function M.upgradeDefs() return {} end

function M.buyUpgrade(id)
    for _, def in ipairs(M.upgradeDefs()) do
        if def.id == id then
            if (G.coins or 0) < (def.cost or 0) then
                G.pushLog("not enough coins") return false
            end
            G.coins = G.coins - (def.cost or 0)
            if def.apply then def.apply(G.units[1]) end
            G.pushLog("bought " .. def.name)
            return true
        end
    end
    return false
end

function M.spawnUnit(def)
    local st = def.stats or { vigor = 2, strength = 2, dexterity = 2, luck = 2, speed = 3, charisma = 2 }
    local stats = { vigor = st.vigor, strength = st.strength, dexterity = st.dexterity,
                    luck = st.luck, speed = st.speed, charisma = st.charisma }
    local maxHP = def.maxHP or stats.vigor * 4
    local maxMana = stats.charisma * 3
    return { id = def.id, name = def.name, gx = def.gx, gy = def.gy,
        px = def.gx, py = def.gy, fx = def.gx, fy = def.gy, map = "over",
        color = def.color, dark = def.dark, range = def.move or stats.speed,
        team = def.team or "hero",
        kind = def.kind or (def.team == "enemy" and "slime" or "hero"),
        rangedDmg = def.rangedDmg, shotRange = def.shotRange,
        stats = stats, maxHP = maxHP, hp = maxHP,
        maxMana = maxMana, mana = maxMana,
        moved = false, attacked = false, acted = false,
        path = {}, t = 0 }
end

-- ---------- enemies ----------
-- Slime: chases adjacent, move 1 / dmg 1 / HP 4. Blob look (drawSlime).
-- Skeleton archer: keeps distance, move 4, ranged 5 dmg @ 3, HP 10.
-- Bone look + bow (drawSkeleton), arrows fly as projectiles (G.arrows).
local SLIME_STATS = { vigor = 1, strength = 1, dexterity = 1,
                      luck = 1, speed = 1, charisma = 1 }
local SLIME_COLOR = {0.35, 0.82, 0.35}
local SLIME_DARK = {0.20, 0.55, 0.22}
local ARCHER_STATS = { vigor = 3, strength = 1, dexterity = 2,
                       luck = 1, speed = 2, charisma = 1 }
local ARCHER_COLOR = {0.88, 0.86, 0.78}
local ARCHER_DARK = {0.45, 0.42, 0.34}
M.ARCHER_RANGE, M.ARCHER_DMG = 3, 5

function M.defaultEnemies()
    return {
        { id = "e1", name = "Slime A", team = "enemy", gx = 2, gy = 6,
          color = SLIME_COLOR, dark = SLIME_DARK, stats = SLIME_STATS },
        { id = "e2", name = "Slime B", team = "enemy", gx = 7, gy = 7,
          color = SLIME_COLOR, dark = SLIME_DARK, stats = SLIME_STATS },
    }
end

-- Flavor + threat readout for the hover intel panel (bio written once here).
function M.bioOf(u)
    if u.kind == "archer" then
        return { kind = "SKELETON ARCHER", style = "RANGED",
            threat = "BOW " .. (u.rangedDmg or M.ARCHER_DMG) .. "  ·  RNG " ..
                (u.shotRange or M.ARCHER_RANGE) .. "  ·  MOVE " .. (u.range or 4),
            bio = "A conscripted guardsman who never got to rest. Its bow arm still " ..
                "remembers every drill — and it hates sharing the meadow." }
    end
    return { kind = "SLIME", style = "MELEE",
        threat = "DMG " .. M.attackDamage(u) .. "  ·  MOVE " .. (u.range or 1),
        bio = "A leftover blob of the meadow's old magic. Boneless, brainless and " ..
            "endlessly hungry — it wobbles toward anything warm." }
end

function M.spawnAll()
    G.units = {}
    for _, def in ipairs(G.roster) do G.units[#G.units + 1] = M.spawnUnit(def) end
    for _, def in ipairs(M.defaultEnemies()) do G.units[#G.units + 1] = M.spawnUnit(def) end
    G.activeIdx = 1
    G.round, G.wiped = 1, false
    M.buildTurnOrder()
    -- initiative can open on an enemy: let it act immediately.
    local a = M.active()
    if a and a.team == "enemy" then M.enemyTurn(a) end
end

-- Run maps: guards scale with level — count 2 + level/2 (max 4),
-- +1 vigor/strength per 2 levels. Archers join from level 2
-- (1, then 2 from level 4): HP 10 + 2/level-step, fixed 5 ranged dmg.
function M.spawnRunEnemies()
    local lvl = G.runLevel or 1
    local n = math.min(2 + math.floor(lvl / 2), 4)
    local bonus = math.floor(lvl / 2)
    local sx, sy = G.spawnTile[1], G.spawnTile[2]
    -- scatter away from the player start (no finish-tile dependency).
    local spots = {}
    for y = 1, G.GRID do for x = 1, G.GRID do
        if Board.inBounds(x, y) and not Board.isBlocked(x, y)
            and not M.unitAt(x, y)
            and not (x == sx and y == sy)
            and (math.abs(x - sx) + math.abs(y - sy)) >= 4 then
            local t = G.terrain[y] and G.terrain[y][x]
            if t ~= "shopdoor" and t ~= "shopwall" then
                spots[#spots + 1] = { x, y }
            end
        end
    end end
    -- shuffle so picks vary across levels
    for i = #spots, 2, -1 do
        local j = math.random(i)
        spots[i], spots[j] = spots[j], spots[i]
    end
    local base = M.defaultEnemies()[1]
    local nArchers = math.min(math.floor(lvl / 2), 2, n)
    local defs = {}
    for i = 1, nArchers do
        defs[#defs + 1] = { id = "a" .. i, name = "Skeleton " .. string.char(64 + i),
            team = "enemy", kind = "archer", color = ARCHER_COLOR, dark = ARCHER_DARK,
            maxHP = 10 + bonus * 2, move = 4,
            rangedDmg = M.ARCHER_DMG, shotRange = M.ARCHER_RANGE,
            stats = ARCHER_STATS }
    end
    for i = 1, n - nArchers do
        defs[#defs + 1] = { id = "e" .. i, name = "Slime " .. string.char(64 + i),
            team = "enemy", kind = "slime", color = SLIME_COLOR, dark = SLIME_DARK,
            stats = { vigor = base.stats.vigor + bonus, strength = base.stats.strength + bonus,
                      dexterity = base.stats.dexterity, luck = base.stats.luck,
                      speed = base.stats.speed, charisma = base.stats.charisma } }
    end
    for i = 1, math.min(n, #spots) do
        local u = M.spawnUnit(defs[i])
        u.gx, u.gy = spots[i][1], spots[i][2]
        u.px, u.py = u.gx, u.gy
        u.fx, u.fy = u.gx, u.gy
        u.map = "over"
        G.units[#G.units + 1] = u
    end
end

function M.clearEnemies()
    for i = #G.units, 1, -1 do
        if G.units[i].team == "enemy" then table.remove(G.units, i) end
    end
    if G.activeIdx > #G.units then G.activeIdx = #G.units end
end

function M.active() return G.units[G.activeIdx] end

-- ---------- turn order (initiative, fastest first) ----------
function M.indexOfId(id)
    for i, u in ipairs(G.units) do if u.id == id then return i end end
    return nil
end

local function speedOf(u) return (u.stats and u.stats.speed) or 0 end

-- Rebuild G.turnOrder (all units, speed desc, roster order breaks ties)
-- and select the fastest unit on the visible map. Drops any queued AI beat.
function M.buildTurnOrder()
    G.ai = nil
    local pos = {}
    for i, u in ipairs(G.units) do pos[u.id] = i end
    local sorted = {}
    for _, u in ipairs(G.units) do sorted[#sorted + 1] = u end
    table.sort(sorted, function(a, b)
        local sa, sb = speedOf(a), speedOf(b)
        if sa ~= sb then return sa > sb end
        return (pos[a.id] or 0) < (pos[b.id] or 0)
    end)
    G.turnOrder = {}
    for _, u in ipairs(sorted) do G.turnOrder[#G.turnOrder + 1] = u.id end
    G.turnPos = 1
    for i, id in ipairs(G.turnOrder) do
        local idx = M.indexOfId(id)
        if idx and G.units[idx].map == G.map then
            G.activeIdx, G.turnPos = idx, i
            break
        end
    end
    G.selAnim = 0
end

-- Point the queue at the manually selected unit (click-select).
function M.syncTurnPos()
    local a = G.units[G.activeIdx]
    if not a then return end
    for i, id in ipairs(G.turnOrder) do
        if id == a.id then G.turnPos = i return end
    end
end

-- After a unit consumes its turn, pass selection to the next unended
-- unit in initiative order on the visible map. When everyone has ended,
-- a new round starts. Selecting an enemy runs its AI immediately.
function M.advanceTurn(finished)
    G.castMode = false
    if #G.turnOrder == 0 then return end
    if finished and G.units[G.activeIdx] ~= finished then return end
    local n = #G.turnOrder
    for _ = 1, n do
        G.turnPos = G.turnPos % n + 1
        local idx = M.indexOfId(G.turnOrder[G.turnPos])
        local u = idx and G.units[idx]
        if u and u.map == G.map and not u.acted then
            G.activeIdx = idx
            G.selAnim = 0
            G.pushLog(u.name .. "'s turn")
            if u.team == "enemy" then M.enemyTurn(u) end
            return
        end
    end
    M.newRound()
end

function M.newRound()
    G.round = (G.round or 1) + 1
    G.castMode = false
    G.ai = nil
    for _, u in ipairs(G.units) do u.moved, u.attacked, u.acted = false, false, false end
    G.pushLog("— ROUND " .. G.round .. " —")
    for i, id in ipairs(G.turnOrder) do
        local idx = M.indexOfId(id)
        if idx and G.units[idx].map == G.map then
            G.activeIdx, G.turnPos = idx, i
            G.selAnim = 0
            local u = G.units[idx]
            if u.team == "enemy" then M.enemyTurn(u) end
            return
        end
    end
end

-- Voluntarily end the active unit's turn (NEXT button / Space).
function M.endTurn()
    local a = M.active()
    if not a or #a.path > 0 then return end
    if a.team == "enemy" then a.acted = true M.advanceTurn(a) return end
    a.acted = true
    G.pushLog(a.name .. " ends turn")
    M.advanceTurn(a)
end

function M.heroesAlive()
    for _, u in ipairs(G.units) do
        if u.team ~= "enemy" and u.hp > 0 and u.map == G.map then return true end
    end
    return false
end

function M.nearestHero(e)
    local best, bestD = nil, math.huge
    for _, u in ipairs(G.units) do
        if u.team ~= "enemy" and u.hp > 0 and u.map == e.map then
            local d = math.abs(e.gx - u.gx) + math.abs(e.gy - u.gy)
            if d < bestD then best, bestD = u, d end
        end
    end
    return best, bestD
end

-- Enemy AI driver. Turns are queued ({id, phase, t}) and paced by
-- updateAI so each beat reads: think pause -> glide -> strike pause.
-- Selection + log happen up front (in advanceTurn), the hit lands later.
function M.enemyTurn(e)
    if e.acted or e.attacked or #e.path > 0 then return end
    if not M.heroesAlive() then
        if not G.wiped then
            G.wiped = true
            G.pushLog("— PARTY WIPED —")
            G.state = "over"
        end
        e.acted = true
        return
    end
    local target = M.nearestHero(e)
    if not target then e.acted = true M.advanceTurn(e) return end
    if G.ai then return end -- already directing (safety)
    G.ai = { id = e.id, phase = "think", t = 0 }
end

-- Per-frame AI tick (called from love.update). Resolves the queued
-- enemy turn one beat at a time; input is gated while G.ai is set.
function M.updateAI(dt)
    if G.state ~= "game" then return end
    local ai = G.ai
    if not ai then return end
    local idx = M.indexOfId(ai.id)
    local u = idx and G.units[idx]
    if not u or u.hp <= 0 or u.acted or u.attacked or u.map ~= G.map or u.team ~= "enemy" then
        G.ai = nil
        M.advanceTurn() -- queued unit gone: carry on without skipping anyone
        return
    end
    ai.t = ai.t + dt
    if ai.phase == "think" then
        if ai.t >= G.AI_THINK then
            local target, dist = M.nearestHero(u)
            if not target then
                u.acted = true G.ai = nil M.advanceTurn(u) return
            end
            -- archers hold at bow range; melee must close to adjacent.
            local shotRng = (u.kind == "archer") and (u.shotRange or M.ARCHER_RANGE) or 1
            if dist >= 1 and dist <= shotRng then
                ai.phase, ai.t = "strike", 0
            else
                local bx, by = M.approachTile(u, target)
                if bx then M.orderMove(u, bx, by) end
                if #u.path == 0 then
                    u.acted = true G.ai = nil M.advanceTurn(u)
                else
                    ai.phase, ai.t = "move", 0
                end
            end
        end
    elseif ai.phase == "move" then
        if #u.path == 0 or ai.t > 3 then -- arrived (or watchdog): wind up
            u.moved = true
            ai.phase, ai.t = "strike", 0
        end
    elseif ai.phase == "strike" then
        if #u.path > 0 then return end -- glide still finishing; hold the beat
        if ai.t >= G.AI_STRIKE then
            G.ai = nil
            local target, dist = M.nearestHero(u)
            if u.kind == "archer" then
                local rng = u.shotRange or M.ARCHER_RANGE
                if target and dist >= 1 and dist <= rng then M.orderRanged(u, target)
                else u.acted = true M.advanceTurn(u) end
            elseif target and dist == 1 then M.orderAttack(u, target)
            else u.acted = true M.advanceTurn(u) end
        end
    end
end

-- Closest reachable tile to the target by Manhattan distance.
function M.approachTile(e, target)
    local reach = M.reachable(e)
    local bx, by, bd = nil, nil, math.huge
    for k in pairs(reach) do
        local x, y = k % 100, math.floor(k / 100)
        local d = math.abs(x - target.gx) + math.abs(y - target.gy)
        if d < bd then bx, by, bd = x, y, d end
    end
    return bx, by
end

-- Enemy post-move (glide completion): hand off to the strike beat.
-- Falls back to an instant pass if the queue was lost.
function M.enemyAfterMove(e)
    e.moved = true
    if G.ai and G.ai.id == e.id then
        G.ai.phase, G.ai.t = "strike", 0
    else
        e.acted = true
        M.advanceTurn(e)
    end
end

function M.unitAt(x, y, ignore)
    -- only units on the visible map collide/select.
    for _, u in ipairs(G.units) do
        if u ~= ignore and u.map == G.map and u.gx == x and u.gy == y then return u end
    end
    return nil
end

-- ---------- queries (Dijkstra; water costs 2, key: y * 100 + x) ----------
function M.findPath(unit, tx, ty)
    if not Board.inBounds(tx, ty) or Board.isBlocked(tx, ty) then return nil end
    if M.unitAt(tx, ty, unit) then return nil end
    local startK = unit.gy * 100 + unit.gx
    local best = { [startK] = 0 }
    local prev = { [startK] = false }
    local queue = { {unit.gx, unit.gy, 0} }
    local head = 1
    while head <= #queue do
        local cx, cy, c = queue[head][1], queue[head][2], queue[head][3]
        head = head + 1
        if c > (best[cy * 100 + cx] or math.huge) then goto next end
        if cx == tx and cy == ty then
            local path = {}
            local k = ty * 100 + tx
            while k do
                table.insert(path, 1, { k % 100, math.floor(k / 100) })
                k = prev[k]
            end
            return path
        end
        for _, d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
            local nx, ny = cx + d[1], cy + d[2]
            local k = ny * 100 + nx
            if Board.inBounds(nx, ny) and not Board.isBlocked(nx, ny) and not M.unitAt(nx, ny, unit) then
                local nc = c + Board.tileCost(nx, ny)
                if best[k] == nil or nc < best[k] then
                    best[k] = nc
                    prev[k] = cy * 100 + cx
                    queue[#queue + 1] = {nx, ny, nc}
                end
            end
        end
        ::next::
    end
    return nil
end

function M.pathCost(path)
    local cost = 0
    for i = 2, #path do cost = cost + Board.tileCost(path[i][1], path[i][2]) end
    return cost
end

function M.reachable(unit)
    -- cost-limited Dijkstra: water eats 2 range per tile
    local seen = { [unit.gy * 100 + unit.gx] = 0 }
    local queue = { {unit.gx, unit.gy, 0} }
    local head = 1
    while head <= #queue do
        local cx, cy, dist = queue[head][1], queue[head][2], queue[head][3]
        head = head + 1
        if dist > (seen[cy * 100 + cx] or math.huge) then goto cont end
        for _, d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
            local nx, ny = cx + d[1], cy + d[2]
            local k = ny * 100 + nx
            if Board.inBounds(nx, ny) and not Board.isBlocked(nx, ny) and not M.unitAt(nx, ny, unit) then
                local nd = dist + Board.tileCost(nx, ny)
                if nd <= unit.range and (seen[k] == nil or nd < seen[k]) then
                    seen[k] = nd
                    queue[#queue + 1] = {nx, ny, nd}
                end
            end
        end
        ::cont::
    end
    seen[unit.gy * 100 + unit.gx] = nil
    return seen
end

-- ---------- orders ----------
function M.orderMove(unit, tx, ty)
    if #unit.path > 0 then G.pushLog(unit.name .. ": still moving...") return end
    if unit.acted then G.pushLog(unit.name .. ": turn ended — start a new round") return end
    if unit.moved then G.pushLog(unit.name .. ": already moved — attack or end turn") return end
    local path = M.findPath(unit, tx, ty)
    if not path then G.pushLog(unit.name .. ": no path to " .. tx .. "," .. ty) return end
    local cost = M.pathCost(path)
    if cost > unit.range then
        G.pushLog(unit.name .. ": too far (" .. cost .. " > " .. unit.range .. ")")
        return
    end
    table.remove(path, 1) -- drop start tile
    unit.path = path
    unit.t = 0
    unit.fx, unit.fy = unit.gx, unit.gy
end

function M.stepMove(unit, dx, dy)
    if #unit.path > 0 then return end
    if unit.acted then G.pushLog(unit.name .. ": already acted — end turn") return end
    if unit.moved then G.pushLog(unit.name .. ": already moved — attack or end turn") return end
    local nx, ny = unit.gx + dx, unit.gy + dy
    if not Board.inBounds(nx, ny) or Board.isBlocked(nx, ny) or M.unitAt(nx, ny, unit) then return end
    unit.path = { {nx, ny} }
    unit.t = 0
    unit.fx, unit.fy = unit.gx, unit.gy
end

-- ---------- actions ----------
-- Default attack: melee, orthogonal adjacency only.
-- Damage = attacker's Strength (min 1). Uses the attack action;
-- movement remains available until END TURN.
-- Tall grass + DEX feed dodge; LUCK feeds crits (x1.5).
local BOLT_COST, BOLT_RANGE = 3, 3
M.BOLT_COST, M.BOLT_RANGE = BOLT_COST, BOLT_RANGE

function M.attackDamage(att)
    return math.max(1, (att.stats and att.stats.strength) or 1)
end

function M.addFloat(gx, gy, txt, col, big)
    G.floats[#G.floats + 1] = { gx = gx, gy = gy, txt = txt, col = col,
                                big = big or false, t = 0, life = 1.1 }
end

-- Crit: luck x 3% chance for x1.5 damage (rounded). Returns dmg, crit?
function M.critRoll(u, dmg)
    local luck = (u.stats and u.stats.luck) or 0
    if math.random() < luck * 0.03 then return math.floor(dmg * 1.5 + 0.5), true end
    return dmg, false
end

-- Dodge: tall-grass cover + 2% per DEX, capped at 75%.
function M.tryDodge(tgt)
    local base = Board.dodgeChanceAt(tgt.gx, tgt.gy)
    local dex = (tgt.stats and tgt.stats.dexterity) or 0
    return math.random() < math.min(0.75, base + dex * 0.02)
end

function M.removeUnit(id)
    local cur = G.units[G.activeIdx]
    local curId = cur and cur.id
    for i, u in ipairs(G.units) do
        if u.id == id then table.remove(G.units, i) break end
    end
    G.squash[id] = nil
    if G.activeIdx > #G.units then G.activeIdx = #G.units end
    M.buildTurnOrder()
    if curId then
        for i, u in ipairs(G.units) do
            if u.id == curId then G.activeIdx = i break end
        end
        M.syncTurnPos()
    end
end

-- Heroes keep selection after acting so the player ends the turn with
-- END TURN / Space; enemies auto-pass to keep their beat moving.
local function afterAction(att)
    if att.team == "enemy" then
        att.acted = true
        M.advanceTurn(att)
    else
        G.pushLog(att.name .. ": press END TURN")
    end
end

function M.orderAttack(att, target)
    if not att then return end
    if #att.path > 0 then G.pushLog(att.name .. ": still moving...") return end
    if att.acted then G.pushLog(att.name .. ": already acted") return end
    if att.attacked then G.pushLog(att.name .. ": already attacked — 1 attack per turn") return end
    if not target or target.hp <= 0 or target.map ~= att.map then return end
    if target.team == att.team then G.pushLog(att.name .. ": allies only, pick an enemy") return end
    local dist = math.abs(att.gx - target.gx) + math.abs(att.gy - target.gy)
    if dist ~= 1 then G.pushLog(att.name .. ": too far — step adjacent") return end
    local dmg, crit = M.critRoll(att, M.attackDamage(att))
    att.attacked = true
    if M.tryDodge(target) then
        M.addFloat(target.gx, target.gy, "DODGED", G.C.floatDodge)
        G.pushLog(att.name .. " swings at " .. target.name .. " — dodged!")
        afterAction(att)
        return
    end
    target.hp = math.max(0, target.hp - dmg)
    G.squash[target.id] = 1
    M.addFloat(target.gx, target.gy, "-" .. dmg .. (crit and "!" or ""),
        crit and G.C.floatCrit or G.C.floatDmg, crit)
    if target.hp <= 0 then
        G.pushLog(att.name .. " hits " .. target.name .. " for " .. dmg .. " — slain!")
        M.rewardKill(att)
        M.removeUnit(target.id)
    else
        G.pushLog(att.name .. " hits " .. target.name .. " for " .. dmg ..
            " (" .. target.hp .. "/" .. target.maxHP .. ")")
    end
    afterAction(att)
end

-- Kill reward: +1 maxHP, heal 2, plus a coin bounty (5 + level).
-- Per-level counters feed the win-transition reward card.
function M.rewardKill(killer)
    killer.maxHP = killer.maxHP + 1
    killer.hp = math.min(killer.maxHP, killer.hp + 2)
    local bounty = 5 + (G.runLevel or 1)
    G.coins = (G.coins or 0) + bounty
    G.levelKills = (G.levelKills or 0) + 1
    G.levelCoins = (G.levelCoins or 0) + bounty
    G.levelHp = (G.levelHp or 0) + 1
    M.addFloat(killer.gx, killer.gy, "+2", G.C.floatHeal)
    M.addFloat(killer.gx, killer.gy - 0.5, "+" .. bounty .. "c", G.C.coin)
    G.pushLog(killer.name .. " grows tougher (+1 maxHP, +2 HP, +" .. bounty .. "c)")
end

-- Firebolt: ranged spell, CHA-based, costs mana. Uses the attack action;
-- movement remains available until END TURN.
function M.orderCast(att, target)
    if not att or att.team ~= "hero" then return end
    if #att.path > 0 then G.pushLog(att.name .. ": still moving...") return end
    if att.acted then G.pushLog(att.name .. ": already acted") return end
    if not target or target.hp <= 0 or target.map ~= att.map then return end
    if target.team == att.team then G.pushLog(att.name .. ": allies only, pick an enemy") return end
    if (att.mana or 0) < BOLT_COST then G.pushLog(att.name .. ": not enough mana") return end
    local dist = math.abs(att.gx - target.gx) + math.abs(att.gy - target.gy)
    if dist > BOLT_RANGE then G.pushLog(att.name .. ": bolt range is " .. BOLT_RANGE) return end
    att.mana = att.mana - BOLT_COST
    G.castMode = false
    M.addFloat(att.gx, att.gy, "-" .. BOLT_COST .. " mana", G.C.floatMana)
    local dmg, crit = M.critRoll(att, 2 + ((att.stats and att.stats.charisma) or 0))
    -- abilities are free: do not consume the 1/turn basic attack
    if M.tryDodge(target) then
        M.addFloat(target.gx, target.gy, "DODGED", G.C.floatDodge)
        G.pushLog(att.name .. "'s bolt misses " .. target.name .. "!")
        afterAction(att)
        return
    end
    target.hp = math.max(0, target.hp - dmg)
    G.squash[target.id] = 1
    M.addFloat(target.gx, target.gy, "-" .. dmg .. (crit and "!" or ""),
        crit and G.C.floatCrit or G.C.floatDmg, crit)
    if target.hp <= 0 then
        G.pushLog(att.name .. " bolts " .. target.name .. " for " .. dmg .. " — slain!")
        M.rewardKill(att)
        M.removeUnit(target.id)
    else
        G.pushLog(att.name .. " bolts " .. target.name .. " for " .. dmg ..
            " (" .. target.hp .. "/" .. target.maxHP .. ")")
    end
    afterAction(att)
end

-- Skeleton archer shot: ranged damage with a flying arrow projectile.
-- Damage lands on fire (numbers stay in sync); the arrow in G.arrows
-- is purely visual and tracks the camera per frame.
function M.orderRanged(att, target)
    if not att then return end
    if #att.path > 0 then G.pushLog(att.name .. ": still moving...") return end
    if att.acted then G.pushLog(att.name .. ": already acted") return end
    if not target or target.hp <= 0 or target.map ~= att.map then return end
    if target.team == att.team then G.pushLog(att.name .. ": allies only, pick an enemy") return end
    local rng = att.shotRange or M.ARCHER_RANGE
    local dist = math.abs(att.gx - target.gx) + math.abs(att.gy - target.gy)
    if dist < 1 or dist > rng then G.pushLog(att.name .. ": no shot (" .. dist .. " > " .. rng .. ")") return end
    local dmg, crit = M.critRoll(att, att.rangedDmg or M.ARCHER_DMG)
    att.attacked = true
    G.arrows[#G.arrows + 1] = { fx = att.px or att.gx, fy = att.py or att.gy,
        tx = target.px or target.gx, ty = target.py or target.gy, t = 0, dur = 0.28 }
    if M.tryDodge(target) then
        M.addFloat(target.gx, target.gy, "DODGED", G.C.floatDodge)
        G.pushLog(att.name .. " looses at " .. target.name .. " — dodged!")
        afterAction(att)
        return
    end
    target.hp = math.max(0, target.hp - dmg)
    G.squash[target.id] = 1
    M.addFloat(target.gx, target.gy, "-" .. dmg .. (crit and "!" or ""),
        crit and G.C.floatCrit or G.C.floatDmg, crit)
    if target.hp <= 0 then
        G.pushLog(att.name .. " shoots " .. target.name .. " for " .. dmg .. " — slain!")
        M.rewardKill(att)
        M.removeUnit(target.id)
    else
        G.pushLog(att.name .. " shoots " .. target.name .. " for " .. dmg ..
            " (" .. target.hp .. "/" .. target.maxHP .. ")")
    end
    afterAction(att)
end

-- per-frame reach cache + hover path preview (drives range wash + dots)
function M.updateQueries()
    local actU = M.active()
    if actU and actU.map == G.map and not actU.moved and not actU.acted and #actU.path == 0 then
        G.cachedReach = M.reachable(actU)
    else
        G.cachedReach = {}
    end
    G.hoverPath = {}
    if G.hover and actU and actU.map == G.map and not actU.moved and not actU.acted
        and #actU.path == 0 and G.cachedReach[G.hover[2]*100+G.hover[1]] then
        local p = M.findPath(actU, G.hover[1], G.hover[2])
        if p then for i = 2, #p do G.hoverPath[#G.hoverPath+1] = p[i] end end
    end
end

-- pawn glide: fixed-time segments with smoothstep easing.
-- u.fx/fy = segment start tile, u.t counts 0 -> STEP_TIME, px/py derived.
function M.updateGlide(dt, onStep)
    -- snapshot: kills inside onStep/AI mutate G.units mid-loop.
    local snap = {}
    for _, u in ipairs(G.units) do snap[#snap + 1] = u end
    for _, u in ipairs(snap) do
        -- units on the other map are frozen until viewed again.
        if u.map ~= G.map then goto frozen end
        if #u.path > 0 then
            u.t = u.t + dt
            local step = u.path[1]
            local k = math.min(1, u.t / G.STEP_TIME)
            local e = k * k * (3 - 2 * k) -- smoothstep: ease in-out
            u.px = u.fx + (step[1] - u.fx) * e
            u.py = u.fy + (step[2] - u.fy) * e
            if k >= 1 then
                u.gx, u.gy = step[1], step[2]
                u.fx, u.fy = step[1], step[2]
                table.remove(u.path, 1)
                u.t = 0
                G.squash[u.id] = 1
                local pcx, pcy = Board.tileToScreen(u.gx, u.gy, 0)
                G.puffs[#G.puffs+1] = { x = pcx, y = pcy, r = 4, a = 0.5 }
                if G.playStep then -- footstep SFX for the landed tile
                    G.playStep(u, G.terrain[u.gy] and G.terrain[u.gy][u.gx])
                end
                if G.playStep then -- footstep SFX for the landed tile
                    G.playStep(u, G.terrain[u.gy] and G.terrain[u.gy][u.gx])
                end
                if #u.path == 0 then G.pushLog(u.name .. " -> " .. u.gx .. "," .. u.gy) end
                if onStep then onStep(u) end
                if #u.path == 0 then
                    -- move spent: heroes hold selection (may still attack),
                    -- enemies strike-or-pass via AI.
                    if u.team == "enemy" then M.enemyAfterMove(u)
                    else u.moved = true end
                end
            end
        else
            u.px, u.py = u.gx, u.gy
            u.fx, u.fy = u.gx, u.gy
        end
        ::frozen::
    end
end

return M

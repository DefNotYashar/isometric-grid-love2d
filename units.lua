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
local PAWN_STATS = { vigor = 4, strength = 3, dexterity = 3, luck = 3,
                     speed = 3, charisma = 3 }
M.PAWN_STATS = PAWN_STATS

-- Assassin: fragile speedster. Long reach dagger (melee 2), thrown blades
-- (range 4, Strength damage, no mana), elite dodge + crit stats.
local ASSASSIN_STATS = { vigor = 2, strength = 3, dexterity = 5, luck = 4,
                         speed = 4, charisma = 1 }
M.ASSASSIN_STATS = ASSASSIN_STATS

-- Tank: the immovable object. Huge HP, slow, smashes harder than its
-- Strength (melee 1), and Taunts nearby enemies into attacking it.
local TANK_STATS = { vigor = 6, strength = 4, dexterity = 1, luck = 1,
                     speed = 2, charisma = 1 }
M.TANK_STATS = TANK_STATS

-- ---------- abilities: 1 innate passive + 6 draftable per class ----------
-- drafted = { [id] = count } on each hero (run-scoped, stacks, no cap).
-- mods keys: dmg, dodgePct, move, roundHeal, killHeal, maxMana, maxHP,
--   throwDmg (unused: sharper covers both), tauntRadius, thorns,
--   firstBlock, executeDmg, refundMoveOnKill, meleePoison, backstabMult.
M.ABILITIES = {
knight = {
    { id = "bulwark", name = "Bulwark", desc = "PASSIVE: first hit each round -2", icon = "shield", passive = true, mods = { firstBlock = 2 } },
    { id = "edge", name = "Sharpened Edge", desc = "+1 sword damage", icon = "sword", mods = { dmg = 1 } },
    { id = "boots", name = "Marching Boots", desc = "+1 move", icon = "boot", mods = { move = 1 } },
    { id = "wind", name = "Second Wind", desc = "heal 2 each round start", icon = "wind", mods = { roundHeal = 2 } },
    { id = "riposte", name = "Riposte", desc = "melee attackers take 1", icon = "fist", mods = { thorns = 1 } },
    { id = "medic", name = "Battlefield Medic", desc = "kill-heal +2", icon = "cross", mods = { killHeal = 2 } },
    { id = "well", name = "Mana Well", desc = "+3 max mana", icon = "crystal", mods = { maxMana = 3 } },
},
assassin = {
    { id = "backstab", name = "Backstab", desc = "PASSIVE: +50% vs targets next to another unit", icon = "dagger", passive = true, mods = { backstabMult = 0.5 } },
    { id = "sharp", name = "Sharper Daggers", desc = "+1 dagger/blade damage", icon = "dagger", mods = { dmg = 1 } },
    { id = "fleet", name = "Fleetfoot", desc = "+1 move", icon = "wing", mods = { move = 1 } },
    { id = "vanish", name = "Vanish", desc = "+8% dodge", icon = "mask", mods = { dodgePct = 0.08 } },
    { id = "execute", name = "Execute", desc = "+2 damage vs targets under half HP", icon = "skull", mods = { executeDmg = 2 } },
    { id = "adrenaline", name = "Adrenaline", desc = "kills refund your move", icon = "bolt", mods = { refundMoveOnKill = 1 } },
    { id = "venom", name = "Poisoned Blades", desc = "dagger hits poison 2", icon = "vial", mods = { meleePoison = 2 } },
},
tank = {
    { id = "mountain", name = "Mountain", desc = "PASSIVE: +8 max HP, attackers take 1", icon = "hex", passive = true, mods = { maxHP = 8, thorns = 1 } },
    { id = "heavy", name = "Heavy Hands", desc = "+1 smash damage", icon = "fist", mods = { dmg = 1 } },
    { id = "march", name = "War March", desc = "+1 move", icon = "boot", mods = { move = 1 } },
    { id = "loud", name = "Loudmouth", desc = "taunt radius +1", icon = "mouth", mods = { tauntRadius = 1 } },
    { id = "wind", name = "Second Wind", desc = "heal 2 each round start", icon = "wind", mods = { roundHeal = 2 } },
    { id = "medic", name = "Battlefield Medic", desc = "kill-heal +2", icon = "cross", mods = { killHeal = 2 } },
    { id = "stone", name = "Stoneskin", desc = "-1 damage from all hits", icon = "shield", mods = { stoneskin = 1 } },
},
}

-- passive id per hero kind (seeded into drafted at spawn for heroes)
M.PASSIVE_OF = { knight = "bulwark", assassin = "backstab", tank = "mountain" }

function M.abilityDef(kind, id)
    for _, a in ipairs(M.ABILITIES[kind] or {}) do
        if a.id == id then return a end
    end
    return nil
end

-- summed numeric bonuses from passive + drafted abilities
function M.abMods(u)
    local out = {}
    if not u or not u.drafted then return out end
    local defs = M.ABILITIES[u.kind] or {}
    for id, count in pairs(u.drafted) do
        if count > 0 then
            for _, a in ipairs(defs) do
                if a.id == id and a.mods then
                    for k, v in pairs(a.mods) do
                        out[k] = (out[k] or 0) + v * count
                    end
                    break
                end
            end
        end
    end
    return out
end

-- effective move range incl. boots-type bonuses
function M.moveRange(u)
    local m = M.abMods(u)
    return (u.range or 0) + (m.move or 0)
end

-- apply a drafted ability: bump counts, grow maxHP/mana, top up a little
function M.draftAbility(u, id)
    local a = M.abilityDef(u.kind, id)
    if not a then return false end
    u.drafted = u.drafted or {}
    u.drafted[id] = (u.drafted[id] or 0) + 1
    local m = M.abMods(u)
    local st = u.stats or {}
    u.maxHP = (st.vigor or 2) * 4 + (m.maxHP or 0)
    u.maxMana = (st.charisma or 0) * 3 + (m.maxMana or 0)
    u.hp = math.min(u.maxHP, u.hp + 2)
    u.mana = math.min(u.maxMana, u.mana + 1)
    return true
end

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
        { id = "p5", name = "Shade", gx = 5, gy = 5,
          color = {0.45, 0.30, 0.75}, dark = {0.28, 0.19, 0.47},
          kind = "assassin", stats = ASSASSIN_STATS,
          meleeRange = 2, throwRange = 4 },
        { id = "p6", name = "Bastion", gx = 5, gy = 6,
          color = {0.75, 0.55, 0.20}, dark = {0.47, 0.34, 0.12},
          kind = "tank", stats = TANK_STATS },
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
    local st = def.stats or {}
    local stats = { vigor = st.vigor or 2, strength = st.strength or 2, dexterity = st.dexterity or 2,
                    luck = st.luck or 1, speed = st.speed or 2, charisma = st.charisma or 0 }
    -- heroes seed their innate passive (run-scoped drafted table)
    local kind = def.kind or (def.team == "enemy" and "slime" or "hero")
    local drafted = nil
    if def.team ~= "enemy" and M.PASSIVE_OF[kind] then
        drafted = { [M.PASSIVE_OF[kind]] = 1 }
    end
    local tmpMods = {}
    if drafted then
        for _, a in ipairs(M.ABILITIES[kind] or {}) do
            if drafted[a.id] and a.mods then
                for k, v in pairs(a.mods) do tmpMods[k] = (tmpMods[k] or 0) + v end
            end
        end
    end
    local maxHP = def.maxHP or (stats.vigor * 4 + (tmpMods.maxHP or 0))
    local isEnemy = def.team == "enemy"
    local maxMana = isEnemy and 0 or (st.charisma and st.charisma * 3 or 0) + (tmpMods.maxMana or 0)
    return { id = def.id, name = def.name, gx = def.gx, gy = def.gy,
        px = def.gx, py = def.gy, fx = def.gx, fy = def.gy, map = "over",
        color = def.color, dark = def.dark, range = def.move or stats.speed,
        meleeRange = def.meleeRange or 1, throwRange = def.throwRange,
        sigil = def.sigil or "cross",
        team = def.team or "hero",
        kind = kind,
        rangedDmg = def.rangedDmg, shotRange = def.shotRange,
        stats = stats, maxHP = maxHP, hp = maxHP,
        maxMana = maxMana, mana = maxMana,
        moved = false, attacked = false, acted = false,
        path = {}, t = 0,
        poison = 0,
        isSmall = def.isSmall or false,
        isBig = def.isBig or false,
        eliteTier = def.eliteTier or 0,
        abilities = def.abilities or {},
        drafted = drafted,
        firstBlockUsed = false,
    }
end

-- ---------- enemy stats (no luck, no charisma, no mana) ----------
-- Slime: dmg 2, move 2, HP 4. Poison on hit (1 dmg × 3 turns).
-- On death → 2 small slimes (dmg 1, move 1, HP 1) that seek to merge.
-- Skeleton: dmg 3, range 3, HP 5, move 2.
-- Elite: 20–30% chance, tiered stat boosts, empty abilities field.

local SLIME_STATS = { vigor = 1, strength = 1, dexterity = 1, speed = 2 }
local SLIME_COLOR = {0.35, 0.82, 0.35}
local SLIME_DARK = {0.20, 0.55, 0.22}
local SLIME_SMALL_COLOR = {0.55, 0.95, 0.55}
local SLIME_SMALL_DARK = {0.35, 0.70, 0.35}

local ARCHER_STATS = { vigor = 2, strength = 1, dexterity = 2, speed = 2 }
local ARCHER_COLOR = {0.88, 0.86, 0.78}
local ARCHER_DARK = {0.45, 0.42, 0.34}
M.ARCHER_RANGE, M.ARCHER_DMG = 3, 2

function M.defaultEnemies()
    return {
        { id = "e1", name = "Slime A", team = "enemy", gx = 2, gy = 6,
          color = SLIME_COLOR, dark = SLIME_DARK, stats = SLIME_STATS },
        { id = "e2", name = "Slime B", team = "enemy", gx = 7, gy = 7,
          color = SLIME_COLOR, dark = SLIME_DARK, stats = SLIME_STATS },
    }
end

-- Elite tier stat bonuses per enemy type
local SLIME_ELITE_TIERS = {
    [1] = { hp = 2 },           -- I: +2 HP (6 total)
    [2] = { hp = 1, str = 1 },  -- II: +1 HP +3 STR (5 HP, 5 dmg)
    [3] = { hp = 3, str = 1, spd = 1 }, -- III: +3 HP +1 STR +1 SPD (7 HP, 3 dmg, 3 move)
}
local ARCHER_ELITE_TIERS = {
    [1] = { hp = 3 },           -- I: +3 HP (8 total)
    [2] = { hp = 5, str = 1 },  -- II: +5 HP +2 STR (10 HP, 5 dmg)
    [3] = { hp = 2, spd = 1, dex = 1 }, -- III: +2 HP +1 SPD +1 DEX (7 HP, 3 dmg, 3 move, 3 DEX)
}

-- Flavor + threat readout for the hover intel panel (bio written once here).
function M.bioOf(u)
    if u.kind == "archer" then
        local tierName = u.eliteTier > 0 and (" (ELITE " .. u.eliteTier .. ")") or ""
        return { kind = "SKELETON ARCHER" .. tierName, style = "RANGED",
            threat = "BOW " .. (u.rangedDmg or M.ARCHER_DMG) .. "  ·  RNG " ..
                (u.shotRange or M.ARCHER_RANGE) .. "  ·  MOVE " .. (u.range or 2) .. "  ·  HP " .. (u.maxHP or 5),
            bio = "A conscripted guardsman who never got to rest. Its bow arm still " ..
                "remembers every drill — and it hates sharing the meadow." }
    end
    if u.kind == "slime" then
        local tierName = u.eliteTier > 0 and (" (ELITE " .. u.eliteTier .. ")") or ""
        if u.isBig then
            return { kind = "BIG SLIME", style = "MELEE",
                threat = "DMG " .. M.attackDamage(u) .. "  ·  MOVE " .. (u.range or 2) .. "  ·  HP " .. (u.maxHP or 6),
                bio = "Two slimes fused into one furious blob. Twice the hunger, twice the wobble — kill it fast or it keeps no fragments." }
        end
        if u.isSmall then
            return { kind = "SMALL SLIME", style = "MELEE",
                threat = "DMG 1  ·  MOVE 1  ·  HP 1",
                bio = "A tiny fragment of a slime, desperate to find its kin and merge." }
        end
        return { kind = "SLIME" .. tierName, style = "MELEE",
            threat = "DMG " .. M.attackDamage(u) .. "  ·  MOVE " .. (u.range or 2) .. "  ·  HP " .. (u.maxHP or 4),
            bio = "A leftover blob of the meadow's old magic. Boneless, brainless and " ..
                "endlessly hungry — it wobbles toward anything warm. " ..
                "On death, splits into two smaller slimes that seek to merge back." }
    end
    return { kind = "UNKNOWN", style = "?", threat = "?", bio = "?" }
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

-- Run maps: guards scale with level — count 2 + level/2 (max 4).
-- Slimes get +1 HP per 2 levels, +1 STR per 2 levels.
-- Skeletons get +1 HP per level, +1 STR per 2 levels.
-- Elite chance 25%, tiered stat boosts.
-- Slimes spawn spread out (not adjacent).
function M.spawnRunEnemies()
    local lvl = G.runLevel or 1
    local n = math.min(2 + math.floor(lvl / 2), 4)
    local bonus = math.floor(lvl / 2)

    -- Use level's enemy spawn positions
    local spawns = G.enemySpawns or {}
    if #spawns == 0 then
        -- Fallback: old behavior
        local sx, sy = G.spawnTile[1], G.spawnTile[2]
        spawns = {}
        for y = 1, G.GRID do for x = 1, G.GRID do
            if Board.inBounds(x, y) and not Board.isBlocked(x, y)
                and not M.unitAt(x, y)
                and not (x == sx and y == sy)
                and (math.abs(x - sx) + math.abs(y - sy)) >= 4 then
                local t = G.terrain[y] and G.terrain[y][x]
                if t ~= "shopdoor" and t ~= "shopwall" then
                    spawns[#spawns + 1] = { x, y }
                end
            end
        end end
    end

    -- Shuffle spawns for variety
    for i = #spawns, 2, -1 do
        local j = math.random(i)
        spawns[i], spawns[j] = spawns[j], spawns[i]
    end

    -- Filter spawns: slimes need spacing (manhattan >= 3)
    local slimeSpawns, otherSpawns = {}, {}
    for _, s in ipairs(spawns) do
        local tooClose = false
        for _, placed in ipairs(slimeSpawns) do
            if math.abs(s.x - placed.x) + math.abs(s.y - placed.y) < 3 then
                tooClose = true
                break
            end
        end
        if not tooClose and #slimeSpawns < n then
            slimeSpawns[#slimeSpawns + 1] = s
        else
            otherSpawns[#otherSpawns + 1] = s
        end
    end
    -- Combine: slime spawns first (spaced), then others
    local finalSpawns = {}
    for _, s in ipairs(slimeSpawns) do finalSpawns[#finalSpawns + 1] = s end
    for _, s in ipairs(otherSpawns) do finalSpawns[#finalSpawns + 1] = s end

    local defs = {}
    local nArchers = math.min(math.floor(lvl / 2), 2, n)
    local enemyIdx = 1

    -- Archer (skeleton) defs
    for i = 1, nArchers do
        local tier = 0
        local eliteChance = 0.25
        if math.random() < eliteChance then tier = math.random(1, 3) end
        local tierBonus = ARCHER_ELITE_TIERS[tier] or {}
        local hp = 5 + lvl + (tierBonus.hp or 0)
        local str = 1 + math.floor(lvl / 2) + (tierBonus.str or 0)
        local spd = 2 + (tierBonus.spd or 0)
        local dex = 2 + (tierBonus.dex or 0)
        defs[#defs + 1] = { id = "a" .. enemyIdx, name = "Skeleton " .. string.char(64 + enemyIdx),
            team = "enemy", kind = "archer", color = ARCHER_COLOR, dark = ARCHER_DARK,
            maxHP = hp, move = spd,
            rangedDmg = M.ARCHER_DMG + str - 1, shotRange = M.ARCHER_RANGE,
            stats = { vigor = math.ceil(hp / 4), strength = str, dexterity = dex, speed = spd },
            eliteTier = tier }
        enemyIdx = enemyIdx + 1
    end

    -- Slime defs
    for i = 1, n - nArchers do
        local tier = 0
        local eliteChance = 0.25
        if math.random() < eliteChance then tier = math.random(1, 3) end
        local tierBonus = SLIME_ELITE_TIERS[tier] or {}
        local hp = 4 + bonus + (tierBonus.hp or 0)
        local str = 1 + bonus + (tierBonus.str or 0)
        local spd = 2 + (tierBonus.spd or 0)
        defs[#defs + 1] = { id = "e" .. enemyIdx, name = "Slime " .. string.char(64 + enemyIdx),
            team = "enemy", kind = "slime", color = SLIME_COLOR, dark = SLIME_DARK,
            maxHP = hp, move = spd,
            stats = { vigor = math.ceil(hp / 4), strength = str, dexterity = 1, speed = spd },
            eliteTier = tier }
        enemyIdx = enemyIdx + 1
    end

    for i = 1, math.min(n, #finalSpawns) do
        local u = M.spawnUnit(defs[i])
        u.gx, u.gy = finalSpawns[i].x, finalSpawns[i].y
        u.px, u.py = u.gx, u.gy
        u.fx, u.fy = u.gx, u.gy
        u.map = "over"
        G.units[#G.units + 1] = u
    end
end

-- Spawn enemies from an encounter definition
-- encounter: { id, enemies = { "slime", "skeleton", ... } }
-- Uses G.enemySpawns from the level for positions
-- Elite chance 25%, tiered stat boosts (I/II/III)
function M.spawnEncounterEnemies(encounter)
    local spawns = G.enemySpawns or {}
    if #spawns == 0 then return end

    -- Shuffle spawns for variety
    for i = #spawns, 2, -1 do
        local j = math.random(i)
        spawns[i], spawns[j] = spawns[j], spawns[i]
    end

    local lvl = G.runLevel or 1
    local bonus = math.floor(lvl / 2)

    -- 2-hero squads pull +1 enemy per extra hero (uses leftover spawns)
    local enemyList = {}
    for _, t in ipairs(encounter.enemies) do enemyList[#enemyList + 1] = t end
    do
        local heroes = 0
        for _, u in ipairs(G.units) do
            if u.team ~= "enemy" then heroes = heroes + 1 end
        end
        for k = 2, heroes do
            if encounter.enemies[1] then
                enemyList[#enemyList + 1] = encounter.enemies[1]
            end
        end
    end

    for i, enemyType in ipairs(enemyList) do
        if i > #spawns then break end
        local spawn = spawns[i]

        local def
        local tier = 0
        if math.random() < 0.25 then tier = math.random(1, 3) end

        if enemyType == "slime" then
            local tierBonus = SLIME_ELITE_TIERS[tier] or {}
            local hp = 4 + bonus + (tierBonus.hp or 0)
            local str = 1 + bonus + (tierBonus.str or 0)
            def = {
                id = "e" .. i, name = "Slime " .. string.char(64 + i),
                team = "enemy", kind = "slime", color = SLIME_COLOR, dark = SLIME_DARK,
                maxHP = hp, move = 2,
                stats = { vigor = math.ceil(hp / 4), strength = str, dexterity = 1, speed = 2 },
                eliteTier = tier
            }
        elseif enemyType == "skeleton" then
            local tierBonus = ARCHER_ELITE_TIERS[tier] or {}
            local hp = 5 + lvl + (tierBonus.hp or 0)
            local str = 1 + math.floor(lvl / 2) + (tierBonus.str or 0)
            local spd = 2 + (tierBonus.spd or 0)
            local dex = 2 + (tierBonus.dex or 0)
            def = {
                id = "a" .. i, name = "Skeleton " .. string.char(64 + i),
                team = "enemy", kind = "archer", color = ARCHER_COLOR, dark = ARCHER_DARK,
                maxHP = hp, move = spd,
                rangedDmg = M.ARCHER_DMG + str - 1, shotRange = M.ARCHER_RANGE,
                stats = { vigor = math.ceil(hp / 4), strength = str, dexterity = dex, speed = spd },
                eliteTier = tier
            }
        else
            -- Unknown type, default to slime
            local tierBonus = SLIME_ELITE_TIERS[tier] or {}
            local hp = 4 + bonus + (tierBonus.hp or 0)
            local str = 1 + bonus + (tierBonus.str or 0)
            def = {
                id = "e" .. i, name = "Slime " .. string.char(64 + i),
                team = "enemy", kind = "slime", color = SLIME_COLOR, dark = SLIME_DARK,
                maxHP = hp, move = 2,
                stats = { vigor = math.ceil(hp / 4), strength = str, dexterity = 1, speed = 2 },
                eliteTier = tier
            }
        end

        local u = M.spawnUnit(def)
        u.gx, u.gy = spawn.x, spawn.y
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

-- Action mode: "move" | "attack" | "spells" (Mewgenics-style buttons).
-- Decides which range wash is drawn and what tile clicks do.
function M.setActionMode(mode)
    local a = M.active()
    if mode == "spells" then
        if not a or a.team ~= "hero" or a.acted then return end
        -- assassins throw blades (free); everyone else casts firebolt (3 mana)
        if a.kind == "assassin" then
            G.actionMode = "spells"
            G.castMode = true
            G.pushLog(a.name .. ": blades ready — click an enemy (M/F/Q to switch)")
            return
        end
        if (a.mana or 0) < (M.BOLT_COST or 3) then
            G.pushLog(a.name .. ": not enough mana for bolt")
            return
        end
        G.actionMode = "spells"
        G.castMode = true
        G.pushLog(a.name .. ": spells armed — click an enemy (M/F/Q to switch)")
        return
    end
    G.actionMode = mode
    G.castMode = false
    if mode == "attack" then
        G.pushLog("attack stance — red tiles are in reach (M/F/Q to switch)")
    end
end
-- After a unit consumes its turn, pass selection to the next unended
-- unit in initiative order on the visible map. When everyone has ended,
-- a new round starts. Selecting an enemy runs its AI immediately.
function M.advanceTurn(finished)
    G.castMode = false
    G.actionMode = "move"
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
    G.actionMode = "move"
    G.ai = nil
    for _, u in ipairs(G.units) do
        u.moved, u.attacked, u.acted = false, false, false
        u.tauntId = nil -- taunts expire each round
    end
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
    -- taunted enemies must go for their taunter (if still standing on this map)
    if e.tauntId then
        for _, u in ipairs(G.units) do
            if u.id == e.tauntId and u.team ~= "enemy" and u.hp > 0 and u.map == e.map then
                return u, math.abs(e.gx - u.gx) + math.abs(e.gy - u.gy)
            end
        end
        e.tauntId = nil
    end
    local best, bestD = nil, math.huge
    for _, u in ipairs(G.units) do
        if u.team ~= "enemy" and u.hp > 0 and u.map == e.map then
            local d = math.abs(e.gx - u.gx) + math.abs(e.gy - u.gy)
            if d < bestD then best, bestD = u, d end
        end
    end
    return best, bestD
end

-- Tank Taunt: all enemies within 2 tiles must target the tank until next
-- round. Instant, costs the attack action.
function M.orderTaunt(att)
    if not att then return end
    if #att.path > 0 then G.pushLog(att.name .. ": still moving...") return end
    if att.acted then G.pushLog(att.name .. ": already acted") return end
    if att.attacked then G.pushLog(att.name .. ": already attacked — 1 attack per turn") return end
    local n = 0
    for _, u in ipairs(G.units) do
        if u.team == "enemy" and u.hp > 0 and u.map == att.map then
            local d = math.abs(u.gx - att.gx) + math.abs(u.gy - att.gy)
            if d >= 1 and d <= 2 then
                u.tauntId = att.id
                n = n + 1
            end
        end
    end
    att.attacked = true
    att.swingT = love.timer.getTime()
    att.swingDx, att.swingDy = 1, 0
    if n == 0 then
        G.pushLog(att.name .. " bellows — no enemies close enough!")
    else
        G.pushLog(att.name .. " TAUNTS " .. n .. " enemies!")
        M.addFloat(att.gx, att.gy - 0.5, "TAUNT!", G.C.floatDmg, true, "callout")
        if G.playSfx then G.playSfx("taunt", 0.9) end
    end
    afterAction(att)
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

-- Process poison damage on all units (called from love.update)
function M.updatePoison(dt)
    for _, u in ipairs(G.units) do
        if u.poison and u.poison > 0 and u.hp > 0 then
            u.poison = u.poison - 1
            if u.poison % 3 == 0 or u.poison == 0 then -- tick every turn
                u.hp = math.max(0, u.hp - 1)
                M.addFloat(u.gx, u.gy, "-1 poison", {0.5, 1, 0.3}, false, "poison")
                if u.hp <= 0 then
                    G.pushLog(u.name .. " succumbs to poison!")
                    if u.kind == "slime" and not u.isSmall then
                        M.splitSlime(u)
                    end
                    M.removeUnit(u.id)
                end
            end
        end
    end
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
            -- Slimes: merge-seek before fighting.
            -- small+small -> normal, normal+normal -> big. Big slimes just fight.
            -- Small slimes always prefer merging; normals merge only when no
            -- hero is in strike range (heroes stay the priority up close).
            local target, dist = M.nearestHero(u)
            if not target then
                u.acted = true G.ai = nil M.advanceTurn(u) return
            end
            -- archers hold at bow range; melee must close to adjacent.
            local shotRng = (u.kind == "archer") and (u.shotRange or M.ARCHER_RANGE) or 1
            local inStrike = target and dist >= 1 and dist <= shotRng
            if u.kind == "slime" and not u.isBig then
                local partner = M.nearestMergePartner(u)
                if partner and (u.isSmall or not inStrike) then
                    local pdist = math.abs(u.gx - partner.gx) + math.abs(u.gy - partner.gy)
                    if pdist == 1 then
                        -- Merge!
                        M.mergeSlimes(u, partner)
                        u.acted = true G.ai = nil M.advanceTurn(u)
                        return
                    else
                        local bx, by = M.approachTile(u, partner)
                        if bx then M.orderMove(u, bx, by) end
                        if #u.path == 0 then
                            u.acted = true G.ai = nil M.advanceTurn(u)
                        else
                            ai.phase, ai.t = "move", 0
                        end
                        return
                    end
                end
                -- No partner (or hero breathing down our neck): fight as usual.
            end
            -- Elite quick: extra move range considered in approachTile via reachable
            if inStrike then
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
            -- Elite fierce: can attack twice
            if u.abilities and u.abilities.fierce then
                ai.phase, ai.t = "strike", 0
            else
                ai.phase, ai.t = "strike", 0
            end
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
            -- Elite fierce: second attack
            if u.abilities and u.abilities.fierce and not u.attacked and target and target.hp > 0 then
                -- Queue a second strike
                G.ai = { id = u.id, phase = "strike", t = G.AI_STRIKE }
            end
        end
    end
end

-- Slime size tier: 0 small, 1 normal, 2 big.
function M.slimeTier(u)
    if u.isBig then return 2 end
    if u.isSmall then return 0 end
    return 1
end

-- Find nearest same-tier slime to merge with (big slimes never merge).
function M.nearestMergePartner(u)
    local want = M.slimeTier(u)
    if want >= 2 then return nil end
    local best, bestD = nil, math.huge
    for _, v in ipairs(G.units) do
        if v ~= u and v.kind == "slime" and v.team == u.team and v.map == u.map and v.hp > 0
            and M.slimeTier(v) == want then
            local d = math.abs(u.gx - v.gx) + math.abs(u.gy - v.gy)
            if d < bestD then best, bestD = v, d end
        end
    end
    return best, bestD
end

-- Find nearest small slime (for merging)
function M.nearestSmallSlime(u)
    local best, bestD = nil, math.huge
    for _, v in ipairs(G.units) do
        if v ~= u and v.isSmall and v.team == u.team and v.map == u.map and v.hp > 0 then
            local d = math.abs(u.gx - v.gx) + math.abs(u.gy - v.gy)
            if d < bestD then best, bestD = v, d end
        end
    end
    return best, bestD
end

-- Merge two same-tier slimes: small+small -> normal, normal+normal -> big.
function M.mergeSlimes(a, b)
    if M.slimeTier(a) >= 2 or M.slimeTier(b) >= 2 then return end
    if M.slimeTier(a) == 1 then
        -- Big slime at a's position
        local merged = M.spawnUnit({
            id = "slime_big_" .. math.random(1000, 9999),
            name = "Big Slime",
            gx = a.gx, gy = a.gy,
            team = "enemy", kind = "slime",
            color = SLIME_COLOR, dark = SLIME_DARK,
            stats = { vigor = 2, strength = 3, dexterity = 1, speed = 2 },
            maxHP = 6, move = 2,
            isSmall = false, isBig = true
        })
        merged.map = a.map
        merged.hp = 6
        G.units[#G.units + 1] = merged
        for i = #G.units, 1, -1 do
            if G.units[i].id == a.id or G.units[i].id == b.id then
                table.remove(G.units, i)
            end
        end
        G.pushLog("Two slimes merge into a BIG slime!")
        if G.playSfx then G.playSfx("merge", 0.9) end
        M.buildTurnOrder()
        return
    end
    -- Create new full slime at a's position
    local merged = M.spawnUnit({
        id = "slime_merged_" .. math.random(1000, 9999),
        name = "Slime",
        gx = a.gx, gy = a.gy,
        team = "enemy", kind = "slime",
        color = SLIME_COLOR, dark = SLIME_DARK,
        stats = { vigor = 1, strength = 1, dexterity = 1, speed = 2 },
        maxHP = 4, move = 2,
        isSmall = false
    })
    merged.map = a.map
    merged.hp = 4
    G.units[#G.units + 1] = merged
    -- Remove both small slimes
    for i = #G.units, 1, -1 do
        if G.units[i].id == a.id or G.units[i].id == b.id then
            table.remove(G.units, i)
        end
    end
    G.pushLog("Two fragments merge into a slime!")
        if G.playSfx then G.playSfx("merge", 0.8) end
    M.buildTurnOrder()
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
    local base = math.max(1, (att.stats and att.stats.strength) or 1)
    if att.kind == "tank" then base = base + 1 end -- smash hits harder
    local m = M.abMods(att)
    return base + (m.dmg or 0)
end

-- outgoing damage mods: backstab (target next to anyone else), execute.
function M.outgoingMods(att, target, dmg)
    if not target then return dmg end
    local m = M.abMods(att)
    if (m.backstabMult or 0) > 0 and target.hp > 0 then
        for _, u in ipairs(G.units) do
            if u ~= att and u ~= target and (u.hp or 0) > 0 and u.map == att.map
                and math.abs(u.gx - target.gx) + math.abs(u.gy - target.gy) == 1 then
                dmg = math.floor(dmg * (1 + m.backstabMult) + 0.5)
                M.addFloat(target.gx, target.gy - 0.5, "BACKSTAB!", G.C.floatCrit, true, "callout")
                break
            end
        end
    end
    if (m.executeDmg or 0) > 0 and target.maxHP > 0 and target.hp <= target.maxHP / 2 then
        dmg = dmg + m.executeDmg
    end
    return dmg
end

-- incoming damage mods: bulwark first-block, stoneskin. Never below 1.
function M.incomingMods(target, dmg)
    local m = M.abMods(target)
    if (m.firstBlock or 0) > 0 and not target.firstBlockUsed and dmg > 1 then
        target.firstBlockUsed = true
        M.addFloat(target.gx, target.gy - 0.5, "BLOCKED", {0.65, 0.75, 0.95}, false, "block")
        dmg = dmg - m.firstBlock
    end
    if (m.stoneskin or 0) > 0 then
        dmg = dmg - m.stoneskin
    end
    if dmg < 1 then dmg = 1 end
    return dmg
end

function M.addFloat(gx, gy, txt, col, big, style)
    G.floats[#G.floats + 1] = { gx = gx, gy = gy, txt = txt, col = col,
        big = big or false, style = style or "hit",
        rot = (math.random() - 0.5) * 0.16, t = 0, life = 1.1 }
end

-- Impact feel: hit-stop freeze + board shake + thud. Call on every landed hit.
function M.impact(killed)
    G.hitstop = killed and 0.12 or 0.05
    G.shake = killed and 6 or 3
    if G.playSfx then G.playSfx("hit", killed and 1.0 or 0.7) end
end

-- Crit: luck x 3% chance for x1.5 damage (rounded). Returns dmg, crit?
-- Heroes have luck, enemies don't (luck defaults to 0 for enemies).
function M.critRoll(u, dmg)
    local luck = (u.stats and u.stats.luck) or 0
    if math.random() < luck * 0.03 then return math.floor(dmg * 1.5 + 0.5), true end
    return dmg, false
end

-- Dodge: tall-grass cover + 2% per DEX + vanish, capped at 75%.
function M.tryDodge(tgt)
    local base = Board.dodgeChanceAt(tgt.gx, tgt.gy)
    local dex = (tgt.stats and tgt.stats.dexterity) or 0
    local m = M.abMods(tgt)
    return math.random() < math.min(0.75, base + dex * 0.02 + (m.dodgePct or 0))
end

function M.removeUnit(id)
    local cur = G.units[G.activeIdx]
    local curId = cur and cur.id
    for i, u in ipairs(G.units) do
        if u.id == id then table.remove(G.units, i) break end
    end
    G.squash[id] = nil
    if G.playSfx then G.playSfx("poof", 0.7) end
    if G.activeIdx > #G.units then G.activeIdx = #G.units end
    M.buildTurnOrder()
    if curId then
        for i, u in ipairs(G.units) do
            if u.id == curId then G.activeIdx = i break end
        end
        M.syncTurnPos()
    end
end

-- Split a dead slime: big -> 2 normals, normal -> 2 smalls.
-- Small slimes just die. Fragments seek to merge back.
function M.splitSlime(slime)
    local gx, gy = slime.gx, slime.gy
    local map = slime.map
    -- Find 2 valid positions 4-5 tiles apart from each other
    local positions = {}
    local attempts = 0
    while #positions < 2 and attempts < 50 do
        local angle = math.random() * math.pi * 2
        local dist = 4 + math.random() -- 4-5 tiles
        local x = math.floor(gx + math.cos(angle) * dist + 0.5)
        local y = math.floor(gy + math.sin(angle) * dist + 0.5)
        if Board.inBounds(x, y) and not Board.isBlocked(x, y) and not M.unitAt(x, y) then
            -- Check distance from other small slime position
            local ok = true
            for _, p in ipairs(positions) do
                if math.abs(x - p.x) + math.abs(y - p.y) < 4 then ok = false break end
            end
            if ok then positions[#positions + 1] = { x = x, y = y } end
        end
        attempts = attempts + 1
    end
    -- Fallback: just place adjacent to death spot
    if #positions < 2 then
        local dirs = {{1,0},{-1,0},{0,1},{0,-1}}
        for _, d in ipairs(dirs) do
            if #positions >= 2 then break end
            local x, y = gx + d[1], gy + d[2]
            if Board.inBounds(x, y) and not Board.isBlocked(x, y) and not M.unitAt(x, y) then
                positions[#positions + 1] = { x = x, y = y }
            end
        end
    end

    for idx, pos in ipairs(positions) do
        local frag
        if slime.isBig then
            frag = M.spawnUnit({
                id = slime.id .. "_frag" .. idx,
                name = "Slime",
                gx = pos.x, gy = pos.y,
                team = "enemy", kind = "slime",
                color = SLIME_COLOR, dark = SLIME_DARK,
                stats = { vigor = 1, strength = 1, dexterity = 1, speed = 2 },
                maxHP = 4, move = 2,
                isSmall = false
            })
            frag.hp = 4
        else
            frag = M.spawnUnit({
                id = slime.id .. "_small" .. idx,
                name = "Small Slime",
                gx = pos.x, gy = pos.y,
                team = "enemy", kind = "slime",
                color = SLIME_SMALL_COLOR, dark = SLIME_SMALL_DARK,
                stats = { vigor = 1, strength = 1, dexterity = 1, speed = 1 },
                maxHP = 1, move = 1,
                isSmall = true
            })
        end
        frag.map = map
        G.units[#G.units + 1] = frag
    end
    if slime.isBig then
        G.pushLog("The big slime bursts into two slimes!")
        if G.playSfx then G.playSfx("split", 0.9) end
    else
        G.pushLog("The slime splits into two fragments!")
        if G.playSfx then G.playSfx("split", 0.8) end
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
    local mr = att.meleeRange or 1
    if dist < 1 or dist > mr then
        G.pushLog(att.name .. ": too far — close to " .. mr .. " tile" .. (mr > 1 and "s" or ""))
        return
    end
    -- swing animation window for the pawn renderer
    att.swingT = love.timer.getTime()
    att.swingDx, att.swingDy = target.gx - att.gx, target.gy - att.gy
    if G.playSfx then G.playSfx("whoosh", 0.6) end
    local dmg, crit = M.critRoll(att, M.attackDamage(att))
    dmg = M.outgoingMods(att, target, dmg)
    att.attacked = true
    if M.tryDodge(target) then
        M.addFloat(target.gx, target.gy, "DODGED", G.C.floatDodge, false, "miss")
        G.pushLog(att.name .. " swings at " .. target.name .. " — dodged!")
        afterAction(att)
        return
    end
    dmg = M.incomingMods(target, dmg)
    target.hp = math.max(0, target.hp - dmg)
    M.impact(target.hp <= 0)
    G.squash[target.id] = 1
    -- Apply poison if attacker is a slime (not small slime, not boss)
    if att.kind == "slime" and not att.isSmall then
        target.poison = (target.poison or 0) + 2 -- 2 turns of poison
        M.addFloat(target.gx, target.gy, "POISONED", {0.5, 1, 0.3}, false, "poison")
    end
    -- assassin venom: dagger hits poison too
    do
        local m = M.abMods(att)
        if (m.meleePoison or 0) > 0 then
            target.poison = (target.poison or 0) + m.meleePoison
            M.addFloat(target.gx, target.gy, "POISONED", {0.5, 1, 0.3}, false, "poison")
        end
    end
    -- thorns / riposte: melee attackers eat it back
    do
        local m = M.abMods(target)
        if (m.thorns or 0) > 0 and att.hp > 0 then
            att.hp = math.max(0, att.hp - m.thorns)
            M.addFloat(att.gx, att.gy, "-" .. m.thorns, G.C.floatDmg)
            if att.hp <= 0 then
                G.pushLog(att.name .. " dies on " .. target.name .. "'s thorns!")
                M.removeUnit(att.id)
            end
        end
    end
    M.addFloat(target.gx, target.gy, "-" .. dmg .. (crit and "!" or ""),
        crit and G.C.floatCrit or G.C.floatDmg, crit)
    if target.hp <= 0 then
        G.pushLog(att.name .. " hits " .. target.name .. " for " .. dmg .. " — slain!")
        M.rewardKill(att)
        -- Slime death: split into 2 small slimes (bosses don't split)
        if target.kind == "slime" and not target.isSmall then
            M.splitSlime(target)
        end
        M.removeUnit(target.id)
    else
        G.pushLog(att.name .. " hits " .. target.name .. " for " .. dmg ..
            " (" .. target.hp .. "/" .. target.maxHP .. ")")
    end
    afterAction(att)
end

-- Kill tracker: no HP/mana/coin per kill — reward granted on round clear.
function M.rewardKill(killer)
    G.levelKills = (G.levelKills or 0) + 1
    G.pushLog(killer.name .. " defeated a foe!")
    if killer and killer.team ~= "enemy" and (killer.hp or 0) > 0 then
        killer.hp = math.min(killer.maxHP, killer.hp + 3)
        M.addFloat(killer.gx, killer.gy, "+3", G.C.floatHeal, false, "heal")
        if G.playSfx then G.playSfx("heal", 0.7) end
    end
end

function M.grantRoundReward()
    local bounty = (5 + (G.runLevel or 1)) * (G.levelKills or 0)
    if bounty > 0 then
        G.coins = (G.coins or 0) + bounty
        G.levelCoins = bounty
        G.pushLog("Round cleared — +" .. bounty .. "c!")
        local hero = G.units[1]
        if hero then M.addFloat(hero.gx, hero.gy - 0.5, "+" .. bounty .. "c", G.C.coin, false, "heal") end
    end
end

-- Assassin thrown blades: physical ranged attack, no mana cost, uses the
-- one attack per turn. Range 4, damage = Strength. Reuses the arrow
-- projectile visual (purely cosmetic, tracks the camera).
function M.orderThrow(att, target)
    if not att then return end
    if #att.path > 0 then G.pushLog(att.name .. ": still moving...") return end
    if att.acted then G.pushLog(att.name .. ": already acted") return end
    if att.attacked then G.pushLog(att.name .. ": already attacked — 1 attack per turn") return end
    if not target or target.hp <= 0 or target.map ~= att.map then return end
    if target.team == att.team then G.pushLog(att.name .. ": allies only, pick an enemy") return end
    local rng = att.throwRange or 4
    local dist = math.abs(att.gx - target.gx) + math.abs(att.gy - target.gy)
    if dist < 1 or dist > rng then G.pushLog(att.name .. ": blades reach " .. rng .. " tiles") return end
    att.attacked = true
    att.swingT = love.timer.getTime()
    att.swingDx, att.swingDy = target.gx - att.gx, target.gy - att.gy
    if G.playSfx then G.playSfx("whoosh", 0.5) end
    G.arrows[#G.arrows + 1] = { fx = att.px or att.gx, fy = att.py or att.gy,
        tx = target.px or target.gx, ty = target.py or target.gy, t = 0, dur = 0.28 }
    local dmg, crit = M.critRoll(att, M.attackDamage(att))
    if M.tryDodge(target) then
        M.addFloat(target.gx, target.gy, "DODGED", G.C.floatDodge, false, "miss")
        G.pushLog(att.name .. "'s blades miss " .. target.name .. "!")
        afterAction(att)
        return
    end
    target.hp = math.max(0, target.hp - dmg)
    M.impact(target.hp <= 0)
    G.squash[target.id] = 1
    M.addFloat(target.gx, target.gy, "-" .. dmg .. (crit and "!" or ""),
        crit and G.C.floatCrit or G.C.floatDmg, crit)
    if target.hp <= 0 then
        G.pushLog(att.name .. " shreds " .. target.name .. " for " .. dmg .. " — slain!")
        M.rewardKill(att)
        if target.kind == "slime" and not target.isSmall then
            M.splitSlime(target)
        end
        M.removeUnit(target.id)
    else
        G.pushLog(att.name .. " cuts " .. target.name .. " for " .. dmg ..
            " (" .. target.hp .. "/" .. target.maxHP .. ")")
    end
    afterAction(att)
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
    M.addFloat(att.gx, att.gy, "-" .. BOLT_COST .. " mana", G.C.floatMana, false, "mana")
    local dmg, crit = M.critRoll(att, 2 + ((att.stats and att.stats.charisma) or 0))
    -- abilities are free: do not consume the 1/turn basic attack
    if M.tryDodge(target) then
        M.addFloat(target.gx, target.gy, "DODGED", G.C.floatDodge, false, "miss")
        G.pushLog(att.name .. "'s bolt misses " .. target.name .. "!")
        afterAction(att)
        return
    end
    target.hp = math.max(0, target.hp - dmg)
    M.impact(target.hp <= 0)
    G.squash[target.id] = 1
    M.addFloat(target.gx, target.gy, "-" .. dmg .. (crit and "!" or ""),
        crit and G.C.floatCrit or G.C.floatDmg, crit)
    if target.hp <= 0 then
        G.pushLog(att.name .. " bolts " .. target.name .. " for " .. dmg .. " — slain!")
        M.rewardKill(att)
        -- Bolt kills split slimes just like melee kills
        if target.kind == "slime" and not target.isSmall then
            M.splitSlime(target)
        end
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
    if G.playSfx then G.playSfx("twang", 0.7) end
    if M.tryDodge(target) then
        M.addFloat(target.gx, target.gy, "DODGED", G.C.floatDodge, false, "miss")
        G.pushLog(att.name .. " looses at " .. target.name .. " — dodged!")
        afterAction(att)
        return
    end
    target.hp = math.max(0, target.hp - dmg)
    M.impact(target.hp <= 0)
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
-- Movement wash only shows for heroes in MOVE mode (never on enemy turn).
-- Attack wash (G.cachedAttack): melee (dist 1) in ATTACK mode,
-- bolt range (dist 3) in SPELLS mode.
function M.updateQueries()
    local actU = M.active()
    local mode = G.actionMode or "move"
    G.cachedAttack = G.cachedAttack or {}
    if actU and actU.team == "hero" and actU.map == G.map and not actU.moved and not actU.acted
        and #actU.path == 0 and mode == "move" then
        G.cachedReach = M.reachable(actU)
    else
        G.cachedReach = {}
    end
    G.cachedAttack = {}
    if actU and actU.team == "hero" and actU.map == G.map and not actU.acted and #actU.path == 0 then
        local rng = nil
        if mode == "attack" then rng = actU.meleeRange or 1
        elseif mode == "spells" and G.castMode then
            rng = (actU.kind == "assassin") and (actU.throwRange or 4) or BOLT_RANGE
        end
        if rng then
            for dy = -rng, rng do
                for dx = -rng, rng do
                    if math.abs(dx) + math.abs(dy) >= 1 and math.abs(dx) + math.abs(dy) <= rng then
                        local nx, ny = actU.gx + dx, actU.gy + dy
                        if Board.inBounds(nx, ny) then
                            G.cachedAttack[ny * 100 + nx] = true
                        end
                    end
                end
            end
        end
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

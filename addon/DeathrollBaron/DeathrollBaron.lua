--[[ Deathroll Baron
     A deathroll incremental for World of Warcraft: Forever (interface 16001).
     One file, no libraries. ]]

local ADDON, ns = ...
local floor, max, min, random = math.floor, math.max, math.min, math.random

local GOLD  = { 0.79, 0.64, 0.15 }
local BONE  = { 0.87, 0.84, 0.77 }
local DIM   = { 0.55, 0.52, 0.46 }
local BLOOD = { 0.72, 0.20, 0.18 }
local GREEN = { 0.55, 0.78, 0.42 }
local RED   = { 0.80, 0.34, 0.30 }

local ICON = "Interface\\Icons\\INV_Misc_Dice_02"

local SCHEMA = 5

-- Desperate is the one enemy modifier the odds solver has to know
-- about by name: it lifts their luck only once the range is small, so
-- no single enemy bias can describe the table. StepMatch and OddsUpTo
-- both read these constants, so the two cannot disagree again.
local DESPERATE_FROM = 20
local DESPERATE_LUCK = 0.30
local RUNNER_EVERY = 6

-- board animation timings
local FLASH_TIME = 0.42
local POP_TIME = 0.12
local ROLL_SPEED = 0.26

-- The opening edge: rung 1 is meant to be winnable, and the edge bleeds away.
-- Rolling LOW is the strong play in a deathroll, so a player "luck" of 0.55
-- means 55% of the time you take the lower of two rolls.
local EDGE_BASE = 0.55
local EDGE_STEP = 0.025

---------------------------------------------------------------------
-- formatting
---------------------------------------------------------------------
local function Comma(n)
    local s = tostring(floor(n))
    local out = (s:reverse():gsub("(%d%d%d)", "%1,")):reverse()
    return (out:gsub("^,", ""))
end

local function Money(c)
    c = floor((c or 0) + 0.5)
    if c < 0 then return "-" .. Money(-c) end
    local g = floor(c / 10000)
    local s = floor((c % 10000) / 100)
    local cu = c % 100
    if g > 0 then return Comma(g) .. "g " .. s .. "s" end
    if s > 0 then return s .. "s " .. cu .. "c" end
    return cu .. "c"
end

local function Signed(c)
    c = floor((c or 0) + 0.5)
    if c < 0 then return "-" .. Money(-c) end
    return "+" .. Money(c)
end

local function Pct(v)
    return floor(v * 100 + 0.5) .. "%"
end

---------------------------------------------------------------------
-- the ladder: name, zone, level, opening ceiling, min wager, purse
---------------------------------------------------------------------
local NPCS = {
    { "Kobold Vermin",           "Elwynn Forest",     "1-2",      100,     50,     300 },
    { "Defias Thug",             "Elwynn Forest",     "3-4",      100,     65,     400 },
    { "Frostmane Troll Whelp",   "Dun Morogh",        "3-4",      100,     90,     530 },
    { "Murloc Forager",          "Elwynn Forest",     "5-6",      100,    115,     700 },
    { "Riverpaw Outrunner",      "Elwynn Forest",     "6-7",      100,    155,     930 },
    { "Leper Gnome",             "Dun Morogh",        "8-10",     150,    205,    1240 },
    { "Goldtooth",               "Elwynn Forest",     "8",        150,    275,    1650 },
    { "Morgan the Collector",    "Elwynn Forest",     "10",       150,    365,    2190 },
    { "Hogger",                  "Elwynn Forest",     "11 elite", 150,    485,    2900 },
    { "Defias Trapper",          "Westfall",          "12-13",    150,    645,    3870 },
    { "Slark",                   "Westfall coast",    "11-15",    250,    860,    5150 },
    { "Defias Messenger",        "Westfall",          "14-15",    250,   1140,    6850 },
    { "Harvest Watcher",         "Westfall",          "14-15",    250,   1520,    9100 },
    { "Defias Pillager",         "Westfall",          "14-15",    250,   2020,   12100 },
    { "Stonesplinter Bonesnapper","Loch Modan",       "15-16",    250,   2680,   16100 },
    { "Stonesplinter Digger",    "Loch Modan",        "18-19",    400,   3570,   21400 },
    { "Brack",                   "Redridge Mountains","18-19",    400,   4750,   28500 },
    { "Squiddic",                "Redridge Mountains","19",       400,   6320,   37900 },
    { "Old Murk-Eye",            "Westfall",          "20 quest", 400,   8400,   50400 },
    { "Cookie",                  "The Deadmines",     "20 elite", 400,  11160,   67000 },
    { "Awakened Lich",           "Duskwood",          "25 elite", 600,  14850,   89100 },
    { "Bone Chewer",             "Duskwood",          "26-27",    600,  19750,  118500 },
    { "Boulderfist Ogre",        "Arathi Highlands",  "30+",      600,  26270,  157600 },
    { "Drywhisker Kobold",       "Arathi Highlands",  "30+",      600,  34930,  209600 },
    { "Daggerspine Raider",      "Arathi Highlands",  "30+",      600,  46470,  278800 },
    { "Dark Iron Shadowcaster",  "Arathi Highlands",  "30+",     1000,  61800,  370800 },
    { "Gelihast",                "Blackfathom Deeps", "23-26",   1000,  82200,  493200 },
    { "Blind Mary",              "Duskwood",          "40",      1000, 109300,  655900 },
    { "Amokarok",                "Duskwood",          "elite",   1000, 145400,  872400 },
    { "Mutanus the Devourer",    "Wailing Caverns",   "elite",   1000, 193400, 1160300 },
}

---------------------------------------------------------------------
-- affixes: rolled once per run, per rung
---------------------------------------------------------------------
local AFFIXES = {
    -- tier 1: weak
    { id = "nervous",  name = "Nervous",         tier = 1, flaw = true,
      text = "Their luck -10%",
      apply = function(c) c.enemyLuck = c.enemyLuck - 0.10 end },
    { id = "fingers",  name = "Quick Fingers",   tier = 1, flaw = false,
      text = "Their luck +10%",
      apply = function(c) c.enemyLuck = c.enemyLuck + 0.10 end },
    { id = "drunk",    name = "Drunk",           tier = 1, flaw = true,
      text = "Their luck -20%, purse +15%",
      apply = function(c) c.enemyLuck = c.enemyLuck - 0.20; c.purse = c.purse * 1.15 end },
    { id = "grit",     name = "Grit in the Eyes",tier = 1, flaw = false,
      text = "Your luck -8%",
      apply = function(c) c.playerLuck = c.playerLuck - 0.08 end },
    { id = "loose",    name = "Loose Purse",     tier = 1, flaw = true,
      text = "Purse +25%",
      apply = function(c) c.purse = c.purse * 1.25 end },
    { id = "tight",    name = "Tight Purse",     tier = 1, flaw = false,
      text = "Purse -20%",
      apply = function(c) c.purse = c.purse * 0.80 end },
    { id = "tell",     name = "Cheater's Tell",  tier = 1, flaw = true,
      text = "They open the roll",
      apply = function(c) c.theyOpen = true end },
    { id = "thick",    name = "Thick Skin",      tier = 1, flaw = false,
      text = "Your Insurance -1 charge",
      apply = function(c) c.insurance = max(0, c.insurance - 1) end },

    -- tier 2: medium
    { id = "marked",   name = "Marked Deck",     tier = 2, flaw = false,
      text = "Their luck +25%",
      apply = function(c) c.enemyLuck = c.enemyLuck + 0.25 end },
    { id = "coldread", name = "Cold Read",       tier = 2, flaw = false,
      text = "You must open the roll",
      apply = function(c) c.forcePlayerOpen = true end },
    { id = "edge",     name = "House Edge",      tier = 2, flaw = false,
      text = "Your payout -15%",
      apply = function(c) c.mult = c.mult * 0.85 end },
    { id = "escort",   name = "Escort",          tier = 2, flaw = true,
      text = "Purse +40%",
      apply = function(c) c.purse = c.purse * 1.40 end },
    { id = "silver",   name = "Silver Tongue",   tier = 2, flaw = false,
      text = "10% of your win is taxed",
      apply = function(c) c.winTax = c.winTax + 0.10 end },
    { id = "desperate",name = "Desperate",       tier = 2, flaw = false,
      text = "Below a 20 ceiling, their luck +30%",
      apply = function(c) c.desperate = true end },

    -- tier 3: strong
    { id = "loaded",   name = "Loaded Dice",     tier = 3, flaw = false,
      text = "Their luck +30%",
      apply = function(c) c.enemyLuck = c.enemyLuck + 0.30 end },
    { id = "stare",    name = "The Stare",       tier = 3, flaw = false,
      text = "Your luck -20%",
      apply = function(c) c.playerLuck = c.playerLuck - 0.20 end },
    { id = "debt",     name = "Debt Collector",  tier = 3, flaw = false,
      text = "A loss costs 150% of the wager",
      apply = function(c) c.lossMult = c.lossMult * 1.5 end },
    { id = "nullward", name = "Null Ward",       tier = 3, flaw = false,
      text = "Your Insurance does nothing",
      apply = function(c) c.insuranceBlocked = true end },
    { id = "double",   name = "Double or Nothing",tier = 3, flaw = false,
      text = "Win pays 2x, loss costs 2x",
      apply = function(c) c.doubleOrNothing = true end },
    { id = "cheapshot",name = "Cheap Shot",      tier = 3, flaw = false,
      text = "Opens at half the ceiling",
      apply = function(c) c.ceiling = max(20, floor(c.ceiling / 2)) end },
}

local AFFIX_BY_ID = {}
for _, a in ipairs(AFFIXES) do AFFIX_BY_ID[a.id] = a end

---------------------------------------------------------------------
-- power-ups
-- Rolling low forces the other side into a tiny range, so "luck" for you is
-- keeping the lower roll and "luck" for them is keeping the higher one.
---------------------------------------------------------------------
local POWERS = {
    { id = "dice",   name = "Weighted Dice",  base = 200,  max = 10,
      desc = "+8% chance to keep your lower roll, per rank",
      apply = function(c, r) if r > 0 then c.playerLuck = c.playerLuck + 0.08 * r end end },
    { id = "sand",   name = "Pocket Sand",    base = 250,  max = 8,
      desc = "Their luck -8% per rank: fewer low rolls for them",
      apply = function(c, r) if r > 0 then c.enemyLuck = c.enemyLuck - 0.08 * r end end },
    { id = "marks",  name = "Marked Cards",   base = 300,  max = 10,
      desc = "+12% payout per rank",
      apply = function(c, r) if r > 0 then c.mult = c.mult + 0.12 * r end end },
    { id = "hands",  name = "Fast Hands",     base = 150,  max = 2,
      desc = "Roll ticker far faster",
      apply = function(c, r) c.speed = ROLL_SPEED / (1 + 0.6 * r) end },
    { id = "trick",  name = "Cheap Trick",    base = 800,  max = 1,
      desc = "The enemy opens every match",
      apply = function(c, r) if r > 0 then c.theyOpen = true end end },
    { id = "cut",    name = "Banker's Cut",   base = 900,  max = 3,
      desc = "Lose only 60/45/35% of the wager",
      apply = function(c, r) if r > 0 then c.lossFrac = ({ 0.60, 0.45, 0.35 })[r] or 0.35 end end },
    { id = "blood",  name = "Blood Pact",     base = 1200, max = 3,
      desc = "+1 Insurance charge per match",
      apply = function(c, r) c.insurance = c.insurance + r end },
    { id = "runner", name = "The Runner",     base = 2500, max = 1,
      desc = "Auto-plays matches, and earns offline" },
}

local PRESTIGE = {
    { id = "money",     name = "Old Money",      per = "+250 starting bankroll", cost = 2 },
    { id = "bloodline", name = "Bloodline",      per = "+2% base Luck",          cost = 3 },
    { id = "inside",    name = "Inside Man",     per = "-5% power-up cost",      cost = 4 },
    { id = "inherit",   name = "Inherited Dice", per = "keep one power-up",      cost = 10, single = true },
}

---------------------------------------------------------------------
-- saved variables
---------------------------------------------------------------------
local DB

local DEFAULTS = {
    gold = 500, peak = 500, runs = 0, crowns = 0, bestRung = 1,
    wins = 0, losses = 0, debt = 0, loanUsed = false, lastSeen = 0,
    ended = false, lastCrowns = 0, stake = 0, forfeits = 0,
    seenWelcome = false, minimapAngle = 220, streak = 0,
}

local function InitDB()
    if type(DeathrollBaronDB) ~= "table" then DeathrollBaronDB = {} end
    DB = DeathrollBaronDB
    for k, v in pairs(DEFAULTS) do
        if DB[k] == nil then DB[k] = v end
    end
    if type(DB.powers) ~= "table" then DB.powers = {} end
    if type(DB.prestige) ~= "table" then DB.prestige = {} end
    if type(DB.rolled) ~= "table" then DB.rolled = {} end

    -- migrate anything a previous version could have written
    DB.bestRung = min(#NPCS, max(1, floor(tonumber(DB.bestRung) or 1)))
    DB.gold = max(0, floor(tonumber(DB.gold) or 0))
    DB.peak = max(DB.gold, floor(tonumber(DB.peak) or 0))
    DB.crowns = max(0, floor(tonumber(DB.crowns) or 0))
    DB.stake = max(0, floor(tonumber(DB.stake) or 0))
    DB.streak = max(0, floor(tonumber(DB.streak) or 0))
    DB.minimapAngle = tonumber(DB.minimapAngle) or 220
    DB.schema = SCHEMA
end

---------------------------------------------------------------------
-- run seeding
---------------------------------------------------------------------
local function AffixCount(rung)
    if rung >= 24 then return 4 end
    if rung >= 18 then return 3 end
    if rung >= 12 then return 2 end
    if rung >= 6 then return 1 end
    return 0
end

local function AffixTier(rung)
    if rung >= 20 then return 3 end
    if rung >= 13 then return 2 end
    return 1
end

local function StartRun()
    DB.rolled = {}
    local used = {}
    for rung = 1, #NPCS do
        local count, maxTier = AffixCount(rung), AffixTier(rung)
        local pool = {}
        for _, a in ipairs(AFFIXES) do
            if a.tier <= maxTier and not used[a.id] then pool[#pool + 1] = a end
        end
        if #pool < count then
            pool = {}
            for _, a in ipairs(AFFIXES) do
                if a.tier <= maxTier then pool[#pool + 1] = a end
            end
        end
        local picked = {}
        for i = 1, count do
            if #pool == 0 then break end
            local a = table.remove(pool, random(#pool))
            used[a.id] = true
            picked[#picked + 1] = a.id
        end
        DB.rolled[rung] = picked
    end
    DB.rolledN = #NPCS
end

---------------------------------------------------------------------
-- match configuration
---------------------------------------------------------------------
local function BuildConfig(rung)
    local n = NPCS[rung]
    local c = {
        rung = rung, name = n[1], zone = n[2], level = n[3],
        ceiling = n[4], purse = n[5], minWager = n[6],
        playerLuck = 0, enemyLuck = 0, mult = 1.0, lossMult = 1.0,
        lossFrac = 1.0, winTax = 0, theyOpen = false, insurance = 0,
        insuranceBlocked = false, doubleOrNothing = false,
        desperate = false, forcePlayerOpen = false, speed = ROLL_SPEED,
        affixes = {},
    }

    -- the house is kind at rung 1 and the kindness runs out by the low 20s
    c.playerLuck = max(0, EDGE_BASE - EDGE_STEP * (rung - 1))
    c.playerLuck = c.playerLuck + 0.02 * (DB.prestige.bloodline or 0)

    for _, p in ipairs(POWERS) do
        local r = DB.powers[p.id] or 0
        if p.apply and r > 0 then p.apply(c, r) end
    end

    for _, id in ipairs(DB.rolled[rung] or {}) do
        local a = AFFIX_BY_ID[id]
        if a then
            a.apply(c)
            c.affixes[#c.affixes + 1] = a
        end
    end

    if c.forcePlayerOpen then c.theyOpen = false end
    if c.doubleOrNothing then
        c.mult = c.mult * 2
        c.lossMult = c.lossMult * 2
    end

    -- negative luck is meaningful: it means you get the *bad* of two rolls
    c.playerLuck = min(0.95, max(-0.95, c.playerLuck))
    c.enemyLuck = min(0.95, max(-0.95, c.enemyLuck))
    c.purse = max(c.minWager, floor(c.purse))
    return c
end

local function PowerCost(p)
    local r = DB.powers[p.id] or 0
    local cost = p.base * (1.75 ^ r)
    cost = cost * (1 - 0.05 * (DB.prestige.inside or 0))
    return max(5, floor(floor(cost / 5 + 0.5) * 5))
end

local function BuyPower(id)
    local p
    for _, q in ipairs(POWERS) do
        if q.id == id then p = q end
    end
    if not p then return false end
    local r = DB.powers[id] or 0
    if r >= p.max then return false end
    local cost = PowerCost(p)
    if DB.gold < cost then return false end
    DB.gold = DB.gold - cost
    DB.powers[id] = r + 1
    return true
end

local function PrestigeCost(entry)
    local r = DB.prestige[entry.id] or 0
    return entry.cost * (r + 1)
end

local function BuyPrestige(id)
    local entry
    for _, e in ipairs(PRESTIGE) do
        if e.id == id then entry = e end
    end
    if not entry then return false end
    local r = DB.prestige[id] or 0
    if entry.single and r >= 1 then return false end
    local cost = PrestigeCost(entry)
    if DB.crowns < cost then return false end
    DB.crowns = DB.crowns - cost
    DB.prestige[id] = r + 1
    return true
end

---------------------------------------------------------------------
-- match engine
-- runnerAccum / runnerClock live up here on purpose: StartNewRun resets
-- them, and Lua resolves upvalues at compile time, so a local declared
-- below StartNewRun would be invisible to it and the assignment would
-- silently create a global instead.
---------------------------------------------------------------------
local state
local stateToken = 0
local runnerAccum, runnerClock = 0, 0
local GameOver, StartNewRun, BustCheck
local Flash, Pop

local function LogLine(s, kind, text)
    s.log[#s.log + 1] = { kind = kind, text = text }
    while #s.log > 6 do table.remove(s.log, 1) end
end

-- wantLow: the roller wants a small number. bias > 0 helps that wish,
-- bias < 0 works against it. So the player passes true and the NPC false.
local function DrawRoll(mx, bias, wantLow)
    if mx < 1 then mx = 1 end
    local a = random(1, mx)
    if not bias or bias == 0 then return a end
    local p, low = bias, wantLow
    if p < 0 then p = -p; low = not low end
    if random() < p then
        local b = random(1, mx)
        if low then a = min(a, b) else a = max(a, b) end
    end
    return a
end

-- The stake left the wallet in StartMatch, so settlement works from the
-- escrow: a win adds the pot, a loss returns whatever fraction of the stake
-- you keep. Net is what the player actually gained or lost.
local function FinishMatch(result)
    local s = state
    if not s or s.finished then return end
    s.finished = true
    s.result = result
    local c = s.cfg
    DB.stake = 0

    if result == "win" then
        local gross = floor(s.wager * c.mult)
        local payout = max(0, min(gross - floor(gross * c.winTax), c.purse))
        DB.gold = DB.gold + payout
        DB.wins = DB.wins + 1
        DB.streak = (DB.streak or 0) + 1
        s.payout = payout
        s.net = payout - s.wager
        LogLine(s, "win", "You take " .. Money(payout) .. " (net " .. Signed(s.net) .. ").")
        if DB.debt > 0 then
            local pay = min(DB.debt, DB.gold)
            DB.gold = DB.gold - pay
            DB.debt = DB.debt - pay
            LogLine(s, "bank", "The shark takes " .. Money(pay) .. ".")
        end
        if c.rung >= DB.bestRung and c.rung < #NPCS then
            DB.bestRung = c.rung + 1
            LogLine(s, "bank", "Rung unlocked: " .. NPCS[DB.bestRung][1] .. ".")
        end
        Flash(GREEN[1], GREEN[2], GREEN[3])
    else
        local loss = floor(s.wager * c.lossMult * c.lossFrac)
        DB.gold = DB.gold + (s.wager - loss)
        DB.losses = DB.losses + 1
        DB.streak = 0
        s.loss = loss
        s.net = -loss
        LogLine(s, "lose", "You pay " .. Money(loss) .. ".")
        Flash(BLOOD[1], BLOOD[2], BLOOD[3])
    end

    if DB.gold < 0 then DB.gold = 0 end
    DB.peak = max(DB.peak, DB.gold)
    BustCheck()
end

local function StepMatch()
    local s = state
    if not s or s.finished then return end
    local c = s.cfg
    local isPlayer = (s.turn == "player")
    local bias = isPlayer and c.playerLuck or c.enemyLuck
    if c.desperate and not isPlayer and s.max <= DESPERATE_FROM then bias = bias + DESPERATE_LUCK end

    -- you want the low roll, they want the high one. That is the whole game.
    local roll = DrawRoll(s.max, bias, isPlayer)

    if roll == 1 and isPlayer and s.insurance > 0 and not c.insuranceBlocked then
        s.insurance = s.insurance - 1
        LogLine(s, "bank", "Blood Pact burns a charge. Roll again.")
        return
    end

    -- the board keeps both sides on screen, so each roll says whose it was
    if isPlayer then s.lastPlayer = roll else s.lastEnemy = roll end
    LogLine(s, isPlayer and "you" or "them", (isPlayer and "you " or "them ") .. roll)
    Pop(isPlayer)

    s.max = roll
    if roll == 1 then
        FinishMatch(isPlayer and "lose" or "win")
        return
    end
    s.turn = isPlayer and "enemy" or "player"
end

-- manual: the ticker is not started; the player advances each roll by clicking
local function StartMatch(rung, wager, manual)
    if DB.ended then return false end
    local c = BuildConfig(rung)
    wager = max(c.minWager, floor(wager or c.minWager))
    if wager > DB.gold then return false end

    -- the stake leaves the wallet here, not at settlement. That is the whole
    -- point: reloading out of a bad opening roll now forfeits the stake
    -- instead of walking away from the match for free.
    DB.gold = DB.gold - wager
    DB.stake = wager

    state = {
        cfg = c, wager = wager, max = c.ceiling,
        turn = c.theyOpen and "enemy" or "player",
        insurance = c.insurance, log = {}, finished = false,
        manual = manual and true or false,
        lastPlayer = nil, lastEnemy = nil,
    }
    stateToken = stateToken + 1
    local token = stateToken
    LogLine(state, "bank", c.name .. " sits down. " .. Money(wager) .. " on the table.")

    if state.manual then return true end

    local function tick()
        if token ~= stateToken then return end
        local s = state
        if not s or s.finished or s.manual then return end
        StepMatch()
        if not s.finished and not s.manual then
            C_Timer.After(s.cfg.speed, tick)
        end
        ns.Refresh()
    end

    C_Timer.After(0.08, tick)
    return true
end

local function SimulateMatch(rung, wager)
    local c = BuildConfig(rung)
    local mx = c.ceiling
    local turn = c.theyOpen and "enemy" or "player"
    local guard = 0
    while guard < 500 do
        guard = guard + 1
        local isPlayer = (turn == "player")
        local bias = isPlayer and c.playerLuck or c.enemyLuck
        if c.desperate and not isPlayer and mx <= 20 then bias = bias + 0.30 end
        local roll = DrawRoll(mx, bias, isPlayer)
        mx = roll
        if roll == 1 then
            if isPlayer then
                return "lose", floor(wager * c.lossMult * c.lossFrac)
            end
            local gross = floor(wager * c.mult)
            return "win", max(0, min(gross - floor(gross * c.winTax), c.purse))
        end
        turn = isPlayer and "enemy" or "player"
    end
    return "win", 0
end

---------------------------------------------------------------------
-- exact win odds
-- A[m]: you to move at range m.  B[m]: them to move at range m.
-- Rows only depend on smaller ranges, so one table grown to the largest
-- ceiling in use answers every question after it.
---------------------------------------------------------------------
local oddsCache = {}

local function OddsUpTo(m, pLuck, eLuck, desperate)
    m = max(1, floor(m))
    local key = floor(pLuck * 1000) .. ":" .. floor(eLuck * 1000) .. ":" .. (desperate and 1 or 0)
    local entry = oddsCache[key]
    if not entry then
        entry = { A = { [1] = 0 }, B = { [1] = 1 }, n = 1 }
        oddsCache[key] = entry
    end

    local A, B = entry.A, entry.B
    local qp = min(1, math.abs(pLuck))
    local pWantLow = pLuck >= 0
    for r = entry.n + 1, m do
        -- Desperate only bites under 20, which is exactly where it matters,
        -- so each row carries its own enemy bias.
        local eb = eLuck
        if desperate and r <= DESPERATE_FROM then eb = eb + DESPERATE_LUCK end
        local qe = min(1, math.abs(eb))
        local eWantLow = eb < 0
        local inv = 1 / r
        local inv2 = inv * inv
        local a, b = 0, 0
        for x = 1, r do
            local pmin = (2 * (r - x) + 1) * inv2
            local pmax = (2 * x - 1) * inv2
            local pp = (1 - qp) * inv + qp * (pWantLow and pmin or pmax)
            local pe = (1 - qe) * inv + qe * (eWantLow and pmin or pmax)
            if x == 1 then
                b = b + pe            -- they rolled 1: you win
            else
                a = a + pp * B[x]     -- your roll x, then them to move
                b = b + pe * A[x]     -- their roll x, then you to move
            end
        end
        A[r], B[r] = a, b
    end

    if m > entry.n then entry.n = m end
    return A, B
end

-- the chance you take the hand from here, read off the table for the ceiling
local function WinChance(cfg, live)
    local A, B = OddsUpTo(cfg.ceiling, cfg.playerLuck, cfg.enemyLuck, cfg.desperate and true or false)
    local m = live and min(state.max, cfg.ceiling) or cfg.ceiling
    local youMove = live and (state.turn == "player") or (not live and not cfg.theyOpen)
    return youMove and A[m] or B[m]
end

-- exactly one bust per run: there is no path that awards crowns twice for the
-- same peak, and no path that awards them while the run is already over.
GameOver = function()
    if DB.ended then return end
    DB.ended = true
    state = nil
    DB.stake = 0
    DB.streak = 0
    -- sqrt over a much smaller divisor, and never less than one: a bad run
    -- still has to buy you something or the loop never starts.
    local earned = max(1, floor(math.sqrt(max(0, DB.peak) / 250)))
    DB.crowns = DB.crowns + earned
    DB.lastCrowns = earned
    DB.runs = DB.runs + 1
    if ns.ShowPrestige then ns.ShowPrestige(earned) end
end

-- if you cannot cover the cheapest wager and the shark has already been taken,
-- the run is over. Without this the window becomes a dead end.
BustCheck = function()
    if DB.ended then return end
    if state and not state.finished then return end
    if DB.gold >= NPCS[1][6] then return end
    if not DB.loanUsed then return end
    GameOver()
end

StartNewRun = function()
    local keepId, keepRank
    if (DB.prestige.inherit or 0) > 0 then
        for _, p in ipairs(POWERS) do
            local r = DB.powers[p.id] or 0
            if r > 0 and (not keepRank or r > keepRank) then
                keepId, keepRank = p.id, r
            end
        end
    end
    DB.powers = {}
    if keepId then DB.powers[keepId] = keepRank end
    DB.gold = 500 + 250 * (DB.prestige.money or 0)
    DB.peak = DB.gold
    DB.bestRung = 1
    DB.wins, DB.losses = 0, 0
    DB.debt, DB.loanUsed = 0, false
    DB.ended, DB.lastCrowns = false, 0
    DB.stake = 0
    DB.streak = 0
    state = nil
    stateToken = stateToken + 1
    -- a new run starts the Runner's clock from zero
    runnerAccum, runnerClock = 0, 0
    StartRun()
    ns.selectedRung = 1
    ns.wager = NPCS[1][6]
end

local function Borrow()
    if DB.loanUsed or DB.ended then return false end
    DB.loanUsed = true
    DB.debt = DB.debt + 450
    DB.gold = DB.gold + 300
    return true
end

---------------------------------------------------------------------
-- the runner: idle and offline income
---------------------------------------------------------------------
local function RunnerStep()
    if (DB.powers.runner or 0) < 1 then return end
    if DB.ended then return end
    if state and not state.finished then return end
    local rung = min(DB.bestRung, #NPCS)
    local wager = NPCS[rung][6]
    if DB.gold < wager then return end
    local res, amount = SimulateMatch(rung, wager)
    if res == "win" then
        DB.gold = DB.gold + amount
        DB.wins = DB.wins + 1
    else
        DB.gold = DB.gold - amount
        DB.losses = DB.losses + 1
    end
    if DB.gold < 0 then DB.gold = 0 end
    DB.peak = max(DB.peak, DB.gold)
    BustCheck()
end

local function ApplyOffline()
    if (DB.powers.runner or 0) < 1 then return 0 end
    local elapsed = time() - (DB.lastSeen or 0)
    if elapsed < 60 then return 0 end
    elapsed = min(elapsed, 8 * 3600)
    local matches = floor(elapsed / RUNNER_EVERY)
    if matches < 1 then return 0 end
    local rung = min(DB.bestRung, #NPCS)
    local wager = NPCS[rung][6]
    if DB.gold < wager then return 0 end
    local sample = min(matches, 60)
    local net = 0
    for _ = 1, sample do
        local res, amount = SimulateMatch(rung, wager)
        if res == "win" then net = net + amount else net = net - amount end
    end
    net = floor(net * (matches / sample) * 0.60)
    DB.gold = max(0, DB.gold + net)
    DB.peak = max(DB.peak, DB.gold)
    return net
end

---------------------------------------------------------------------
-- ui
-- Every function the anchors below call is forward-declared here first.
-- Lua binds upvalues when the chunk compiles, so a name used above its own
-- `local function` line would quietly become a global lookup.
---------------------------------------------------------------------
local frame, prestigeFrame, welcomeFrame, minimapBtn
local W = { affix = {}, log = {}, shop = {}, prestige = {} }
local AdjustWager, SelectRung, DoRoll, StartNewRunUI
local Toggle, ShowWelcome, CreateMinimap

ns.selectedRung = 1
ns.wager = 50

-- one safe virtual font, every size set explicitly: no dependency on
-- GameFontNormalHuge / Large / Small existing on this client.
local function FS(parent, color, size)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    local path, _, flags = fs:GetFont()
    if path and size then fs:SetFont(path, size, flags) end
    if color then fs:SetTextColor(color[1], color[2], color[3]) end
    return fs
end

local function Btn(parent, text, w, h, size, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, h)
    b:SetText(text)
    local fs = b:GetFontString()
    if fs and size then
        local path, _, flags = fs:GetFont()
        if path then fs:SetFont(path, size, flags) end
    end
    b:SetScript("OnClick", onClick)
    return b
end

local function Panel(parent, w, h, borderColor)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(w, h)
    f:EnableMouse(true)
    local edge = f:CreateTexture(nil, "BACKGROUND", nil, -8)
    edge:SetAllPoints()
    edge:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], 0.85)
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", 2, -2)
    bg:SetPoint("BOTTOMRIGHT", -2, 2)
    bg:SetColorTexture(0.07, 0.06, 0.05, 0.97)
    f.edge = edge
    return f
end

-- the tour copy: five lines, each sized to sit in one slot at 11pt
local TOUR = {
    "A deathroll opens at 1-100. You trade rolls inside a shrinking range, and whoever rolls a 1 pays the pot.",
    "You want the LOW roll: a small number leaves them almost nothing to roll in. High rolls are how you lose.",
    "Set the stake, then press ROLL. The stake leaves your purse the moment the hand starts.",
    "Shift-click ROLL to step one roll at a time. The odds bar under the board is your real chance.",
    "Between hands, buy power-ups. Go broke and the table takes you: Bone Crowns buy permanent upgrades.",
}

-- animation state for the roll board
local flashT, pulsing = 0, false
local popT, popTarget = 0, nil

local function BoardAlpha(a)
    if W.youFlash then W.youFlash:SetAlpha(a) end
    if W.themFlash then W.themFlash:SetAlpha(a) end
end

local function BoardColor(r, g, b)
    if W.youFlash then W.youFlash:SetColorTexture(r, g, b, 1) end
    if W.themFlash then W.themFlash:SetColorTexture(r, g, b, 1) end
end

-- a winning hand paints the board green, a losing one red, then it fades
Flash = function(r, g, b)
    if not W.youFlash then return end
    pulsing = false
    flashT = FLASH_TIME
    BoardColor(r, g, b)
    BoardAlpha(0.40)
end

-- each roll punches its own number so you can see which side just moved
Pop = function(forPlayer)
    local fs = forPlayer and W.youNum or W.themNum
    if not fs then return end
    popTarget = fs
    popT = POP_TIME
    fs:SetAlpha(0.15)
end

local function Build()
    frame = CreateFrame("Frame", "DeathrollBaronFrame", UIParent)
    frame:SetSize(400, 630)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    local edge = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    edge:SetAllPoints()
    edge:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.55)
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", 2, -2)
    bg:SetPoint("BOTTOMRIGHT", -2, 2)
    bg:SetColorTexture(0.07, 0.06, 0.05, 0.97)

    W.title = FS(frame, GOLD, 14)
    W.title:SetPoint("TOP", 0, -12)
    W.title:SetText("DEATHROLL BARON")

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -3, -3)

    -- reopens the tour; the splash itself only auto-shows once
    W.help = Btn(frame, "?", 18, 18, 11, function() ShowWelcome() end)
    W.help:SetPoint("TOPRIGHT", -38, -8)

    W.gold = FS(frame, GOLD, 22)
    W.gold:SetPoint("TOPLEFT", 16, -38)

    W.sub = FS(frame, DIM, 11)
    W.sub:SetPoint("TOPLEFT", 16, -64)

    W.npc = FS(frame, BONE, 15)
    W.npc:SetPoint("TOPLEFT", 16, -92)
    W.npcInfo = FS(frame, DIM, 11)
    W.npcInfo:SetPoint("TOPLEFT", 16, -112)

    -- 13pt apart, not 15: the four-affix rungs need to clear the roll board
    for i = 1, 4 do
        local fs = FS(frame, DIM, 11)
        fs:SetPoint("TOPLEFT", 16, -128 - (i - 1) * 13)
        fs:SetText("")
        W.affix[i] = fs
    end

    -- the board: two panels, your roll and theirs, never one shared number
    W.youPanel = Panel(frame, 184, 64, GOLD)
    W.youPanel:SetPoint("TOPLEFT", 8, -184)
    W.youEdge = W.youPanel.edge

    W.youFlash = W.youPanel:CreateTexture(nil, "BACKGROUND", nil, 1)
    W.youFlash:SetAllPoints()
    W.youFlash:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
    W.youFlash:SetAlpha(0)

    W.youLabel = FS(W.youPanel, DIM, 10)
    W.youLabel:SetPoint("TOP", 0, -4)
    W.youLabel:SetText("YOUR ROLL")

    W.youNum = FS(W.youPanel, GOLD, 32)
    W.youNum:SetPoint("TOP", 0, -17)
    W.youNum:SetText("--")

    W.themPanel = Panel(frame, 184, 64, RED)
    W.themPanel:SetPoint("TOPRIGHT", -8, -184)
    W.themEdge = W.themPanel.edge

    W.themFlash = W.themPanel:CreateTexture(nil, "BACKGROUND", nil, 1)
    W.themFlash:SetAllPoints()
    W.themFlash:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
    W.themFlash:SetAlpha(0)

    W.themLabel = FS(W.themPanel, DIM, 10)
    W.themLabel:SetPoint("TOP", 0, -4)
    W.themLabel:SetText("THEIR ROLL")

    W.themNum = FS(W.themPanel, RED, 32)
    W.themNum:SetPoint("TOP", 0, -17)
    W.themNum:SetText("--")

    W.range = FS(frame, DIM, 11)
    W.range:SetPoint("TOP", 0, -252)
    W.luck = FS(frame, GOLD, 11)
    W.luck:SetPoint("TOP", 0, -268)

    for i = 1, 6 do
        local fs = FS(frame, BONE, 11)
        fs:SetPoint("TOPLEFT", 20, -288 - (i - 1) * 14)
        fs:SetText("")
        W.log[i] = fs
    end

    W.prev = Btn(frame, "<", 24, 18, 10, function() SelectRung(-1) end)
    W.prev:SetPoint("TOPRIGHT", -60, -90)
    W.next = Btn(frame, ">", 24, 18, 10, function() SelectRung(1) end)
    W.next:SetPoint("TOPRIGHT", -30, -90)

    W.minus = Btn(frame, "-", 28, 22, 12, function() AdjustWager(-1) end)
    W.minus:SetPoint("TOPLEFT", 16, -368)
    W.plus = Btn(frame, "+", 28, 22, 12, function() AdjustWager(1) end)
    W.plus:SetPoint("TOPRIGHT", -16, -368)

    W.wager = FS(frame, BONE, 13)
    W.wager:SetPoint("TOP", 0, -372)

    -- 108 wide and MIN nudged right: at 130 the two boxes overlapped by 16px
    W.loan = Btn(frame, "Take the loan", 108, 20, 10, function()
        if Borrow() then ns.Refresh() end
    end)
    W.loan:SetPoint("TOPLEFT", 16, -396)
    W.loan:Hide()

    W.min = Btn(frame, "MIN", 70, 20, 10, function()
        ns.wager = BuildConfig(ns.selectedRung).minWager
        ns.Refresh()
    end)
    W.min:SetPoint("TOPRIGHT", -190, -396)

    W.half = Btn(frame, "HALF", 70, 20, 10, function()
        local cfg = BuildConfig(ns.selectedRung)
        ns.wager = max(cfg.minWager, floor(DB.gold / 2))
        ns.Refresh()
    end)
    W.half:SetPoint("TOPRIGHT", -116, -396)

    W.allin = Btn(frame, "ALL IN", 70, 20, 10, function()
        local cfg = BuildConfig(ns.selectedRung)
        ns.wager = max(cfg.minWager, DB.gold)
        ns.Refresh()
    end)
    W.allin:SetPoint("TOPRIGHT", -42, -396)

    W.roll = Btn(frame, "ROLL", 368, 40, 16, function()
        -- a plain click on a live auto hand stops the next deal, not this one
        if ns.auto and not IsShiftKeyDown() and state and not state.finished then
            ns.auto = false
            ns.Refresh()
            return
        end
        DoRoll()
    end)
    W.roll:SetPoint("TOP", 0, -424)
    W.roll:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("ROLL", GOLD[1], GOLD[2], GOLD[3])
        GameTooltip:AddLine("Left click puts up the stake.", 1, 1, 1)
        GameTooltip:AddLine("Shift-click rolls one number at a time.", 1, 1, 1)
        GameTooltip:Show()
    end)
    W.roll:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- auto-spin is a control you can see: a pill on the right of the bar
    W.autoBtn = CreateFrame("Button", nil, W.roll)
    W.autoBtn:SetSize(72, 22)
    W.autoBtn:SetPoint("RIGHT", -6, 0)
    W.autoBtn.edge = W.autoBtn:CreateTexture(nil, "BACKGROUND")
    W.autoBtn.edge:SetAllPoints()
    W.autoBtn.edge:SetColorTexture(DIM[1], DIM[2], DIM[3], 0.55)
    W.autoBtn.bg = W.autoBtn:CreateTexture(nil, "BACKGROUND", nil, 1)
    W.autoBtn.bg:SetPoint("TOPLEFT", 1, -1)
    W.autoBtn.bg:SetPoint("BOTTOMRIGHT", -1, 1)
    W.autoBtn.bg:SetColorTexture(0.10, 0.09, 0.07, 0.95)
    W.autoBtn.label = FS(W.autoBtn, BONE, 10)
    W.autoBtn.label:SetPoint("CENTER")
    W.autoBtn.label:SetText("AUTO OFF")
    W.autoBtn:SetScript("OnClick", function()
        ns.auto = not ns.auto
        ns.autoT = 0
        ns.Refresh()
    end)
    W.autoBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Auto-spin", GOLD[1], GOLD[2], GOLD[3])
        GameTooltip:AddLine("On: every hand that ends deals the same stake again, until you stop it or go broke.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    W.autoBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- under the button, in its own band: above it would clip the quick buttons
    W.hint = FS(frame, DIM, 10)
    W.hint:SetPoint("TOP", W.roll, "BOTTOM", 0, -2)
    W.hint:SetText("")

    for i, p in ipairs(POWERS) do
        local col = (i - 1) % 2
        local row = floor((i - 1) / 2)
        local b = Btn(frame, p.name, 178, 24, 10, function(self)
            BuyPower(self.powerId)
            BustCheck()
            ns.Refresh()
        end)
        b:SetPoint("TOPLEFT", 14 + col * 192, -484 - row * 28)
        b.powerId = p.id
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(p.name, GOLD[1], GOLD[2], GOLD[3])
            GameTooltip:AddLine(p.desc, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        W.shop[i] = b
    end

    -- one animation driver: board pulse, result flash, per-roll pop
    frame:SetScript("OnUpdate", function(_, elapsed)
        local liveNow = state and not state.finished

        if flashT > 0 then
            flashT = max(0, flashT - elapsed)
            BoardAlpha((flashT / FLASH_TIME) * 0.40)
        elseif liveNow then
            if not pulsing then
                pulsing = true
                BoardColor(GOLD[1], GOLD[2], GOLD[3])
            end
            BoardAlpha(0.05 + 0.05 * (0.5 + 0.5 * math.sin(GetTime() * 2.6)))
        elseif pulsing then
            pulsing = false
            BoardAlpha(0)
        end

        if popT > 0 then
            popT = max(0, popT - elapsed)
            if popTarget then
                popTarget:SetAlpha(1 - (popT / POP_TIME) * 0.85)
                if popT == 0 then popTarget = nil end
            end
        end
    end)

    frame:Hide()

    -- prestige overlay: crowns are spendable, in place
    prestigeFrame = Panel(UIParent, 360, 300, BLOOD)
    prestigeFrame:SetPoint("CENTER")
    prestigeFrame:SetFrameStrata("DIALOG")

    local ptitle = FS(prestigeFrame, BLOOD, 16)
    ptitle:SetPoint("TOP", 0, -18)
    ptitle:SetText("THE TABLE TAKES YOU")

    W.pCrowns = FS(prestigeFrame, GOLD, 14)
    W.pCrowns:SetPoint("TOP", 0, -44)
    W.pCrowns:SetText("")

    for i, e in ipairs(PRESTIGE) do
        local b = Btn(prestigeFrame, e.name, 300, 22, 11, function(self)
            if BuyPrestige(self.prestigeId) then ns.ShowPrestige(DB.lastCrowns) end
        end)
        b:SetPoint("TOPLEFT", 20, -72 - (i - 1) * 26)
        b.prestigeId = e.id
        W.prestige[i] = b
    end

    W.pAgain = Btn(prestigeFrame, "Sit down again", 200, 26, 12, function()
        StartNewRunUI()
    end)
    W.pAgain:SetPoint("BOTTOM", 0, 18)

    prestigeFrame:Hide()

    -- the tour: shown once, then reachable from the ? button and /drb help
    welcomeFrame = Panel(UIParent, 380, 340, GOLD)
    welcomeFrame:SetPoint("CENTER")
    welcomeFrame:SetFrameStrata("DIALOG")

    local wtitle = FS(welcomeFrame, GOLD, 16)
    wtitle:SetPoint("TOP", 0, -14)
    wtitle:SetText("DEATHROLL BARON")

    local wsub = FS(welcomeFrame, DIM, 11)
    wsub:SetPoint("TOP", 0, -34)
    wsub:SetText("the whole game, in five lines")

    for i, text in ipairs(TOUR) do
        local fs = FS(welcomeFrame, BONE, 11)
        fs:SetPoint("TOPLEFT", 22, -54 - (i - 1) * 40)
        fs:SetWidth(336)
        fs:SetJustifyH("LEFT")
        fs:SetText(text)
    end

    W.wGo = Btn(welcomeFrame, "Sit down", 180, 28, 12, function()
        DB.seenWelcome = true
        welcomeFrame:Hide()
    end)
    W.wGo:SetPoint("BOTTOM", 0, 16)

    local wclose = CreateFrame("Button", nil, welcomeFrame, "UIPanelCloseButton")
    wclose:SetPoint("TOPRIGHT", -3, -3)
    wclose:SetScript("OnClick", function()
        DB.seenWelcome = true
        welcomeFrame:Hide()
    end)

    welcomeFrame:Hide()
end

ShowWelcome = function()
    if not welcomeFrame then return end
    welcomeFrame:Show()
end

-- minimap button, hand-rolled: 32pt icon, drag it around the ring, angle saved
local function PlaceMinimapButton()
    if not minimapBtn then return end
    local angle = math.rad(DB.minimapAngle or 220)
    local radius = (Minimap:GetWidth() or 140) / 2 + 5
    minimapBtn:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

CreateMinimap = function()
    if minimapBtn or not Minimap then return end

    local b = CreateFrame("Button", "DeathrollBaronMinimapButton", Minimap)
    b:SetSize(32, 32)
    b:SetFrameStrata("MEDIUM")
    b:SetClampedToScreen(true)
    b:RegisterForDrag("LeftButton")

    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetSize(53, 53)
    bg:SetPoint("CENTER")

    local icon = b:CreateTexture(nil, "BACKGROUND", nil, 1)
    icon:SetTexture(ICON)
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")

    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT")

    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")

    b:SetScript("OnClick", function() Toggle() end)

    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Deathroll Baron", GOLD[1], GOLD[2], GOLD[3])
        GameTooltip:AddLine("Click to open the table.", 1, 1, 1)
        GameTooltip:AddLine("Drag around the minimap to move it.", DIM[1], DIM[2], DIM[3])
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- rotate around the ring while dragged, and remember the angle
    b:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            if not mx then return end
            local scale = Minimap:GetEffectiveScale()
            local cx, cy = GetCursorPosition()
            cx, cy = cx / scale, cy / scale
            DB.minimapAngle = math.deg(math.atan2(cy - my, cx - mx))
            PlaceMinimapButton()
        end)
    end)
    b:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)

    minimapBtn = b
    PlaceMinimapButton()
end

-- the croupier: one line of tension, chosen by how tight the range has become
local function Tension(mx)
    if mx <= 4 then return "  .  no room left" end
    if mx <= 12 then return "  .  the table goes quiet" end
    if mx <= 25 then return "  .  every number matters" end
    if mx >= 60 then return "  .  plenty of room" end
    return ""
end

function ns.Refresh()
    if not frame or not DB then return end

    if not ns.selectedRung then ns.selectedRung = DB.bestRung end
    ns.selectedRung = min(DB.bestRung, max(1, ns.selectedRung))

    local cfg = BuildConfig(ns.selectedRung)
    local live = state and not state.finished

    -- while a match is live the stake is already off the wallet, so the bet on
    -- the table is state.wager and must not be re-clamped to the lower gold
    if live then
        ns.wager = state.wager
    else
        if not ns.wager or ns.wager < cfg.minWager then ns.wager = cfg.minWager end
        if ns.wager > DB.gold then ns.wager = max(cfg.minWager, DB.gold) end
    end

    W.gold:SetText(Money(DB.gold))
    local crowns = DB.crowns > 0 and ("   " .. DB.crowns .. " crowns") or ""
    local streak = (DB.streak or 0) >= 3 and ("   " .. DB.streak .. " in a row") or ""
    W.sub:SetText(("peak %s%s%s    run %d    %dW/%dL"):format(
        Money(DB.peak), crowns, streak, DB.runs + 1, DB.wins, DB.losses))

    W.npc:SetText(("%d/%d  %s"):format(ns.selectedRung, #NPCS, cfg.name))
    W.npcInfo:SetText(("%s   .   level %s   .   purse %s"):format(
        cfg.zone, cfg.level, Money(cfg.purse)))

    for i = 1, 4 do
        local a = cfg.affixes[i]
        if a then
            W.affix[i]:SetText((a.flaw and "flaw " or "EDGE ") .. a.name .. " - " .. a.text)
            if a.flaw then
                W.affix[i]:SetTextColor(GREEN[1], GREEN[2], GREEN[3])
            else
                W.affix[i]:SetTextColor(RED[1], RED[2], RED[3])
            end
        else
            W.affix[i]:SetText("")
        end
    end
    if ns.selectedRung < 6 and W.affix[1]:GetText() == "" then
        W.affix[1]:SetText("no tricks. base rng.")
        W.affix[1]:SetTextColor(DIM[1], DIM[2], DIM[3])
    end

    -- the board: who rolled what, and whose turn it is right now
    local yours = live and state.turn == "player"
    local theirs = live and state.turn == "enemy"

    if state and state.lastPlayer then
        W.youNum:SetText(tostring(state.lastPlayer))
    else
        W.youNum:SetText(live and "?" or "--")
    end
    if state and state.lastEnemy then
        W.themNum:SetText(tostring(state.lastEnemy))
    else
        W.themNum:SetText(live and "?" or "--")
    end

    W.youLabel:SetText("YOUR ROLL" .. (yours and "   <<" or ""))
    W.themLabel:SetText("THEIR ROLL" .. (theirs and "   <<" or ""))
    W.youEdge:SetAlpha(yours and 0.95 or 0.30)
    W.themEdge:SetAlpha(theirs and 0.95 or 0.30)

    if live then
        local turn = yours and "your turn" or "their turn"
        W.range:SetText(("%s  .  roll 1 - %d%s"):format(turn, state.max, Tension(state.max)))
        if yours then
            W.range:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        else
            W.range:SetTextColor(RED[1], RED[2], RED[3])
        end
    elseif state and state.finished then
        if state.result == "win" then
            W.range:SetText("you take the pot  .  " .. Signed(state.net or 0))
            W.range:SetTextColor(GREEN[1], GREEN[2], GREEN[3])
        else
            W.range:SetText("you pay up  .  " .. Signed(state.net or 0))
            W.range:SetTextColor(0.85, 0.30, 0.26)
        end
    else
        W.range:SetText(("opens at 1 - %d  .  %s to sit down"):format(cfg.ceiling, Money(cfg.minWager)))
        W.range:SetTextColor(DIM[1], DIM[2], DIM[3])
    end

    -- the odds line: the actual chance you take this hand, given both sides'
    -- luck and who is holding the dice right now
    local oddsCfg = live and state.cfg or cfg
    local chance = WinChance(oddsCfg, live)
    local odds = floor(chance * 100 + 0.5)
    W.luck:SetText(("ODDS %d%%   .   luck you %s / them %s   .   payout x%.2f"):format(
        odds, Pct(oddsCfg.playerLuck), Pct(oddsCfg.enemyLuck), oddsCfg.mult))
    if odds >= 55 then
        W.luck:SetTextColor(GREEN[1], GREEN[2], GREEN[3])
    elseif odds <= 45 then
        W.luck:SetTextColor(RED[1], RED[2], RED[3])
    else
        W.luck:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    end

    local entries = {}
    if state then
        for i = max(1, #state.log - 5), #state.log do
            entries[#entries + 1] = state.log[i]
        end
    end
    for i = 1, 6 do
        local e = entries[i]
        if e then
            W.log[i]:SetText(e.text)
            if e.kind == "you" then
                W.log[i]:SetTextColor(GOLD[1] + 0.15, GOLD[2] + 0.15, GOLD[3] + 0.25)
            elseif e.kind == "them" then
                W.log[i]:SetTextColor(RED[1], RED[2], RED[3])
            elseif e.kind == "win" then
                W.log[i]:SetTextColor(GREEN[1], GREEN[2], GREEN[3])
            elseif e.kind == "lose" then
                W.log[i]:SetTextColor(0.85, 0.30, 0.26)
            elseif e.kind == "bank" then
                W.log[i]:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
            else
                W.log[i]:SetTextColor(BONE[1], BONE[2], BONE[3])
            end
        else
            W.log[i]:SetText("")
        end
    end

    W.wager:SetText(Money(ns.wager))
    -- enabled during a match too: a manual match is advanced by clicking it
    W.roll:SetEnabled(true)
    if live and state.manual then
        W.roll:SetText("ROLL ONE   (click)")
        W.hint:SetText("manual: one roll per click, shift or not")
    elseif live then
        W.roll:SetText("ROLLING")
        W.hint:SetText(ns.auto and "click to stop after this hand" or "shift-click to take over")
    else
        W.roll:SetText("ROLL   " .. Money(ns.wager))
        W.hint:SetText(ns.auto and "same stake deals again on its own  .  AUTO to stop"
            or "shift-click: roll one at a time  .  AUTO: keep dealing")
    end
    -- the pill on the bar is the control, so the bar's own text stays plain
    if W.autoBtn then
        W.autoBtn.label:SetText(ns.auto and "AUTO ON" or "AUTO OFF")
        if ns.auto then
            W.autoBtn.label:SetTextColor(GREEN[1], GREEN[2], GREEN[3])
            W.autoBtn.edge:SetColorTexture(GREEN[1], GREEN[2], GREEN[3], 0.90)
            W.autoBtn.bg:SetColorTexture(0.14, 0.20, 0.10, 0.95)
        else
            W.autoBtn.label:SetTextColor(BONE[1], BONE[2], BONE[3])
            W.autoBtn.edge:SetColorTexture(DIM[1], DIM[2], DIM[3], 0.55)
            W.autoBtn.bg:SetColorTexture(0.10, 0.09, 0.07, 0.95)
        end
    end

    -- no loan while a hand is live: the stake is already committed
    W.loan:SetShown(not live and DB.gold < cfg.minWager and not DB.loanUsed and not DB.ended)
    W.prev:SetEnabled(ns.selectedRung > 1)
    W.next:SetEnabled(ns.selectedRung < DB.bestRung)

    for i, p in ipairs(POWERS) do
        local b = W.shop[i]
        if b then
            local r = DB.powers[p.id] or 0
            if r >= p.max then
                b:SetText(p.name .. "  maxed")
                b:SetEnabled(false)
            else
                local cost = PowerCost(p)
                b:SetText(("%s %d/%d   %s"):format(p.name, r, p.max, Money(cost)))
                b:SetEnabled(DB.gold >= cost and not DB.ended)
            end
        end
    end
end

ns.ShowPrestige = function(earned)
    if not prestigeFrame then return end
    W.pCrowns:SetText(("+%d Bone Crowns   (you hold %d)"):format(earned or DB.lastCrowns, DB.crowns))
    for i, e in ipairs(PRESTIGE) do
        local b = W.prestige[i]
        if b then
            local r = DB.prestige[e.id] or 0
            if e.single and r >= 1 then
                b:SetText(("%s  -  owned"):format(e.name))
                b:SetEnabled(false)
            else
                local cost = PrestigeCost(e)
                b:SetText(("%s  rank %d  -  %s  -  %d crowns"):format(e.name, r, e.per, cost))
                b:SetEnabled(DB.crowns >= cost)
            end
        end
    end
    prestigeFrame:Show()
end

SelectRung = function(dir)
    ns.selectedRung = min(DB.bestRung, max(1, (ns.selectedRung or 1) + dir))
    ns.wager = BuildConfig(ns.selectedRung).minWager
    ns.Refresh()
end

AdjustWager = function(dir)
    local cfg = BuildConfig(ns.selectedRung)
    local step = max(10, floor(cfg.minWager / 4))
    ns.wager = max(cfg.minWager, min(max(DB.gold, cfg.minWager), ns.wager + dir * step))
    ns.Refresh()
end

-- One button, three jobs:
--   no match, no shift   -> start a match on the ticker
--   no match, shift      -> start a match in manual mode, and roll once
--   live match, any mode -> any click on a manual match steps; shift takes over an auto one
DoRoll = function()
    if DB.ended then
        if ns.ShowPrestige then ns.ShowPrestige(DB.lastCrowns) end
        return
    end

    if state and not state.finished then
        if state.manual or IsShiftKeyDown() then
            state.manual = true
            StepMatch()
            ns.Refresh()
        end
        return
    end

    local cfg = BuildConfig(ns.selectedRung)
    if DB.gold < cfg.minWager then
        if Borrow() then
            ns.Refresh()
        else
            BustCheck()
        end
        return
    end

    local manual = IsShiftKeyDown() and true or false
    if StartMatch(ns.selectedRung, ns.wager, manual) and manual then
        StepMatch()
    end
    ns.Refresh()
end

StartNewRunUI = function()
    prestigeFrame:Hide()
    StartNewRun()
    ns.Refresh()
    print("|cffc9a227Deathroll Baron|r: a new table, a new set of cheats.")
end

---------------------------------------------------------------------
-- events
---------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGOUT")
ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        InitDB()
        if DB.rolledN ~= #NPCS or next(DB.rolled) == nil then StartRun() end
        ns.selectedRung = DB.bestRung
        ns.wager = NPCS[DB.bestRung][6]
        Build()
        CreateMinimap()
        -- A stake still on the table at login means the client was reloaded or
        -- killed mid-match. The house keeps it and the hand counts as a loss,
        -- so bailing out of a bad opening roll is never free.
        if (DB.stake or 0) > 0 then
            local abandoned = DB.stake
            DB.stake = 0
            DB.losses = DB.losses + 1
            DB.forfeits = (DB.forfeits or 0) + 1
            print(("|cffc9a227Deathroll Baron|r: you left %s on the table. The house keeps it."):format(Money(abandoned)))
            BustCheck()
        end
        local net = ApplyOffline()
        if net ~= 0 then
            print(("|cffc9a227Deathroll Baron|r: the Runner brought back %s."):format(Money(net)))
        end
        ns.Refresh()
        if DB.ended then ns.ShowPrestige(DB.lastCrowns) end
        if not DB.seenWelcome then ShowWelcome() end
    elseif event == "PLAYER_LOGOUT" then
        if DB then
            DB.lastSeen = time()
            DB.schema = SCHEMA
        end
    end
end)

-- one second clock; the runner only acts every RUNNER_EVERY seconds
local clock = CreateFrame("Frame")
clock:SetScript("OnUpdate", function(_, elapsed)
    if not DB then return end
    runnerAccum = runnerAccum + elapsed
    if runnerAccum < 1 then return end
    runnerAccum = 0
    if DB.ended or (DB.powers.runner or 0) < 1 then
        runnerClock = 0
        return
    end
    runnerClock = runnerClock + 1
    if runnerClock >= RUNNER_EVERY then
        runnerClock = 0
        RunnerStep()
        if frame and frame:IsShown() then ns.Refresh() end
    end
end)

---------------------------------------------------------------------
-- entry points
---------------------------------------------------------------------
Toggle = function()
    if not frame then return end
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
        if DB.ended and ns.ShowPrestige then ns.ShowPrestige(DB.lastCrowns) end
        ns.Refresh()
    end
end

function DeathrollBaron_CompartmentClick() Toggle() end
function DeathrollBaron_CompartmentEnter() end
function DeathrollBaron_CompartmentLeave() end

SLASH_DEATHROLLBARON1 = "/drb"
SLASH_DEATHROLLBARON2 = "/baron"
SlashCmdList["DEATHROLLBARON"] = function(msg)
    msg = (msg or ""):lower()
    if msg == "help" then
        ShowWelcome()
        return
    end
    if msg == "odds" then
        local rung = ns.selectedRung or 1
        local cfg = BuildConfig(rung)
        local A, B = OddsUpTo(cfg.ceiling, cfg.playerLuck, cfg.enemyLuck, cfg.desperate and true or false)
        print(("|cffc9a227odds|r rung %d (%s): ceiling %d, %.1f%% as the opener, %.1f%% as the second player"):format(
            rung, cfg.name, cfg.ceiling, A[cfg.ceiling] * 100, B[cfg.ceiling] * 100))
        return
    end
    if msg == "reset" then
        DB.powers = {}
        DB.bestRung = 1
        DB.gold = 500 + 250 * (DB.prestige.money or 0)
        DB.peak = DB.gold
        DB.debt, DB.loanUsed = 0, false
        DB.ended, DB.lastCrowns = false, 0
        DB.wins, DB.losses = 0, 0
        DB.stake, DB.streak = 0, 0
        state = nil
        stateToken = stateToken + 1
        runnerAccum, runnerClock = 0, 0
        StartRun()
        ns.selectedRung = 1
        ns.wager = NPCS[1][6]
        if prestigeFrame then prestigeFrame:Hide() end
        ns.Refresh()
        print("|cffc9a227Deathroll Baron|r: fresh table, fresh cheats.")
        return
    end
    if msg == "sim" then
        local rung = ns.selectedRung or 1
        local wins, total, net = 0, 300, 0
        local wager = NPCS[rung][6]
        for _ = 1, total do
            local res, amount = SimulateMatch(rung, wager)
            if res == "win" then
                wins = wins + 1
                net = net + amount
            else
                net = net - amount
            end
        end
        print(("|cffc9a227sim|r rung %d (%s): %d/%d wins = %.1f%%, net %s over %d matches"):format(
            rung, NPCS[rung][1], wins, total, wins / total * 100, Money(net), total))
        return
    end
    Toggle()
end

---------------------------------------------------------------------
-- juice: quick-fire layer
-- Additive: nothing above this is rewritten, so the odds solver and
-- the match engine behave exactly as before. Everything lives on one
-- table so the file's chunk-local budget is untouched.
---------------------------------------------------------------------
local J = {}

J.COIN = "Interface\\Icons\\INV_Misc_Coin_01"
J.COIN2 = "Interface\\Icons\\INV_Misc_Coin_02"
J.WHITE = "Interface\\Buttons\\WHITE8X8"
J.ready = false

function J.Sound(name)
    if not SOUNDKIT then return end
    local id = SOUNDKIT[name]
    if id then pcall(PlaySound, id) end
end

function J.Center(panel)
    if not panel or not frame then return 0, 0 end
    local px, py = panel:GetCenter()
    local fx, fy = frame:GetCenter()
    if not px or not py or not fx or not fy then return 0, 0 end
    return px - fx, py - fy
end

function J.Init()
    if J.ready or not frame or not W.youNum or not W.gold then return end
    J.ready = true
    J.scaleYou, J.scaleThem, J.goldScale, J.glowA = 1, 1, 1, 0
    J.parts, J.texts = {}, {}

    -- the odds bar: the one number the whole game hangs on
    -- range line ends about -266, bar runs -269..-285, log starts -288:
    -- 3pt clear above and below. 18pt at -264 touched the range line.
    local bar = CreateFrame("Frame", nil, frame)
    bar:SetSize(384, 16)
    bar:SetPoint("TOP", frame, "TOP", 0, -269)
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.10, 0.09, 0.07, 0.96)
    bar.fill = bar:CreateTexture(nil, "BACKGROUND", nil, 1)
    bar.fill:SetPoint("TOPLEFT", 1, -1)
    bar.fill:SetPoint("BOTTOMLEFT", 1, 1)
    bar.fill:SetWidth(1)
    bar.fill:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.9)
    local mid = bar:CreateTexture(nil, "BACKGROUND", nil, 2)
    mid:SetSize(1, 18)
    mid:SetPoint("CENTER")
    mid:SetColorTexture(1, 1, 1, 0.16)
    bar.text = FS(bar, GOLD, 11)
    bar.text:SetPoint("CENTER")
    J.bar = bar

    if W.luck then W.luck:Hide() end

    local glow = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
    glow:SetAllPoints()
    glow:SetColorTexture(1, 0.84, 0.28, 1)
    glow:SetAlpha(0)
    J.glow = glow

    for i = 1, 44 do
        local t = frame:CreateTexture(nil, "OVERLAY", nil, 3)
        t:SetTexture(J.WHITE)
        t:SetSize(10, 10)
        t:Hide()
        J.parts[i] = { tex = t, life = 0 }
    end

    for i = 1, 6 do
        local fs = FS(frame, GOLD, 20)
        fs:SetPoint("CENTER", frame, "CENTER", 0, 0)
        fs:SetAlpha(0)
        fs:SetText("")
        J.texts[i] = { fs = fs, life = 0, x = 0, y = 0, vy = 0 }
    end
end

function J.Take()
    for i = 1, #J.parts do
        if J.parts[i].life <= 0 then return J.parts[i] end
    end
    return nil
end

function J.Burst(x, y, n, big)
    if not J.ready then return end
    for i = 1, n do
        local p = J.Take()
        if p then
            local ang = math.random() * 6.28318
            local spd = 90 + math.random() * (big and 240 or 130)
            p.x, p.y = x, y
            p.vx = math.cos(ang) * spd
            p.vy = math.sin(ang) * spd * 0.75 + (big and 190 or 110)
            p.life = 0.5 + math.random() * 0.45
            p.max = p.life
            if math.random() < 0.45 then
                p.tex:SetTexture(math.random() < 0.5 and J.COIN or J.COIN2)
                p.tex:SetSize(13, 13)
                p.tex:SetVertexColor(1, 1, 1)
            else
                p.tex:SetTexture(J.WHITE)
                p.tex:SetSize(3 + math.random() * 4, 3 + math.random() * 4)
                p.tex:SetVertexColor(1, 0.80 + math.random() * 0.2, 0.25 + math.random() * 0.45)
            end
            p.tex:SetAlpha(1)
            p.tex:SetScale(1)
            p.tex:SetPoint("CENTER", frame, "CENTER", p.x, p.y)
            p.tex:Show()
        end
    end
end

function J.Float(x, y, str, size, color, life)
    if not J.ready then return end
    for i = 1, #J.texts do
        local t = J.texts[i]
        if t.life <= 0 then
            local path, _, flags = t.fs:GetFont()
            if path then t.fs:SetFont(path, size or 18, flags) end
            t.fs:SetText(str)
            t.fs:SetTextColor(color[1], color[2], color[3])
            t.fs:SetPoint("CENTER", frame, "CENTER", x, y)
            t.fs:SetAlpha(1)
            t.x, t.y = x, y
            t.vy = 48
            t.life = life or 1.1
            t.max = t.life
            return
        end
    end
end

function J.Roll(side)
    local panel = W.youPanel
    if side ~= "you" then panel = W.themPanel end
    if side == "you" then J.scaleYou = 1.5 else J.scaleThem = 1.5 end
    local x, y = J.Center(panel)
    J.Burst(x, y, 3, false)
end

function J.Result(s)
    if s.result == "win" then
        local x, y = J.Center(W.youPanel)
        J.Burst(x, y, 20, true)
        J.Burst(0, 30, 12, true)
        J.Float(0, 100, "CHA-CHING!", 26, GOLD, 1.3)
        J.Float(0, 66, "you take " .. Money(s.payout or 0), 16, GREEN, 1.3)
        J.glowA = 0.26
        J.goldScale = 1.35
        if J.glow then J.glow:SetColorTexture(1, 0.84, 0.28, 1) end
        J.Sound("LOOT_ROLL_WON")
    else
        local x, y = J.Center(W.themPanel)
        J.Burst(x, y, 8, false)
        J.Float(0, 84, "BUSTED   " .. Signed(s.net or 0), 20, RED, 1.1)
        J.glowA = 0.16
        if J.glow then J.glow:SetColorTexture(0.78, 0.16, 0.12, 1) end
        J.Sound("LOOT_ROLL_LOST")
    end
end

function J.Odds()
    if not J.ready or not DB then return end
    local s = state
    local live = (s and not s.finished) and true or false
    local cfg = live and s.cfg or BuildConfig(ns.selectedRung or 1)
    local chance = WinChance(cfg, live)
    if chance < 0 then chance = 0 end
    if chance > 1 then chance = 1 end
    local pct = floor(chance * 100 + 0.5)
    local wager = live and s.wager or (ns.wager or cfg.minWager)
    local gross = floor(wager * cfg.mult)
    local payout = max(0, min(gross - floor(gross * cfg.winTax), cfg.purse))
    local risk = floor(wager * cfg.lossMult * cfg.lossFrac)
    -- what a hand is worth from here: a win is the payout net of the
    -- stake that already left the purse, a loss is the fraction paid back.
    local ev = chance * (payout - wager) - (1 - chance) * risk
    local col = GOLD
    if pct >= 56 then col = GREEN elseif pct <= 44 then col = RED end
    J.bar.fill:SetWidth(max(1, floor(382 * chance)))
    J.bar.fill:SetColorTexture(col[1], col[2], col[3], 0.55 + 0.25 * (0.5 + 0.5 * math.sin(GetTime() * 3)))
    J.bar.text:SetText(("%d%% YOU  .  pays %s  .  risk %s  .  EV %s"):format(
        pct, Money(payout), Money(risk), Signed(ev)))
    J.bar.text:SetTextColor(col[1], col[2], col[3])
end

function J.Step(el)
    if not J.ready then return end
    if el > 0.1 then el = 0.1 end

    J.Pace()
    J.TickReels(el)
    J.TickHold(el)

    for i = 1, #J.parts do
        local p = J.parts[i]
        if p.life > 0 then
            p.life = p.life - el
            if p.life <= 0 then
                p.tex:Hide()
            else
                p.vy = p.vy - 620 * el
                p.x = p.x + p.vx * el
                p.y = p.y + p.vy * el
                local k = p.life / p.max
                p.tex:ClearAllPoints()
                p.tex:SetPoint("CENTER", frame, "CENTER", p.x, p.y)
                p.tex:SetAlpha(min(1, k * 1.6))
                p.tex:SetScale(0.55 + 0.75 * k)
            end
        end
    end

    for i = 1, #J.texts do
        local t = J.texts[i]
        if t.life > 0 then
            t.life = t.life - el
            if t.life <= 0 then
                t.fs:SetAlpha(0)
            else
                t.y = t.y + t.vy * el
                t.vy = t.vy * (1 - el * 1.4)
                t.fs:SetAlpha(min(1, t.life / 0.45))
                t.fs:ClearAllPoints()
                t.fs:SetPoint("CENTER", frame, "CENTER", t.x, t.y)
            end
        end
    end

    J.scaleYou = 1 + (J.scaleYou - 1) * max(0, 1 - el * 10)
    J.scaleThem = 1 + (J.scaleThem - 1) * max(0, 1 - el * 10)
    J.goldScale = 1 + (J.goldScale - 1) * max(0, 1 - el * 8)
    if W.youNum then W.youNum:SetScale(J.scaleYou) end
    if W.themNum then W.themNum:SetScale(J.scaleThem) end
    if W.gold then W.gold:SetScale(J.goldScale) end

    if J.glowA > 0 then
        J.glowA = max(0, J.glowA - el * 1.2)
        if J.glow then J.glow:SetAlpha(J.glowA) end
    end
end

---------------------------------------------------------------------
-- 0.0.10: pace, reel, and a ceremony for the one
-- Still additive: the odds solver, the match engine and the save file
-- are untouched. Everything is detected in the refresh wrapper and
-- animated in J.Step, so nothing changes a frame before it is drawn.
---------------------------------------------------------------------

-- The ticker re-reads cfg.speed after every roll, so the curve is
-- written straight onto the live config. The base is cached on the hand
-- table, which keeps Fast Hands fast and disappears with the hand.
function J.PaceK(m, ceiling)
    return min(1.50, 0.70 + 0.95 * (1 - m / ceiling) ^ 1.7)
end

function J.Pace()
    local s = state
    if not s or s.finished or s.manual then return end
    s.paceBase = s.paceBase or s.cfg.speed
    s.cfg.speed = s.paceBase * J.PaceK(s.max, s.cfg.ceiling)
end

local HOLD = 0.55

-- One reel slot is enough: only one side can be rolling at a time, so a
-- new roll always ends the old one. Settling first is what keeps the
-- previous number honest when two rolls land inside one reel's life.
J.reel, J.span, J.done = nil, nil, nil

function J.ReelSettle()
    local r = J.reel
    if not r then return end
    J.reel = nil
    r.fs:SetText(tostring(r.value))
    if r.side == 'you' then J.scaleYou = 1.30 else J.scaleThem = 1.30 end
end

function J.ReelStart(side, value)
    J.ReelSettle()
    local s = state
    local fs = side == 'you' and W.youNum or W.themNum
    if not fs then return end
    J.reel = {
        side = side, fs = fs, value = value,
        span = J.span or s.cfg.ceiling,
        life = 0.16 + 0.18 * (1 - s.max / s.cfg.ceiling),
    }
    -- Fast Hands can make a tick shorter than a reel, and a reel that is
    -- still spinning when the next number lands never shows a number at
    -- all. Cap its life under the gap the ticker actually scheduled, timed
    -- from the range the gap was measured on (J.span, the previous number).
    if not s.manual and s.paceBase then
        local gap = s.cfg.speed
        if J.span then gap = min(gap, s.paceBase * J.PaceK(J.span, s.cfg.ceiling)) end
        J.reel.life = max(0.05, min(J.reel.life, gap * 0.75))
    end
    J.span = s.max
    J.Roll(side)
end

function J.ReelPaint()
    local r = J.reel
    if r then r.fs:SetText(tostring(random(1, r.span))) end
end

function J.TickReels(el)
    local r = J.reel
    if not r then return end
    r.life = r.life - el
    if r.life <= 0 then J.ReelSettle() end
end

-- Every hand ends on a one, so the beat always happens: the losing
-- number slams up and holds, and the headline is held back until the
-- hold is spent.
function J.Ceremony(s)
    J.ReelSettle()
    local won = (s.lastEnemy == 1)
    if won then J.scaleThem = 2.5 else J.scaleYou = 2.5 end
    local x, y = J.Center(won and W.themPanel or W.youPanel)
    J.Burst(x, y, 22, true)
    J.Burst(x, y - 24, 10, true)
    local col = won and GOLD or RED
    J.Float(0, 150, won and 'THEY ROLL A ONE' or 'A ONE. THE POT GOES.', 22, col, 1.5)
    if J.glow then J.glow:SetColorTexture(col[1], col[2], col[3], 1) end
    J.glowA = 0.40
    J.hold = { s = s, t = HOLD, won = won }
end

function J.TickHold(el)
    local h = J.hold
    if not h then return end
    h.t = h.t - el
    if h.t <= 0 then
        J.hold = nil
        J.Result(h.s)
        ns.Refresh()
        return
    end
    local slam = 2.0 + 0.6 * (h.t / HOLD)
    if h.won then J.scaleThem = slam else J.scaleYou = slam end
end

-- Everything that changes when the state changes is detected on the
-- refresh that ends the roll, so no panel can show a number or a
-- verdict a frame before the juice knows about it.
function J.Sync()
    local s = state
    if s ~= J.seenState then
        J.seenState = s
        J.lastP, J.lastE = nil, nil
        J.scaleYou, J.scaleThem = 1, 1
        J.span, J.done, J.hold = nil, nil, nil
    end
    if not s then return end

    if not s.finished then
        if s.lastPlayer ~= J.lastP then
            J.lastP = s.lastPlayer
            if s.lastPlayer then J.ReelStart('you', s.lastPlayer) end
        end
        if s.lastEnemy ~= J.lastE then
            J.lastE = s.lastEnemy
            if s.lastEnemy then J.ReelStart('them', s.lastEnemy) end
        end
    elseif J.done ~= s then
        J.done = s
        J.Ceremony(s)
    end

    if J.hold then
        local col = J.hold.won and GOLD or RED
        W.range:SetText(J.hold.won and 'a one  .  the pot is coming' or 'a one  .  the pot is going')
        W.range:SetTextColor(col[1], col[2], col[3])
    end
end

local jbase = ns.Refresh
ns.Refresh = function(...)
    if jbase then jbase(...) end
    J.Sync()
    J.ReelPaint()
    J.Odds()
end

local jdriver = CreateFrame("Frame")
jdriver:SetScript("OnUpdate", function(_, el)
    if not J.ready then
        if frame and W.youNum and W.gold then J.Init() end
        return
    end
    J.Step(el)
    ns.AutoTick(el)
end)

---------------------------------------------------------------------
-- auto-spin: the table keeps dealing
-- Session-only on purpose: it is off at login and it stops when the
-- frame closes, so it can never spend a purse unattended. The pause
-- contains the ceremony's hold, so the reveal is still never cut short.
---------------------------------------------------------------------
ns.auto = false
ns.autoT = 0

-- One pause, not a hold plus a fixed gap. The ceremony already spends
-- HOLD on the one; what is left is a breath sized by the result and by
-- how fast the hand ran, so a fast hand cannot machine-gun and a slow
-- one is not slowed further.
function ns.AutoPause(s)
    local breath = (s and s.result == "win") and 0.28 or 0.42
    local pace = 1
    if s and s.cfg then pace = J.PaceK(s.max, s.cfg.ceiling) end
    return HOLD + breath * (1.30 - 0.30 * pace)
end

-- Runs on the existing driver, one line after J.Step. StartMatch is the
-- wallet's own guard: it refuses a finished run and any stake the purse
-- cannot cover, so a refusal is the only way this stops itself.
function ns.AutoTick(el)
    if not ns.auto then return end
    if DB.ended or not frame:IsShown() then
        ns.auto = false
        return
    end
    local s = state
    if s and not s.finished then
        ns.autoT = 0
        return
    end
    if s and s.manual then
        ns.auto = false
        return
    end
    ns.autoT = ns.autoT + el
    if ns.autoT < ns.AutoPause(s) then return end
    ns.autoT = 0
    if not StartMatch(ns.selectedRung, ns.wager, false) then ns.auto = false end
    ns.Refresh()
end

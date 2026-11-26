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
---------------------------------------------------------------------
local POWERS = {
    { id = "dice",   name = "Weighted Dice",  base = 200,  max = 10,
      desc = "+8% Luck per rank",
      apply = function(c, r) if r > 0 then c.playerLuck = c.playerLuck + 0.08 * r end end },
    { id = "sand",   name = "Pocket Sand",    base = 250,  max = 8,
      desc = "+8% enemy Hex per rank",
      apply = function(c, r) if r > 0 then c.enemyLuck = c.enemyLuck + 0.08 * r end end },
    { id = "marks",  name = "Marked Cards",   base = 300,  max = 10,
      desc = "+12% payout per rank",
      apply = function(c, r) if r > 0 then c.mult = c.mult + 0.12 * r end end },
    { id = "hands",  name = "Fast Hands",     base = 150,  max = 2,
      desc = "Roll ticker twice as fast",
      apply = function(c, r) c.speed = 0.85 / (1 + 0.6 * r) end },
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
    { id = "money",     name = "Old Money",     per = "+250 starting bankroll", cost = 2 },
    { id = "bloodline", name = "Bloodline",     per = "+2% base Luck",          cost = 3 },
    { id = "inside",    name = "Inside Man",    per = "-5% power-up cost",      cost = 4 },
    { id = "inherit",   name = "Inherited Dice",per = "keep one power-up",      cost = 10, single = true },
    { id = "read",      name = "Read the Room", per = "see affixes before betting", cost = 15, single = true },
}

---------------------------------------------------------------------
-- saved variables
---------------------------------------------------------------------
local DB

local DEFAULTS = {
    gold = 500, peak = 500, runs = 0, crowns = 0, bestRung = 1,
    wins = 0, losses = 0, debt = 0, loanUsed = false, lastSeen = 0,
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
        desperate = false, forcePlayerOpen = false, speed = 0.85,
        affixes = {},
    }

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
    c.playerLuck = min(0.95, max(0, c.playerLuck))
    c.enemyLuck = min(0.95, max(0, c.enemyLuck))
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

---------------------------------------------------------------------
-- match engine
---------------------------------------------------------------------
local state
local stateToken = 0
local GameOver, StartNewRun

local function LogLine(s, kind, text)
    s.log[#s.log + 1] = { kind = kind, text = text }
    while #s.log > 6 do table.remove(s.log, 1) end
end

local function DrawRoll(mx, bias, high)
    if mx < 1 then mx = 1 end
    local a = random(1, mx)
    if bias > 0 and random() < bias then
        local b = random(1, mx)
        if high then a = max(a, b) else a = min(a, b) end
    end
    return a
end

local function FinishMatch(result)
    local s = state
    if not s or s.finished then return end
    s.finished = true
    s.result = result
    local c = s.cfg

    if result == "win" then
        local gross = floor(s.wager * c.mult)
        local payout = max(0, min(gross - floor(gross * c.winTax), c.purse))
        DB.gold = DB.gold + payout
        DB.wins = DB.wins + 1
        s.payout = payout
        LogLine(s, "win", "You take " .. Money(payout) .. ".")
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
    else
        local loss = floor(s.wager * c.lossMult * c.lossFrac)
        DB.gold = DB.gold - loss
        DB.losses = DB.losses + 1
        s.loss = loss
        LogLine(s, "lose", "You pay " .. Money(loss) .. ".")
    end

    DB.peak = max(DB.peak, DB.gold)
    if DB.gold <= 0 then
        DB.gold = 0
        GameOver()
    end
end

local function StepMatch()
    local s = state
    if not s or s.finished then return end
    local c = s.cfg
    local isPlayer = (s.turn == "player")
    local bias = isPlayer and c.playerLuck or c.enemyLuck
    if c.desperate and not isPlayer and s.max <= 20 then bias = bias + 0.30 end

    local roll = DrawRoll(s.max, bias, isPlayer)

    if roll == 1 and isPlayer and s.insurance > 0 and not c.insuranceBlocked then
        s.insurance = s.insurance - 1
        LogLine(s, "bank", "Blood Pact burns a charge. Roll again.")
        return
    end

    LogLine(s, isPlayer and "you" or "them", tostring(roll))
    s.max = roll
    if roll == 1 then
        FinishMatch(isPlayer and "lose" or "win")
        return
    end
    s.turn = isPlayer and "enemy" or "player"
end

local function StartMatch(rung, wager)
    local c = BuildConfig(rung)
    wager = floor(wager or c.minWager)
    if wager > DB.gold then return false end
    if wager < c.minWager then wager = c.minWager end
    if wager > DB.gold then return false end

    state = {
        cfg = c, wager = wager, max = c.ceiling,
        turn = c.theyOpen and "enemy" or "player",
        insurance = c.insurance, log = {}, finished = false,
    }
    stateToken = stateToken + 1
    local token = stateToken
    LogLine(state, "bank", c.name .. " sits down. " .. Money(wager) .. " on the table.")

    local function tick()
        if token ~= stateToken then return end
        local s = state
        if not s or s.finished then return end
        StepMatch()
        if not s.finished then
            C_Timer.After(s.cfg.speed, tick)
        end
        if ns.Refresh then ns.Refresh() end
    end

    C_Timer.After(0.30, tick)
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

GameOver = function()
    local earned = floor(math.sqrt(max(0, DB.peak) / 1000))
    DB.crowns = DB.crowns + earned
    DB.runs = DB.runs + 1
    state = nil
    if ns.ShowPrestige then ns.ShowPrestige(earned) end
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
    StartRun()
    ns.selectedRung = 1
    ns.wager = NPCS[1][6]
end

local function Borrow()
    if DB.loanUsed then return false end
    DB.loanUsed = true
    DB.debt = DB.debt + 450
    DB.gold = DB.gold + 300
    return true
end

---------------------------------------------------------------------
-- the runner: idle and offline income
---------------------------------------------------------------------
local runnerAccum = 0

local function RunnerStep()
    if (DB.powers.runner or 0) < 1 then return end
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
    DB.peak = max(DB.peak, DB.gold)
    if DB.gold <= 0 then
        DB.gold = 0
        GameOver()
    end
end

local function ApplyOffline()
    if (DB.powers.runner or 0) < 1 then return 0 end
    local elapsed = time() - (DB.lastSeen or 0)
    if elapsed < 60 then return 0 end
    elapsed = min(elapsed, 8 * 3600)
    local matches = floor(elapsed / 6)
    if matches < 1 then return 0 end
    local rung = min(DB.bestRung, #NPCS)
    local wager = NPCS[rung][6]
    if DB.gold < wager then return 0 end
    local sample = min(matches, 120)
    local net = 0
    for i = 1, sample do
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
---------------------------------------------------------------------
local frame, prestigeFrame
local W = { affix = {}, log = {}, shop = {}, prestige = {} }
local AdjustWager, SelectRung, DoRoll, StartNewRunUI

ns.selectedRung = 1
ns.wager = 50

local function FS(parent, template, color, size)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
    if color then fs:SetTextColor(color[1], color[2], color[3]) end
    if size then
        local path, _, flags = fs:GetFont()
        if path then fs:SetFont(path, size, flags) end
    end
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

    local border = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    border:SetAllPoints()
    border:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.55)

    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", 2, -2)
    bg:SetPoint("BOTTOMRIGHT", -2, 2)
    bg:SetColorTexture(0.07, 0.06, 0.05, 0.97)

    W.title = FS(frame, "GameFontNormalLarge", GOLD, 14)
    W.title:SetPoint("TOP", 0, -12)
    W.title:SetText("DEATHROLL BARON")

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -3, -3)

    W.gold = FS(frame, "GameFontNormalHuge", GOLD, 22)
    W.gold:SetPoint("TOPLEFT", 16, -38)

    W.sub = FS(frame, "GameFontNormalSmall", DIM)
    W.sub:SetPoint("TOPLEFT", 16, -66)

    W.npc = FS(frame, "GameFontNormalLarge", BONE, 15)
    W.npc:SetPoint("TOPLEFT", 16, -94)
    W.npcInfo = FS(frame, "GameFontNormalSmall", DIM)
    W.npcInfo:SetPoint("TOPLEFT", 16, -114)

    for i = 1, 4 do
        local fs = FS(frame, "GameFontNormalSmall", DIM)
        fs:SetPoint("TOPLEFT", 16, -132 - (i - 1) * 15)
        fs:SetText("")
        W.affix[i] = fs
    end

    W.big = FS(frame, "GameFontNormalHuge", BONE, 46)
    W.big:SetPoint("TOP", 0, -206)
    W.big:SetText("")

    W.range = FS(frame, "GameFontNormalSmall", DIM)
    W.range:SetPoint("TOP", 0, -258)
    W.luck = FS(frame, "GameFontNormalSmall", GOLD)
    W.luck:SetPoint("TOP", 0, -274)

    for i = 1, 6 do
        local fs = FS(frame, "GameFontNormalSmall", BONE)
        fs:SetPoint("TOPLEFT", 20, -296 - (i - 1) * 14)
        fs:SetText("")
        W.log[i] = fs
    end

    W.prev = Btn(frame, "<", 24, 18, 10, function() SelectRung(-1) end)
    W.prev:SetPoint("TOPRIGHT", -60, -92)
    W.next = Btn(frame, ">", 24, 18, 10, function() SelectRung(1) end)
    W.next:SetPoint("TOPRIGHT", -30, -92)

    W.minus = Btn(frame, "-", 28, 22, 12, function() AdjustWager(-1) end)
    W.minus:SetPoint("TOPLEFT", 16, -386)
    W.plus = Btn(frame, "+", 28, 22, 12, function() AdjustWager(1) end)
    W.plus:SetPoint("TOPRIGHT", -16, -386)

    W.wager = FS(frame, "GameFontNormal", BONE, 13)
    W.wager:SetPoint("TOP", 0, -390)

    W.loan = Btn(frame, "Take the shark's loan", 130, 20, 10, function()
        if Borrow() then ns.Refresh() end
    end)
    W.loan:SetPoint("TOPLEFT", 16, -412)
    W.loan:Hide()

    W.min = Btn(frame, "MIN", 70, 20, 10, function()
        local cfg = BuildConfig(ns.selectedRung)
        ns.wager = cfg.minWager
        ns.Refresh()
    end)
    W.min:SetPoint("TOPRIGHT", -200, -412)

    W.half = Btn(frame, "HALF", 70, 20, 10, function()
        local cfg = BuildConfig(ns.selectedRung)
        ns.wager = max(cfg.minWager, floor(DB.gold / 2))
        ns.Refresh()
    end)
    W.half:SetPoint("TOPRIGHT", -126, -412)

    W.allin = Btn(frame, "ALL IN", 70, 20, 10, function()
        local cfg = BuildConfig(ns.selectedRung)
        ns.wager = max(cfg.minWager, DB.gold)
        ns.Refresh()
    end)
    W.allin:SetPoint("TOPRIGHT", -52, -412)

    W.roll = Btn(frame, "ROLL", 368, 40, 16, function() DoRoll() end)
    W.roll:SetPoint("TOP", 0, -440)

    for i, p in ipairs(POWERS) do
        local col = (i - 1) % 2
        local row = floor((i - 1) / 2)
        local b = Btn(frame, p.name, 178, 24, 10, function(self)
            if BuyPower(self.powerId) then ns.Refresh() end
        end)
        b:SetPoint("TOPLEFT", 14 + col * 192, -494 - row * 28)
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

    frame:Hide()

    -- prestige overlay
    prestigeFrame = CreateFrame("Frame", "DeathrollBaronPrestige", UIParent)
    prestigeFrame:SetSize(340, 260)
    prestigeFrame:SetPoint("CENTER")
    prestigeFrame:SetFrameStrata("DIALOG")
    prestigeFrame:EnableMouse(true)

    local pborder = prestigeFrame:CreateTexture(nil, "BACKGROUND", nil, -8)
    pborder:SetAllPoints()
    pborder:SetColorTexture(BLOOD[1], BLOOD[2], BLOOD[3], 0.9)
    local pbg = prestigeFrame:CreateTexture(nil, "BACKGROUND")
    pbg:SetPoint("TOPLEFT", 2, -2)
    pbg:SetPoint("BOTTOMRIGHT", -2, 2)
    pbg:SetColorTexture(0.06, 0.05, 0.04, 0.98)

    local ptitle = FS(prestigeFrame, "GameFontNormalLarge", BLOOD, 16)
    ptitle:SetPoint("TOP", 0, -20)
    ptitle:SetText("THE TABLE TAKES YOU")

    W.pCrowns = FS(prestigeFrame, "GameFontNormal", GOLD, 14)
    W.pCrowns:SetPoint("TOP", 0, -48)
    W.pCrowns:SetText("")

    for i = 1, 4 do
        local fs = FS(prestigeFrame, "GameFontNormalSmall", BONE)
        fs:SetPoint("TOPLEFT", 18, -74 - (i - 1) * 16)
        fs:SetText("")
        W.prestige[i] = fs
    end

    W.pAgain = Btn(prestigeFrame, "Sit down again", 200, 26, 12, function()
        StartNewRunUI()
    end)
    W.pAgain:SetPoint("BOTTOM", 0, 20)

    prestigeFrame:Hide()
end

function ns.Refresh()
    if not frame or not DB then return end

    if not ns.selectedRung then ns.selectedRung = DB.bestRung end
    if ns.selectedRung > DB.bestRung then ns.selectedRung = DB.bestRung end
    if ns.selectedRung < 1 then ns.selectedRung = 1 end

    local cfg = BuildConfig(ns.selectedRung)
    if not ns.wager or ns.wager < cfg.minWager then ns.wager = cfg.minWager end

    W.gold:SetText(Money(DB.gold))
    local crowns = DB.crowns > 0 and ("   " .. DB.crowns .. " crowns") or ""
    W.sub:SetText(("peak %s%s    run %d    %dW/%dL"):format(
        Money(DB.peak), crowns, DB.runs + 1, DB.wins, DB.losses))

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
                W.affix[i]:SetTextColor(0.80, 0.34, 0.30)
            end
        else
            W.affix[i]:SetText("")
        end
    end
    if ns.selectedRung < 6 then
        W.affix[1]:SetText("no tricks. base rng.")
        W.affix[1]:SetTextColor(DIM[1], DIM[2], DIM[3])
    end

    local live = state and not state.finished
    if live then
        W.big:SetText(tostring(state.max))
        W.big:SetTextColor(BONE[1], BONE[2], BONE[3])
        W.range:SetText(("rolling 1 - %d    .    %s on the table"):format(state.max, Money(state.wager)))
    elseif state and state.finished then
        if state.result == "win" then
            W.big:SetText("+" .. Money(state.payout or 0))
            W.big:SetTextColor(GREEN[1], GREEN[2], GREEN[3])
            W.range:SetText("you take the pot")
        else
            W.big:SetText("-" .. Money(state.loss or 0))
            W.big:SetTextColor(0.85, 0.30, 0.26)
            W.range:SetText("you pay up")
        end
    else
        W.big:SetText(tostring(cfg.ceiling))
        W.big:SetTextColor(BONE[1] * 0.6, BONE[2] * 0.6, BONE[3] * 0.6)
        W.range:SetText(("opens at 1 - %d"):format(cfg.ceiling))
    end

    W.luck:SetText(("your luck %s   .   their luck %s   .   payout x%.2f"):format(
        Pct(cfg.playerLuck), Pct(cfg.enemyLuck), cfg.mult))

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
            if e.kind == "win" then
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
    W.roll:SetText(live and "ROLLING" or ("ROLL   " .. Money(ns.wager)))
    W.roll:SetEnabled(not live and DB.gold >= cfg.minWager)

    W.loan:SetShown(DB.gold < cfg.minWager and not DB.loanUsed)
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
                b:SetEnabled(DB.gold >= cost)
            end
        end
    end
end

ns.ShowPrestige = function(earned)
    if not prestigeFrame then return end
    W.pCrowns:SetText(("+%d Bone Crowns   (total %d)"):format(earned, DB.crowns))
    local shown = 0
    for _, e in ipairs(PRESTIGE) do
        if e.id ~= "read" then
            shown = shown + 1
            local r = DB.prestige[e.id] or 0
            local fs = W.prestige[shown]
            if fs then
                fs:SetText(("%s  rank %d  -  %s  -  next %d crowns"):format(e.name, r, e.per, PrestigeCost(e)))
            end
        end
    end
    prestigeFrame:Show()
end

SelectRung = function(dir)
    ns.selectedRung = max(1, min(DB.bestRung, (ns.selectedRung or 1) + dir))
    local cfg = BuildConfig(ns.selectedRung)
    ns.wager = cfg.minWager
    ns.Refresh()
end

AdjustWager = function(dir)
    local cfg = BuildConfig(ns.selectedRung)
    local step = max(10, floor(cfg.minWager / 4))
    ns.wager = max(cfg.minWager, min(max(DB.gold, cfg.minWager), ns.wager + dir * step))
    ns.Refresh()
end

DoRoll = function()
    if state and not state.finished then return end
    local cfg = BuildConfig(ns.selectedRung)
    if DB.gold < cfg.minWager then
        if Borrow() then ns.Refresh() end
        return
    end
    StartMatch(ns.selectedRung, ns.wager)
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
        if next(DB.rolled) == nil then StartRun() end
        ns.selectedRung = DB.bestRung
        ns.wager = NPCS[DB.bestRung][6]
        Build()
        local net = ApplyOffline()
        if net ~= 0 then
            print(("|cffc9a227Deathroll Baron|r: the Runner brought back %s."):format(Money(net)))
        end
        ns.Refresh()
    elseif event == "PLAYER_LOGOUT" then
        if DB then DB.lastSeen = time() end
    end
end)

-- the runner's clock
local clock = CreateFrame("Frame")
clock:SetScript("OnUpdate", function(_, elapsed)
    if not DB then return end
    runnerAccum = runnerAccum + elapsed
    if runnerAccum < 1 then return end
    runnerAccum = 0
    RunnerStep()
    if frame and frame:IsShown() then ns.Refresh() end
end)

---------------------------------------------------------------------
-- entry points
---------------------------------------------------------------------
local function Toggle()
    if not frame then return end
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
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
    if msg == "reset" then
        DB.powers = {}
        DB.bestRung = 1
        DB.gold = 500 + 250 * (DB.prestige.money or 0)
        DB.peak = DB.gold
        StartRun()
        state = nil
        ns.selectedRung = 1
        ns.wager = NPCS[1][6]
        ns.Refresh()
        print("|cffc9a227Deathroll Baron|r: fresh table, fresh cheats.")
        return
    end
    if msg == "sim" then
        local rung = ns.selectedRung or 1
        local wins, total = 0, 300
        for i = 1, total do
            local res = SimulateMatch(rung, NPCS[rung][6])
            if res == "win" then wins = wins + 1 end
        end
        print(("|cffc9a227sim|r rung %d (%s): %d/%d wins = %.1f%%"):format(
            rung, NPCS[rung][1], wins, total, wins / total * 100))
        return
    end
    Toggle()
end

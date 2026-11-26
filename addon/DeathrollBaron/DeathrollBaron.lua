--[[ Deathroll Baron
     A deathroll incremental for World of Warcraft: Forever (interface 16001).
     One file, no libraries. ]]

local ADDON, ns = ...
local floor, max, min, random = math.floor, math.max, math.min, math.random

-- 0.0.7: DESPERATE_FROM / DESPERATE_LUCK live here because the odds solver has
-- to agree with StepMatch about them. One constant, two readers.
local DESPERATE_FROM = 20
local DESPERATE_LUCK = 0.30

local GOLD  = { 0.79, 0.64, 0.15 }
local BONE  = { 0.87, 0.84, 0.77 }
local DIM   = { 0.55, 0.52, 0.46 }
local BLOOD = { 0.72, 0.16, 0.13 }
local GREEN = { 0.30, 0.78, 0.35 }
local AMBER = { 0.95, 0.62, 0.18 }

local ROLL_TIME  = 0.55
local FLASH_TIME = 0.9
local POP_TIME   = 0.18
local RUNNER_TICK = 6

local SCHEMA = 5

local NPCS = {
    { name = "Kobold Vermin",           short = "Kobold Vermin" },
    { name = "Zhevra Charger",          short = "Zhevra Charger" },
    { name = "Mudsnout Gnoll",          short = "Mudsnout Gnoll" },
    { name = "Rockjaw Trogg",           short = "Rockjaw Trogg" },
    { name = "Kolkari Blademaster",     short = "K. Blademaster" },
    { name = "Frostmane Seer",          short = "Frostmane Seer" },
    { name = "Warchief's Runner",       short = "Warchief's Runner" },
    { name = "Baron Rivendare",         short = "Baron Rivendare" },
    { name = "Rage Talon Fireclaw",     short = "R. Talon Fireclaw" },
    { name = "Herald Volazj",           short = "Herald Volazj" },
    { name = "Troll Berserker",         short = "Troll Berserker" },
    { name = "Anub'Rekhan",             short = "Anub'Rekhan" },
    { name = "Shade of Aran",           short = "Shade of Aran" },
    { name = "Teron Gorefiend",         short = "Teron Gorefiend" },
    { name = "Vashj",                   short = "Lady Vashj" },
    { name = "Illidan Stormrage",       short = "Illidan" },
    { name = "Kel'Thuzad",              short = "Kel'Thuzad" },
    { name = "Kil'jaeden",              short = "Kil'jaeden" },
    { name = "Archimonde",              short = "Archimonde" },
    { name = "Garrosh Hellscream",      short = "Garrosh" },
    { name = "Grommash Hellscream",     short = "Grommash" },
    { name = "Orgrim Doomhammer",       short = "Orgrim" },
    { name = "Anduin Lothar",           short = "Anduin Lothar" },
    { name = "C'Thun",                  short = "C'Thun" },
    { name = "Yogg-Saron",              short = "Yogg-Saron" },
    { name = "N'Zoth",                  short = "N'Zoth" },
    { name = "The Lich King",           short = "The Lich King" },
    { name = "Deathwing",               short = "Deathwing" },
    { name = "Sargeras",                short = "Sargeras" },
    { name = "Mutanus the Devourer",    short = "Mutanus" },
}

-- Affixes. Each one names the side it touches: "p" player, "e" enemy.
-- kind "luck" is a bias on the roll, kind "gold" is the stake, "range" the ceiling.
local AFFIXES = {
    { key = "Sweaty",        kind = "luck",  side = "p", value =  0.18, text = "Your luck +18%" },
    { key = "Tilted",       kind = "luck",  side = "p", value = -0.15, text = "Your luck -15%" },
    { key = "Lucky Dice",   kind = "luck",  side = "p", value =  0.12, text = "Your luck +12%" },
    { key = "Clumsy",       kind = "luck",  side = "p", value = -0.10, text = "Your luck -10%" },
    { key = "Steady Hands", kind = "luck",  side = "p", value =  0.08, text = "Your luck +8%" },
    { key = "Shaky",        kind = "luck",  side = "e", value =  0.14, text = "Their luck +14%" },
    { key = "Hexed",        kind = "luck",  side = "e", value = -0.12, text = "Their luck -12%" },
    { key = "Desperate",    kind = "luck",  side = "e", value =  DESPERATE_LUCK, text = "Under " .. DESPERATE_FROM .. ", their luck +30%" },
    { key = "Drunk",        kind = "luck",  side = "e", value = -0.09, text = "Their luck -9%" },
    { key = "Cursed",       kind = "luck",  side = "e", value =  0.10, text = "Their luck +10%" },
    { key = "Greedy",       kind = "gold",  side = "e", value =  0.25, text = "Stake +25%" },
    { key = "Cheap",        kind = "gold",  side = "e", value = -0.20, text = "Stake -20%" },
    { key = "Taxing",       kind = "gold",  side = "e", value =  0.15, text = "Stake +15%" },
    { key = "Generous",     kind = "gold",  side = "e", value = -0.15, text = "Stake -15%" },
    { key = "Wide Table",   kind = "range", side = "e", value =  1.5,  text = "Wider range" },
    { key = "Narrow Table", kind = "range", side = "e", value =  0.8,  text = "Narrower range" },
    { key = "Sharp",        kind = "luck",  side = "e", value =  0.06, text = "Their luck +6%" },
    { key = "Sloppy",       kind = "luck",  side = "e", value = -0.06, text = "Their luck -6%" },
    { key = "Focused",      kind = "luck",  side = "p", value =  0.06, text = "Your luck +6%" },
    { key = "Sweating",     kind = "luck",  side = "p", value = -0.06, text = "Your luck -6%" },
}

local POWERS = {
    { key = "pocketSand",  name = "Pocket Sand",   cost = 250,    max = 9,  desc = "Their luck -8%" },
    { key = "loadedDice",  name = "Loaded Dice",   cost = 800,    max = 6,  desc = "Your luck +6%" },
    { key = "rubberChicken", name = "Rubber Chicken", cost = 1500, max = 4, desc = "Win pays +20%" },
    { key = "insurance",   name = "Insurance",     cost = 2500,   max = 3,  desc = "Loss refunds 25%" },
    { key = "mark",        name = "Marked Cards",  cost = 6000,   max = 2,  desc = "They open 40% less" },
    { key = "runner",      name = "The Runner",    cost = 12000,  max = 5,  desc = "+2% bankroll / 6s" },
    { key = "bluff",       name = "Bluff",         cost = 40000,  max = 3,  desc = "Win pays +40%" },
    { key = "houseEdge",   name = "House Edge",    cost = 150000, max = 1,  desc = "Their luck -15%" },
}

local PRESTIGE = {
    { key = "charm",  name = "Bone Charm",   cost = 1,  desc = "+1 starting luck", max = 5 },
    { key = "purse",  name = "Fat Purse",     cost = 2,  desc = "Start with +50% copper", max = 5 },
    { key = "nerve",  name = "Gambler's Nerve", cost = 3, desc = "Lose less on a bust", max = 4 },
    { key = "read",   name = "Cold Read",     cost = 4,  desc = "See the odds on every rung", max = 1 },
    { key = "crown",  name = "Crown Dividend", cost = 6, desc = "+20% crowns", max = 3 },
}

-- ----------------------------------------------------------------------------
-- Database
-- ----------------------------------------------------------------------------

local DB

local function DefaultDB()
    return {
        schema   = SCHEMA,
        gold     = 50,
        best     = 1,
        bestRung = 1,
        crowns   = 0,
        peak     = 0,
        runs     = 0,
        wins     = 0,
        losses   = 0,
        wager    = 50,
        streak   = 0,
        forfeits = 0,
        stake    = 0,
        ended    = false,
        powers   = {},
        prestige = {},
        rolled   = {},
        rolledN  = 0,
        minimapAngle = 220,
        seenWelcome  = false,
        position = { x = 0, y = 0 },
    }
end

local function InitDB()
    DeathrollBaronDB = DeathrollBaronDB or DefaultDB()
    DB = DeathrollBaronDB

    local d = DefaultDB()
    for k, v in pairs(d) do
        if DB[k] == nil then DB[k] = v end
    end

    if DB.schema ~= SCHEMA then
        DB.schema = SCHEMA
    end

    if type(DB.gold) ~= "number" or DB.gold < 0 then DB.gold = 50 end
    if type(DB.peak) ~= "number" or DB.peak < 0 then DB.peak = 0 end
    if type(DB.crowns) ~= "number" or DB.crowns < 0 then DB.crowns = 0 end
    if not NPCS[DB.bestRung] then DB.bestRung = 1 end
    if not NPCS[DB.best] then DB.best = 1 end
    if type(DB.minimapAngle) ~= "number" then DB.minimapAngle = 220 end

    DB.powers = DB.powers or {}
    DB.prestige = DB.prestige or {}

    if type(DB.wager) ~= "number" or DB.wager < 1 then DB.wager = 50 end
    if DB.wager < DB.gold then DB.wager = DB.gold end
end

local function Save()
    -- SavedVariables only persist on logout/reload; nothing to do per-frame.
end

-- ----------------------------------------------------------------------------
-- Config
-- ----------------------------------------------------------------------------

local EDGE_BASE = 0.55
local EDGE_STEP = 0.025

local function PlayerLuck()
    local p = DB.prestige.charm or 0
    return p * 0.02
end

local function BuildConfig(rung, seed)
    local npc = NPCS[rung]
    local c = {
        rung    = rung,
        npc     = npc,
        ceiling = 100 * rung,
        stakeMult = 1,
        playerLuck = PlayerLuck(),
        enemyLuck  = 0,
        desperate  = false,
        theyOpen   = false,
        affixes    = {},
    }

    if rung > 5 then
        local list = {}
        for i = 1, #AFFIXES do
            local a = AFFIXES[i]
            if a.kind ~= "range" or rung >= 12 then
                list[#list + 1] = a
            end
        end
        math.randomseed(seed + rung * 7919)
        local count = min(#list, 1 + floor((rung - 5) / 4))
        for i = 1, count do
            local j = random(i, #list)
            list[i], list[j] = list[j], list[i]
        end
        for i = 1, count do
            local a = list[i]
            c.affixes[#c.affixes + 1] = a
            if a.kind == "luck" then
                if a.key == "Desperate" then
                    c.desperate = true
                elseif a.side == "p" then
                    c.playerLuck = c.playerLuck + a.value
                else
                    c.enemyLuck = c.enemyLuck + a.value
                end
            elseif a.kind == "gold" then
                c.stakeMult = c.stakeMult + a.value
            end
        end
    end

    local lv = DB.prestige.nerve or 0
    if lv > 0 then c.stakeMult = c.stakeMult - 0.05 * lv end

    local sand = DB.powers.pocketSand or 0
    if sand > 0 then c.enemyLuck = c.enemyLuck - 0.08 * sand end
    local dice = DB.powers.loadedDice or 0
    if dice > 0 then c.playerLuck = c.playerLuck + 0.06 * dice end
    local hb = DB.powers.houseEdge or 0
    if hb > 0 then c.enemyLuck = c.enemyLuck - 0.15 * hb end

    c.playerLuck = c.playerLuck + (EDGE_BASE - EDGE_STEP * (rung - 1))

    c.playerLuck = max(-0.95, min(0.95, c.playerLuck))
    c.enemyLuck  = max(-0.95, min(0.95, c.enemyLuck))

    c.theyOpen = (rung % 3 == 0)

    if rung >= 12 then
        local mark = DB.powers.mark or 0
        if mark > 0 and random() < 0.4 then c.theyOpen = not c.theyOpen end
    end

    return c
end

-- ----------------------------------------------------------------------------
-- The dice
-- ----------------------------------------------------------------------------

-- Roll 1..max and keep two, biased by luck.
-- wantLow: the roller is trying to keep the SMALL number. In a deathroll that is
-- the player, always: a small number leaves the opponent almost nothing to roll
-- inside, so their odds of rolling a 1 go up. The enemy keeps the HIGH roll.
-- Negative luck is meaningful: it means you get the bad of two.
local function DrawRoll(m, bias, wantLow)
    local a = random(1, m)
    local b = random(1, m)
    local p = min(1, math.abs(bias))
    local keepA
    if bias == 0 then
        keepA = random() < 0.5
    elseif bias > 0 then
        keepA = random() < p
    else
        keepA = random() >= p
    end

    local lo, hi = min(a, b), max(a, b)
    if keepA then
        if wantLow then return lo else return hi end
        return a
    else
        if wantLow then return hi else return lo end
        return b
    end
end

-- ----------------------------------------------------------------------------
-- Odds
-- ----------------------------------------------------------------------------

-- The survival tables, exactly, not by sampling.
--
-- A[r] = the roller-to-move wins at range r when the player is to move.
-- B[r] = the roller-to-move wins at range r when the enemy is to move.
-- Rows only depend on smaller rows, so one table grown to the largest ceiling in
-- use answers every roll after that: the old version rebuilt all m^2 cells on
-- every call, which at rung 10 (ceiling 1000) was half a second of main term.
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
        -- Desperate raises their luck once the range is small; that is exactly
        -- the range where it matters, so each row carries its own enemy bias.
        local eb = eLuck
        if desperate and r <= DESPERATE_FROM then eb = eb + DESPERATE_LUCK end
        local qe = min(1, math.abs(eb))
        local eWantLow = eb < 0

        local inv  = 1 / r
        local inv2 = inv * inv
        local a, b = 0, 0
        for x = 1, r do
            local pmin = (2 * (r - x) + 1) * inv2
            local pmax = (2 * x - 1) * inv2
            local pp = (1 - qp) * inv + qp * (pWantLow and pmin or pmax)
            local pe = (1 - qe) * inv + qe * (eWantLow and pmin or pmax)
            if x == 1 then
                b = b + pe
            else
                a = a + pp * B[x]
                b = b + pe * A[x]
            end
        end
        A[r], B[r] = a, b
    end

    if m > entry.n then entry.n = m end
    return A, B
end

-- Probability the player wins from here. live: consult the running match.
local function WinChance(cfg, live)
    local A, B = OddsUpTo(cfg.ceiling, cfg.playerLuck, cfg.enemyLuck, cfg.desperate and true or false)
    local m = live and min(state.max, cfg.ceiling) or cfg.ceiling
    local youMove = live and (state.turn == "player") or (not live and not cfg.theyOpen)
    return youMove and A[m] or B[m]
end

-- ----------------------------------------------------------------------------
-- State
-- ----------------------------------------------------------------------------

local state = {
    live = false,
    cfg  = nil,
    max  = 1,
    turn = "player",
    last = nil,
    history = {},
    wager = 0,
    seen = 0,
}

local runnerAccum, runnerClock = 0, 0

local function Log(line, r, g, b)
    table.insert(state.history, 1, { text = line, r = r or 0.85, g = g or 0.82, b = b or 0.72 })
    while #state.history > 6 do table.remove(state.history) end
end

local function StartRun()
    DB.peak = max(DB.peak or 0, DB.gold)
    DB.ended = false
    DB.stake = 0
    DB.rolled = {}
    DB.rolledN = 0
    runnerAccum, runnerClock = 0, 0
    state.history = {}
    state.last = nil
    state.seen = 0
end

local function StartMatch(rung)
    local cfg = BuildConfig(rung, DB.rolledN or 0)
    local stake = floor(DB.wager * cfg.stakeMult)
    stake = max(1, min(stake, DB.gold))

    DB.gold = DB.gold - stake
    DB.stake = stake

    state.live = true
    state.cfg  = cfg
    state.max  = cfg.ceiling
    state.turn = cfg.theyOpen and "enemy" or "player"
    state.wager = stake
    state.last = nil

    Log("stake " .. stake .. "c on " .. cfg.npc.short, 0.95, 0.62, 0.18)
    Log(cfg.theyOpen and "they open" or "you open", 0.85, 0.82, 0.72)
end

local function FinishMatch(won)
    local cfg = state.cfg
    local stake = DB.stake or 0
    local base = stake
    local payout = 0

    if won then
        payout = base
        local chick = DB.powers.rubberChicken or 0
        if chick > 0 then payout = payout + floor(base * 0.20 * chick) end
        local bluff = DB.powers.bluff or 0
        if bluff > 0 then payout = payout + floor(base * 0.40 * bluff) end
        DB.gold = DB.gold + stake + payout
        DB.wins = DB.wins + 1
        DB.streak = (DB.streak or 0) + 1
        Log("you take the pot . +" .. payout .. "c", 0.30, 0.78, 0.35)
    else
        DB.losses = DB.losses + 1
        DB.streak = 0
        local ins = DB.powers.insurance or 0
        if ins > 0 then
            local refund = floor(stake * 0.25 * ins)
            DB.gold = DB.gold + refund
            payout = -stake + refund
            Log("lost . refund " .. refund .. "c", 0.72, 0.16, 0.13)
        else
            payout = -stake
            Log("lost . -" .. stake .. "c", 0.72, 0.16, 0.13)
        end
    end

    DB.peak = max(DB.peak or 0, DB.gold)
    DB.stake = 0
    state.live = false
    state.net = payout
    state.flash = won and 1 or -1
    state.flashT = FLASH_TIME

    if state.cfg and state.cfg.rung >= DB.bestRung then
        DB.bestRung = min(#NPCS, state.cfg.rung + 1)
    end
end

local function StepMatch()
    local s = state
    local c = s.cfg
    local isPlayer = (s.turn == "player")
    local bias = isPlayer and c.playerLuck or c.enemyLuck

    if c.desperate and not isPlayer and s.max <= DESPERATE_FROM then
        bias = bias + DESPERATE_LUCK
    end

    local roll = DrawRoll(s.max, bias, isPlayer)
    s.last = { roll = roll, player = isPlayer, pop = POP_TIME }

    if roll == 1 then
        if isPlayer then
            Log("you 1", 0.72, 0.16, 0.13)
            FinishMatch(false)
        else
            Log("them 1", 0.30, 0.78, 0.35)
            FinishMatch(true)
        end
        return
    end

    Log((isPlayer and "you " or "them ") .. roll, isPlayer and 0.95 or 0.72, isPlayer and 0.62 or 0.16, isPlayer and 0.18 or 0.13)

    s.max = roll - 1
    s.turn = isPlayer and "enemy" or "player"
    s.seen = s.seen + 1
end

-- ----------------------------------------------------------------------------
-- UI
-- ----------------------------------------------------------------------------

local W

local function Tension(m)
    if m > 60 then return "plenty of room" end
    if m > 25 then return "every number matters" end
    if m > 12 then return "the table goes quiet" end
    if m > 4  then return "no room left" end
    return "one number between you"
end

local function C3(f, r, g, b)
    f:SetTextColor(r, g, b)
end

local function Font(f, size, flags)
    local path = "Fonts\\FRIZQT__.TTF"
    if not f:SetFont(path, size, flags or "") then
        f:SetFontObject("GameFontNormal")
    end
end

local Build

local function BuildFrame()
    local f = CreateFrame("Frame", "DeathrollBaronFrame", UIParent)
    f:SetSize(400, 630)
    f:SetPoint("CENTER", 0, 0)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local x, y = self:GetCenter()
        DB.position.x = floor(x - UIParent:GetWidth() / 2)
        DB.position.y = floor(y - UIParent:GetHeight() / 2)
    end)

    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.04, 0.03, 0.96)

    local border = f:CreateTexture(nil, "BORDER")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetColorTexture(0.35, 0.28, 0.12, 0.9)

    local title = f:CreateFontString(nil, "OVERLAY")
    Font(title, 18)
    title:SetPoint("TOPLEFT", 14, -12)
    title:SetText("DEATHROLL BARON")
    C3(title, GOLD[1], GOLD[2], GOLD[3])

    local close = CreateFrame("Button", nil, f)
    close:SetSize(20, 20)
    close:SetPoint("TOPRIGHT", -12, -12)
    close:SetNormalFontObject("GameFontNormal")
    close:SetText("X")
    close:SetScript("OnClick", function() f:Hide() end)

    f.title = title
    return f
end

Build = function()
    W = BuildFrame()
end

-- ----------------------------------------------------------------------------
-- Commands
-- ----------------------------------------------------------------------------

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffd4a017Deathroll Baron|r  " .. msg)
end

local function Slash(msg)
    if msg == "" or msg == nil then
        if W then W:Show() end
        return
    end
    if msg == "odds" then
        local rung = DB.bestRung
        local cfg = BuildConfig(rung, DB.rolledN or 0)
        local A, B = OddsUpTo(cfg.ceiling, cfg.playerLuck, cfg.enemyLuck, cfg.desperate and true or false)
        Print(format("%s  opener %.0f%%  second %.0f%%", cfg.npc.short, A[cfg.ceiling] * 100, B[cfg.ceiling] * 100))
        return
    end
    Print("commands: /drb, /drb odds, /drb help")
end

SlashCmdList["DEATHROLLBARON"] = Slash
SLASH_DEATHROLLBARON1 = "/drb"
SLASH_DEATHROLLBARON2 = "/baron"

local e = CreateFrame("Frame")
e:RegisterEvent("ADDON_LOADED")
e:SetScript("OnEvent", function(_, _, addon)
    if addon ~= ADDON then return end
    InitDB()
    Build()
end)

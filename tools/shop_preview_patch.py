import pathlib
import re

path = pathlib.Path("addon/DeathrollBaron/DeathrollBaron.lua")
src = path.read_text()

if "ns.ShopPreview" in src:
    raise SystemExit("already applied")


def swap(old, new, label):
    global src
    n = src.count(old)
    if n != 1:
        raise SystemExit("%s: %d matches" % (label, n))
    src = src.replace(old, new, 1)
    print("ok", label)


swap(
    "local function BuildConfig(rung)",
    "local function BuildConfig(rung, powers)",
    "buildconfig signature",
)

pattern = re.compile(
    r"(for _, p in ipairs\(POWERS\) do\s*\n\s*)local r = DB\.powers\[p\.id\] or 0"
    r"(\s*\n\s*if p\.apply and r > 0 then p\.apply\(c, r\) end)"
)
src, n = pattern.subn(
    r"\1local r = (powers or DB.powers)[p.id] or 0\2", src, count=1
)
if n != 1:
    raise SystemExit("buildconfig powers read: %d matches" % n)
print("ok buildconfig powers read")

swap(
    '''        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(p.name, GOLD[1], GOLD[2], GOLD[3])
            GameTooltip:AddLine(p.desc, 1, 1, 1, true)
            GameTooltip:Show()
        end)''',
    '''        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(p.name, GOLD[1], GOLD[2], GOLD[3])
            GameTooltip:AddLine(p.desc, 1, 1, 1, true)
            if ns.ShopPreview then ns.ShopPreview(p) end
            GameTooltip:Show()
        end)''',
    "shop tooltip hook",
)

preview = '''-- shop hover: what the next rank does at the current stake. Read-only:
-- BuildConfig gets a copied powers table, and the solver is only read.
ns.ShopPreview = function(p)
    local r = DB.powers[p.id] or 0
    if r >= p.max then
        GameTooltip:AddLine("maxed", DIM[1], DIM[2], DIM[3])
        return
    end
    if DB.ended then return end

    local rung = min(DB.bestRung or 1, max(1, ns.selectedRung or 1))
    GameTooltip:AddLine(("next rank %d/%d  .  %s"):format(r + 1, p.max, Money(PowerCost(p))),
        GOLD[1], GOLD[2], GOLD[3])

    if not p.apply then
        GameTooltip:AddLine("no direct odds or money change", DIM[1], DIM[2], DIM[3])
    else
        local copy = {}
        for k, v in pairs(DB.powers) do copy[k] = v end
        copy[p.id] = r + 1
        local cur = BuildConfig(rung)
        local nxt = BuildConfig(rung, copy)
        local wager = ns.wager or cur.minWager

        local function stats(c)
            local chance = WinChance(c, false) or 0
            if chance < 0 then chance = 0 end
            if chance > 1 then chance = 1 end
            local gross = floor(wager * c.mult)
            local payout = max(0, min(gross - floor(gross * c.winTax), c.purse))
            local risk = floor(wager * c.lossMult * c.lossFrac)
            local ev = chance * (payout - wager) - (1 - chance) * risk
            return chance, payout, risk, ev
        end

        local c1, p1, r1, e1 = stats(cur)
        local c2, p2, r2, e2 = stats(nxt)
        GameTooltip:AddLine(("odds %d%% -> %d%%   pays %s -> %s"):format(
            floor(c1 * 100 + 0.5), floor(c2 * 100 + 0.5), Money(p1), Money(p2)),
            BONE[1], BONE[2], BONE[3], true)
        local ec = e2 > e1 and GREEN or (e2 < e1 and RED or BONE)
        GameTooltip:AddLine(("risk %s -> %s   EV %s -> %s"):format(
            Money(r1), Money(r2), Signed(e1), Signed(e2)), ec[1], ec[2], ec[3], true)
    end

    if state and not state.finished then
        GameTooltip:AddLine("applies next hand", DIM[1], DIM[2], DIM[3])
    end
end'''

anchor = "\nfunction J.Odds()\n"
if src.count(anchor) != 1:
    raise SystemExit("J.Odds anchor: %d matches" % src.count(anchor))
src = src.replace(anchor, "\n" + preview + "\n\nfunction J.Odds()\n", 1)
print("ok shop preview")

path.write_text(src)
print("patched")

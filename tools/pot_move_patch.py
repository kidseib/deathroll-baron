import pathlib

path = pathlib.Path("addon/DeathrollBaron/DeathrollBaron.lua")
src = path.read_text()

if "J.PotSlide" in src:
    raise SystemExit("already applied")


def swap(old, new, label):
    global src
    n = src.count(old)
    if n != 1:
        i = src.find(old.splitlines()[0])
        raise SystemExit("%s: %d matches\n%s" % (label, n, repr(src[i:i + 260])))
    src = src.replace(old, new, 1)
    print("ok", label)


swap(
    '''    -- the pot: a small stack of coins on the board seam, above both panels.
    -- Brightening while live and the slide to the winner come after this pass.
    local pot = CreateFrame("Frame", nil, J.fx)
    pot:SetSize(26, 50)
    pot:SetPoint("CENTER", W.youPanel, "TOPRIGHT", 8, -30)
    pot:SetAlpha(0.92)
    pot.coins = {}
    for i = 1, 4 do
        local c = pot:CreateTexture(nil, "OVERLAY", nil, i)
        c:SetTexture(i % 2 == 0 and J.COIN2 or J.COIN)
        c:SetSize(18, 18)
        c:SetPoint("CENTER", pot, "CENTER", (i % 2 == 0) and 1 or -1, -16 + (i - 1) * 4)
        c:SetAlpha(0.92)
        pot.coins[i] = c
    end
    pot.label = FS(pot, GOLD, 10)
    pot.label:SetPoint("TOP", 0, -2)
    pot.label:SetShadowColor(0, 0, 0, 0.95)
    pot.label:SetShadowOffset(1, -1)
    pot.label:SetText("")
    J.pot = pot
    J.Pot()''',
    '''    -- the pot: a small stack of coins on the board seam, above both panels.
    -- The seam anchor stays fixed; only the inner body slides to the winner.
    local pot = CreateFrame("Frame", nil, J.fx)
    pot:SetSize(26, 50)
    pot:SetPoint("CENTER", W.youPanel, "TOPRIGHT", 8, -30)
    pot.body = CreateFrame("Frame", nil, J.fx)
    pot.body:SetSize(26, 50)
    pot.body:SetPoint("CENTER", pot, "CENTER", 0, 0)
    pot.coins = {}
    for i = 1, 4 do
        local c = pot.body:CreateTexture(nil, "OVERLAY", nil, i)
        c:SetTexture(i % 2 == 0 and J.COIN2 or J.COIN)
        c:SetSize(18, 18)
        c:SetPoint("CENTER", pot.body, "CENTER", (i % 2 == 0) and 1 or -1, -16 + (i - 1) * 4)
        c:SetAlpha(1)
        pot.coins[i] = c
    end
    pot.label = FS(pot.body, GOLD, 10)
    pot.label:SetPoint("TOP", 0, -2)
    pot.label:SetShadowColor(0, 0, 0, 0.95)
    pot.label:SetShadowOffset(1, -1)
    pot.label:SetText("")
    J.pot = pot
    J.potX, J.potY = 0, 0
    J.potA = 0.84
    J.potAtWinner = false
    J.pot.body:SetAlpha(J.potA)
    J.Pot()''',
    "pot body",
)

swap(
    '''function J.Pot()
    if not J.pot then return end
    local s = state
    local stake = (s and not s.finished and s.wager) or ns.wager or 0
    J.pot.label:SetText(Money(stake))
end''',
    '''function J.Pot()
    if not J.pot then return end
    local s = state
    local live = s and not s.finished
    J.potLive = live and true or false
    local stake
    if s and s.wager and (live or J.potAtWinner) then
        stake = s.wager
    else
        stake = ns.wager or 0
    end
    J.pot.label:SetText(Money(stake))
end

function J.PotHome()
    if not J.pot then return end
    J.potAtWinner = false
    if (J.potX or 0) == 0 and (J.potY or 0) == 0 then
        J.potAnim = nil
        return
    end
    J.potAnim = { x0 = J.potX or 0, y0 = J.potY or 0, x1 = 0, y1 = 0, t = 0, dur = 0.26 }
end

function J.PotSlide(won)
    if not J.pot then return end
    J.potAtWinner = true
    J.potAnim = {
        x0 = J.potX or 0,
        y0 = J.potY or 0,
        x1 = won and -170 or 170,
        y1 = -2,
        t = 0,
        dur = 0.42,
    }
end''',
    "pot movement",
)

swap(
    '''    J.hold = { s = s, t = HOLD, won = won }''',
    '''    J.PotSlide(won)
    J.hold = { s = s, t = HOLD, won = won }''',
    "ceremony slide",
)

swap(
    '''        J.span, J.done, J.hold = nil, nil, nil
        if s and not s.finished and s.wager then''',
    '''        J.span, J.done, J.hold = nil, nil, nil
        J.PotHome()
        if s and not s.finished and s.wager then''',
    "state home",
)

swap(
    '''    if el > 0.1 then el = 0.1 end

    J.Pace()''',
    '''    if el > 0.1 then el = 0.1 end

    if J.pot then
        if J.potAnim then
            local a = J.potAnim
            a.t = a.t + el
            local k = min(1, a.t / a.dur)
            k = k * k * (3 - 2 * k)
            J.potX = a.x0 + (a.x1 - a.x0) * k
            J.potY = a.y0 + (a.y1 - a.y0) * k
            J.pot.body:SetPoint("CENTER", J.pot, "CENTER", J.potX, J.potY)
            if k >= 1 then J.potAnim = nil end
        end
        local target = J.potLive and 1 or 0.84
        J.potA = J.potA or 0.84
        J.potA = J.potA + (target - J.potA) * min(1, el * 8)
        J.pot.body:SetAlpha(J.potA)
    end

    J.Pace()''',
    "pot step",
)

swap(
    '''        J.Sound("LOOT_ROLL_LOST")
    end
end''',
    '''        J.Sound("LOOT_ROLL_LOST")
    end

    J.PotHome()
end''',
    "result home",
)

path.write_text(src)
print("patched")

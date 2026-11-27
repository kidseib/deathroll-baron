import pathlib

path = pathlib.Path("addon/DeathrollBaron/DeathrollBaron.lua")
src = path.read_text()

if "J.PotCoin" in src:
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
    '''    -- the pot: a small stack of coins on the board seam, above both panels.
    -- The seam anchor stays fixed; only the inner body slides to the winner.
    local rail = J.fx:CreateTexture(nil, "BACKGROUND", nil, 1)
    rail:SetSize(1, 68)
    rail:SetPoint("CENTER", W.youPanel, "TOPRIGHT", 8, -32)
    rail:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.22)

    local pot = CreateFrame("Frame", nil, J.fx)
    pot:SetSize(26, 50)
    pot:SetPoint("CENTER", W.youPanel, "TOPRIGHT", 8, -30)
    pot.body = CreateFrame("Frame", nil, J.fx)
    pot.body:SetSize(26, 50)
    pot.body:SetPoint("CENTER", pot, "CENTER", 0, 0)

    -- a soft base and a dark plate keep the stack seated and the stake legible
    local base = pot.body:CreateTexture(nil, "BACKGROUND")
    base:SetSize(34, 8)
    base:SetPoint("BOTTOM", 0, -1)
    base:SetColorTexture(0, 0, 0, 0.38)
    local baseSoft = pot.body:CreateTexture(nil, "BACKGROUND")
    baseSoft:SetSize(42, 12)
    baseSoft:SetPoint("BOTTOM", 0, -3)
    baseSoft:SetColorTexture(0, 0, 0, 0.18)
    local plate = pot.body:CreateTexture(nil, "BACKGROUND")
    plate:SetSize(46, 14)
    plate:SetPoint("TOP", 0, -1)
    plate:SetColorTexture(0.035, 0.030, 0.024, 0.80)

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

    local coin = J.fx:CreateTexture(nil, "OVERLAY", nil, 6)
    coin:SetTexture(J.COIN)
    coin:SetSize(13, 13)
    coin:SetAlpha(0)
    coin:Hide()

    J.pot = pot
    J.potCoin = coin
    J.potX, J.potY = 0, 0
    J.potA = 0.84
    J.potAtWinner = false
    J.potHidden = false
    J.pot.body:SetAlpha(J.potA)
    J.Pot()''',
    "pot seat",
)

swap(
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

function J.PotReset()
    if not J.pot then return end
    J.potAnim = nil
    J.potX, J.potY = 0, 0
    J.potAtWinner = false
    J.potHidden = false
    J.pot.body:SetPoint("CENTER", J.pot, "CENTER", 0, 0)
    J.pot.body:Show()
    J.potA = 0.84
    J.pot.body:SetAlpha(J.potA)
end

function J.PotCoin()
    if not J.pot or not J.potCoin then return end
    local x0, y0 = J.Center(J.pot.body)
    local x1, y1 = J.Center(W.gold)
    J.coinAnim = { x0 = x0, y0 = y0, x1 = x1, y1 = y1, t = 0, dur = 0.55 }
    J.potCoin:SetPoint("CENTER", J.fx, "CENTER", x0, y0)
    J.potCoin:SetAlpha(1)
    J.potCoin:Show()
end

function J.PotSink()
    if not J.pot then return end
    J.potAtWinner = true
    J.potAnim = {
        x0 = J.potX or 0,
        y0 = J.potY or 0,
        x1 = (J.potX or 0) + 6,
        y1 = (J.potY or 0) - 20,
        t = 0,
        dur = 0.38,
        fade = true,
        a0 = J.potA or 1,
    }
end

function J.PotResult(s)
    if not J.pot then return end
    if s.result == "win" then
        J.potAtWinner = true
        J.PotCoin()
    else
        J.PotSink()
    end
end

function J.PotSlide(won)
    if not J.pot then return end
    J.potHidden = false
    J.pot.body:Show()
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
    "pot settlement",
)

swap(
    '''        J.Sound("LOOT_ROLL_LOST")
    end

    J.PotHome()
end''',
    '''        J.Sound("LOOT_ROLL_LOST")
    end

    J.PotResult(s)
end''',
    "result split",
)

swap(
    '''        J.span, J.done, J.hold = nil, nil, nil
        J.PotHome()''',
    '''        J.span, J.done, J.hold = nil, nil, nil
        J.PotReset()''',
    "state reset",
)

swap(
    '''    if J.pot then
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
    end''',
    '''    if J.pot then
        if J.potAnim then
            local a = J.potAnim
            a.t = a.t + el
            local k = min(1, a.t / a.dur)
            k = k * k * (3 - 2 * k)
            J.potX = a.x0 + (a.x1 - a.x0) * k
            J.potY = a.y0 + (a.y1 - a.y0) * k
            J.pot.body:SetPoint("CENTER", J.pot, "CENTER", J.potX, J.potY)
            if a.fade then
                J.potA = (a.a0 or 1) * (1 - k)
                J.pot.body:SetAlpha(J.potA)
            end
            if k >= 1 then
                J.potAnim = nil
                if a.fade then
                    J.pot.body:Hide()
                    J.potHidden = true
                    J.potAtWinner = false
                end
            end
        elseif not J.potHidden then
            local target = (J.potLive or J.potAtWinner) and 1 or 0.84
            J.potA = J.potA or 0.84
            J.potA = J.potA + (target - J.potA) * min(1, el * 8)
            J.pot.body:SetAlpha(J.potA)
        end
    end

    if J.coinAnim and J.potCoin then
        local c = J.coinAnim
        c.t = c.t + el
        local k = min(1, c.t / c.dur)
        local x = c.x0 + (c.x1 - c.x0) * k
        local y = c.y0 + (c.y1 - c.y0) * k + math.sin(k * math.pi) * 36
        J.potCoin:SetPoint("CENTER", J.fx, "CENTER", x, y)
        J.potCoin:SetAlpha(k > 0.88 and max(0, 1 - (k - 0.88) / 0.12) or 1)
        if k >= 1 then
            J.coinAnim = nil
            J.potCoin:Hide()
        end
    end''',
    "step settle",
)

path.write_text(src)
print("patched")

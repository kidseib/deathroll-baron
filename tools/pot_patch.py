import pathlib

path = pathlib.Path("addon/DeathrollBaron/DeathrollBaron.lua")
src = path.read_text()

if "J.pot" in src:
    raise SystemExit("already applied")


def swap(old, new, label):
    global src
    n = src.count(old)
    if n != 1:
        i = src.find(old.splitlines()[0])
        raise SystemExit("%s: %d matches\n%s" % (label, n, repr(src[i:i + 220])))
    src = src.replace(old, new, 1)
    print("ok", label)


swap(
    '''        J.texts[i] = { fs = fs, life = 0, x = 0, y = 0, vy = 0 }
    end
end''',
    '''        J.texts[i] = { fs = fs, life = 0, x = 0, y = 0, vy = 0 }
    end

    -- the pot: a small stack of coins on the board seam, above both panels.
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
    J.Pot()
end''',
    "pot stack",
)

swap(
    '''function J.Sync()''',
    '''function J.Pot()
    if not J.pot then return end
    local s = state
    local stake = (s and not s.finished and s.wager) or ns.wager or 0
    J.pot.label:SetText(Money(stake))
end

function J.Sync()''',
    "pot update",
)

swap(
    '''    J.Sync()
    J.ReelPaint()''',
    '''    J.Sync()
    J.Pot()
    J.ReelPaint()''',
    "refresh hook",
)

path.write_text(src)
print("patched")

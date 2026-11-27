import pathlib

path = pathlib.Path("addon/DeathrollBaron/DeathrollBaron.lua")
src = path.read_text()


def swap(old, new, label):
    global src
    n = src.count(old)
    if n != 1:
        raise SystemExit("%s: %d matches" % (label, n))
    src = src.replace(old, new, 1)
    print("ok", label)


swap(
    '''    pot.coins = {}
    for i = 1, 4 do
        local c = pot.body:CreateTexture(nil, "OVERLAY", nil, i)
        c:SetTexture(i % 2 == 0 and J.COIN2 or J.COIN)
        c:SetSize(18, 18)
        c:SetPoint("CENTER", pot.body, "CENTER", (i % 2 == 0) and 1 or -1, -16 + (i - 1) * 4)
        c:SetAlpha(1)
        pot.coins[i] = c
    end''',
    '''    pot.coins = {}
    -- stake tiers: 3 coins, then one more at 10s, 1g and 10g.
    -- The label still carries the exact amount.
    for i = 1, 6 do
        local c = pot.body:CreateTexture(nil, "OVERLAY", nil, i)
        c:SetTexture(i % 2 == 0 and J.COIN2 or J.COIN)
        c:SetSize(18, 18)
        c:SetPoint("CENTER", pot.body, "CENTER", (i % 2 == 0) and 1 or -1, -16 + (i - 1) * 4)
        c:SetAlpha(1)
        c:Hide()
        pot.coins[i] = c
    end''',
    "coin stack",
)

swap(
    '''    J.pot.label:SetText(Money(stake))
end''',
    '''    J.pot.label:SetText(Money(stake))
    local coins = 3
    if stake >= 100000 then coins = 6
    elseif stake >= 10000 then coins = 5
    elseif stake >= 1000 then coins = 4 end
    for i = 1, #J.pot.coins do
        if i <= coins then J.pot.coins[i]:Show() else J.pot.coins[i]:Hide() end
    end
end''',
    "stake tiers",
)

checks = {
    "six textures": ("for i = 1, 6 do", 4),
    "stake tiers": ("stake tiers: 3 coins", 1),
    "tier six": ("if stake >= 100000 then coins = 6", 1),
    "exact label": ("J.pot.label:SetText(Money(stake))", 1),
    "show call": ("J.pot.coins[i]:Show()", 1),
}
for name, (needle, want) in checks.items():
    n = src.count(needle)
    if n != want:
        raise SystemExit("%s: %d occurrences (want %d)" % (name, n, want))
    print("ok check", name)

path.write_text(src)
print("patched")

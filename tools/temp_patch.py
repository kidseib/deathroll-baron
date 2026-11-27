import pathlib, sys

path = pathlib.Path("addon/DeathrollBaron/DeathrollBaron.lua")
src = path.read_text()

if "PowerLabel" in src:
    print("already applied")
    sys.exit(0)

def once(old, new):
    global src
    n = src.count(old)
    if n != 1:
        raise SystemExit("anchor %d: %r" % (n, old[:70]))
    src = src.replace(old, new)

# one formatter for the shop buttons, sat next to the cost it prints
once('''local function PowerCost(p)
    local r = DB.powers[p.id] or 0
    local cost = p.base * (1.75 ^ r)
    cost = cost * (1 - 0.05 * (DB.prestige.inside or 0))
    return max(5, floor(floor(cost / 5 + 0.5) * 5))
end
''', '''local function PowerCost(p)
    local r = DB.powers[p.id] or 0
    local cost = p.base * (1.75 ^ r)
    cost = cost * (1 - 0.05 * (DB.prestige.inside or 0))
    return max(5, floor(floor(cost / 5 + 0.5) * 5))
end

-- one label for every shop button: Build and Refresh both call it, so the
-- rank and the price can never drift apart
local function PowerLabel(p, r, cost)
    if r >= p.max then return p.name .. "  maxed" end
    return ("%s  %d/%d   %s"):format(p.name, r, p.max, Money(cost or PowerCost(p)))
end
''')

# Build: same helper, current rank
once('("%s  %s"):format(p.name, Money(PowerCost(p)))',
     'PowerLabel(p, DB.powers[p.id] or 0)')

# Refresh: maxed and priced branches, same helper
once('b:SetText(p.name .. "  maxed")',
     'b:SetText(PowerLabel(p, r))')
once('b:SetText(("%s %d/%d   %s"):format(p.name, r, p.max, Money(cost)))',
     'b:SetText(PowerLabel(p, r, cost))')

# the two blank lines left where W.luck was hidden
once('''    J.bar = bar


    local glow''', '''    J.bar = bar

    local glow''')

path.write_text(src)
print("patched", len(src), "bytes")

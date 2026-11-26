import io, sys

LUA = 'addon/DeathrollBaron/DeathrollBaron.lua'
LOG = 'CHANGELOG.md'
s = io.open(LUA, encoding='utf-8').read()


def rep(text, old, new, label):
    n = text.count(old)
    if n != 1:
        print('FAIL %s: %d' % (label, n))
        sys.exit(1)
    print('ok %s' % label)
    return text.replace(old, new, 1)


s = rep(s,
'''function J.Odds()
    if not J.ready or not DB then return end''',
'''-- The bar is a single 384px line, so a zero unit is dropped rather than
-- padded: "116g 3s", "116g", "50s", "25c". Nothing nonzero is rounded.
local function BarMoney(c)
    c = floor((c or 0) + 0.5)
    if c < 0 then return "-" .. BarMoney(-c) end
    local g = floor(c / 10000)
    local s = floor((c % 10000) / 100)
    local cu = c % 100
    if g > 0 then
        if s > 0 then return Comma(g) .. "g " .. s .. "s" end
        return Comma(g) .. "g"
    end
    if s > 0 then
        if cu > 0 then return s .. "s " .. cu .. "c" end
        return s .. "s"
    end
    return cu .. "c"
end

local function BarSigned(c)
    c = floor((c or 0) + 0.5)
    if c < 0 then return "-" .. BarMoney(-c) end
    return "+" .. BarMoney(c)
end

function J.Odds()
    if not J.ready or not DB then return end''',
'bar money')

s = rep(s,
'''    J.bar.text:SetText(("%d%% YOU  .  pays %s  .  risk %s  .  EV %s"):format(
        pct, Money(payout), Money(risk), Signed(ev)))''',
'''    J.bar.text:SetText(("%d%% . pays %s . risk %s . EV %s"):format(
        pct, BarMoney(payout), BarMoney(risk), BarSigned(ev)))''',
'bar line')

log = io.open(LOG, encoding='utf-8').read()
log = rep(log,
'''- **The odds bar carries the hand's EV.** `57% YOU . pays 2g 40s . risk 50s . EV +37c` is
  `chance x (payout - stake) - (1 - chance) x loss`. It uses the same `WinChance` that draws the
  bar, and it shows the selected rung while idle, so a rung can be judged before the auto-spin
  leaves it.''',
'''- **The odds bar carries the hand's EV.** `57% . pays 2g 40s . risk 50s . EV +37c` is
  `chance x (payout - stake) - (1 - chance) x loss`. It uses the same `WinChance` that draws the
  bar, and it shows the selected rung while idle, so a rung can be judged before the auto-spin
  leaves it. The bar drops zero units (`116g`, not `116g 0s`) and the redundant `YOU`, so the
  longest realistic line - `100% . pays 116g 3s . risk 2,997g . EV -1,900g` at 46 characters -
  fits the 384px bar with room to spare.''',
'changelog')

for token in ('local function BarMoney', 'local function BarSigned', 'BarMoney(payout), BarMoney(risk), BarSigned(ev)'):
    if token not in s:
        print('FAIL: missing %r' % token)
        sys.exit(1)
if 'YOU  .  pays' in s:
    print('FAIL: the old bar line survived')
    sys.exit(1)

io.open(LUA, 'w', encoding='utf-8', newline='\n').write(s)
io.open(LOG, 'w', encoding='utf-8', newline='\n').write(log)
print('PATCH OK: lua %d bytes' % len(s))

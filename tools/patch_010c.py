import io, re, sys

LUA = 'addon/DeathrollBaron/DeathrollBaron.lua'
CHG = 'CHANGELOG.md'

def read(p):
    f = io.open(p, 'r', encoding='utf-8', newline='')
    s = f.read()
    f.close()
    return s

def write(p, s):
    f = io.open(p, 'w', encoding='utf-8', newline='')
    f.write(s)
    f.close()

def sub1(text, pattern, build, label):
    rx = re.compile(pattern, re.S)
    n = len(rx.findall(text))
    if n != 1:
        sys.exit(label + ': matched ' + str(n) + ' times')
    print('anchor ok: ' + label)
    return rx.sub(build, text, count=1)

BLOCK = '''---------------------------------------------------------------------
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

'''

lua = read(LUA)
if 'function J.Sync' in lua:
    sys.exit('lua already patched')
lines0 = lua.count('\n')

lua = sub1(lua,
    r'\n    local s = state\n    if s ~= J\.seenState then.*?\n        J\.EndCheck\(\)\n    end\n',
    lambda m: '', 'step detection removed')

lua = sub1(lua,
    r'ns\.Refresh = function\(\.\.\.\)\n    if jbase then jbase\(\.\.\.\) end\n    J\.ReelPaint\(\)\n    J\.EndCheck\(\)\n    J\.HoldPaint\(\)\n    J\.Odds\(\)\nend\n',
    lambda m: 'ns.Refresh = function(...)\n    if jbase then jbase(...) end\n    J.Sync()\n    J.ReelPaint()\n    J.Odds()\nend\n',
    'wrapper')

marker = '-- 0.0.10: pace, reel, and a ceremony for the one'
i = lua.find(marker)
if i < 0:
    sys.exit('block marker missing')
line_start = lua.rfind('\n', 0, i) + 1
dash_start = lua.rfind('\n', 0, line_start - 1) + 1
j = lua.find('local jbase = ns.Refresh\n', i)
if j < 0:
    sys.exit('jbase marker missing')
lua = lua[:dash_start] + BLOCK + lua[j:]
print('block replaced')

for gone in ['J.seenResult', 'J.prevMax', 'J.seenP', 'J.seenE', 'J.EndCheck', 'J.HoldPaint', 'J.SettleAll']:
    if gone in lua:
        sys.exit('leftover reference: ' + gone)
for need in ['function J.Sync', 'function J.ReelSettle', 'function J.TickHold', '    J.Sync()']:
    if need not in lua:
        sys.exit('missing after patch: ' + need)

write(LUA, lua)
print('lua lines ' + str(lines0) + ' -> ' + str(lua.count('\n')))

chg = read(CHG)
chg = sub1(chg,
    r'`J\.paceBase` is captured per hand, which keeps Fast\s+Hands fast instead of flattening it back to the default\.',
    lambda m: 'The base is cached on the hand table, which keeps Fast\n  Hands fast instead of flattening it back to the default.',
    'changelog pace')
chg = sub1(chg,
    r'`ns\.Refresh` rewrites both numbers every tick, so the wrapper repaints\s+the reel after it and the real number cannot leak a frame early\.',
    lambda m: 'Rolls are detected in the refresh wrapper rather than a frame later, so\n  the reel starts over the number in the same paint and the real number never shows first.',
    'changelog reel')
write(CHG, chg)
print('changelog updated')
print('done')

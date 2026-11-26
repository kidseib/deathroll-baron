import io, sys

LUA = 'addon/DeathrollBaron/DeathrollBaron.lua'
s = io.open(LUA, encoding='utf-8').read()


def rep(old, new, label):
    global s
    n = s.count(old)
    if n != 1:
        print('FAIL %s: %d' % (label, n))
        sys.exit(1)
    print('ok %s' % label)
    s = s.replace(old, new, 1)


rep('''local function BarMoney(c)
    c = floor((c or 0) + 0.5)
    if c < 0 then return "-" .. BarMoney(-c) end
    local g = floor(c / 10000)''',
'''local function BarMoney(c)
    c = floor((c or 0) + 0.5)
    local g = floor(c / 10000)''',
'bar money sign')

rep('local REEL_READ = 0.10',
'''local REEL_READ = 0.10
-- Three frames: shorter than this, a scramble is never seen.
local MIN_SPIN = 0.05''',
'min spin')

rep('if gap and gap - REEL_READ < 0.05 then',
    'if gap and gap - REEL_READ < MIN_SPIN then',
    'skip threshold')

rep('''    -- Fast Hands can make a tick shorter than the reel. Reserve REEL_READ
    -- of the gap for the landing, with a floor so the spin is never zero.
    if gap then
        J.reel.life = max(0.05, min(J.reel.life, gap - REEL_READ))
    end''',
'''    -- Fast Hands can make a tick shorter than the reel. Reserve REEL_READ
    -- of the gap for the landing; the skip above already guarantees that a
    -- scrambling reel gets at least MIN_SPIN.
    if gap then
        J.reel.life = min(J.reel.life, gap - REEL_READ)
    end''',
'reel life floor')

rep('    if ns.autoT < ns.AutoPause(s) then return end',
    '    if ns.autoT < ns.AutoPause(s) or J.hold then return end',
    'hold guard')

if 'max(0.05, min(J.reel.life' in s:
    print('FAIL: reel floor survived')
    sys.exit(1)
if s.count('if c < 0 then return "-" .. BarMoney(-c) end') != 1:
    print('FAIL: signed negative branch count')
    sys.exit(1)
if 'local MIN_SPIN = 0.05' not in s or 'gap - REEL_READ < MIN_SPIN' not in s:
    print('FAIL: min spin missing')
    sys.exit(1)

io.open(LUA, 'w', encoding='utf-8', newline='\n').write(s)
print('PATCH OK: lua %d bytes' % len(s))

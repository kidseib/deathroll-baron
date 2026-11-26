import io, re, sys

LUA = 'addon/DeathrollBaron/DeathrollBaron.lua'
TOC = 'addon/DeathrollBaron/DeathrollBaron.toc'
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

def swap(text, old, new, label):
    n = text.count(old)
    if n != 1:
        sys.exit(label + ': anchor found ' + str(n) + ' times')
    print('anchor ok: ' + label)
    return text.replace(old, new, 1)

A1 = '''    if el > 0.1 then el = 0.1 end

    local s = state
'''
B1 = '''    if el > 0.1 then el = 0.1 end

    J.Pace()
    J.TickReels(el)
    J.TickHold(el)

    local s = state
'''

A2 = '''        J.scaleYou, J.scaleThem = 1, 1
    end
'''
B2 = '''        J.scaleYou, J.scaleThem = 1, 1
        J.prevMax = nil
    end
'''

A3 = '''                if s.lastPlayer then J.Roll("you") end
'''
B3 = '''                if s.lastPlayer then J.ReelStart("you", s.lastPlayer) end
'''

A4 = '''                if s.lastEnemy then J.Roll("them") end
'''
B4 = '''                if s.lastEnemy then J.ReelStart("them", s.lastEnemy) end
'''

A5 = '''        J.seenResult = s.result or "win"
        J.Result(s)
'''
B5 = '''        J.seenResult = s.result or "win"
        J.Ceremony(s)
'''

A6 = '''ns.Refresh = function(...)
    if jbase then jbase(...) end
    J.Odds()
end
'''
B6 = '''ns.Refresh = function(...)
    if jbase then jbase(...) end
    J.ReelPaint()
    J.Odds()
end
'''

BLOCK = '''---------------------------------------------------------------------
-- 0.0.10: pace, reel, and a ceremony for the one
-- Still additive: the odds solver, the match engine and the save file
-- are untouched. These three only change what the table feels like.
---------------------------------------------------------------------

-- The base ticker re-reads cfg.speed after every roll, so the tension
-- curve is written straight onto the live config: wide ranges run brisk
-- and the ticker drags as the range closes. J.paceBase is captured once
-- per hand, which keeps Fast Hands fast instead of flattening it to 0.85.
function J.PaceK(m, ceiling)
    local frac = m / max(1, ceiling)
    if frac > 1 then frac = 1 end
    if frac < 0 then frac = 0 end
    return min(1.50, max(0.62, 0.70 + 0.95 * (1 - frac) ^ 1.7))
end

function J.Pace()
    local s = state
    if not s then
        J.paceState = nil
        return
    end
    if J.paceState ~= s then
        J.paceState = s
        J.paceBase = (s.cfg and s.cfg.speed) or 0.85
    end
    if s.finished or s.manual or not s.cfg then return end
    s.cfg.speed = J.paceBase * J.PaceK(s.max or 1, s.cfg.ceiling or 100)
end

-- The reel: the number spins inside the range it was rolled in, then
-- lands. ns.Refresh rewrites both numbers on every tick, so the wrapper
-- repaints the reel after it; a reel in flight wins the frame, which is
-- what stops the real number leaking a frame early.
J.reelYou, J.reelThem, J.prevMax = nil, nil, nil

function J.ReelStart(side, value)
    local s = state
    local ceiling = (s and s.cfg and s.cfg.ceiling) or 100
    local span = J.prevMax or ceiling
    if span < 2 then span = 2 end
    local frac = min(1, (s and s.max or span) / max(1, ceiling))
    local t = { value = value, span = span, life = 0.16 + 0.18 * (1 - frac) }
    if side == 'you' then J.reelYou = t else J.reelThem = t end
    J.prevMax = s and s.max or nil
    J.Roll(side)
end

function J.ReelPaint()
    if J.reelYou and W.youNum then
        W.youNum:SetText(tostring(random(1, J.reelYou.span)))
    end
    if J.reelThem and W.themNum then
        W.themNum:SetText(tostring(random(1, J.reelThem.span)))
    end
end

function J.ReelSettle(t, fs, side)
    if not t or not fs then return nil end
    if t.life > 0 then return t end
    fs:SetText(tostring(t.value))
    if side == 'you' then J.scaleYou = 1.30 else J.scaleThem = 1.30 end
    return nil
end

function J.TickReels(el)
    if J.reelYou then
        J.reelYou.life = J.reelYou.life - el
        J.reelYou = J.ReelSettle(J.reelYou, W.youNum, 'you')
    end
    if J.reelThem then
        J.reelThem.life = J.reelThem.life - el
        J.reelThem = J.ReelSettle(J.reelThem, W.themNum, 'them')
    end
end

function J.SettleAll()
    if J.reelYou and W.youNum then W.youNum:SetText(tostring(J.reelYou.value)) end
    if J.reelThem and W.themNum then W.themNum:SetText(tostring(J.reelThem.value)) end
    J.reelYou, J.reelThem = nil, nil
end

-- The one. Every hand ends here, so this is the beat that has to land:
-- the losing number slams up, the table holds, and only then the verdict.
J.hold = nil

function J.Ceremony(s)
    J.SettleAll()
    local one = ((s.lastEnemy == 1) and 'them') or ((s.lastPlayer == 1) and 'you') or nil
    if not one then
        J.Result(s)
        return
    end
    local won = (one == 'them')
    local panel = won and W.themPanel or W.youPanel
    if won then J.scaleThem = 2.5 else J.scaleYou = 2.5 end
    local x, y = J.Center(panel)
    J.Burst(x, y, 22, true)
    J.Burst(x, y - 24, 10, true)
    if won then
        J.Float(0, 150, 'THEY ROLL A ONE', 22, GOLD, 1.5)
        if J.glow then J.glow:SetColorTexture(1, 0.84, 0.28, 1) end
    else
        J.Float(0, 150, 'A ONE. THE POT GOES.', 20, RED, 1.5)
        if J.glow then J.glow:SetColorTexture(0.78, 0.16, 0.12, 1) end
    end
    J.glowA = 0.40
    J.hold = { s = s, t = 0.55, one = one }
end

function J.TickHold(el)
    local h = J.hold
    if not h then return end
    if state ~= h.s then
        J.hold = nil
        return
    end
    h.t = h.t - el
    if h.t <= 0 then
        J.hold = nil
        J.Result(h.s)
        return
    end
    if h.t > 0.12 then
        local slam = 2.0 + 0.6 * (h.t / 0.55)
        if h.one == 'them' then J.scaleThem = slam else J.scaleYou = slam end
    end
end

'''

SECTION = '''## [0.0.10] \u2014 2026-11-26

The table learns to hold its breath: the ticker, the number and the one all get their own timing.

### Added

- **A tension curve on the roll ticker.** `J.PaceK` maps the live range onto a multiplier: the
  opening rolls run at about 0.7x, the middle is neutral, and the last few drag at up to 1.5x. It is
  written onto `cfg.speed` between rolls, and the ticker re-reads that field every time it schedules
  itself, so the match engine did not change. `J.paceBase` is captured per hand, which keeps Fast
  Hands fast instead of flattening it back to the default.
- **A reel on the number.** A roll now spins for 160-340ms inside the range it was rolled in, then
  lands with a small punch. `ns.Refresh` rewrites both numbers every tick, so the wrapper repaints
  the reel after it and the real number cannot leak a frame early.
- **A ceremony for the one.** Every hand ends on a 1, so that is the beat worth staging: the losing
  number slams to 2.5x, the frame glow spikes, a line hangs above the board (`THEY ROLL A ONE` in
  gold, `A ONE. THE POT GOES.` in red), and the verdict is held back 550ms so the hand lands before
  the money does.

### Changed

- Roll cadence is no longer one flat 0.85s. A hand opens quick, slows as the range closes, and
  finishes on a held beat. Manual (shift-click) matches keep their one-roll-per-click feel.

### Note

Schema is still 5, and `OddsUpTo` / `WinChance` are untouched: this pass draws, times and sequences,
and never changes what is rolled or what is saved. Still not seen in game.

'''

lua = read(LUA)
if 'J.PaceK' in lua:
    sys.exit('lua already patched')
lines0 = lua.count('\n')

lua = swap(lua, A1, B1, 'step prologue')
lua = swap(lua, A2, B2, 'per-hand reset')
lua = swap(lua, A3, B3, 'you reel')
lua = swap(lua, A4, B4, 'them reel')
lua = swap(lua, A5, B5, 'finish hook')
lua = swap(lua, A6, B6, 'refresh wrapper')
lua = swap(lua, 'local jbase = ns.Refresh\n', BLOCK + 'local jbase = ns.Refresh\n', 'module block')

write(LUA, lua)
print('lua lines ' + str(lines0) + ' -> ' + str(lua.count('\n')))

toc = read(TOC)
if '## Version: 0.0.10' in toc:
    sys.exit('toc already 0.0.10')
toc2 = re.sub(r'^## Version: .*$', '## Version: 0.0.10', toc, count=1, flags=re.M)
if toc2 == toc:
    sys.exit('toc version line not found')
write(TOC, toc2)
print('toc bumped to 0.0.10')

chg = read(CHG)
if '## [0.0.10]' in chg:
    sys.exit('changelog already has 0.0.10')
m = re.search(r'^## \[0\.0\.\d+\]', chg, re.M)
if not m:
    sys.exit('changelog: no release heading found')
write(CHG, chg[:m.start()] + SECTION + chg[m.start():])
print('changelog section inserted before char ' + str(m.start()))
print('done')

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
'''local HOLD = 0.55''',
'''local HOLD = 0.55
-- About six frames at 60fps: the time a settled number needs on screen
-- before the next roll repaints the panel.
local REEL_READ = 0.10''',
'read constant')

s = rep(s,
'''function J.ReelStart(side, value)
    J.ReelSettle()
    local s = state
    local fs = side == 'you' and W.youNum or W.themNum
    if not fs then return end
    J.reel = {
        side = side, fs = fs, value = value,
        span = J.span or s.cfg.ceiling,
        life = 0.16 + 0.18 * (1 - s.max / s.cfg.ceiling),
    }
    -- Fast Hands can make a tick shorter than a reel, and a reel that is
    -- still spinning when the next number lands never shows a number at
    -- all. Cap its life under the gap the ticker actually scheduled, timed
    -- from the range the gap was measured on (J.span, the previous number).
    if not s.manual and s.paceBase then
        local gap = s.cfg.speed
        if J.span then gap = min(gap, s.paceBase * J.PaceK(J.span, s.cfg.ceiling)) end
        J.reel.life = max(0.05, min(J.reel.life, gap * 0.75))
    end
    J.span = s.max
    J.Roll(side)
end''',
'''function J.ReelStart(side, value)
    J.ReelSettle()
    local s = state
    local fs = side == 'you' and W.youNum or W.themNum
    if not fs then return end

    -- The gap the ticker actually scheduled for the next roll. It was timed
    -- from the range before this one, which is J.span here.
    local gap
    if not s.manual and s.paceBase then
        gap = s.cfg.speed
        if J.span then gap = min(gap, s.paceBase * J.PaceK(J.span, s.cfg.ceiling)) end
    end

    -- If the gap cannot fit a scramble and still leave REEL_READ for the
    -- landing, skip the scramble: the true number ns.Refresh already
    -- painted stays up for the whole gap, and only the punch remains.
    if gap and gap - REEL_READ < 0.05 then
        if side == 'you' then J.scaleYou = 1.30 else J.scaleThem = 1.30 end
        J.span = s.max
        J.Roll(side)
        return
    end

    J.reel = {
        side = side, fs = fs, value = value,
        span = J.span or s.cfg.ceiling,
        life = 0.16 + 0.18 * (1 - s.max / s.cfg.ceiling),
    }
    -- Fast Hands can make a tick shorter than the reel. Reserve REEL_READ
    -- of the gap for the landing, with a floor so the spin is never zero.
    if gap then
        J.reel.life = max(0.05, min(J.reel.life, gap - REEL_READ))
    end
    J.span = s.max
    J.Roll(side)
end''',
'reel start')

log = io.open(LOG, encoding='utf-8').read()
log = rep(log,
'''- **The reel lands at Fast Hands speeds.** A reel lives 0.16-0.34s, but the ticker runs at
  0.08-0.18s with Fast Hands and the opening curve, so the next number used to arrive while the
  reel was still spinning and the real number was never on screen. Reel life is now capped just
  under the gap the ticker actually scheduled, with a 0.05s floor.''',
'''- **The reel lands, or it does not scramble at all.** A reel lives 0.16-0.34s, but the ticker
  runs at 0.08-0.18s with Fast Hands and the opening curve, so the next number used to arrive
  while the reel was still spinning. Reel life now reserves 100ms of the gap for the landing;
  when the gap cannot fit a scramble and still leave that much, the scramble is skipped and the
  true number stays up for the whole gap. At max Fast Hands that trades a one-frame flash for
  the full tick, and the landing punch still fires.''',
'changelog')

if 'gap * 0.75' in s:
    print('FAIL: the old clamp survived')
    sys.exit(1)
for token in ('local REEL_READ = 0.10', 'gap - REEL_READ < 0.05', 'gap - REEL_READ))'):
    if token not in s:
        print('FAIL: missing %r' % token)
        sys.exit(1)

io.open(LUA, 'w', encoding='utf-8', newline='\n').write(s)
io.open(LOG, 'w', encoding='utf-8', newline='\n').write(log)
print('PATCH OK: lua %d bytes' % len(s))

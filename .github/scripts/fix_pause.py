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
'''-- One pause, not a hold plus a fixed gap. The ceremony already spends
-- HOLD on the one; what is left is a breath sized by the result and by
-- how fast the hand ran, so a fast hand cannot machine-gun and a slow
-- one is not slowed further.''',
'''-- One pause, not a hold plus a fixed gap. The ceremony already spends
-- HOLD on the one; what is left is a breath sized by the result, and
-- shortened by Fast Hands so the ticker's speed is not eaten by it.''',
'comment')

s = rep(s,
'''function ns.AutoPause(s)
    local breath = (s and s.result == "win") and 0.28 or 0.42
    local pace = 1
    if s and s.cfg then pace = J.PaceK(s.max, s.cfg.ceiling) end
    return HOLD + breath * (1.30 - 0.30 * pace)
end''',
'''function ns.AutoPause(s)
    local breath = (s and s.result == "win") and 0.28 or 0.42
    -- Fast Hands shortens every tick, so the breath shrinks with the base
    -- speed: a beat, not a wait, and a fast hand keeps its pace.
    local fast = 1
    if s and s.paceBase and s.paceBase > 0 then fast = ROLL_SPEED / s.paceBase end
    breath = breath * max(0.70, 1 - 0.15 * (fast - 1))
    return HOLD + breath
end''',
'pause')

log = io.open(LOG, encoding='utf-8').read()
log = rep(log,
'''  0.28s after a win and 0.42s after a loss, scaled by `J.PaceK` (about 0.79-1.01s in total), so a
  fast hand does not machine-gun and a slow one is not slowed further. The next deal still never
  lands inside the ceremony.''',
'''  0.28s after a win and 0.42s after a loss, shrinking with `Fast Hands` (about 0.78-0.97s in
  total), so the pause stays a beat instead of becoming the bulk of a fast hand. The next deal
  still never lands inside the ceremony.''',
'changelog')

if 'J.PaceK(s.max, s.cfg.ceiling) end\n    return HOLD' in s:
    print('FAIL: the old pace line survived')
    sys.exit(1)
if 'ROLL_SPEED / s.paceBase' not in s:
    print('FAIL: the fast factor is missing')
    sys.exit(1)

io.open(LUA, 'w', encoding='utf-8', newline='\n').write(s)
io.open(LOG, 'w', encoding='utf-8', newline='\n').write(log)
print('PATCH OK: lua %d bytes' % len(s))

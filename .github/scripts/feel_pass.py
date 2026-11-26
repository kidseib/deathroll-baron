import io, sys

LUA = 'addon/DeathrollBaron/DeathrollBaron.lua'
TOC = 'addon/DeathrollBaron/DeathrollBaron.toc'
LOG = 'CHANGELOG.md'

src = io.open(LUA, encoding='utf-8').read()
juice = src.index('juice: quick-fire layer')
before = len(src)


def guard(text, old, label):
    n = text.count(old)
    if n != 1:
        print('FAIL %s: anchor matched %d' % (label, n))
        sys.exit(1)
    if text.index(old) < juice:
        print('FAIL %s: above the juice module' % label)
        sys.exit(1)


def sub(text, old, new, label):
    guard(text, old, label)
    print('ok %s' % label)
    return text.replace(old, new, 1)


def sub_raw(text, old, new, label):
    n = text.count(old)
    if n != 1:
        print('FAIL %s: anchor matched %d' % (label, n))
        sys.exit(1)
    print('ok %s' % label)
    return text.replace(old, new, 1)


edits = []

edits.append((
    'reel life',
    '''        life = 0.16 + 0.18 * (1 - s.max / s.cfg.ceiling),
    }
    J.span = s.max''',
    '''        life = 0.16 + 0.18 * (1 - s.max / s.cfg.ceiling),
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
    J.span = s.max''',
))

edits.append((
    'auto comment',
    '''-- frame closes, so it can never spend a purse unattended. The delay is
-- longer than the ceremony's hold, so a reveal is never cut short.''',
    '''-- frame closes, so it can never spend a purse unattended. The pause
-- contains the ceremony's hold, so the reveal is still never cut short.''',
))

edits.append((
    'auto pause',
    '''ns.auto = false
ns.autoT = 0
ns.autoDelay = 1.1''',
    '''ns.auto = false
ns.autoT = 0

-- One pause, not a hold plus a fixed gap. The ceremony already spends
-- HOLD on the one; what is left is a breath sized by the result and by
-- how fast the hand ran, so a fast hand cannot machine-gun and a slow
-- one is not slowed further.
function ns.AutoPause(s)
    local breath = (s and s.result == "win") and 0.28 or 0.42
    local pace = 1
    if s and s.cfg then pace = J.PaceK(s.max, s.cfg.ceiling) end
    return HOLD + breath * (1.30 - 0.30 * pace)
end''',
))

edits.append((
    'auto tick',
    '    if ns.autoT < ns.autoDelay then return end',
    '    if ns.autoT < ns.AutoPause(s) then return end',
))

edits.append((
    'ev math',
    '''    local risk = floor(wager * cfg.lossMult * cfg.lossFrac)
    local col = GOLD''',
    '''    local risk = floor(wager * cfg.lossMult * cfg.lossFrac)
    -- what a hand is worth from here: a win is the payout net of the
    -- stake that already left the purse, a loss is the fraction paid back.
    local ev = chance * (payout - wager) - (1 - chance) * risk
    local col = GOLD''',
))

edits.append((
    'ev text',
    '''    J.bar.text:SetText(("%d%% YOU   .   pays %s   .   risk %s"):format(pct, Money(payout), Money(risk)))''',
    '''    J.bar.text:SetText(("%d%% YOU  .  pays %s  .  risk %s  .  EV %s"):format(
        pct, Money(payout), Money(risk), Signed(ev)))''',
))

for label, old, new in edits:
    src = sub(src, old, new, label)

if 'ns.autoDelay' in src:
    print('FAIL: ns.autoDelay survived')
    sys.exit(1)
for token in ('EV %s', 'function ns.AutoPause(s)', 'ns.AutoPause(s) then return end', 'gap * 0.75', 'SCHEMA = 5'):
    if src.count(token) != 1:
        print('FAIL: expected one %r, found %d' % (token, src.count(token)))
        sys.exit(1)

toc = io.open(TOC, encoding='utf-8').read()
toc = sub_raw(toc, '## Version: 0.0.11', '## Version: 0.0.12', 'toc version')

log = io.open(LOG, encoding='utf-8').read()
anchor = '- Challenge your current target; addon-vs-addon multiplayer.\n\n## [0.0.11] \u2014 2026-11-26'
section = '''## [0.0.12] \u2014 2026-11-26

One pause, one number, one reel that lands.

### Changed

- **Auto-spin waits one adaptive pause, not a hold plus a fixed gap.** The ceremony still spends
  its 0.55s on the one, and the fixed 1.1s deal delay is gone. The breath after the headline is
  0.28s after a win and 0.42s after a loss, scaled by `J.PaceK` (about 0.79-1.01s in total), so a
  fast hand does not machine-gun and a slow one is not slowed further. The next deal still never
  lands inside the ceremony.
- **The odds bar carries the hand's EV.** `57% YOU . pays 2g 40s . risk 50s . EV +37c` is
  `chance x (payout - stake) - (1 - chance) x loss`. It uses the same `WinChance` that draws the
  bar, and it shows the selected rung while idle, so a rung can be judged before the auto-spin
  leaves it.

### Fixed

- **The reel lands at Fast Hands speeds.** A reel lives 0.16-0.34s, but the ticker runs at
  0.08-0.18s with Fast Hands and the opening curve, so the next number used to arrive while the
  reel was still spinning and the real number was never on screen. Reel life is now capped just
  under the gap the ticker actually scheduled, with a 0.05s floor.

### Note

Schema is still 5. `OddsUpTo` and `WinChance` are untouched; the EV line only reads them.
Still never played in game - syntax-checked by CI only.

'''
log = sub_raw(log, anchor, '- Challenge your current target; addon-vs-addon multiplayer.\n\n' + section + '## [0.0.11] \u2014 2026-11-26', 'changelog')

io.open(LUA, 'w', encoding='utf-8', newline='\n').write(src)
io.open(TOC, 'w', encoding='utf-8', newline='\n').write(toc)
io.open(LOG, 'w', encoding='utf-8', newline='\n').write(log)
print('PATCH OK: lua %d -> %d bytes' % (before, len(src)))

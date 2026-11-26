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

def resub(text, pattern, build, label):
    rx = re.compile(pattern, re.M)
    n = len(rx.findall(text))
    if n != 1:
        sys.exit(label + ': matched ' + str(n) + ' times')
    print('anchor ok: ' + label)
    return rx.sub(build, text, count=1)

HOLD = '''-- The headline is the verdict, so the beat has to hold it: the base
-- refresh writes 'you take the pot' on the same frame the 1 lands, and
-- this paints over it until the hold is spent, then calls a refresh to
-- reveal the real line.
function J.HoldPaint()
    local h = J.hold
    if not h or not W.range then return end
    if h.won then
        W.range:SetText('a one  .  the pot is coming')
        W.range:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    else
        W.range:SetText('a one  .  the pot is going')
        W.range:SetTextColor(RED[1], RED[2], RED[3])
    end
end

-- One place decides the hand is over. The refresh wrapper reaches this
-- before the verdict can be painted at all; J.Step keeps it as a fallback.
function J.EndCheck()
    local s = state
    if not s or not s.finished or J.seenResult then return end
    J.seenResult = s.result or 'win'
    J.Ceremony(s)
end

'''

NEW = '''- **A ceremony for the one.** Every hand ends on a 1, so that is the beat worth staging: the losing
  number slams to 2.5x and holds, the frame glow spikes, a line hangs above the board
  (`THEY ROLL A ONE` in gold, `A ONE. THE POT GOES.` in red), and the headline holds
  `a one  .  the pot is coming` for 550ms. What is actually deferred is the text: the board flash
  still fires on the 1 in the win/lose colour, and the CHA-CHING or BUSTED float, the payout line and
  the real headline all land together when the beat is spent.
'''

lua = read(LUA)
if 'J.HoldPaint' in lua:
    sys.exit('lua already patched')
if 'J.PaceK' not in lua:
    sys.exit('expected the 0.0.10 module, not found')
lines0 = lua.count('\n')

lua = resub(lua, r'^([ \t]*)J\.seenResult = s\.result or "win"\n\1J\.Ceremony\(s\)',
            lambda m: m.group(1) + 'J.EndCheck()', 'single end check')

lua = resub(lua, r'J\.hold = \{ s = s, t = 0\.55, one = one \}',
            lambda m: 'J.hold = { s = s, t = 0.55, one = one, won = won }', 'hold payload')

lua = resub(lua, r'^([ \t]*)J\.hold = nil\n\1J\.Result\(h\.s\)\n\1return',
            lambda m: m.group(1) + 'J.hold = nil\n' + m.group(1) + 'J.Result(h.s)\n'
                      + m.group(1) + 'ns.Refresh()\n' + m.group(1) + 'return',
            'reveal after the beat')

lua = resub(lua, r'^([ \t]*)J\.ReelPaint\(\)\n\1J\.Odds\(\)',
            lambda m: m.group(1) + 'J.ReelPaint()\n' + m.group(1) + 'J.EndCheck()\n'
                      + m.group(1) + 'J.HoldPaint()\n' + m.group(1) + 'J.Odds()',
            'refresh guard')

lua = resub(lua, r'^function J\.TickHold\(el\)',
            lambda m: HOLD + 'function J.TickHold(el)', 'hold functions')

write(LUA, lua)
print('lua lines ' + str(lines0) + ' -> ' + str(lua.count('\n')))

chg = read(CHG)
old = re.compile(r'- \*\*A ceremony for the one\.\*\*.*?the money does\.\n', re.S)
n = len(old.findall(chg))
if n != 1:
    sys.exit('changelog bullet: ' + str(n) + ' matches')
chg = old.sub(NEW, chg, count=1)
write(CHG, chg)
print('changelog bullet corrected')
print('done')

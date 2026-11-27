import pathlib
import re

# Applies the staggered hand-end beat and the pre-deal pot gate.
path = pathlib.Path("addon/DeathrollBaron/DeathrollBaron.lua")
src = path.read_text()


def swap(old, new, label):
    global src
    n = src.count(old)
    if n != 1:
        i = src.find(old.splitlines()[0]) if old.splitlines() else -1
        raise SystemExit("%s: %d matches\n%s" % (label, n, repr(src[i:i + 500])))
    src = src.replace(old, new, 1)
    print("ok", label)


def replace_between(start, end, new, label):
    global src
    i = src.find(start)
    if i < 0:
        raise SystemExit("%s: start not found" % label)
    j = src.find(end, i)
    if j < 0:
        raise SystemExit("%s: end not found" % label)
    src = src[:i] + new + "\n\n" + src[j:]
    print("ok", label)


# 1. hand-end beat lengths
swap(
    "local HOLD = 0.55",
    "-- The one, then the pot, then the result: each beat gets its own air.\n"
    "local HOLD = 0.72\n"
    "local POT_LEAD = 0.20\n"
    "local POT_SLIDE = 0.42\n"
    "local SLAM_TIME = 0.16",
    "beat lengths",
)

# 2. ceremony: land the one, start no pot motion yet
ceremony = '''function J.Ceremony(s)
    J.ReelSettle()
    local won = (s.lastEnemy == 1)
    J.potAtWinner = true
    if won then J.scaleThem = 2.6 else J.scaleYou = 2.6 end
    local x, y = J.Center(won and W.themPanel or W.youPanel)
    -- the one lands first; the pot gets the next beat to itself
    J.Burst(x, y, 14, true)
    local col = won and GOLD or RED
    if J.glow then J.glow:SetColorTexture(col[1], col[2], col[3], 1) end
    J.glowA = 0.34
    J.hold = { s = s, t = HOLD, won = won, beat = 0, pot = false, slam = SLAM_TIME }
end'''
replace_between("function J.Ceremony(s)", "function J.TickHold(el)", ceremony, "ceremony")

# 3. hold: slam first, pot slide second, result after it lands
tickhold = '''function J.TickHold(el)
    local h = J.hold
    if not h then return end
    h.t = h.t - el
    h.beat = (h.beat or 0) + el
    h.slam = max(0, (h.slam or 0) - el)
    local slam = 2.2 + 0.4 * (h.slam / SLAM_TIME)
    if h.won then J.scaleThem = slam else J.scaleYou = slam end
    if not h.pot and h.beat >= POT_LEAD then
        h.pot = true
        J.PotSlide(h.won)
    end
    if h.t <= 0 then
        J.hold = nil
        J.Result(h.s)
        ns.Refresh()
    end
end'''
replace_between(
    "function J.TickHold(el)",
    "-- Everything that changes when the state changes",
    tickhold,
    "tickhold",
)

# 4. pot step: add the home branch and its arrival state
old_step = re.compile(
    r"(?s)(?P<i>[ \t]*)if a\.fade then\n"
    r"(?P=i)[ \t]+J\.potA = \(a\.a0 or 1\) \* \(1 - k\)\n"
    r"(?P=i)[ \t]+J\.pot\.body:SetAlpha\(J\.potA\)\n"
    r"(?P=i)end\n"
    r"(?P=i)if k >= 1 then\n"
    r"(?P=i)[ \t]+J\.potAnim = nil\n"
    r"(?P=i)[ \t]+if a\.fade then\n"
    r"(?P=i)[ \t]+J\.pot\.body:Hide\(\)\n"
    r"(?P=i)[ \t]+J\.potHidden = true\n"
    r"(?P=i)[ \t]+J\.potAtWinner = false\n"
    r"(?P=i)[ \t]+end\n"
    r"(?P=i)end"
)


def new_step(m):
    i = m.group("i")
    return (
        i + "if a.fade then\n"
        + i + "    J.potA = (a.a0 or 1) * (1 - k)\n"
        + i + "    J.pot.body:SetAlpha(J.potA)\n"
        + i + "elseif a.home then\n"
        + i + "    J.potA = (a.a0 or 1) + (0.84 - (a.a0 or 1)) * k\n"
        + i + "    J.pot.body:SetAlpha(J.potA)\n"
        + i + "end\n"
        + i + "if k >= 1 then\n"
        + i + "    J.potAnim = nil\n"
        + i + "    if a.fade then\n"
        + i + "        J.pot.body:Hide()\n"
        + i + "        J.potHidden = true\n"
        + i + "        J.potAtWinner = false\n"
        + i + "    elseif a.home then\n"
        + i + "        J.potX, J.potY = 0, 0\n"
        + i + "        J.potAtWinner = false\n"
        + i + "        J.potA = 0.84\n"
        + i + "        J.pot.body:SetAlpha(J.potA)\n"
        + i + "        J.Pot()\n"
        + i + "    end\n"
        + i + "end"
    )


src, count = old_step.subn(new_step, src)
if count != 1:
    k = src.find("if a.fade then")
    raise SystemExit("step home branch: %d matches\n%s" % (count, repr(src[k - 200:k + 700])))
print("ok step home branch")

# 5. pot slide duration constant
swap(
    "        dur = 0.42,",
    "        dur = POT_SLIDE,",
    "slide duration",
)

# 6. seating helpers and the pending manual deal, before J.Sync
helpers = '''function J.PotSeated()
    if not J.pot then return true end
    if J.potHidden or J.potAnim then return false end
    return (J.potX or 0) == 0 and (J.potY or 0) == 0
end

-- The pot only leaves the winner when the table is ready to deal again.
function J.PotReturn()
    if not J.pot then return end
    if J.potHidden then
        J.PotReset()
        return
    end
    if J.potAnim then return end
    if (J.potX or 0) == 0 and (J.potY or 0) == 0 then
        J.potAtWinner = false
        J.Pot()
        return
    end
    J.potAnim = {
        x0 = J.potX or 0, y0 = J.potY or 0,
        x1 = 0, y1 = 0,
        t = 0, dur = 0.26, home = true,
        a0 = J.potA or 1,
    }
end

function ns.PotSeat()
    if not J.pot then return true end
    if J.PotSeated() then return true end
    J.PotReturn()
    return J.PotSeated()
end

-- A manual deal waits for the same pot gate as auto.
function J.DealPending()
    local p = ns.pendingDeal
    if not p then return end
    if not frame or not frame:IsShown() then
        ns.pendingDeal = nil
        return
    end
    if p.token ~= stateToken then
        ns.pendingDeal = nil
        return
    end
    if J.hold or J.coinAnim then return end
    if state and not state.finished then
        ns.pendingDeal = nil
        return
    end
    if not J.PotSeated() then
        J.PotReturn()
        if not J.PotSeated() then return end
    end
    ns.pendingDeal = nil
    if StartMatch(ns.selectedRung, ns.wager, p.manual) then
        if p.manual then StepMatch() end
        ns.Refresh()
    end
end'''
swap("function J.Sync()", helpers + "\n\nfunction J.Sync()", "helpers")

# 7. manual roll waits for the return
swap(
    '''    local manual = IsShiftKeyDown() and true or false
    if StartMatch(ns.selectedRung, ns.wager, manual) and manual then
        StepMatch()
    end
    ns.Refresh()
end''',
    '''    local manual = IsShiftKeyDown() and true or false
    -- the pot gets home before the cards hit the felt
    if ns.PotSeat and not ns.PotSeat() then
        ns.pendingDeal = { manual = manual, token = stateToken }
        return
    end
    ns.pendingDeal = nil
    if StartMatch(ns.selectedRung, ns.wager, manual) and manual then
        StepMatch()
    end
    ns.Refresh()
end''',
    "DoRoll gate",
)

# 8. pending manual deal runs after the pot step
swap(
    '''    J.Step(el)
    ns.AutoTick(el)''',
    '''    J.Step(el)
    J.DealPending()
    ns.AutoTick(el)''',
    "driver",
)

# 9. auto waits for the pot to be seated before it deals
swap(
    '''    if ns.autoT < ns.AutoPause(s) or J.hold or J.potAnim or J.coinAnim then return end
    ns.autoT = 0''',
    '''    if ns.autoT < ns.AutoPause(s) or J.hold or J.potAnim or J.coinAnim then return end
    if not J.PotSeated() then
        J.PotReturn()
        if not J.PotSeated() then return end
    end
    ns.pendingDeal = nil
    ns.autoT = 0''',
    "auto gate",
)

# 10. sanity checks
checks = {
    "POT_LEAD": ("local POT_LEAD = 0.20", 1),
    "POT_SLIDE": ("local POT_SLIDE = 0.42", 1),
    "home alpha": ("J.potA = (a.a0 or 1) + (0.84 - (a.a0 or 1)) * k", 1),
    "return": ("function J.PotReturn()", 1),
    "seated": ("function J.PotSeated()", 1),
    "pending": ("function J.DealPending()", 1),
    "pending token": ("if p.token ~= stateToken then", 1),
    "manual gate": ("ns.pendingDeal = { manual = manual, token = stateToken }", 1),
    "auto gate": ("ns.pendingDeal = nil\n    ns.autoT = 0", 1),
    "driver": ("    J.DealPending()\n    ns.AutoTick(el)", 1),
}
for name, (needle, want) in checks.items():
    n = src.count(needle)
    if n != want:
        raise SystemExit("%s: %d occurrences (want %d)" % (name, n, want))
    print("ok check", name)

if "J.PotSlide(won)\n    J.hold" in src:
    raise SystemExit("ceremony still starts the slide")

path.write_text(src)
print("patched")

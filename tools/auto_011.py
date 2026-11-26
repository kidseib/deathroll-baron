import re, sys, pathlib

LUA = pathlib.Path("addon/DeathrollBaron/DeathrollBaron.lua")
TOC = pathlib.Path("addon/DeathrollBaron/DeathrollBaron.toc")
LOG = pathlib.Path("CHANGELOG.md")


def read(p):
    with open(p, "r", encoding="utf-8", newline="") as f:
        return f.read()


def write(p, text):
    with open(p, "w", encoding="utf-8", newline="") as f:
        f.write(text)


src = read(LUA)
NL = "\r\n" if "\r\n" in src else "\n"


def rx_line(line):
    return r"[ \t]+".join(re.escape(t) for t in line.split())


def rx_block(lines):
    return r"[ \t]*" + r"(?:\r?\n[ \t]*)".join(rx_line(l) for l in lines if l.strip())


def swap(text, anchor, repl, label):
    rx = re.compile(rx_block(anchor))
    hits = rx.findall(text)
    if len(hits) != 1:
        print("ANCHOR %s matched %d times, aborting" % (label, len(hits)))
        sys.exit(1)
    print("anchor ok: %s" % label)
    return rx.sub(lambda m: repl.replace("\n", NL), text, count=1)


BUTTON = [
    'W.roll = Btn(frame, "ROLL", 368, 40, 16, function() DoRoll() end)',
    'W.roll:SetPoint("TOP", 0, -424)',
]

BUTTON_NEW = '''    W.roll = Btn(frame, "ROLL", 368, 40, 16, function(_, button)
        if button == "RightButton" then
            ns.auto = not ns.auto
            ns.autoKey, ns.autoT = nil, 0
            ns.Refresh()
            return
        end
        -- a plain click on a live auto hand stops the next deal, not this one
        if ns.auto and not IsShiftKeyDown() and state and not state.finished then
            ns.auto = false
            ns.Refresh()
            return
        end
        DoRoll()
    end)
    W.roll:SetPoint("TOP", 0, -424)
    W.roll:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    W.roll:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("ROLL", GOLD[1], GOLD[2], GOLD[3])
        GameTooltip:AddLine("Left click puts up the stake.", 1, 1, 1)
        GameTooltip:AddLine("Right click turns auto-spin on: the same stake is dealt again after every hand, until you stop it or go broke.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    W.roll:SetScript("OnLeave", function() GameTooltip:Hide() end)'''

LABELS = [
    'if live and state.manual then',
    'W.roll:SetText("ROLL ONE   (click)")',
    'W.hint:SetText("manual: one roll per click, shift or not")',
    'elseif live then',
    'W.roll:SetText("ROLLING")',
    'W.hint:SetText("shift-click to take over")',
    'else',
    'W.roll:SetText("ROLL   " .. Money(ns.wager))',
    'W.hint:SetText("click to auto-roll  .  shift-click to roll it yourself")',
    'end',
]

LABELS_NEW = '''    if live and state.manual then
        W.roll:SetText("ROLL ONE   (click)")
        W.hint:SetText("manual: one roll per click, shift or not")
    elseif live then
        W.roll:SetText(ns.auto and "ROLLING   .   AUTO ON" or "ROLLING")
        W.hint:SetText(ns.auto and "click to stop after this hand" or "shift-click to take over")
    else
        W.roll:SetText((ns.auto and "AUTO ON   .   ROLL " or "ROLL   ") .. Money(ns.wager))
        W.hint:SetText(ns.auto and "the same stake again in a moment  .  right-click to stop"
            or "right-click: auto-spin  .  shift-click: roll one at a time")
    end
    -- the button carries its own state: green and named while auto is on
    local rollFS = W.roll:GetFontString()
    if rollFS then
        local rc = ns.auto and GREEN or BONE
        rollFS:SetTextColor(rc[1], rc[2], rc[3])
    end'''

AUTO_BLOCK = '''---------------------------------------------------------------------
-- auto-spin: the table keeps dealing
-- Session-only on purpose: it is off at login and it stops when the
-- frame closes, so it can never spend a purse unattended. The delay is
-- longer than the ceremony's hold, so a reveal is never cut short.
---------------------------------------------------------------------
ns.auto = false
ns.autoDelay = 1.1

function ns.AutoDeal()
    local cfg = BuildConfig(ns.selectedRung)
    local ok = not DB.ended and DB.gold >= cfg.minWager and ns.wager <= DB.gold
        and StartMatch(ns.selectedRung, ns.wager, false)
    if not ok then ns.auto = false end
    ns.Refresh()
end

function ns.AutoTick(el)
    if not ns.auto then return end
    if DB.ended or (frame and not frame:IsShown()) then
        ns.auto = false
        return
    end
    local s = state
    if s and not s.finished then
        ns.autoKey, ns.autoT = nil, 0
        return
    end
    if s and s.manual then
        ns.auto = false
        return
    end
    local key = s or 0
    if ns.autoKey ~= key then
        ns.autoKey, ns.autoT = key, 0
        return
    end
    ns.autoT = ns.autoT + el
    if ns.autoT < ns.autoDelay then return end
    ns.autoKey, ns.autoT = nil, 0
    ns.AutoDeal()
end

ns.autoDriver = CreateFrame("Frame")
ns.autoDriver:SetScript("OnUpdate", function(_, el)
    ns.AutoTick(el)
end)'''

SECTION = '''## [0.0.11] \u2014 2026-11-26

The table never waits for you to press anything twice.

- **Auto-spin lives on the ROLL button.** Right-click it and the button turns green and names itself
  (`AUTO ON . ROLL 50`); the hint under it says what the next click will do, and the tooltip spells
  both clicks out. Every hand that ends deals the same stake again, one beat after the ceremony, so
  the reveal is never cut short.
- **Stopping is one click.** A plain click during an auto hand turns the deal off and lets that hand
  finish, since the stake is already on the table and there is nothing to cancel. Taking over with
  shift-click ends it at the end of the hand too.
- **It stops itself at the edge.** No purse for the stake, a bust, or a closed table all end it
  instead of retrying, and it is session-only: off at login, so it can never spend a purse
  unattended.

'''

src = swap(src, BUTTON, BUTTON_NEW, "roll button")
src = swap(src, LABELS, LABELS_NEW, "roll labels")

if not src.endswith(NL):
    src += NL
src += NL + AUTO_BLOCK.replace("\n", NL) + NL
print("appended auto-spin block")

for needle in ["ns.AutoTick", "ns.AutoDeal", 'RegisterForClicks("LeftButtonUp", "RightButtonUp")',
               '"AUTO ON   .   ROLL "']:
    if needle not in src:
        print("MISSING after patch: %s" % needle)
        sys.exit(1)

write(LUA, src)

log = read(LOG)
rx = re.compile(r"(?m)^## \[0\.0\.10\]")
if len(rx.findall(log)) != 1:
    print("changelog anchor matched %d times" % len(rx.findall(log)))
    sys.exit(1)
log = rx.sub(lambda m: SECTION.replace("\n", NL) + m.group(0), log, count=1)
write(LOG, log)
print("changelog ok")

toc = read(TOC)
rx = re.compile(r"(?m)^## Version: 0\.0\.10")
if len(rx.findall(toc)) != 1:
    print("toc anchor matched %d times" % len(rx.findall(toc)))
    sys.exit(1)
toc = rx.sub("## Version: 0.0.11", toc, count=1)
write(TOC, toc)
print("toc ok")
print("lines now:", src.count(NL) + 1)

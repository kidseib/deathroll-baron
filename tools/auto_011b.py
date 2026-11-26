import re, sys, pathlib

LUA = pathlib.Path("addon/DeathrollBaron/DeathrollBaron.lua")
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


BUTTON = '''W.roll = Btn(frame, "ROLL", 368, 40, 16, function(_, button)
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
W.roll:SetScript("OnLeave", function() GameTooltip:Hide() end)'''.split("\n")

BUTTON_NEW = '''    W.roll = Btn(frame, "ROLL", 368, 40, 16, function()
        -- a plain click on a live auto hand stops the next deal, not this one
        if ns.auto and not IsShiftKeyDown() and state and not state.finished then
            ns.auto = false
            ns.Refresh()
            return
        end
        DoRoll()
    end)
    W.roll:SetPoint("TOP", 0, -424)
    W.roll:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("ROLL", GOLD[1], GOLD[2], GOLD[3])
        GameTooltip:AddLine("Left click puts up the stake.", 1, 1, 1)
        GameTooltip:AddLine("Shift-click rolls one number at a time.", 1, 1, 1)
        GameTooltip:Show()
    end)
    W.roll:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- auto-spin is a control you can see: a pill on the right of the bar
    W.autoBtn = CreateFrame("Button", nil, W.roll)
    W.autoBtn:SetSize(72, 22)
    W.autoBtn:SetPoint("RIGHT", -6, 0)
    W.autoBtn.edge = W.autoBtn:CreateTexture(nil, "BACKGROUND")
    W.autoBtn.edge:SetAllPoints()
    W.autoBtn.edge:SetColorTexture(DIM[1], DIM[2], DIM[3], 0.55)
    W.autoBtn.bg = W.autoBtn:CreateTexture(nil, "BACKGROUND", nil, 1)
    W.autoBtn.bg:SetPoint("TOPLEFT", 1, -1)
    W.autoBtn.bg:SetPoint("BOTTOMRIGHT", -1, 1)
    W.autoBtn.bg:SetColorTexture(0.10, 0.09, 0.07, 0.95)
    W.autoBtn.label = FS(W.autoBtn, BONE, 10)
    W.autoBtn.label:SetPoint("CENTER")
    W.autoBtn.label:SetText("AUTO OFF")
    W.autoBtn:SetScript("OnClick", function()
        ns.auto = not ns.auto
        ns.autoKey, ns.autoT = nil, 0
        ns.Refresh()
    end)
    W.autoBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Auto-spin", GOLD[1], GOLD[2], GOLD[3])
        GameTooltip:AddLine("On: every hand that ends deals the same stake again, until you stop it or go broke.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    W.autoBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)'''

LABELS = '''if live and state.manual then
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
end'''.split("\n")

LABELS_NEW = '''    if live and state.manual then
        W.roll:SetText("ROLL ONE   (click)")
        W.hint:SetText("manual: one roll per click, shift or not")
    elseif live then
        W.roll:SetText("ROLLING")
        W.hint:SetText(ns.auto and "click to stop after this hand" or "shift-click to take over")
    else
        W.roll:SetText("ROLL   " .. Money(ns.wager))
        W.hint:SetText(ns.auto and "same stake deals again on its own  .  AUTO to stop"
            or "shift-click: roll one at a time  .  AUTO: keep dealing")
    end
    -- the pill on the bar is the control, so the bar's own text stays plain
    if W.autoBtn then
        W.autoBtn.label:SetText(ns.auto and "AUTO ON" or "AUTO OFF")
        if ns.auto then
            W.autoBtn.label:SetTextColor(GREEN[1], GREEN[2], GREEN[3])
            W.autoBtn.edge:SetColorTexture(GREEN[1], GREEN[2], GREEN[3], 0.90)
            W.autoBtn.bg:SetColorTexture(0.14, 0.20, 0.10, 0.95)
        else
            W.autoBtn.label:SetTextColor(BONE[1], BONE[2], BONE[3])
            W.autoBtn.edge:SetColorTexture(DIM[1], DIM[2], DIM[3], 0.55)
            W.autoBtn.bg:SetColorTexture(0.10, 0.09, 0.07, 0.95)
        end
    end'''

OLD_BULLET = '''- **Auto-spin lives on the ROLL button.** Right-click it and the button turns green and names itself
  (`AUTO ON . ROLL 50`); the hint under it says what the next click will do, and the tooltip spells
  both clicks out. Every hand that ends deals the same stake again, one beat after the ceremony, so
  the reveal is never cut short.'''

NEW_BULLET = '''- **Auto-spin is a control on the button.** The right end of the ROLL bar carries an `AUTO OFF` pill;
  click it and it reads `AUTO ON` in green behind a green border, with its own tooltip. Nothing is
  hidden behind a modifier key. Every hand that ends deals the same stake again, one beat after the
  ceremony, so the reveal is never cut short.'''

src = swap(src, BUTTON, BUTTON_NEW, "roll button")
src = swap(src, LABELS, LABELS_NEW, "roll labels")

for needle in ["W.autoBtn = CreateFrame", '"AUTO OFF"', 'W.autoBtn.label:SetText(ns.auto and "AUTO ON"']:
    if needle not in src:
        print("MISSING after patch: %s" % needle)
        sys.exit(1)
if "W.roll:RegisterForClicks" in src:
    print("the hidden right-click gesture survived")
    sys.exit(1)

write(LUA, src)

log = read(LOG)
rx = re.compile(r"(?m)^- \*\*Auto-spin lives on the ROLL button\.\*\*")
if len(rx.findall(log)) != 1:
    print("changelog bullet anchor matched %d times" % len(rx.findall(log)))
    sys.exit(1)
log = log.replace(OLD_BULLET, NEW_BULLET)
if NEW_BULLET not in log:
    print("changelog bullet not replaced")
    sys.exit(1)
write(LOG, log)
print("changelog ok")
print("done")

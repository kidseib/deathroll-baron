import pathlib

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


swap(
    "local SLAM_TIME = 0.16",
    "local SLAM_TIME = 0.16\n"
    "-- the slide lifts and softens only while it crosses the winner's roll\n"
    "local POT_ARC = 10\n"
    "local POT_CROSS = 0.58\n"
    "local POT_CROSS_W = 0.24",
    "cross constants",
)

swap(
    '''            J.potX = a.x0 + (a.x1 - a.x0) * k
            J.potY = a.y0 + (a.y1 - a.y0) * k
            J.pot.body:SetPoint("CENTER", J.pot, "CENTER", J.potX, J.potY)''',
    '''            J.potX = a.x0 + (a.x1 - a.x0) * k
            J.potY = a.y0 + (a.y1 - a.y0) * k
            if a.arc then
                J.potY = J.potY + math.sin(k * math.pi) * a.arc
            end
            J.pot.body:SetPoint("CENTER", J.pot, "CENTER", J.potX, J.potY)
            if a.shrink then
                local bump = max(0, 1 - math.abs(k - a.cross) / a.span)
                J.pot.body:SetScale(1 - 0.24 * bump)
                J.pot.body:SetAlpha((J.potA or 1) * (1 - 0.30 * bump))
            end''',
    "cross path",
)

swap(
    '''            if k >= 1 then
                J.potAnim = nil
                if a.fade then''',
    '''            if k >= 1 then
                J.potAnim = nil
                J.pot.body:SetScale(1)
                if a.fade then''',
    "scale reset",
)

swap(
    '''    J.pot.body:SetPoint("CENTER", J.pot, "CENTER", 0, 0)
    J.pot.body:Show()
    J.potA = 0.84''',
    '''    J.pot.body:SetPoint("CENTER", J.pot, "CENTER", 0, 0)
    J.pot.body:Show()
    J.pot.body:SetScale(1)
    J.potA = 0.84''',
    "reset scale",
)

swap(
    '''    J.potHidden = false
    J.pot.body:Show()
    J.potAtWinner = true
    J.potAnim = {
        x0 = J.potX or 0,
        y0 = J.potY or 0,
        x1 = won and -170 or 170,
        y1 = -2,
        t = 0,
        dur = POT_SLIDE,
    }''',
    '''    J.potHidden = false
    J.pot.body:Show()
    J.pot.body:SetScale(1)
    J.potAtWinner = true
    J.potAnim = {
        x0 = J.potX or 0,
        y0 = J.potY or 0,
        x1 = won and -170 or 170,
        y1 = -2,
        t = 0,
        dur = POT_SLIDE,
        arc = POT_ARC,
        cross = POT_CROSS,
        span = POT_CROSS_W,
        shrink = true,
    }''',
    "slide path",
)

swap(
    '''function J.PotSink()
    if not J.pot then return end
    J.potAtWinner = true''',
    '''function J.PotSink()
    if not J.pot then return end
    J.pot.body:SetScale(1)
    J.potAtWinner = true''',
    "sink scale",
)

swap(
    '''    if J.potAnim then return end
    if (J.potX or 0) == 0 and (J.potY or 0) == 0 then
        J.potAtWinner = false''',
    '''    if J.potAnim then return end
    J.pot.body:SetScale(1)
    if (J.potX or 0) == 0 and (J.potY or 0) == 0 then
        J.potAtWinner = false''',
    "return scale",
)

checks = {
    "arc": ("local POT_ARC = 10", 1),
    "cross": ("local POT_CROSS = 0.58", 1),
    "shrink": ("if a.shrink then", 1),
    "slide arc": ("arc = POT_ARC,", 1),
    "slide shrink": ("shrink = true,", 1),
    "scale resets": ("J.pot.body:SetScale(1)", 4),
}
for name, (needle, want) in checks.items():
    n = src.count(needle)
    if n != want:
        raise SystemExit("%s: %d occurrences (want %d)" % (name, n, want))
    print("ok check", name)

path.write_text(src)
print("patched")

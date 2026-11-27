import pathlib, re, sys

path = pathlib.Path("addon/DeathrollBaron/DeathrollBaron.lua")
src = path.read_text()

if "J.fx" in src:
    print("already applied")
    sys.exit(0)

def once(old, new):
    global src
    n = src.count(old)
    if n != 1:
        raise SystemExit("anchor %d: %r" % (n, old[:70]))
    src = src.replace(old, new)

# 1. the old odds line is dead UI (W.luck is hidden) and it aborts the whole
#    refresh before the log, the wager and the shop prices are written
pat = re.compile("-- the odds line:.*?local entries = \\{\\}", re.S)
src, n = pat.subn("local entries = {}", src)
if n != 1:
    raise SystemExit("odds block: %d" % n)

# 2. W.luck goes with it
once('''    W.luck = FS(frame, GOLD, 11)
    W.luck:SetPoint("TOP", 0, -268)
''', "")
once('''    if W.luck then W.luck:Hide() end
''', "")
if "W.luck" in src:
    raise SystemExit("W.luck still referenced")

# 3. juice gets its own frame above every child panel
once('''    J.parts, J.texts = {}, {}
''',
'''    J.parts, J.texts = {}, {}

    -- juice draws on a frame above every child panel: a FontString parented
    -- straight to `frame` sits under the roll panels and their dark fills
    local fx = CreateFrame("Frame", nil, frame)
    fx:SetAllPoints(frame)
    fx:SetFrameLevel(frame:GetFrameLevel() + 12)
    J.fx = fx
''')

src, n = re.subn('SetPoint\("CENTER", frame, "CENTER"',
                 'SetPoint("CENTER", J.fx, "CENTER"', src)
if n != 5:
    raise SystemExit("center anchors: %d" % n)

once('local t = frame:CreateTexture(nil, "OVERLAY", nil, 3)',
     'local t = J.fx:CreateTexture(nil, "OVERLAY", nil, 3)')
once('local fs = FS(frame, GOLD, 20)', 'local fs = FS(J.fx, GOLD, 20)')

# 4. the bar text needs a box to centre in
once('''    bar.text:SetPoint("CENTER")
''',
'''    bar.text:SetPoint("CENTER")
    bar.text:SetWidth(376)
    bar.text:SetJustifyH("CENTER")
''')

# 5. paint the bar once init is done, and keep painting it
once('if frame and W.youNum and W.gold then J.Init() end',
'''if frame and W.youNum and W.gold then
            J.Init()
            J.Odds()
        end''')

pat = re.compile(r"(J\.Step\(el\)\n[ \t]*ns\.AutoTick\(el\))")
src, n = pat.subn(r'''\1
    -- the bar has its own clock: a refresh that never fires cannot blank it
    if frame and frame:IsShown() then
        J.oddsT = (J.oddsT or 0) + el
        if J.oddsT >= 0.20 then
            J.oddsT = 0
            J.Odds()
        end
    end''', src)
if n != 1:
    raise SystemExit("driver anchor: %d" % n)

# 6. prices on the buttons from the very first paint
once("p.name, 178, 24, 10, function(self)",
     '("%s  %s"):format(p.name, Money(PowerCost(p))), 178, 24, 10, function(self)')

# 7. the idle table gets copy instead of a black hole
once('''    local entries = {}
    if state then
        for i = max(1, #state.log - 5), #state.log do
            entries[#entries + 1] = state.log[i]
        end
    end
''',
'''    local entries = {}
    if state then
        for i = max(1, #state.log - 5), #state.log do
            entries[#entries + 1] = state.log[i]
        end
    end
    if #entries == 0 then
        entries[1] = { kind = "dim", text = "the table is quiet." }
        entries[2] = { kind = "dim", text = "you want the low roll. they want the high one." }
        entries[3] = { kind = "dim", text = "gold buys cheats. crowns buy permanence." }
    end
''')

once('''            else
                W.log[i]:SetTextColor(BONE[1], BONE[2], BONE[3])
            end''',
'''            elseif e.kind == "dim" then
                W.log[i]:SetTextColor(DIM[1], DIM[2], DIM[3])
            else
                W.log[i]:SetTextColor(BONE[1], BONE[2], BONE[3])
            end''')

path.write_text(src)
print("patched", len(src), "bytes")

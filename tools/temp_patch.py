import pathlib, re, sys

path = pathlib.Path("addon/DeathrollBaron/DeathrollBaron.lua")
src = path.read_text()

if "CrownLabel" in src:
    print("already applied")
    sys.exit(0)

def once(old, new):
    global src
    n = src.count(old)
    if n != 1:
        raise SystemExit("anchor %d: %r" % (n, old[:70]))
    src = src.replace(old, new)

# 1. one label for the header counter and the button's first paint
once('''    f.edge = edge
    return f
end
''', '''    f.edge = edge
    return f
end

local function CrownLabel(n)
    n = n or 0
    if n == 1 then return "1 crown" end
    return Comma(n) .. " crowns"
end
''')

# 2. the counter itself, on the gold row, under the help button
once('''    W.help:SetPoint("TOPRIGHT", -38, -8)
''', '''    W.help:SetPoint("TOPRIGHT", -38, -8)

    -- crowns are spendable any time, not just when the table takes you
    W.crowns = Btn(frame, CrownLabel(DB.crowns), 92, 18, 10, function()
        if ns.ShowPrestige then ns.ShowPrestige(DB.lastCrowns) end
    end)
    W.crowns:SetPoint("TOPRIGHT", -38, -36)
    W.crowns:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Bone Crowns", GOLD[1], GOLD[2], GOLD[3])
        GameTooltip:AddLine("Earned when the table takes you. Click to spend them on permanent upgrades.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    W.crowns:SetScript("OnLeave", function() GameTooltip:Hide() end)
''')

# 3. the sub line drops its crowns copy: the button is the counter now
pat = re.compile(
    r'''    W\.gold:SetText\(Money\(DB\.gold\)\)
    local crowns = DB\.crowns > 0 and \("   " \.\. DB\.crowns \.\. " crowns"\) or ""
    local streak = \(DB\.streak or 0\) >= 3 and \("   " \.\. DB\.streak \.\. " in a row"\) or ""
    W\.sub:SetText\(\("peak %s%s%s    run %d    %dW/%dL"\):format\(
\s*Money\(DB\.peak\), crowns, streak, DB\.runs \+ 1, DB\.wins, DB\.losses\)\)''')
src, n = pat.subn('''    W.gold:SetText(Money(DB.gold))
    local streak = (DB.streak or 0) >= 3 and ("   " .. DB.streak .. " in a row") or ""
    W.sub:SetText(("peak %s%s    run %d    %dW/%dL"):format(
        Money(DB.peak), streak, DB.runs + 1, DB.wins, DB.losses))
    if W.crowns then W.crowns:SetText(CrownLabel(DB.crowns)) end''', src)
if n != 1:
    raise SystemExit("subline anchor: %d" % n)

# 4. the panel keeps the death title, but can be a plain crown shop mid-run
once('''    local ptitle = FS(prestigeFrame, BLOOD, 16)
    ptitle:SetPoint("TOP", 0, -18)
    ptitle:SetText("THE TABLE TAKES YOU")
''', '''    local ptitle = FS(prestigeFrame, BLOOD, 16)
    ptitle:SetPoint("TOP", 0, -18)
    ptitle:SetText("THE TABLE TAKES YOU")
    W.pTitle = ptitle

    -- mid-run the panel needs a way out that is not "start a new run"
    W.pClose = CreateFrame("Button", nil, prestigeFrame, "UIPanelCloseButton")
    W.pClose:SetPoint("TOPRIGHT", -3, -3)
    W.pClose:SetScript("OnClick", function()
        prestigeFrame:Hide()
        ns.Refresh()
    end)
''')

# 5. one panel, two entry points: death screen or crown shop
once('''ns.ShowPrestige = function(earned)
    if not prestigeFrame then return end
    W.pCrowns:SetText(("+%d Bone Crowns   (you hold %d)"):format(earned or DB.lastCrowns, DB.crowns))
''', '''ns.ShowPrestige = function(earned)
    if not prestigeFrame then return end

    -- the same panel serves the death screen and the crown button
    if W.pTitle then
        if DB.ended then
            W.pTitle:SetText("THE TABLE TAKES YOU")
            W.pTitle:SetTextColor(BLOOD[1], BLOOD[2], BLOOD[3])
        else
            W.pTitle:SetText("BONE CROWNS")
            W.pTitle:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        end
    end
    if W.pAgain then W.pAgain:SetShown(DB.ended) end
    if W.pClose then W.pClose:SetShown(not DB.ended) end
    if DB.ended then
        W.pCrowns:SetText(("+%d Bone Crowns   (you hold %d)"):format(earned or DB.lastCrowns, DB.crowns))
    else
        W.pCrowns:SetText(("you hold %d Bone Crowns"):format(DB.crowns))
    end
    if W.crowns then W.crowns:SetText(CrownLabel(DB.crowns)) end
''')

path.write_text(src)
print("patched", len(src), "bytes")

import pathlib

path = pathlib.Path("addon/DeathrollBaron/DeathrollBaron.lua")
src = path.read_text()

old = '''    -- the pot: a small stack of coins on the board seam, above both panels.
    -- The seam anchor stays fixed; only the inner body slides to the winner.
    -- one brass hairline at the seam, the only divider between the panels
    local rail = J.fx:CreateTexture(nil, "BACKGROUND", nil, 1)
    rail:SetSize(1, 72)
    rail:SetPoint("CENTER", W.youPanel, "TOPRIGHT", 8, -32)
    rail:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.42)

    local pot = CreateFrame("Frame", nil, J.fx)'''

new = '''    -- one brass hairline at the seam, the only divider between the panels
    local rail = J.fx:CreateTexture(nil, "BACKGROUND", nil, 1)
    rail:SetSize(1, 72)
    rail:SetPoint("CENTER", W.youPanel, "TOPRIGHT", 8, -32)
    rail:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.42)

    -- the pot: a small stack of coins on the board seam, above both panels.
    -- The seam anchor stays fixed; only the inner body slides to the winner.
    local pot = CreateFrame("Frame", nil, J.fx)'''

if src.count(old) != 1:
    raise SystemExit("rail comment block: %d matches" % src.count(old))
src = src.replace(old, new, 1)
path.write_text(src)
print("ok rail comment")

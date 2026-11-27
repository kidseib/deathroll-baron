import pathlib

path = pathlib.Path("addon/DeathrollBaron/DeathrollBaron.lua")
src = path.read_text()


def swap(old, new, label):
    global src
    n = src.count(old)
    if n != 1:
        raise SystemExit("%s: %d matches" % (label, n))
    src = src.replace(old, new, 1)
    print("ok", label)


swap(
    '''    -- the board: two panels, your roll and theirs, never one shared number
    W.youPanel = Panel(frame, 184, 64, GOLD)''',
    '''    -- the felt band: the table surface under both panels. The panels cover
    -- most of it; only the seam and a thin margin show.
    local felt = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    felt:SetPoint("TOPLEFT", 4, -180)
    felt:SetPoint("TOPRIGHT", -4, -180)
    felt:SetHeight(72)
    felt:SetColorTexture(0.060, 0.085, 0.070, 0.72)

    -- the board: two panels, your roll and theirs, never one shared number
    W.youPanel = Panel(frame, 184, 64, GOLD)''',
    "felt band",
)

swap(
    '''    local rail = J.fx:CreateTexture(nil, "BACKGROUND", nil, 1)
    rail:SetSize(1, 68)
    rail:SetPoint("CENTER", W.youPanel, "TOPRIGHT", 8, -32)
    rail:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.30)''',
    '''    -- one brass hairline at the seam, the only divider between the panels
    local rail = J.fx:CreateTexture(nil, "BACKGROUND", nil, 1)
    rail:SetSize(1, 72)
    rail:SetPoint("CENTER", W.youPanel, "TOPRIGHT", 8, -32)
    rail:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.42)''',
    "seam rail",
)

checks = {
    "felt comment": ("the felt band", 1),
    "felt color": ("SetColorTexture(0.060, 0.085, 0.070, 0.72)", 1),
    "felt height": ("felt:SetHeight(72)", 1),
    "rail width": ("rail:SetSize(1, 72)", 1),
    "rail alpha": ("rail:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.42)", 1),
    "old rail": ("rail:SetSize(1, 68)", 0),
}
for name, (needle, want) in checks.items():
    n = src.count(needle)
    if n != want:
        raise SystemExit("%s: %d occurrences (want %d)" % (name, n, want))
    print("ok check", name)

path.write_text(src)
print("patched")

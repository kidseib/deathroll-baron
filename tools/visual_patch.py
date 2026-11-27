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
    '''    W.title = FS(frame, GOLD, 14)
    W.title:SetPoint("TOP", 0, -12)
    W.title:SetText("DEATHROLL BARON")''',
    '''    -- the masthead: a darker plate and a gold rule separate the title, the
    -- purse and the record from the table below
    local plate = frame:CreateTexture(nil, "BACKGROUND")
    plate:SetPoint("TOPLEFT", 3, -3)
    plate:SetPoint("TOPRIGHT", -3, -3)
    plate:SetHeight(81)
    plate:SetColorTexture(0.045, 0.040, 0.033, 0.85)

    local headerRule = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    headerRule:SetPoint("TOPLEFT", 8, -84)
    headerRule:SetPoint("TOPRIGHT", -8, -84)
    headerRule:SetHeight(1)
    headerRule:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.30)

    W.title = FS(frame, GOLD, 15)
    W.title:SetPoint("TOP", 0, -12)
    W.title:SetText("DEATHROLL BARON")
    W.title:SetShadowColor(0, 0, 0, 0.9)
    W.title:SetShadowOffset(1, -1)

    -- a short rule under the wordmark gives it weight without a second size
    local titleRule = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
    titleRule:SetPoint("TOP", 0, -33)
    titleRule:SetSize(96, 1)
    titleRule:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.55)''',
    "header",
)

swap(
    '''    W.sub = FS(frame, DIM, 11)''',
    '''    W.sub = FS(frame, DIM, 10)
    W.sub:SetAlpha(0.9)''',
    "subline",
)

swap(
    '''    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.10, 0.09, 0.07, 0.96)''',
    '''    -- a framed gauge: border outside, darker track inside
    bar.edge = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
    bar.edge:SetPoint("TOPLEFT", -1, 1)
    bar.edge:SetPoint("BOTTOMRIGHT", 1, -1)
    bar.edge:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.22)
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", 1, -1)
    bg:SetPoint("BOTTOMRIGHT", -1, 1)
    bg:SetColorTexture(0.055, 0.050, 0.043, 0.97)''',
    "bar track",
)

swap(
    '''    bar.fill:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.9)''',
    '''    bar.fill:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.9)
    bar.shine = bar:CreateTexture(nil, "BACKGROUND", nil, 2)
    bar.shine:SetPoint("TOPLEFT", bar.fill, "TOPLEFT", 0, 0)
    bar.shine:SetPoint("TOPRIGHT", bar.fill, "TOPRIGHT", 0, 0)
    bar.shine:SetHeight(1)
    bar.shine:SetColorTexture(1, 0.95, 0.75, 0.35)''',
    "bar shine",
)

swap(
    '''    local mid = bar:CreateTexture(nil, "BACKGROUND", nil, 2)
    mid:SetSize(1, 18)
    mid:SetPoint("CENTER")
    mid:SetColorTexture(1, 1, 1, 0.16)''',
    '''    local mid = bar:CreateTexture(nil, "BACKGROUND", nil, 2)
    mid:SetSize(1, 10)
    mid:SetPoint("CENTER")
    mid:SetColorTexture(1, 1, 1, 0.16)

    -- quarter ticks and a fixed tag: the gauge reads without the sentence
    for _, q in ipairs({ 0.25, 0.75 }) do
        local tick = bar:CreateTexture(nil, "BACKGROUND", nil, 2)
        tick:SetSize(1, 9)
        tick:SetPoint("CENTER", bar, "LEFT", floor(382 * q) + 1, 0)
        tick:SetColorTexture(1, 1, 1, 0.10)
    end

    bar.tag = FS(bar, DIM, 9)
    bar.tag:SetPoint("LEFT", 7, 0)
    bar.tag:SetText("ODDS")
    bar.tag:SetAlpha(0.75)''',
    "bar ticks and tag",
)

swap(
    '''    bar.text = FS(bar, GOLD, 11)
    bar.text:SetPoint("CENTER")
    bar.text:SetWidth(376)
    bar.text:SetJustifyH("CENTER")''',
    '''    bar.text = FS(bar, GOLD, 11)
    bar.text:SetPoint("CENTER", 16, 0)
    bar.text:SetWidth(340)
    bar.text:SetJustifyH("CENTER")
    bar.text:SetShadowColor(0, 0, 0, 0.85)
    bar.text:SetShadowOffset(1, -1)''',
    "bar text",
)

swap(
    '''        b.powerId = p.id''',
    '''        b.accent = b:CreateTexture(nil, "ARTWORK")
        b.accent:SetPoint("TOPLEFT", 4, -5)
        b.accent:SetPoint("BOTTOMLEFT", 4, 5)
        b.accent:SetWidth(2)
        b.accent:SetColorTexture(DIM[1], DIM[2], DIM[3], 0.45)
        b.powerId = p.id''',
    "shop accent",
)

swap(
    '''        W.shop[i] = b
    end''',
    '''        W.shop[i] = b
    end

    -- one hairline between the columns: the shop reads as a grid
    local shopRule = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    shopRule:SetPoint("TOPLEFT", 199, -481)
    shopRule:SetSize(1, 114)
    shopRule:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.12)''',
    "shop rule",
)

swap(
    '''            if r >= p.max then
                b:SetText(PowerLabel(p, r))
                b:SetEnabled(false)
            else
                local cost = PowerCost(p)
                b:SetText(PowerLabel(p, r, cost))
                b:SetEnabled(DB.gold >= cost and not DB.ended)
            end''',
    '''            if r >= p.max then
                b:SetText(PowerLabel(p, r))
                b:SetEnabled(false)
                if b.accent then b.accent:SetColorTexture(GREEN[1], GREEN[2], GREEN[3], 0.85) end
                local fs = b:GetFontString()
                if fs then fs:SetTextColor(GREEN[1], GREEN[2], GREEN[3]) end
            else
                local cost = PowerCost(p)
                local can = DB.gold >= cost and not DB.ended
                b:SetText(PowerLabel(p, r, cost))
                b:SetEnabled(can)
                if b.accent then
                    if can then
                        b.accent:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.90)
                    else
                        b.accent:SetColorTexture(DIM[1], DIM[2], DIM[3], 0.40)
                    end
                end
                local fs = b:GetFontString()
                if fs then
                    if can then
                        fs:SetTextColor(BONE[1], BONE[2], BONE[3])
                    else
                        fs:SetTextColor(DIM[1], DIM[2], DIM[3])
                    end
                end
            end''',
    "shop state colors",
)

path.write_text(src)
print("patched")

import pathlib

path = pathlib.Path("addon/DeathrollBaron/DeathrollBaron.lua")
src = path.read_text()

if "local ledger" in src:
    raise SystemExit("already applied")


def swap(old, new, label):
    global src
    n = src.count(old)
    if n != 1:
        raise SystemExit("%s: %d matches" % (label, n))
    src = src.replace(old, new, 1)
    print("ok", label)


swap(
    '''        LogLine(s, "win", "You take " .. Money(payout) .. " (net " .. Signed(s.net) .. ").")''',
    '''        local tax = floor(gross * c.winTax)
        local ledger = "pot " .. Money(gross)
        if tax > 0 then ledger = ledger .. ", house " .. Money(tax) end
        if payout < gross - tax then ledger = ledger .. ", limit " .. Money(c.purse) end
        ledger = ledger .. ", net " .. Signed(s.net)
        LogLine(s, "win", ledger)''',
    "win ledger",
)

swap(
    '''        LogLine(s, "lose", "You pay " .. Money(loss) .. ".")''',
    '''        local ledger = "pot " .. Money(s.wager) .. ", pay " .. Money(loss)
        if loss < s.wager then ledger = ledger .. ", kept " .. Money(s.wager - loss) end
        ledger = ledger .. ", net " .. Signed(s.net)
        LogLine(s, "lose", ledger)''',
    "loss ledger",
)

swap(
    '''    if s ~= J.seenState then
        J.seenState = s
        J.lastP, J.lastE = nil, nil
        J.scaleYou, J.scaleThem = 1, 1
        J.span, J.done, J.hold = nil, nil, nil
    end''',
    '''    if s ~= J.seenState then
        J.seenState = s
        J.lastP, J.lastE = nil, nil
        J.scaleYou, J.scaleThem = 1, 1
        J.span, J.done, J.hold = nil, nil, nil
        if s and not s.finished and s.wager then
            J.Float(0, 258, "-" .. Money(s.wager), 13, RED, 0.9)
        end
    end''',
    "stake float",
)

swap(
    '''            J.Float(0, 66, "you take " .. Money(s.payout or 0), 16, GREEN, 1.3)''',
    '''            J.Float(0, 66, "you take " .. Money(s.payout or 0), 16, GREEN, 1.3)
            J.Float(0, 274, "+" .. Money(s.payout or 0), 13, GREEN, 1.1)''',
    "payout float",
)

path.write_text(src)
print("patched")

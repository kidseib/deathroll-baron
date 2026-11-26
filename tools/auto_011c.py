import re, sys, pathlib

LUA = pathlib.Path("addon/DeathrollBaron/DeathrollBaron.lua")


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
    out = r"[ \t]*" + rx_line(lines[0])
    for l in lines[1:]:
        out += r"(?:\r?\n[ \t]*)" + (rx_line(l) if l.strip() else "")
    return out


def swap(text, anchor, repl, label):
    rx = re.compile(rx_block(anchor))
    hits = rx.findall(text)
    if len(hits) != 1:
        print("ANCHOR %s matched %d times, aborting" % (label, len(hits)))
        sys.exit(1)
    print("anchor ok: %s" % label)
    return rx.sub(lambda m: repl.replace("\n", NL), text, count=1)


PILL_OLD = [
    "ns.auto = not ns.auto",
    "ns.autoKey, ns.autoT = nil, 0",
    "ns.Refresh()",
]

PILL_NEW = '''        ns.auto = not ns.auto
        ns.autoT = 0
        ns.Refresh()'''

DRIVER_OLD = [
    "J.Step(el)",
    "end)",
]

DRIVER_NEW = '''    J.Step(el)
    ns.AutoTick(el)
end)'''

BLOCK_OLD = '''ns.auto = false
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
end)'''.split("\n")

BLOCK_NEW = '''ns.auto = false
ns.autoT = 0
ns.autoDelay = 1.1

-- Runs on the existing driver, one line after J.Step. StartMatch is the
-- wallet's own guard: it refuses a finished run and any stake the purse
-- cannot cover, so a refusal is the only way this stops itself.
function ns.AutoTick(el)
    if not ns.auto then return end
    if DB.ended or not frame:IsShown() then
        ns.auto = false
        return
    end
    local s = state
    if s and not s.finished then
        ns.autoT = 0
        return
    end
    if s and s.manual then
        ns.auto = false
        return
    end
    ns.autoT = ns.autoT + el
    if ns.autoT < ns.autoDelay then return end
    ns.autoT = 0
    if not StartMatch(ns.selectedRung, ns.wager, false) then ns.auto = false end
    ns.Refresh()
end'''

before = src.count(NL) + 1
src = swap(src, PILL_OLD, PILL_NEW, "pill toggle")
src = swap(src, DRIVER_OLD, DRIVER_NEW, "existing driver")
src = swap(src, BLOCK_OLD, BLOCK_NEW, "auto-spin block")
after = src.count(NL) + 1

for dead in ["ns.autoKey", "ns.AutoDeal", "ns.autoDriver"]:
    if dead in src:
        print("DEAD CODE SURVIVED: %s" % dead)
        sys.exit(1)

calls = re.findall(r"(?m)^[ \t]*ns\.AutoTick\(el\)[ \t]*$", src)
if len(calls) != 1:
    print("driver call lines: %d" % len(calls))
    sys.exit(1)

write(LUA, src)
print("lua lines %d -> %d" % (before, after))
print("done")

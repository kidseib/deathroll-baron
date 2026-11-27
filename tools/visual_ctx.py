import re
import pathlib

src = pathlib.Path("addon/DeathrollBaron/DeathrollBaron.lua")
lines = src.read_text().splitlines()
n = len(lines)


def first(pat, start=0):
    rx = re.compile(pat)
    for i in range(start, n):
        if rx.search(lines[i]):
            return i
    return -1


def next_def(i):
    for j in range(i + 4, n):
        if re.match(
            r"^(local function |function |ns\.[A-Za-z_]+ *= *function|J\.[A-Za-z_]+ *= *function)",
            lines[j],
        ):
            return j
    return n


spans = []


def span(name, a, b):
    if a < 0:
        spans.append((name, -1, -1))
        return
    spans.append((name, max(0, a), min(n, b)))


b = first(r"^local function Build\(")
r = first(r"^function ns\.Refresh\(")
p = first(r"^ns\.ShowPrestige *= *function")
i0 = first(r"^function J\.Init\(")
f = first(r"^local function FS\(")
pc = first(r"^local function PowerCost\(")
o = first(r"^J\.Odds *= *function")

span("top", 0, 45)
span("helpers", f, f + 160)
span("cost+label", pc, pc + 55)
span("Build", b, next_def(b))
span("Refresh", r, next_def(r))
span("ShowPrestige", p, p + 70)
span("J.Init", i0, next_def(i0))
span("J.Odds", o, next_def(o))

if b >= 0 and r > b:
    for j in range(b, r):
        if "for i, p in ipairs(POWERS)" in lines[j]:
            span("shop loop", j - 10, j + 32)

if i0 >= 0:
    for j in range(i0, n):
        if "C_Timer" in lines[j] or "OnUpdate" in lines[j]:
            span("driver", j - 10, j + 24)

start_odds = b if b >= 0 else 0
for j in range(start_odds, n):
    if "odds" in lines[j].lower():
        span("odds mention", j - 6, j + 10)

spans.sort(key=lambda s: s[1])
merged = []
for name, a, e in spans:
    if a < 0:
        merged.append((name, -1, -1))
        continue
    if merged and merged[-1][0] != -1 and a <= merged[-1][2]:
        merged[-1] = (merged[-1][0] + " / " + name, merged[-1][1], max(merged[-1][2], e))
    else:
        merged.append((name, a, e))

out = ["DeathrollBaron.lua UI context, %d lines total" % n]
for name, a, e in merged:
    if a < 0:
        out.append("\n== %s NOT FOUND ==" % name)
        continue
    out.append("\n== %s (lines %d-%d) ==" % (name, a + 1, e))
    for k in range(a, e):
        out.append("%4d| %s" % (k + 1, lines[k]))

text = "\n".join(out)
pathlib.Path("tools/visual_ctx.txt").write_text(text[:48000])
pathlib.Path("tools/visual_ctx_tail.txt").write_text(text[-10000:])
print("total %d chars, main 48000, tail 10000" % len(text))

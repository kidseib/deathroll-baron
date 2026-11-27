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

m = first(r"^local function Money")
span("Money", m, m + 25)
pw = first(r"^local POWERS")
span("POWERS", pw, pw + 70)
o = first(r"^(function J\.Odds|J\.Odds *= *function)")
span("J.Odds", o, next_def(o))
s = first(r"^function J\.Sync")
span("J.Sync", s, next_def(s))

out = ["DeathrollBaron.lua bar/shop context, %d lines total" % n]
for name, a, e in spans:
    if a < 0:
        out.append("\n== %s NOT FOUND ==" % name)
        continue
    out.append("\n== %s (lines %d-%d) ==" % (name, a + 1, e))
    for k in range(a, e):
        out.append("%4d| %s" % (k + 1, lines[k]))

text = "\n".join(out)
pathlib.Path("tools/visual_ctx.txt").write_text(text)
pathlib.Path("tools/visual_ctx_tail.txt").write_text("")
print("wrote %d chars" % len(text))

P = "addon/DeathrollBaron/DeathrollBaron.lua"
s = open(P, encoding="utf-8").read()
before = len(s)


def one(old, new):
    global s
    assert s.count(old) == 1, (old, s.count(old))
    s = s.replace(old, new)


one('bar:SetSize(384, 18)', 'bar:SetSize(384, 16)')
one('bar:SetPoint("TOP", frame, "TOP", 0, -264)', 'bar:SetPoint("TOP", frame, "TOP", 0, -269)')
one('bar.text = FS(bar, GOLD, 12)', 'bar.text = FS(bar, GOLD, 11)')
one('    -- the odds bar: the one number the whole game hangs on\n',
    '    -- the odds bar: the one number the whole game hangs on\n'
    '    -- range line ends about -266, bar runs -269..-285, log starts -288:\n'
    '    -- 3pt clear above and below. 18pt at -264 touched the range line.\n')

RANGE_TOP, RANGE_H = 252, 14
BAR_TOP, BAR_H = 269, 16
LOG_TOP = 288
assert BAR_TOP > RANGE_TOP + RANGE_H, "bar still inside the range line"
assert BAR_TOP + BAR_H < LOG_TOP, "bar reaches the log"
print("range %d..%d  bar %d..%d  log %d" % (
    RANGE_TOP, RANGE_TOP + RANGE_H, BAR_TOP, BAR_TOP + BAR_H, LOG_TOP))

open(P, "w", encoding="utf-8").write(s)
print("lua %d -> %d bytes" % (before, len(s)))

T = "addon/DeathrollBaron/DeathrollBaron.toc"
t = open(T, encoding="utf-8").read()
assert "## Version: 0.0.8" in t, "toc is not 0.0.8"
open(T, "w", encoding="utf-8").write(
    t.replace("## Version: 0.0.8", "## Version: 0.0.9", 1))

C = "CHANGELOG.md"
c = open(C, encoding="utf-8").read()
assert "## [0.0.9]" not in c, "already logged"
BLOCK = """## [0.0.9] - 2026-11-26

A layout fix. No rule, no number, no save format touched.

### Fixed

- **The odds bar was sitting on the range line.** Its band started at -264 while the range line
  above it ends around -266, so the top of the fill and its label ran under the turn text. The bar
  is now 16pt tall at -269: 3pt under the range line, 3pt above the first log line at -288. Its label
  drops to 11pt so it fits the shorter bar.
- The log block stays at -288. It was already clear of the bar, and nudging it down would push its
  sixth line further into the wager row at -368.

### Note

The frame stays 400x630. Only the appended juice module, the version line and this file moved;
the odds solver, the match engine and schema 5 are untouched.
"""
i = c.index("## [0.0.8]")
out = c[:i] + BLOCK + c[i:]
open(C, "w", encoding="utf-8").write(out)
print("changelog %d bytes" % len(out))

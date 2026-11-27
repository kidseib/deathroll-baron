import pathlib, sys

toc_path = pathlib.Path("addon/DeathrollBaron/DeathrollBaron.toc")
log_path = pathlib.Path("CHANGELOG.md")

toc = toc_path.read_text()
log = log_path.read_text()

if "[0.0.13]" in log:
    print("already applied")
    sys.exit(0)

old = "## Version: 0.0.12"
if toc.count(old) != 1:
    raise SystemExit("toc anchor: %d" % toc.count(old))
toc = toc.replace(old, "## Version: 0.0.13")

anchor = "## [0.0.11]"
if log.count(anchor) != 1:
    raise SystemExit("changelog anchor: %d" % log.count(anchor))

section = '''## [0.0.13] — 2026-11-27

The table finally shows its prices, its odds and its money.

### Added

- **A crown counter in the header.** A small `N crowns` button under the help mark opens the Bone
  Crown upgrades at any time, not only when the table takes you. Opened alive it is a plain crown
  shop with its own close button; the death screen keeps its title and its "sit down again" door.

### Fixed

- **Every cheat is priced.** The shop buttons print their rank and their cost on the first paint,
  after every purchase and after a reload (`Weighted Dice  3/10   12s 50c`). One `PowerLabel` builds
  the string for both the initial and the refreshed label, so they cannot drift. Buttons you cannot
  afford stay greyed out instead of looking free.
- **The odds bar is painted again.** `ns.Refresh` still wrote the old, hidden odds line; when that
  block failed, the rest of the refresh went with it — no log lines, no wager text, no shop prices,
  and the new bar was never painted. The dead line is gone, the bar owns the number, and the
  animation driver repaints it every 0.2s so a missed refresh cannot blank it.
- **Payout floats rise in front of the board.** CHA-CHING, the payout line and the coin sparks sit on
  a dedicated frame twelve levels above the roll panels; before, the panels drew straight over them.
- **The idle table is not a black hole.** With no hand running, the log area shows three dim lines of
  what the table wants instead of empty space.

### Note

Schema stays 5, and `OddsUpTo` / `WinChance` are untouched: this pass only changes what is drawn.
The new layout is syntax-checked by CI, not loaded in game.

'''

log = log.replace(anchor, section + anchor, 1)

toc_path.write_text(toc)
log_path.write_text(log)
print("bumped to 0.0.13")

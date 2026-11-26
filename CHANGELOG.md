# Changelog

All notable changes to Deathroll Baron. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versioning is [SemVer](https://semver.org/).

## [Unreleased]

- Live-client validation pass: still nothing has been played in game.
- Wager slider to replace the stepper (needs a thumb texture).
- Challenge your current target; addon-vs-addon multiplayer.

## [0.0.3] — 2026-11-26

0.0.1 and 0.0.2 both told you to hold Shift to step the deathroll by hand. No such code existed —
the claim was documentation for a feature that was never written. This release either makes the
documentation true or deletes it, and it makes it true.

### Added

- **Shift-stepping, for real.** `DoRoll` now reads `IsShiftKeyDown()` at click time:
  - no match, plain click — start a match on the ticker, as before;
  - no match, **Shift**-click — start a match in manual mode and roll once immediately;
  - manual match, any click — advance exactly one roll;
  - auto match, **Shift**-click — take the ticker off auto and step one roll.
- A hint line under the ROLL button that names the current mode, so the control is never a secret:
  `click to auto-roll . shift-click to roll it yourself`, then `shift-click to take over`, then
  `manual: one roll per click, shift or not`. The button label changes with it.

### Fixed

- ROLL was disabled during any live match (`SetEnabled(not live)`), which would have made manual
  stepping impossible even if it had been wired up. It is now always enabled and `DoRoll` decides.
- `runnerClock` was an accidental global; it is a file-scoped local now.

### Note

`IsShiftKeyDown()` is read when the button fires, not polled every frame, so there is no per-frame
cost and no state to get stuck in if you release Shift mid-roll.

## [0.0.2] — 2026-11-26

A self-review pass over 0.0.1 looking for faults the parser cannot see.

### Fixed

- **Bone Crowns could be awarded twice from one peak.** `GameOver` had no guard: after a bust you
  could take the shark's loan, keep playing with `peak` intact, lose again, and bank a second payout
  off the same run. It is now idempotent behind `DB.ended`, which also blocks rolling, buying and the
  Runner while the run is over.
- **Bone Crowns could not be spent at all.** The prestige overlay listed upgrade costs as plain text
  with no purchase path. Each line is now a button backed by `BuyPrestige`, and crowns are deducted.
- **The Runner ran every second instead of every six.** `runnerAccum` reset at one second, paying out
  six times the intended rate.
- **Dead end on a low bankroll.** With gold under a rung's minimum and the loan already taken, ROLL
  was disabled and nothing could move again. `BustCheck` ends the run when the cheapest wager is
  unreachable.
- **Crash on load from a stale save.** `NPCS[DB.bestRung]` was indexed with whatever SavedVariables
  held. `InitDB` now clamps `bestRung`, `gold`, `peak` and `crowns`, with a schema number.
- **Run seeding broke if the roster changed.** `DB.rolled` is keyed by rung; `DB.rolledN` is now
  checked on load and the run reseeds.
- **Layout overlaps.** The 46pt number's box ran to about -261 while the range line sat at -258; the
  number is 40pt now. `MIN` (x 130-200) overlapped the loan button (x 16-146).
- **Fragile font templates.** Two labels used `GameFontNormalHuge`; if the client does not expose that
  virtual font, `Build()` throws and no window appears.

### Changed

- Removed the inert `Read the Room` prestige row.
- `/drb sim` reports net gold, not just win rate.
- Wager is clamped to the bankroll at both ends.

## [0.0.1-beta] — 2026-11-26

First beta drop, built and syntax-checked by CI.

### Added

- A deathroll match engine: shrinking range, alternating turns, roll a 1 and you pay.
- 30 real Azeroth NPCs, ladder order from Kobold Vermin to Mutanus the Devourer.
- Run seeding: every rung rolls its affixes when a run begins. Rungs 1-5 always roll zero affixes.
- 20 affixes across three tiers, some the NPC's edge and some their flaw.
- Mirrored luck: your **Luck** rolls twice and keeps the higher; their **Hex** rolls twice and keeps
  the lower.
- Eight power-ups, a loan shark, prestige into Bone Crowns, and the Runner for offline income.
- A movable window with affix tags, a roll ticker, a six-line log, and `/drb` / `/baron` commands.

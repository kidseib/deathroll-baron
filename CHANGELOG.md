# Changelog

All notable changes to Deathroll Baron. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versioning is [SemVer](https://semver.org/).

## [Unreleased]

- Live-client validation pass: still nothing has been played in game.
- Wager slider to replace the stepper (needs a thumb texture).
- Challenge your current target; addon-vs-addon multiplayer.

## [0.0.2] — 2026-11-26

A self-review pass over 0.0.1 looking for faults the parser cannot see. Every fix below is a
correctness bug, not a feature.

### Fixed

- **Bone Crowns could be awarded twice from one peak.** `GameOver` had no guard, so after a bust you
  could take the shark's loan, keep playing with `peak` intact, lose again, and bank a second payout
  off the same run. It is now idempotent behind `DB.ended`, which also blocks rolling, buying and the
  Runner while the run is over.
- **Bone Crowns could not be spent at all.** The prestige overlay listed upgrade costs as plain text
  with no purchase path. Each line is now a button backed by `BuyPrestige`, and crowns are deducted.
- **The Runner ran every second instead of every six.** `runnerAccum` reset at one second, so it paid
  out six times the intended rate. It now uses a one-second clock with a separate six-second counter.
- **Dead end on a low bankroll.** With gold under a rung's minimum and the loan already taken, ROLL was
  disabled and nothing could move again — the bust could never fire. `BustCheck` now ends the run when
  the cheapest wager is unreachable, and ROLL is always enabled so the player gets an answer.
- **Crash on load from a stale save.** `NPCS[DB.bestRung]` was indexed with whatever was in
  SavedVariables; an out-of-range or nil `bestRung` threw inside `ADDON_LOADED`. `InitDB` now clamps
  `bestRung`, `gold`, `peak` and `crowns`, and a schema number records the migration.
- **Wrong run seeding after a roster change.** `DB.rolled` is keyed by rung; adding or removing an NPC
  left rungs with no affixes. `DB.rolledN` is compared on load and the run reseeds when it disagrees.
- **Layout overlaps.** The 46pt number's text box ran to about -261 while the range line sat at -258;
  the number is now 40pt with the range moved clear. The `MIN` button (x 130-200) overlapped the loan
  button (x 16-146) on the same row; the loan button is narrower and the quick buttons shifted right.
- **Fragile font templates.** Two labels used `GameFontNormalHuge`; if the client does not expose that
  virtual font, `Build()` throws and the window never appears. Everything now uses `GameFontNormal`
  with an explicit size, and never depends on a named virtual font existing.

### Changed

- Removed the inert `Read the Room` prestige entry rather than leaving a dead row in the data.
- `/drb sim` also reports the net gold result, not just the win rate.
- Wager is clamped to the bankroll on both ends, so a loss cannot leave it pointing past your gold.
- `StartMatch` no longer carries two identical affordability checks.

## [0.0.1-beta] — 2026-11-26

First beta drop. The zip is built by CI, which also parses the Lua with `luac5.1 -p`.

### Added

- A deathroll match engine: shrinking range, alternating turns, roll a 1 and you pay.
- 30 real Azeroth NPCs as opponents, ladder order from Kobold Vermin to Mutanus the Devourer,
  each with its own opening ceiling, minimum wager and purse cap.
- Run seeding: every rung rolls its affixes when a run begins. Rungs 1-5 always roll zero affixes.
- 20 affixes across three tiers, some the NPC's edge and some their flaw.
- Mirrored luck: your **Luck** rolls twice and keeps the higher; their **Hex** rolls twice and keeps
  the lower.
- Eight power-ups, a loan shark, prestige into Bone Crowns, and the Runner for offline income.
- A movable window with affix tags, a roll ticker, a six-line log, and `/drb` / `/baron` commands.

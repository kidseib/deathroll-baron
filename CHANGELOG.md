# Changelog

All notable changes to Deathroll Baron. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versioning is [SemVer](https://semver.org/).

## [Unreleased]

- Live-client validation pass: nothing has been run in game yet.
- Wire up **Read the Room** (defined in the prestige table, not shown in the UI).
- Replace the wager stepper with a real slider once a thumb texture exists.
- Balance pass driven by `/drb sim` numbers per rung.

## [0.0.1-beta] — 2026-11-26

First beta drop. **Not yet played.** The zip is built by CI (which also parses the Lua with
`luac5.1 -p`), so it loads without a syntax error — that is not the same as working.

### Added

- A deathroll match engine: shrinking range, alternating turns, roll a 1 and you pay.
- 30 real Azeroth NPCs as opponents, ladder order from Kobold Vermin to Mutanus the Devourer,
  each with its own opening ceiling, minimum wager and purse cap.
- Run seeding: every rung rolls its affixes when a run begins, so the same NPC is a soft touch on
  one run and a nightmare on the next. Rungs 1-5 always roll zero affixes.
- 20 affixes across three tiers, some the NPC's edge and some their flaw.
- Mirrored luck: your **Luck** rolls twice and keeps the higher; their **Hex** rolls twice and keeps
  the lower.
- Eight power-ups with escalating costs, including Cheap Trick, Banker's Cut, Blood Pact and the Runner.
- Loan shark: 300 gold now against 450 owed, once per run.
- Prestige into Bone Crowns on going broke, with four permanent upgrades.
- Offline income through the Runner, capped at eight hours.
- A movable window with affix tags, a roll ticker, a six-line log, and `/drb` / `/baron` commands.

### Known issues

- Never played. The Lua parses; the UI has never been drawn, no match has been rolled, and the
  economy has never been felt. Expect behaviour bugs, not syntax errors.
- `Read the Room` is inert.
- `/dr` is deliberately not registered; other gambling addons claim it.

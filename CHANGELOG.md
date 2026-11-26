# Changelog

All notable changes to Deathroll Baron. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versioning is [SemVer](https://semver.org/).

## [Unreleased]

- Live-client validation pass: still nothing has been played in game.
- Resume a match across a reload, so the stake cannot be dodged and the hand is not lost.
- Wager slider to replace the stepper (needs a thumb texture).
- Challenge your current target; addon-vs-addon multiplayer.

## [0.0.9] - 2026-11-26

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
## [0.0.8] - 2026-11-26
The feel pass: the table stops being a spreadsheet and starts being a slot machine.
Nothing about the odds changed - only how loud they are.

### Added

- **A real odds bar.** The line under the board is now a 384x18 bar with a live fill and
  `57% YOU . pays 2g 40s . risk 50s` on it. Green above 56%, gold between, red under 44%.
  It updates on every roll, live or between hands, and the fill breathes.
- **Cha-ching.** Winning a hand throws a coin-and-spark burst out of your panel and across the
  board, floats `CHA-CHING!` and the pot in gold, flashes the whole frame and punches the
  gold counter. Every single roll punches that side's number and spits a few sparks, so the
  board is never still.
- **Sound**, where the client exposes `SOUNDKIT` (`LOOT_ROLL_WON` / `LOOT_ROLL_LOST`);
  guarded, so an old client just stays quiet instead of erroring.

### Changed

- **Quick fire.** Roll ticker 0.85s -> 0.26s, opening delay 0.30s -> 0.08s, result flash
  0.90s -> 0.42s, number pop 0.18s -> 0.12s. A ten-roll hand now takes about three seconds.
- Fast Hands now scales off the new base speed, so a maxed Fast Hands hand is near-instant.
- The tour line points at the odds bar instead of the old ODD% line.

### Note

Everything above is appended as one self-contained module at the end of the file; no existing
function was rewritten, so the odds solver, the match engine and the save format are untouched.
Schema stays 5. Still never played in game - syntax-checked by CI only.

## [0.0.7] — 2026-11-26

Three wins in twenty, and no crowns to show for any of it. The luck system was pointing backwards.

### Fixed

- **"Luck" was a penalty and "their hex" was a buff.** In a deathroll you want to roll *low*: a small
  number leaves the other side almost nothing to roll in. The old `DrawRoll` had the player keeping the
  **higher** of two rolls and the NPC keeping the **lower** — both made the player more likely to lose.
  `DrawRoll(max, bias, wantLow)` now takes which end the roller wants; the player passes `true`, the
  NPC `false`. Negative luck is meaningful too: it means you get the bad of two.
- **`Pocket Sand` helped the enemy.** Sold at 250c as a power-up, it *added* 8% enemy luck per rank.
  It now subtracts it. That was nine ranks of buying your own losses.
- **Bone Crowns were practically unwinnable.** `floor(sqrt(peak / 1000))` returns 0 until a run peaks at
  1000 copper, so a losing run paid nothing and the prestige loop never started. It is now
  `max(1, floor(sqrt(peak / 250)))`: every finished run pays at least one, a 500-peak bust pays 1, a
  full ladder pays about 68.

### Added

- **A live odds meter.** `ODDS 54%` sits under the board, coloured green above 55 and red below 45, and
  it is the real number — solved exactly, not sampled. It accounts for the current range, whose turn it
  is, both sides' luck, and the `Desperate` affix, and it updates after every roll. Idle, it shows the
  odds of the hand you are about to start.
- **`/drb odds`** prints the opening odds for the selected rung from both seats: opener and second player.

### Changed

- **The opening edge.** `BuildConfig` gives the player `0.55` luck at rung 1, bleeding away by `0.025`
  per rung until it is gone in the early twenties. Early rungs are meant to be won; affixes take over
  from there. `EDGE_BASE` and `EDGE_STEP` are the two constants if it still feels wrong.
- The solver is O(m²) per ceiling, not per roll: rows only depend on smaller ranges, so one table grown
  to the largest ceiling in use answers everything after that. Without this the 1000-ceiling rungs
  would have spent half a second of the main thread on every roll.

### Note

Never played in game — syntax-checked only. The odds numbers are derived from the rules, not observed,
so `ODDS` is the one thing in here that should be trustworthy before the rest is.

## [0.0.6] — 2026-11-26

One number in the middle of the window could not tell you whose roll it was. Now the board has two
sides, and it reacts when a number lands.

### Added

- **A split roll board.** `YOUR ROLL` on the left in gold and `THEIR ROLL` on the right in red, each
  with its own 32pt number, each in its own framed panel. The side to move is marked with `<<` and a
  bright border; the other sits dim.
- **Per-roll pop.** The number that just changed punches in from 15% alpha to full over 180ms, so you
  can see which side moved even at a glance across the room.
- **Result flash.** A winning hand paints both panels green, a losing one red, and the wash fades over
  0.9s.
- **Live pulse.** While a hand is running, the same wash breathes gold at ~0.4Hz under the numbers.
- **A croupier line.** The range text carries tension chosen by the ceiling: `plenty of room` above 60,
  `every number matters` at 25, `the table goes quiet` at 12, `no room left` at 4 or less.
- **Streaks.** `DB.streak` counts consecutive won hands and shows in the header from 3 up
  (`6 in a row`). It resets on a loss, a new run, `/drb reset`, and on a bust.

### Changed

- **The log says who rolled it.** Entries now read `you 47` / `them 12`, in gold and red respectively,
  instead of one unlabelled number in white.
- Affix lines sit 13pt apart instead of 15pt, and start at -128 instead of -130, so the four-affix
  rungs clear the board at -184.
- The range line carries the turn (`your turn`, `their turn`) in the matching colour, and the verdict
  after a hand (`you take the pot . +3s 25c`).

### Note

Schema is 5 (`DB.streak`). The single `W.big` label and its 40pt font are gone; the board replaces it
and the net result moved to the range line. Nothing here has been seen rendering — the board sits at
-184 with a 64pt height, the affixes end around -181, and the range line is at -252.

## [0.0.5] — 2026-11-26

Two things a first-time player never had: a way in, and a door.

### Added

- **A minimap button.** 32pt, hand-rolled — this addon still ships no libraries. Left-click
  toggles the window; drag it and it rotates around the ring, with the angle saved in
  `DB.minimapAngle` so it stays where you put it. Tooltip says both of those things.
- **A first-run tour.** A small panel on first login: five lines covering what a deathroll is,
  picking a target with `<` `>`, that the stake leaves your purse when the hand starts, that
  shift-click steps a single roll, and that a bust pays Bone Crowns. It appears once, behind
  `DB.seenWelcome`; the `?` button in the title bar and `/drb help` reopen it on demand.
- `DB.minimapAngle` and `DB.seenWelcome` join the schema (now 4). A non-numeric angle falls back
  to 220 on load rather than being trusted.

### Fixed

- **Cross-section calls are forward-declared now.** The minimap button, the tour and the
  `ADDON_LOADED` handler all run code that lives further down the chunk than the functions it calls
  — `Toggle` most of all. Without a declaration above the UI, each of those would have compiled to a
  runtime global lookup and returned `nil` the moment someone clicked the icon. `Toggle`,
  `ShowWelcome` and `CreateMinimap` are all named in the forward-declaration block with
  `AdjustWager`, `SelectRung` and `DoRoll`.

## [0.0.4] — 2026-11-26

The wager used to move only in `FinishMatch`, which meant a `/reload` during a bad opening
roll abandoned the hand for free. Every loss was optional. This release takes the stake first.

### Changed

- **The stake is taken up front.** `StartMatch` deducts the wager and records it in `DB.stake`;
  `FinishMatch` settles from that escrow — a win pays the pot on top of it, a loss returns the
  portion of the stake you keep. `DB.stake` is cleared the moment the hand settles.
- **Net instead of gross after a hand.** The big number shows the real change to the wallet
  (`payout - stake`), signed, and coloured by the result rather than by the sign. The win log line
  names the net too.

### Fixed

- **Reloading out of a match no longer dodges the loss.** A non-zero `DB.stake` at login means the
  client was reloaded or killed mid-hand: the stake is forfeit, the hand counts as a loss,
  `DB.forfeits` tallies it, and the chat log says where the money went.
- **The wager readout no longer collapses mid-match.** `ns.Refresh` re-clamped the wager to the
  bankroll on every call; once the stake left the wallet that would have shown a smaller bet than
  the one actually on the table. A live hand now displays `state.wager`, and the loan button hides
  while the stake is committed.
- `GameOver`, `StartNewRun` and `/drb reset` zero `DB.stake`, so no path can orphan an escrowed
  wager and then charge for it later.

### Known gap

A reload cannot save the stake, but in a `Debt Collector` match (`lossMult` 1.5) it still avoids the
extra half of the loss. Resuming the hand across a reload is the only way to remove that, and it
needs persisted match state — it is first on the Unreleased list.

## [0.0.3] — 2026-11-26

0.0.1 and 0.0.2 both told you to hold Shift to step the deathroll by hand. No such code existed —
the claim was documentation for a feature that was never written. This release makes the
documentation true.

### Added

- **Shift-stepping, for real.** `DoRoll` now reads `IsShiftKeyDown()` at click time:
  - no match, plain click — start a match on the ticker, as before;
  - no match, **Shift**-click — start a match in manual mode and roll once immediately;
  - manual match, any click — advance exactly one roll;
  - auto match, **Shift**-click — take the ticker off auto and step one roll.
- A hint line under the ROLL button that names the current mode, so the control is never a secret.
  The button label changes with it (`ROLL 500c` / `ROLLING` / `ROLL ONE (click)`).

### Fixed

- ROLL was disabled during any live match (`SetEnabled(not live)`), which would have made manual
  stepping impossible even if it had been wired up. It is now always enabled and `DoRoll` decides.
- The hint line initially sat 4px into the MIN / HALF / ALL IN row; it now has its own band under the
  button, and the shop grid moved down 6px to make room.
- **The runner's second-counter was an accidental global.** It was written as `runnerClock = ...`
  with no `local`, so every tick leaked into `_G` and two addons using the same name would have
  fought over it. It is now a file-local declared beside `runnerAccum`.
- **That declaration had to move.** `runnerAccum` and `runnerClock` were declared *below*
  `StartNewRun` in the file; a reset written inside `StartNewRun` would have created a fresh global
  instead of touching the local, because Lua resolves upvalues at compile time. Both are now declared
  above the match engine, so `StartNewRun` can reset them for real.
- The runner's counters now reset on `StartNewRun` and on `/drb reset`, so a new run cannot inherit a
  partly-elapsed six-second tick from the previous one.

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

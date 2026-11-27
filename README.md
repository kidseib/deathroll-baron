# Deathroll Baron

<p align="center">
  <img src="https://img.shields.io/github/v/release/kidseib/deathroll-baron?include_prereleases&style=flat-square&label=version&color=c9a227" alt="Latest prerelease">
  <img src="https://img.shields.io/badge/interface-16001-3f7d4e?style=flat-square" alt="Interface 16001">
  <img src="https://img.shields.io/badge/Lua-5.1-2c2d72?style=flat-square&logo=lua&logoColor=white" alt="Lua 5.1">
  <img src="https://img.shields.io/badge/dependencies-none-6b4f2a?style=flat-square" alt="No runtime dependencies">
  <img src="https://img.shields.io/badge/license-MIT-3f7d4e?style=flat-square" alt="MIT License">
  <img src="https://img.shields.io/badge/status-beta-c9a227?style=flat-square" alt="Beta">
</p>

<p align="center">
  <strong>Roll first, or roll last. Just don't roll a one.</strong><br>
  A deathroll gambling incremental for <strong>World of Warcraft: Forever</strong>.<br>
  Native Lua 5.1 · no libraries · no real gold touched.
</p>

> **Status: beta — `0.0.14-beta.1`.** This is a test build, not a finished addon. CI parses every
> Lua file and packages the zip, but it has **not been played in game yet**. The live-client
> checklist in [TODO.md](TODO.md) is the gate for 0.1.0.

---

## Download

Grab the newest `DeathrollBaron-*.zip` and its `.sha256` from
**[Releases](https://github.com/kidseib/deathroll-baron/releases)**. GitHub's "Latest" label only
 tracks stable releases and every build here is a prerelease, so open the top prerelease rather than
`/releases/latest`.

```powershell
# Windows PowerShell
Get-FileHash .\DeathrollBaron-0.0.14-beta.1.zip -Algorithm SHA256
```

```bash
# macOS / Linux
shasum -a 256 DeathrollBaron-0.0.14-beta.1.zip
```

---

## Install

1. Extract the release zip so the folder layout is:

   ```text
   World of Warcraft\_forever_\Interface\AddOns\DeathrollBaron\DeathrollBaron.toc
   World of Warcraft\_forever_\Interface\AddOns\DeathrollBaron\DeathrollBaron.lua
   ```

2. Restart the client (a brand-new addon needs a full restart; after that `/reload` is enough).
3. Type `/drb` in game.

The addon declares `## Interface: 16001`, the Forever client value (1.60.1). If a patch moves it,
`/dump select(4, GetBuildInfo())` reports what your client expects.

---

## What it is

You run a table in a back-alley gambling den. No swords, no spells — dice. You sit down opposite a
mob you could walk up to in Azeroth, put gold on the felt, and deathroll it.

The table opens at a ceiling. One side rolls `1..ceiling`, then the other rolls `1..(that result)`,
alternating, until somebody rolls a 1 and pays. Win and you take the pot; lose and it is gone. Your
whole bankroll is fictional, lives in SavedVariables, and never touches your character's gold.

A run is 30 named opponents, a shop of eight power-ups, and one long climb. When the bankroll hits
zero the table takes you, and the peak of the run converts into **Bone Crowns** for permanent
upgrades next time.

---

## How a hand works

1. **The stake leaves your wallet first.** `StartMatch` deducts it and records it in `DB.stake`.
   A win settles the pot on top; a loss returns the fraction you keep. Reloading mid-hand forfeits
   the stake and counts the hand as a loss.
2. **The range only shrinks.** The opener rolls `1..ceiling`; the next roll is `1..previous`; a 1
   ends the hand. There is no separate damage roll and no hidden hit chance.
3. **The odds are solved, not sampled.** `OddsUpTo` fills a dynamic-programming table of exact
   probabilities for every smaller range, turn and luck state. `WinChance` reads the current row,
   so the number above the bar is the real chance from here, not a simulation.
4. **The bar carries the EV.** `chance × (payout - stake) - (1 - chance) × risk` is printed beside
   the odds. Payout is `stake × Marked Cards`, capped by the opponent's purse; risk includes
   `Banker's Cut`, `Debt Collector` and `Double or Nothing`.
5. **Auto or manual.** A plain click deals the whole hand on a shrinking ticker. Shift-click starts
   in manual mode and advances one roll per click; shift-click mid-hand takes an auto hand off the
   ticker. The line under the button always names the mode.
6. **The pot tells the story.** It sits on the seam, stacks more coins as the stake crosses 1g, 10g
   and 100g, and lifts across the board to the winner when the final 1 lands.

---

## The run

1. **Pick a rung.** Beat one opponent and the next name sits down. You can re-fight anyone you have
   already beaten.
2. **Read the cheats.** Each NPC brings affixes — sometimes its edge, sometimes its flaw. They are
   rolled when the run starts, so the same Hogger is a pushover tonight and a monster tomorrow.
3. **Set the stake.** The `-` / `+` stepper is bounded by the rung's minimum and your bankroll;
   `MIN`, `HALF` and `ALL IN` are one click. Payout is capped by the NPC's purse, which is the
   ratchet that forces you up the ladder.
4. **Spend.** Power-ups improve your luck, tax theirs, raise the multiplier or blunt your losses.
5. **Go broke.** The peak bankroll converts into Bone Crowns and buys permanent advantages.

### The ladder, at a glance

| Rungs | Examples | Affixes | Purse band |
|---|---|---|---|
| 1–5 | Kobold Vermin, Defias Thug, Murloc Forager | 0 | 3s–9s 30c |
| 6–11 | Hogger, Defias Trapper, Slark | 1 | 12s 40c–51s 50c |
| 12–17 | Defias Messenger, Stonesplinter Digger, Brack | 2 | 68s 50c–2g 85s |
| 18–23 | Old Murk-Eye, Cookie, Boulderfist Ogre | 3 | 3g 79s–15g 76s |
| 24–30 | Dark Iron Shadowcaster, Blind Mary, Mutanus | 4 | 20g 96s–116g 3s |

The roster order is fixed so the world reads as the world. What gets randomised is what each one
brings. Rungs 1–5 always roll zero affixes: there is no round-one way to buy a cheat, and the early
ladder is decided by honest dice.

---

## Luck, hex and the odds

In a deathroll, low is strong: a small number leaves the other side almost nothing to roll in. Your
**Luck** is the chance to keep the lower of two rolls; the opponent's **Hex** is the same pressure
pointed back at you. `Weighted Dice` adds 8% Luck per rank. `Pocket Sand` removes 8% of the
opponent's luck per rank.

The design centre is that upgrades compound instead of cancelling. A lower roll does not merely
protect you from a 1 — it shortens the chain, which gives the opponent more turns to roll a 1
themselves. The ticker stays tense at every tier because the range, not a damage number, is the
clock.

The odds bar is the one number in the addon that should be trustworthy before the rest is:
`OddsUpTo` and `WinChance` are solved from the same constants the match engine uses, including
`Desperate` under a 20 ceiling. `/drb odds` prints both seats' opening chances for the selected rung.

---

## Power-ups

Cost for rank `n` is `base × 1.75^(n-1)`, rounded to 5. `Inside Man` takes 5% off per rank.

| Power-up | Per rank | Max | Base cost |
|---|---|---|---|
| Weighted Dice | +8% chance to keep your lower roll | 10 | 200 |
| Pocket Sand | −8% enemy luck | 8 | 250 |
| Marked Cards | +12% payout | 10 | 300 |
| Fast Hands | faster roll ticker (up to ~2.2×) | 2 | 150 |
| Cheap Trick | the enemy opens every match | 1 | 800 |
| Banker's Cut | lose 60/45/35% of the wager | 3 | 900 |
| Blood Pact | +1 Insurance charge per match | 3 | 1,200 |
| The Runner | auto-play + offline income | 1 | 2,500 |

**The Runner** plays one simulated match every six seconds while the table is idle and pays offline
at 60% of the simulated rate, capped at eight hours.

---

## Prestige

A finished run pays `max(1, floor(sqrt(peak / 250)))` Bone Crowns. Every run pays at least one; a
500-copper bust pays 1 and a full ladder pays about 68. Four permanent upgrades, bought in the crown
panel:

| Upgrade | Per rank | First cost |
|---|---|---|
| Old Money | +250 starting bankroll | 2 crowns |
| Bloodline | +2% base Luck | 3 crowns |
| Inside Man | −5% power-up cost | 4 crowns |
| Inherited Dice | keep one power-up between runs | 10 crowns, once |

A new run starts at 500 copper, plus 250 per rank of Old Money. The crown button in the header opens
the same shop at any time, not only on the death screen.

---

## The table

The board is a 400×630 frame with two 184×64 roll panels. A dark felt band sits behind both panels,
inset 4px and 72px tall, so only a thin margin and the seam show. A single 1px brass hairline runs
the full height of the felt at the seam. The pot sits on that seam: three coins at a copper stake,
then a fourth at 1g, a fifth at 10g and a sixth at 100g; the exact amount stays on the label.

The odds/EV bar is a single 384px line. The board flashes green or red on a result, the live side
breathes gold, each roll punches its number, and a dedicated layer above the panels carries the
CHA-CHING and BUSTED floats so the panels cannot draw over them.

---

## Commands

```
/drb, /baron        open or close the table
/drb help           reopen the five-line tour
/drb odds           print opener and second-player odds for the selected rung
/drb sim            300 silent matches at the selected rung: win rate and net gold
/drb reset          wipe progress and deal a fresh set of cheats
```

`/dr` is deliberately **not** registered — other gambling addons claim it.

---

## Compatibility and safety

- Written against **Forever** interface `16001` (client 1.60.1), Lua 5.1, no libraries.
- Uses only frames, textures, font strings, SavedVariables and timers, plus `IsShiftKeyDown()` for
  manual mode. It reads no combat data, no unit health and no combat log.
- The bankroll is fictional. `GetMoney()` is never called, no trade window is opened, and no real
  item or coin is touched.
- Opponents are stored as names and zone strings. No unit tokens, no GUIDs, no NPC lookups.
- Save schema is `5`; `OddsUpTo` / `WinChance` are untouched by UI work.

### Beta limits

This build has not been loaded in a live client. Known limits, all tracked in [TODO.md](TODO.md):

- A `/reload` mid-hand forfeits the stake rather than resuming the hand.
- The wager is still a stepper; the slider is not in yet.
- Challenge/multiplayer and the `Read the Room` prestige upgrade are held back.
- Balance has not been played; `/drb sim` exists, but the curve is unverified.

0.1.0 is deliberately gated on the live-client checklist. Until that pass is done, treat this as a
beta and expect UI or runtime faults.

---

## Development

```
addon/DeathrollBaron/DeathrollBaron.toc
addon/DeathrollBaron/DeathrollBaron.lua   one file, all of it
.github/workflows/release.yml             parses the Lua, zips the addon, attaches it to the release
```

CI runs `luac5.1 -p` on every Lua file before it packages anything. Retuning the economy is a table
edit in `NPCS`, `AFFIXES` or `POWERS`; nothing derives a hard-coded cost. See [TODO.md](TODO.md) for
the live-client checklist and [AI-DISCLOSURE.md](AI-DISCLOSURE.md) for who wrote what.

---

## License

MIT — see [LICENSE](LICENSE).

**Created by ErrorSeiB & Buffy (Codebuff).**

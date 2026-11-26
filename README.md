# Deathroll Baron

<p align="center">
  <img src="https://img.shields.io/badge/version-0.0.3-c9a227?style=flat-square" alt="Version 0.0.3">
  <img src="https://img.shields.io/badge/interface-16001-3f7d4e?style=flat-square" alt="Interface 16001">
  <img src="https://img.shields.io/badge/Lua-5.1-2c2d72?style=flat-square&logo=lua&logoColor=white" alt="Lua 5.1">
  <img src="https://img.shields.io/badge/dependencies-none-6b4f2a?style=flat-square" alt="No runtime dependencies">
  <img src="https://img.shields.io/badge/license-MIT-3f7d4e?style=flat-square" alt="MIT License">
</p>

<p align="center">
  <strong>Roll first, or roll last. Just don't roll a one.</strong><br>
  A deathroll gambling incremental for <strong>World of Warcraft: Forever</strong>.<br>
  Native Lua 5.1 · no libraries · no real gold touched.
</p>

> **Status — 0.0.3.** Syntax-checked by CI on every release. 0.0.2 fixed a round of runtime faults;
> 0.0.3 implements the Shift-stepping that earlier versions advertised but did not have. It has
> still **never been played in game**. Checklist: [TODO.md](TODO.md).

---

## Download

Grab the newest `DeathrollBaron-*.zip` from the **[latest release](../../releases/latest)**. A
matching `.sha256` file sits beside it:

```powershell
# Windows PowerShell
Get-FileHash .\DeathrollBaron-0.0.3.zip -Algorithm SHA256
```

```bash
# macOS / Linux
shasum -a 256 DeathrollBaron-0.0.3.zip
```

---

## What it is

You run a table in a back-alley gambling den. No swords, no spells — dice. You sit down opposite a
mob you could walk up to in Azeroth, put gold on the felt, and deathroll it.

The table opens at a ceiling. One side rolls `1..ceiling`, then the other rolls `1..(that result)`,
alternating, until somebody rolls a 1 and pays. Win and you take the pot; lose and it's gone. Your
whole bankroll is fictional, lives in SavedVariables, and never touches your character's gold.

Progress is a run: climb 30 named opponents, buy power-ups, and when the bankroll finally hits zero
the table takes you and you convert a peak into **Bone Crowns** for the next run.

---

## Install

1. Extract the release zip (or copy `addon/DeathrollBaron`) so the layout is:

   ```
   World of Warcraft\_forever_\Interface\AddOns\DeathrollBaron\DeathrollBaron.toc
   World of Warcraft\_forever_\Interface\AddOns\DeathrollBaron\DeathrollBaron.lua
   ```

2. Restart the client (a brand-new addon needs a full restart; after that `/reload` is enough).
3. Type `/drb` in game.

The addon declares `## Interface: 16001`, the Forever client value (1.60.1). If a patch moves it,
`/dump select(4, GetBuildInfo())` reports what your client expects.

---

## The loop

1. **Pick a rung.** Rungs unlock in order: beat one and the next name sits down. You can always
   re-fight anyone you've already beaten.
2. **Read the cheats.** Each NPC brings affixes — sometimes its edge, sometimes its flaw. They are
   rolled when the run starts, so the same Hogger is a pushover tonight and a monster tomorrow.
3. **Set a wager.** Bounded below by the rung's minimum and above by your bankroll; the payout is
   capped by the NPC's purse, which is the ratchet that forces you up the ladder.
4. **Roll.** A plain click resolves the whole deathroll on a shrinking ticker.
   **Shift-click** instead and you roll it yourself, one click per roll; you can also Shift-click
   mid-run to take the ticker off auto. The line under the button always names the current mode.
5. **Spend.** Power-ups improve your luck, tax their luck, raise the multiplier or blunt your losses.
6. **Go broke.** Peak bankroll converts into Bone Crowns, which buy permanent advantages for the
   next run.

---

## The ladder

30 real mobs, in the order you'd meet them.

| # | NPC | Where | Level | Opens at | Min wager | Purse |
|---|---|---|---|---|---|---|
| 1 | Kobold Vermin | Elwynn Forest | 1-2 | 100 | 50 | 300 |
| 2 | Defias Thug | Elwynn Forest | 3-4 | 100 | 65 | 400 |
| 3 | Frostmane Troll Whelp | Dun Morogh | 3-4 | 100 | 90 | 530 |
| 4 | Murloc Forager | Elwynn Forest | 5-6 | 100 | 115 | 700 |
| 5 | Riverpaw Outrunner | Elwynn Forest | 6-7 | 100 | 155 | 930 |
| 6 | Leper Gnome | Dun Morogh | 8-10 | 150 | 205 | 1,240 |
| 7 | Goldtooth | Elwynn Forest | 8 | 150 | 275 | 1,650 |
| 8 | Morgan the Collector | Elwynn Forest | 10 | 150 | 365 | 2,190 |
| 9 | Hogger | Elwynn Forest | 11 elite | 150 | 485 | 2,900 |
| 10 | Defias Trapper | Westfall | 12-13 | 150 | 645 | 3,870 |
| 11 | Slark | Westfall coast | 11-15 | 250 | 860 | 5,150 |
| 12 | Defias Messenger | Westfall | 14-15 | 250 | 1,140 | 6,850 |
| 13 | Harvest Watcher | Westfall | 14-15 | 250 | 1,520 | 9,100 |
| 14 | Defias Pillager | Westfall | 14-15 | 250 | 2,020 | 12,100 |
| 15 | Stonesplinter Bonesnapper | Loch Modan | 15-16 | 250 | 2,680 | 16,100 |
| 16 | Stonesplinter Digger | Loch Modan | 18-19 | 400 | 3,570 | 21,400 |
| 17 | Brack | Redridge Mountains | 18-19 | 400 | 4,750 | 28,500 |
| 18 | Squiddic | Redridge Mountains | 19 | 400 | 6,320 | 37,900 |
| 19 | Old Murk-Eye | Westfall | 20 quest | 400 | 8,400 | 50,400 |
| 20 | Cookie | The Deadmines | 20 elite | 400 | 11,160 | 67,000 |
| 21 | Awakened Lich | Duskwood | 25 elite | 600 | 14,850 | 89,100 |
| 22 | Bone Chewer | Duskwood | 26-27 | 600 | 19,750 | 118,500 |
| 23 | Boulderfist Ogre | Arathi Highlands | 30+ | 600 | 26,270 | 157,600 |
| 24 | Drywhisker Kobold | Arathi Highlands | 30+ | 600 | 34,930 | 209,600 |
| 25 | Daggerspine Raider | Arathi Highlands | 30+ | 600 | 46,470 | 278,800 |
| 26 | Dark Iron Shadowcaster | Arathi Highlands | 30+ | 1000 | 61,800 | 370,800 |
| 27 | Gelihast | Blackfathom Deeps | 23-26 | 1000 | 82,200 | 493,200 |
| 28 | Blind Mary | Duskwood | 40 | 1000 | 109,300 | 655,900 |
| 29 | Amokarok | Duskwood | elite | 1000 | 145,400 | 872,400 |
| 30 | Mutanus the Devourer | Wailing Caverns | elite | 1000 | 193,400 | 1,160,300 |

The roster order is fixed so the world reads as the world. What gets randomised is what each one
brings.

---

## Affixes — rolled fresh every run

| Rungs | Affixes | Pool unlocked |
|---|---|---|
| 1-5 | **0** — pure base RNG | — |
| 6-11 | 1 | weak |
| 12-17 | 2 | weak + medium |
| 18-23 | 3 | + strong |
| 24-30 | 4 | all |

Rungs 1-5 cannot roll anything at all. That is the anti-snowball: there is no round-one way to get a
cheater, and the early ladder is decided by honest dice.

---

## Luck and hex

```lua
local function rollSide(max, bias, takeHigh)
    local a = math.random(1, max)
    if math.random() < bias then
        local b = math.random(1, max)
        if takeHigh then a = math.max(a, b) else a = math.min(a, b) end
    end
    return a
end
```

Your **Luck** rolls twice and keeps the higher. Their **Hex** rolls twice and keeps the lower. This is
the design centre of the whole thing: keeping the higher number does not merely protect you from a 1,
it lengthens the chain, which hands the opponent more turns to kill themselves. Upgrades compound
instead of cancelling out, and the ticker stays tense at every tier.

---

## Power-ups

Cost for rank `n` is `base × 1.75^(n-1)`, rounded to 5.

| Power-up | Per rank | Max | Base cost |
|---|---|---|---|
| Weighted Dice | +8% Luck | 10 | 200 |
| Pocket Sand | +8% enemy Hex | 8 | 250 |
| Marked Cards | +12% payout | 10 | 300 |
| Fast Hands | ticker ×2 speed | 2 | 150 |
| Cheap Trick | the enemy opens | 1 | 800 |
| Banker's Cut | lose 60/45/35% of the wager | 3 | 900 |
| Blood Pact | +1 Insurance charge | 3 | 1,200 |
| The Runner | auto-play + offline income | 1 | 2,500 |

**The Runner** plays one match every six seconds and pays offline at 60% of your simulated rate,
capped at eight hours.

---

## Prestige

Going broke pays `floor(sqrt(peak / 1000))` Bone Crowns. Four permanent upgrades, bought in the
game-over overlay: Old Money (+250 starting bankroll), Bloodline (+2% base Luck), Inside Man (-5%
power-up cost) and Inherited Dice (keep one power-up between runs).

---

## Commands

```
/drb, /baron        open or close the table
/drb sim            300 silent matches at the selected rung: win rate and net gold
/drb reset          wipe progress and deal a fresh set of cheats
```

`/dr` is deliberately **not** registered — other gambling addons claim it.

---

## Compatibility and safety

- Written against **Forever** interface `16001` (client 1.60.1), Lua 5.1, no libraries.
- Uses only frames, textures, font strings, SavedVariables and timers, plus `IsShiftKeyDown()` for the
  manual mode. It reads no combat data, no unit health, no combat log.
- The bankroll is fictional. `GetMoney()` is never called, no trade window is opened, and no real item
  or coin is touched.
- Opponents are stored as names and zone strings. No unit tokens, no GUIDs, no NPC lookups.

---

## Development

```
addon/DeathrollBaron/DeathrollBaron.toc
addon/DeathrollBaron/DeathrollBaron.lua   one file, all of it
.github/workflows/release.yml             parses the Lua, zips the addon, attaches it to the release
```

CI runs `luac5.1 -p` on every Lua file before it will package anything. Retuning the economy is a
table edit in `NPCS`, `AFFIXES` or `POWERS`; nothing derives a hard-coded cost.

See [TODO.md](TODO.md) for the in-game checklist, and [AI-DISCLOSURE.md](AI-DISCLOSURE.md) for who
wrote what.

---

## License

MIT — see [LICENSE](LICENSE).

**Created by ErrorSeiB & Buffy (Codebuff).**

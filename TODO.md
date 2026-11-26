# TODO

## Before anyone calls 0.1.0 usable

- [ ] `/console scriptErrors 1`, then load the client and fix the first error. Repeat until quiet.
- [ ] Open the window with `/drb`. Confirm the frame builds, drags, and closes.
- [ ] Play rung 1 to a win and to a loss. Confirm gold moves by exactly the wager.
- [ ] Confirm a win on rung 1 unlocks rung 2 and the `<` / `>` buttons respect it.
- [ ] Buy one rank of Weighted Dice and confirm the luck line changes.
- [ ] Confirm affixes appear from rung 6 and are absent on 1-5.
- [ ] Lose everything on purpose: the prestige overlay should appear with Bone Crowns.
- [ ] `/reload` mid-run and confirm the bankroll, rung and rolled affixes survive.
- [ ] Take the shark's loan once and confirm it cannot be taken twice.
- [ ] Buy the Runner, close the window, wait two minutes, confirm gold moved.

## Balance

- [ ] Run `/drb sim` on every rung and record the win rate. Adjust `playerLuck`, purses or affixes
      until the curve rises smoothly and no rung is a coin-flip wall.
- [ ] Check a full run takes 15-40 minutes.
- [ ] Check the first prestige lands after roughly 8-12 rungs, not 30.

## Features held back

- [ ] `Read the Room` prestige upgrade (see affixes before betting).
- [ ] Wager slider to replace the stepper.
- [ ] Challenge your current target: roll affixes from its level using the same engine.
- [ ] Addon-vs-addon multiplayer over a seeded shared table.

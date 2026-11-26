# AI disclosure

Deathroll Baron was designed and written by **ErrorSeiB** working with **Buffy** (Codebuff), an AI
coding agent. The design decisions, the ladder, the affix pools and the balance numbers were
argued out in conversation; the Lua was written by the agent.

The important part, stated plainly: **none of this code has been executed.** It was written on a
machine Freebuff could not reach, so there was no shell, no `luac -p`, and no client to load it in.
Treat 0.1.0 as a first draft that compiles in someone's head and nowhere else, until the in-game
pass in [TODO.md](TODO.md) is done.

What the AI did **not** do:

- It did not touch any Blizzard API that reads combat data, unit health or the combat log.
- It did not move, create or inspect real gold. The bankroll is fictional and stored in SavedVariables.
- It did not invent NPC names. Every opponent is a mob that exists in the game.

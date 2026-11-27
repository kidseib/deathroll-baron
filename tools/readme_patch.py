import pathlib

p = pathlib.Path("README.md")
s = p.read_text()
anchor = "shasum -a 256 DeathrollBaron-0.0.14-beta.1.zip\n```\n\n---\n\n## What it is"
install = """shasum -a 256 DeathrollBaron-0.0.14-beta.1.zip
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

## What it is"""

if s.count(anchor) != 1: raise SystemExit("README install anchor: %d matches" % s.count(anchor))
s = s.replace(anchor, install, 1)
p.write_text(s)
print("ok install")

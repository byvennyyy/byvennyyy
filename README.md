# Escape the Animals!

A Roblox difficulty-chart obby with a twist: every difficulty tier is a **biome**, and every biome
has an **animal that hatches from an egg and chases you** through its 10 stages. 20 biomes, 200
stages, 200 checkpoints, 20 eggs to hatch, 20 animals to outrun and tame.

- **Design doc:** [`docs/GDD.md`](docs/GDD.md) (short). Long version with every table: `docs/GDD-full.md`
- **Name shortlist:** `docs/names.json` (recommendation: **Escape the Animals!**)
- **Studio setup and asset import:** [`docs/SETUP.md`](docs/SETUP.md)
- **Biome roster (design data):** `docs/roster.json` -> generated into
  `src/ReplicatedStorage/Shared/Config/Biomes.luau` by `scripts/gen_biomes.py`

## Layout

```
default.project.json                       Rojo tree (code only; models live in Studio)
src/ReplicatedStorage/Shared/              shared engine: types, path math, chase profiles, remotes, config
src/ServerScriptService/Server/            services: data, checkpoints, chaser, biome registry, greybox builder
src/StarterPlayer/StarterPlayerScripts/    client: chaser renderer, egg-hatch cutscene, progress bar, HUD
tests/                                     unit tests for the pure modules (standalone luau CLI)
scripts/check.sh                           typecheck + lint + format check
```

## How the chase works, in one paragraph

Each biome has a path (a polyline of waypoints through all 10 stages). The animal is a number: how
many studs along that path it is. The server advances it every frame using the biome's speed and
the animal's chase profile, rubber-bands it so it never falls hopelessly behind and never catches a
player who keeps moving, and sends the number to the player 15 times a second. The client draws the
animal at that point on the path and the progress bar draws both markers. No pathfinding, no
physics, so any rig works.

## Quick start

```
rokit install            # rojo, luau-lsp, stylua
rojo serve               # then Connect from the Rojo plugin in Studio
scripts/check.sh         # before committing
LUAU=luau tests/run.sh   # unit tests
```

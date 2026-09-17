# Hatch & Dash: Game Design Document

A classic stud-brick Difficulty Chart Obby, with one twist: every difficulty is a biome, and every biome hatches an animal that chases you.

## 1. Overview

- **Genre:** Difficulty Chart Obby (DCO). 20 difficulties, 10 stages each, 200 stages, one checkpoint per stage.
- **Twist:** each difficulty is a biome. At the start of every biome an egg hatches, an animal jumps out and chases you through all 10 stages. Beat the biome and you tame the animal.
- **Look:** typical DCO. Studded plastic bricks in the difficulty colour, neon red kill bricks, simple geometry. The biome is the theme layer on top: palette, skybox, a few props, music.
- **Platform:** Roblox, PC and mobile (thumbstick + jump only).
- **Audience:** 9-14, obby players and the egg/animal crowd.

## 2. Core loop

1. Spawn at your checkpoint.
2. Egg at the biome start hatches (5 s cutscene). Animal appears. RUN!
3. Run 10 stages while the animal follows behind you.
4. Caught or fell: respawn at your checkpoint, animal is pushed back behind it and frozen for a few seconds.
5. Touch the next biome's first checkpoint: animal defeated and tamed, next egg.

## 3. Rules

**Stages and checkpoints.** Stage N is in biome ceil(N/10). Checkpoints only count in order (you must be on stage N-1 to take N). Respawn on your checkpoint, 1.5 s.

**The chase.** The animal runs the same route as you (a path of invisible waypoints through the biome). It is always behind you. It moves at the biome's speed; you move at 16 studs/s. The only way to get caught is to stop.

- **Catch:** animal within 3 studs of you along the path and 6 studs in 3D (or stuck on you for 1 s). You die.
- **Head start:** after the hatch, 9-12 s depending on biome. After each death, 2.5-4 s.
- **Reset:** on death the animal moves 30-45 studs behind your checkpoint.
- **Rubber band:** far behind (more than about 150-200 studs) it speeds up so it stays in view. Close behind you while you keep moving forward, it is capped just under your pace so it never catches a player who is playing well. Standing still is always punished.

**Taming.** Beating a biome adds its animal to your Egg Dex. Tamed animals can follow you as pets (gamepass).

**Multiplayer.** Everyone has their own animal. You only see yours. No PvP.

## 4. The 20 biomes

Animal names are the exact model names from the Animal Empire bundle.

| # | Difficulty | Biome | Animal | New obstacle | Chase feel | Speed | Head start |
|---|---|---|---|---|---|---|---|
| 1 | Easy | Sunny Meadow | Capybara | gap jumps | steady, slow | 9 | 12 s |
| 2 | Medium | Golden Farm | GoldenRetriver | moving platforms | trots, stops to sniff | 10 | 11 s |
| 3 | Hard | Sunset Rooftops | Cat | kill bricks | stalks, faster if you idle | 11 | 10 s |
| 4 | Difficult | Whispering Woods | Tanuki | spinners | hides in bushes, then runs | 11.5 | 10 s |
| 5 | Challenging | Sunset Shore | Quokka | conveyors | steady, stops for a selfie | 12 | 10 s |
| 6 | Intense | Red Outback | Kangaroo | bounce pads | hops in bursts | 13 | 9 s |
| 7 | Remorseless | Honey Mines | HoneyBadger | wall hops | relentless, punishes idling | 13.5 | 9 s |
| 8 | Insane | Emerald Jungle | Cassowary | truss climbs | charges after a warning | 14 | 9 s |
| 9 | Extreme | Ape Temple | Gorilla | falling floors | chest-beat, then sprint | 14.5 | 9 s |
| 10 | Terrifying | Shark Reef | Shark | narrow beams over water | swims alongside | 15 | 9 s |
| 11 | Catastrophic | Croc Caverns | Crocodile | darkness | lurks, fast if you stop | 15 | 9 s |
| 12 | Horrific | Glacier Age | Mamoth | ice | steady heavyweight | 15.5 | 9 s |
| 13 | Unreal | Tar Pits | SABER_TOOTHED_TIGER | sinking platforms | pounces (short teleport) | 16 | 10 s |
| 14 | Nil | Pterosaur Peaks | QUETZALCOATLUS | wind | flies over gaps | 16.5 | 10 s |
| 15 | Extinction | The Trench | MEGALODON | crushers | swims, huge | 17 | 10 s |
| 16 | Mythic | The Labyrinth | MINOTAUR | portal pads | roars, then charges | 17.5 | 11 s |
| 17 | Infernal | Inferno | CERBERUS | rising lava | three-phase bursts | 18 | 11 s |
| 18 | Abyssal | Storm Sea | KRAKEN | rotating bars | swims, tentacle slam pause | 18.5 | 12 s |
| 19 | Celestial | Phoenix Peak | FIREPHOENIX | updraft fans | flies, circles every 12 s | 19 | 12 s |
| 20 | Omega | Dragon's End | CLASSICDRAGON | beam grids | roars 3 s, then sprints | 20 | 12 s |

Speeds are studs per second. Difficulties 1-14 use the standard chart names and colours; 15-20 are custom (bone white, gold, ember, deep violet, lavender, hot pink).

Acts: 1-5 cute pets, 6-10 wild animals, 11-15 ancient beasts, 16-20 myths. Leftover bundle animals (Fenrir, Shoebill, Blobfish, Hyena, Kitsune, Hydra, Dullahan) are event biomes later.

## 5. Difficulty

Difficulty comes from the biome number. Every biome adds one new obstacle and keeps all earlier ones. Between biome 1 and 20, gaps grow from 3-5 to 8-11 studs, platforms shrink from 12 to 4 studs, kill brick density goes from 5% to 55%, moving parts go from 6 to 22 studs/s, timing windows shrink from 2.2 s to 0.7 s, and stages get longer (about 200 to 430 studs of path, 40 s to 130 s). Within a biome: stages 1-3 introduce the new obstacle, 4-7 mix it with old ones, 8-10 are the hard version.

A generator builds all 200 stages as greybox from these numbers so the game is playable on day one. Builders replace stages one at a time.

## 6. Egg hatch cutscene (about 5 s, every biome start)

1. Player freezes, camera swings to the egg on its pedestal (0.6 s).
2. Egg wobbles three times, harder each time, crack sounds (1.4 s).
3. Flash, shell bursts, animal pops up from small to full size with a bounce, camera shake (0.5 s).
4. Card slams in: "BIOME 7 - REMORSELESS - HONEY MINES" and the animal name, in the difficulty colour (1.75 s).
5. Camera returns, control returns, big red RUN! (0.5 s).
6. Head start countdown on the progress bar. Animal starts moving when it hits zero.

First hatch of each biome always plays. Repeats can be skipped with any tap or key. A setting turns repeats into just the card.

## 7. Progress bar and HUD

**Bar (top centre, whole biome):** 10 segments in the difficulty colour with a tick at each checkpoint and a flag at the end. Your headshot is one marker, a small live render of the animal is the other. Under it: the distance in studs. Under 40 studs the animal marker pulses red and a heartbeat sound fades in. While the animal is frozen, the countdown shows on its marker.

**Also on screen:** biome name and difficulty badge (top left), "Stage 63 / 200" and "3 / 10" (top right), deaths and biome timer (bottom left), Egg Dex / Shop / Settings buttons (bottom right). CAUGHT! flash when caught, TAMED! flash when you beat a biome.

**Egg Dex:** 4 x 5 grid of the 20 eggs: unknown, hatched, tamed, equipped.

## 8. Art style

- Studded plastic bricks (TopSurface Studs, BottomSurface Inlet), 1-stud slabs and classic brick sizes.
- Platforms in the difficulty colour, kill bricks neon red, checkpoints neon in the difficulty colour with a flag and the stage number.
- Biome theme = palette for accents and ground, a skybox, lighting, a handful of props (fences and daisies, hay bales, rooftops and vents, trees, palms, ...), and a music loop. No realistic materials.
- A difficulty chart board at spawn listing all 20 difficulties with their colours and biomes.
- Animals: the bundle rigs as they are, with Idle and Run animations where available. Eggs from the EggPack, one per biome, tinted to the biome.

## 9. Monetization

| Item | Type | Price |
|---|---|---|
| Skip Stage | product | 25 R$ |
| Revive Here (on the death screen) | product | 30 R$ |
| Skip Biome | product | 149 R$ |
| Speed Coil / Gravity Coil | gamepass | 99 / 149 R$ |
| Double Head Start | gamepass | 199 R$ |
| Pet Follow (tamed animals follow you) | gamepass | 249 R$ |
| VIP (tag, trail, 3 free skips a day) | gamepass | 499 R$ |

Nothing affects other players. Skips are never needed to finish.

## 10. Build order

1. Engine (done, in this repo): chase, checkpoints, cutscene, bar, data, generator, shop hooks.
2. Import the animal bundle and egg pack into the place; set the egg model per biome.
3. Build biomes 1-2 by hand in stud style, with props and sky. Playtest the hatch and the chase.
4. Build biomes 3-10, then 11-20, in order. Tune speeds and head starts per biome from playtests (catches should be 5-20% of deaths).
5. Wire real gamepass and product ids, badges, leaderboards.
6. Icon, thumbnails, soft launch, then event biomes.

## 11. Name

**Hatch & Dash**, listed as "Hatch & Dash 🥚 Animal Chase Obby [20 BIOMES]". Runner-up: Eggscape Obby. Avoid "Escape Animals Obby" (lost among many similar titles) and "Obby but Animals Chase You" (an almost identical game exists).

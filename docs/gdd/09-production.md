## 9. Production Plan

### 9.1 Team

| Role | Owns | Also |
|---|---|---|
| Game director / designer | roster, tuning, GDD, playtests, store page | QA lead |
| Level builder | 200 stages from greybox to art, biome kits, pedestals | lighting per biome |
| Scripter | engine (this repo), monetization, data, analytics events | Studio tooling |
| Artist / animator (part-time) | 20 animal rig checks and animations, 20 eggs, UI icons, thumbnails | sound sourcing |

### 9.2 Milestones

| Milestone | Content | Exit criteria |
|---|---|---|
| M0 Greybox prototype (done) | engine, generated 20 biomes, placeholder animals and eggs, cutscene, bar, HUD, data | plays end to end in Studio; typecheck, tests and build green |
| M1 Vertical slice | biomes 1-2 art complete with real Capybara and Golden Retriever rigs, real eggs, sounds, music | 10 external testers finish biome 1 at 80%+ and say the hatch is the best moment |
| M2 Alpha | biomes 1-10 hand-built, all 20 animals imported and checked, Egg Dex, shop wired with real ids | catch share 5-20% per biome; D1 40% in a closed test |
| M3 Beta | biomes 11-20, follower pets, leaderboards, badges, analytics events, settings | full funnel targets in a 500-player test |
| M4 Soft launch | store page, icon, three thumbnails, title A/B | 2 weeks of data, tuning pass |
| M5 Launch | first event biome ready (Fenrir / Ragnarok), YouTuber keys | |

### 9.3 Work breakdown

**Engineering (scripter)**

| Task | Estimate | Depends on | Milestone |
|---|---|---|---|
| Wire real gamepass/product/badge ids, test receipts in a live test place | 4 h | Roblox items created | M2 |
| Death screen with Revive Here | 6 h | | M2 |
| Follower pet (equippedPet spawns the tamed rig behind the player, per-player, client-rendered) | 12 h | animal rigs | M3 |
| Leaderboards (OrderedDataStore boards in lobby + per biome) | 10 h | | M3 |
| Analytics events (BiomeCompleted, Caught, CutsceneDone skipped) | 4 h | | M2 |
| Daily streak + skip tokens | 8 h | | M3 |
| Friends' chaser ghosts at low tick rate | 8 h | | post-launch |
| Biome teleport from the Egg Dex | 4 h | | M3 |
| Sky/lighting tween per biome in the cutscene | 3 h | palettes | M2 |
| Event biome loader (extra biome folder + def) | 6 h | | M5 |

**Level design (builder), per biome**

| Task | Estimate per biome | Notes |
|---|---|---|
| Greybox review and route lock (walk the generated stages, mark keepers) | 2 h | |
| Hand-build 10 stages inside the parameter table | 12 h | acts 3-4: 16 h |
| Biome kit: materials, props, pedestal dressing, skybox and lighting | 8 h | |
| Hazard pass to targets (deaths per stage) | 3 h | |
| Waypoint path re-lay and checkpoint placement | 2 h | |
| Tuning with 3 skill bands | 3 h | |

20 biomes x about 30 h = 600 h, about 15 builder-weeks. Act 1 first (M1), then in roster order.

**Art**

| Task | Estimate | Milestone |
|---|---|---|
| Import the Animal Empire bundle, set PrimaryParts, check scale (20 animals) | 6 h | M1-M2 |
| Animation check and fills: Idle/Run for 14 ground rigs, Fly loops for 3, Swim loops for 3, Roar for 4, Pounce for 1 | 40 h | M2 |
| Egg pack mapping + 20 egg materials/patterns | 10 h | M1-M2 |
| 20 animal render icons (128 px) | 8 h | M2 |
| UI icon set, Egg Dex art, tier badges | 10 h | M2 |
| Icon and 3 thumbnails (animal lunging, tier band, biome backdrop) | 12 h | M4 |

**Audio**

| Task | Estimate |
|---|---|
| Hatch set (rumble, 3 cracks, bass burst, GO stinger), caught, checkpoint, tamed, heartbeat loop, click | 6 h |
| 20 animal vocalisations + footstep sets (bundle or library) | 10 h |
| 20 biome music loops + 5 chase layers (one per act) | licensed library, 8 h to select and cut |

**QA and design**

| Task | Estimate |
|---|---|
| Playtest sessions per milestone (3 skill bands x 5 players) | 6 h per session |
| Funnel review and tuning per act | 8 h per act |
| Store page copy, title A/B setup | 6 h |

### 9.4 Risk register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Bundle rigs vary in quality (missing animations, odd scale, no PrimaryPart) | high | medium | resolver auto-fixes PrimaryPart and scale; procedural bob covers missing animations; alternates listed per biome |
| Difficulty curve too steep in act 2, funnel collapses at biome 6-8 | medium | high | parameter table + per-biome tuning loop; two extra playtests on biomes 5-8 |
| Mobile performance in generated biomes (part count) | medium | medium | StreamingEnabled, 4 x 5 grid keeps cells apart, hand-built stages replace generated ones with fewer parts |
| DataStore outage wipes progress | low | high | read-only fallback, never save defaults over unknown data |
| Catch feels unfair (caught while moving) | medium | high | mercy rule caps speed at 0.9 x player pace; contact catch needs 1 s; telemetry on catch share |
| Cutscene fatigue | high | medium | skip on repeats, card-only setting, 5.2 s budget |
| Name collision / search invisibility | medium | medium | brand + keyword listing title, A/B at soft launch (section 10) |
| Exploiters teleporting through stages | medium | low | sequential checkpoints; only the exploiter's own run is affected |

### 9.5 Playtest plan

- Every milestone: 15 testers (5 new to obbies, 5 mid, 5 veterans), 30-minute sessions, screen recorded.
- Measure per stage: clear time, deaths, catches, quits; per player: the biome they stopped at and why (short survey).
- The tuning loop in section 4.7 runs after every session; a biome is locked when three consecutive sessions hit its targets.

### 9.6 Launch and marketing

- **Icon**: a cracked egg with an animal eye glaring out, tier-colour band along the bottom, the brand name.
- **Thumbnails** (formula): animal lunging at the player from behind, mid-jump, biome backdrop, a tier-colour band with the biome name; one per act plus one "20 BIOMES 20 ANIMALS" grid.
- **Title A/B**: two listing titles for a week each, keep the higher click-through.
- **Update cadence**: one event biome or one new animal cosmetic every 3-4 weeks, announced through the bracketed title tag.
- **Creators**: keys to obby YouTubers with a "beat biome 20 without getting caught" challenge; the TAMED flash and the bar are built to be clipped.

### 9.7 Post-launch roadmap

1. Event biomes: Ragnarok (Fenrir, winter), Stare Swamp (Shoebill, autumn), Gloom Marsh (Dullahan, Halloween), Lunar New Year (Kitsune).
2. Boss rush mode: Hydra biome with three chasers.
3. Chicken Run: 2-player mode where one player is the chicken.
4. First-person camera toggle and a "no coils" leaderboard.
5. Egg cosmetics and animal skins in the shop.

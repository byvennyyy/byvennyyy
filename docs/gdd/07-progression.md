## 7. Progression, Retention and Monetization

### 7.1 Player data

Saved per player (DataStore `PlayerData_v1`, autosave every 60 s, on leave and on server close, loaded with five retries and a read-only fallback that never overwrites real progress with defaults):

| Field | Meaning |
|---|---|
| stage | 1-201, the checkpoint you spawn at |
| deaths | lifetime deaths |
| eggsHatched | biome index -> true, set when a biome's egg hatches for you |
| tamed | animal name -> true, set when you beat the animal's biome |
| biomeBestTimes | biome index -> best clear time in seconds |
| equippedPet | the tamed animal that follows you |
| settings | skipCutscenes, showGap, musicVolume, sfxVolume |
| purchases | gamepass key -> true (cache of ownership) |

Leaderstats show **Stage** (1-200) and **Biome** (name), so the default player list doubles as a leaderboard.

### 7.2 Badges

| Badge | Condition |
|---|---|
| First Hatch | biome 1's egg hatched |
| Pet Owner | act 1 complete (biome 5) |
| Wild Thing | act 2 complete (biome 10) |
| Ancient | act 3 complete (biome 15) |
| Halfway | reached biome 11 |
| Finished | stage 201 |
| Zookeeper | all 20 animals tamed |

### 7.3 The tame loop (retention spine)

Beat a biome and the animal that chased you is yours. The Egg Dex is the collection screen; the follower pet is the flex. Progression is therefore visible to other players (your pet), to you (the Dex grid filling in), and to your friends (the leaderstats). Seasonal biomes add animals to the Dex without touching the 200-stage core.

### 7.4 Daily streak and login rewards (milestone 3)

Day 1-7 rewards: one free Skip Stage token on days 3 and 7, an egg-shell cosmetic on day 5, a trail on day 7; the streak resets after 48 h. Tokens are consumed by the same handler as the paid product.

### 7.5 Leaderboards

- Global: highest stage (from leaderstats via OrderedDataStore, refreshed every 60 s).
- Per biome: best clear time, one board per biome in the lobby of that biome (from biomeBestTimes).
- Fair-play flag: runs with coils are shown with a coil icon; the top ten filter to coil-free runs.

### 7.6 Social hooks

- Other players and their tamed pets are visible; friends spawn in the same server when possible.
- "Chased by" screenshot button (roadmap): freezes the frame with the animal one body length behind and adds the biome name and tier colour band, the same composition as the thumbnails.
- Biome 20 hatch broadcasts a server-wide toast.

### 7.7 Seasonal and event biomes

Event biomes reuse the engine with one extra biome folder and one extra animal from the bundle, no core changes:

{{UNUSED_ANIMALS}}

### 7.8 Monetization

Prices are grounded in the September 2026 observations in the research (Skip Stage 20-50 R$ with 20 the most common; coils 99-299; revive 30; VIP 500):

| Item | Type | Effect | Price (R$) | Fairness note |
|---|---|---|---|---|
| Skip Stage | product, repeatable | next checkpoint; the animal comes with you, frozen for a head start | 25 | never required; stages are designed to be beaten |
| Skip Biome | product, repeatable | first checkpoint of the next biome; no tame for the skipped animal | 149 | the Dex shows the animal as hatched, not tamed, so skipping costs collection |
| Revive Here | product, repeatable | respawn where you fell with 3 s of invulnerability | 30 | offered on the death screen after a catch |
| Speed Coil | gamepass | walkspeed 24 | 99 | flagged on leaderboards |
| Gravity Coil | gamepass | jump power 65 | 149 | flagged on leaderboards |
| Double Head Start | gamepass | every hatch and respawn head start doubled | 199 | convenience only |
| VIP | gamepass | chat tag, trail, 3 Skip Stage tokens a day | 499 | |
| Pet Follow | gamepass | tamed animals follow you as pets | 249 | cosmetic |
| Egg shells and trails | cosmetics | | 49-149 | |

**What stays fair.** No purchase affects another player. Skips move you along your own run and are counted separately in stats. The animal never gets easier for money except through head-start time.

### 7.9 KPI table

| KPI | Target | Instrument |
|---|---|---|
| D1 / D7 retention | 40% / 15% | Roblox analytics |
| Sessions per DAU | 1.8 | Roblox analytics |
| Biome completion funnel | 80% b1, 55% b3, 35% b5, 15% b10, 3% b20 | custom event per BiomeCompleted |
| Catch share of deaths | 5-20% per biome | custom event per ChaserEvent Caught |
| Cutscene skip rate on repeats | < 60% | custom event on CutsceneDone with skipped flag |
| Payer conversion | 3% | Roblox analytics |
| ARPDAU | 25-40 R$ | Roblox analytics |

### 7.10 A/B tests at soft launch

1. Listing title (brand first vs keyword first).
2. Biome 1 head start 12 s vs 8 s (does tension in the first minute help or hurt D1).
3. Revive Here at 30 vs 49 R$.
4. Repeat-hatch length: full vs card-only by default.
5. Bar gap label on vs off by default.

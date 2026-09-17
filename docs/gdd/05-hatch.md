## 5. Egg Hatch Cutscene and Animals

### 5.1 Beat sheet

Timings are `GameConfig.Cutscene`; the whole thing is 5.2 s plus a 0.5 s camera return. The first hatch of each biome always plays in full.

| Beat | Start | Length | Camera | Animation | VFX | SFX | UI |
|---|---|---|---|---|---|---|---|
| 1 Lock and frame | 0.0 s | 0.6 s | Scriptable; tweens (Quad out) from behind the player to a low 3/4 shot 8 studs right, 6 forward, 4.5 up from the pedestal, looking at the egg | player frozen (anchored, walkspeed 0) | letterbox bars | low rumble starts | HUD dims |
| 2 Wobble | 0.6 s | 1.4 s | holds | egg rotates on a sine, 3 wobbles, amplitude growing from 4 to 20 degrees | dust puffs at the base | a crack tick on every wobble peak | "tap to skip" hint on repeats |
| 3 Burst | 2.0 s | 0.45 s | shakes 0.6 studs | egg Top pops up and away (or the whole egg vanishes); animal scales from 10% to 100% with a 25% overshoot bounce | white flash 0.35 s, 10 shell shards flung with physics, 60 tier-coloured particles | bass drop | flash frame |
| 4 Reveal card | 2.45 s | 1.75 s | holds, animal idles | animal Idle (or Roar if the rig has one) | | animal vocalisation | card slams in with a Back ease from 1.8x: "BIOME 7 - REMORSELESS - HONEY MINES", animal name under it, in the tier colour |
| 5 Release | 4.2 s | 0.5 s | tweens back behind the player, then Custom | player unfrozen | | "GO" stinger | RUN! in red, fades over 1.1 s |
| 6 Head start | 4.7 s | biome headStart | normal | animal idles at the pedestal | | | countdown on the bar's animal marker |

**Escalation by act.** Acts 1-2 use the standard hatch. Act 3 adds a sky change (Lighting tween to the biome's palette over the wobble) and a slower camera push. Biome 20's hatch broadcasts a server-wide toast ("<name> reached the Dragon") so it is an event for everyone.

**Skip rules.** First view of each biome: not skippable. Later views: any input skips (tap, key, gamepad button); the hint line says so. The `skipCutscenes` setting reduces repeat hatches to the card only (1.2 s). Skipping tells the server, which starts the head start at once.

**Failure paths.** Death or disconnect during the cutscene aborts it: camera returns, control returns, the server head start still applies. Any script error inside a beat is caught and the release beat always runs; the player can never be left frozen.

### 5.2 Egg pedestal art direction

A 12 x 2 x 12 slate base and a 4 x 1.5 x 4 marble pedestal in the biome accent colour, 24 studs before the first checkpoint, with the biome's palette on the ground around it. Hand-built biomes dress the pedestal (nest, hay bale, tide pool, mine cart, temple altar, ice block, tar, cloud nest, trench vent, labyrinth door, lava crust, ship deck, sun disc, dragon hoard).

### 5.3 Egg designs and mapping the EggPack

{{EGG_TABLE}}

Eggs are models under `ReplicatedStorage/Assets/Eggs`. Each biome's `eggModel` field names the model; a missing name or nil gets a procedural egg (a tall sphere in the biome's secondary colour). If the egg model has a part named `Top`, it pops off in beat 3; otherwise the whole egg vanishes in the flash. Eggs never need animations.

### 5.4 Animal asset requirements

- **PrimaryPart** set (the code picks the HumanoidRootPart or the largest part if missing).
- **Size**: any rig taller than 12 studs is scaled down to 12 automatically; ideal is 3-8 studs.
- **Animations**: `Animation` objects anywhere in the model named Idle, Run or Walk (Fly/Swim count as Run). The renderer plays Run while chasing and Idle while frozen; rigs without animations get a procedural bob and tilt so placeholders still feel alive.
- **Defeated**: no animation needed; the renderer tips the model over with a bounce.
- **Sounds**: one vocalisation (roar, bark, hiss), footsteps or wingbeats, and a telegraph sound for roarers and the pouncer. Ids go into the client `Sfx` table.
- **Progress-bar render**: a ViewportFrame clone of the model, slowly yawing; or set `renderImage` on the biome to a pre-rendered 128 x 128 icon (recommended for launch, costs a render pass per animal).
- **Budget**: under 8k triangles and two 512 textures per animal; the client only ever renders one chaser plus one viewport clone.
- **Reuse**: the same rigs are the tamed follower pets and the Egg Dex renders; no second version.

### 5.5 Animal checklist

{{ANIMAL_CHECKLIST}}

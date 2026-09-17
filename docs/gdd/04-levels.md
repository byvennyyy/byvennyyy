## 4. Difficulty Curve and Level Design Bible

### 4.1 Philosophy

- **Difficulty comes from the biome number, not from the stage number.** Stages 1-10 within a biome ramp gently (introduce, combine, master), but the jump in difficulty happens at the biome boundary, where the new mechanic and the faster animal arrive together.
- **Stages are long.** Stage length grows from about 200 studs of path (40 s) in biome 1 to about 430 studs (130 s) in biome 20. A death costs seconds, never minutes, because there is a checkpoint at every stage.
- **The animal adds time pressure, not deaths.** Hazards kill; the animal only kills the player who stops. Tune hazards for the target death rate and the animal for tension.
- **One new verb per biome, stacked.** From biome 3 on, stages 4-10 recombine every earlier verb. Biomes 16-20 are compound exams.

{{MECHANIC_SEQUENCE}}

### 4.2 Per-biome parameters

These are the values `Difficulty.Get(i)` returns (linear between biome 1 and biome 20) plus the design targets. The greybox generator uses the first eight columns directly; hand-built stages should land inside them.

{{DIFFICULTY_TABLE}}

"Gap" is the horizontal jump distance between platforms, "Platform" the side length of a landing platform (largest to smallest), "Kill density" the fraction of lane tiles that are lethal, "Mover speed" the speed of moving platforms, conveyors, spinners and lava, "Timing window" the safe window of timed hazards (laser off time, crusher period base), "Chunks/stage" the number of obstacle chunks per stage, "Height drift" the vertical variance between chunks.

### 4.3 The 20 mechanics

{{MECHANIC_TABLE}}

Always available in every biome: plain platform runs (`platformRun`) as filler between obstacles, and corner platforms (`turn`) that bend the route.

**Mechanic rules for builders.**

- **Gap jumps.** Never exceed the biome's gapMax; a 50 jump-power character clears 11 studs flat. Downward jumps may add 2 studs, upward jumps subtract 1 per stud of rise.
- **Moving platforms.** Loop on fixed timings (server tweens), never random. The player must be able to see both ends from the boarding platform.
- **Kill lanes.** One safe column per row, moving at most one column per row. Kill tiles are red neon; nothing else in the game is red neon.
- **Spinners.** The bar rotates at 40 degrees/s + 4 x mover speed; the disc is walkable. Post height 6 so the bar never hits a jumping player at head height.
- **Conveyors.** Direction is readable from the DiamondPlate texture; backwards belts are 40% of belts. From biome 8 the side rails kill.
- **Bounce pads.** Fixed arcs: launch is 55 up and 22 forward; the landing platform is 10-14 studs ahead and 6-10 up. Chain two only from biome 12.
- **Wall hops.** Ledges alternate left and right, 5 studs up each; ledge size is half the biome's smallest platform.
- **Truss climbs.** 12-18 studs plus height drift; the truss is 2 wide, the wall behind it is solid so the animal (on the path) visibly waits below.
- **Falling floors.** Drop 0.4 s after the first touch, return 3 s later. Tiles are half-size platforms.
- **Narrow beams.** 1.2 studs wide, 10-18 long, bends up to 25 degrees. No kill parts on beams; falling is the punishment.
- **Dark corridors.** Enclosed box, lethal floor, lit pads only; pad light range is 1.6 x pad size so the next pad is always just visible.
- **Ice.** Friction 0.02; the exit gap after ice is 0.8 x the normal gap because momentum carries.
- **Sinking platforms.** Sink 6 studs over 2.2 s after the first touch, return after 3.5 s.
- **Wind tunnels.** Sideways push at 0.9 x mover speed toward a lethal rail; particles show the direction.
- **Crushers.** Slam every max(1.6, 1.6 x timing window) s: 15% of the period down, 20% resting, 65% rising. The block is lethal at all times; it rests 11 studs up.
- **Portal pads.** Paired; 30-50 studs apart; 1.5 s cooldown per player; decoys (hand-built only) return the player one room.
- **Rising lava.** A lava plane tweens up and down over the pit; pillars rise 5 studs each.
- **Rotating bars.** 22-30 studs long, 3 wide, rotate at 18 degrees/s + mover speed; the player rides the bar across a gap.
- **Updraft fans.** Launch 70 up and 18 forward; landing is 14-20 studs up (plus drift) and 6-10 ahead.
- **Beam grids.** Beams every 7 studs at 2.5 studs height, on for `timingWindow` s and off for 0.8 x that, offset 0.6 s per beam so a rhythm emerges.

### 4.4 Stage authoring rules

1. **Length by act.** Act 1 stages 200-260 studs of path, act 2 260-320, act 3 320-380, act 4 380-430.
2. **Always show the next platform.** From any safe platform the player must see the next safe platform without moving the camera. No blind drops.
3. **No cheese.** The chaser follows the path and the player is projected onto it within a 120-stud window; routes that leave the path corridor by more than 60 studs make the projection ambiguous. Keep alternate routes inside the corridor or block them.
4. **Sightlines for the animal.** Every 60-90 studs, give the player a spot where looking back shows the path 30+ studs behind. Seeing the animal is the point.
5. **Checkpoint placement.** At the start of each stage on a 7 x 7 pad, on flat ground, with 4 studs of run-up before the first obstacle. The flag pole stands at the front right.
6. **Colour language.** Red neon kills, tier colour marks progress (checkpoints, flags, biome exit), the biome accent colour marks interactive things (pads, portals, fans, movers), the biome ground colour is scenery.
7. **Materials per biome.** Use the palette from the biome sheet; keep a single "safe platform" material per biome so platforms read at a glance.
8. **Mobile.** Every obstacle is passable with thumbstick and jump; no wall jumps, no shift-lock requirements, no timing tighter than 0.7 s.
9. **Introduce, combine, master.** Stage 1-3 use the new mechanic alone with generous sizes; 4-7 combine it with two or three earlier mechanics; 8-10 use the biome's parameters at full strength and end with a set piece.
10. **The biome's mechanic appears at least twice in every stage** (the generator enforces this; hand-built stages should too).

### 4.5 Level authoring contract (what the code expects)

```
Workspace/Obby/
  Biome_01/                     zero-padded, one per biome
    EggPedestal                 Part; cutscene camera and chaser spawn use its CFrame
    Path/                       Folder of invisible parts WP_0001 .. WP_nnnn, in route order
    Stage_01/ .. Stage_10/      Folders
      Checkpoint                Part with attribute Stage = global stage number (set by the registry if missing)
      ...                       geometry; lethal parts carry the CollectionService tag KillBrick
    BiomeExit                   Part with attribute Stage = next biome's first stage (biomes 1-19)
    Finish                      Part with attribute Stage = 201 (biome 20 only)
```

- Waypoints are 3 studs above the walkable surface, every 10-25 studs, denser on corners, one on every safe platform. They are sorted by name.
- Checkpoints are projected onto the path at load; no hand-entered distances.
- Moving parts are anchored and moved by server tweens or the shared Movers driver so they replicate.
- Anything tagged `KillBrick` gets the lethal Touched handler automatically, including hand-built parts.

### 4.6 Using the greybox generator

With `Workspace/Obby` empty the server generates all 20 biomes at boot (about 3 s): grid of 2500-stud cells, four per row, each row 60 studs higher, every biome another 12 studs up. Each stage is 8-16 chunks chosen from the mechanics unlocked at that biome, with the biome's own mechanic at least twice, a turn every 4-6 chunks, and forced turns back toward the cell centre. Generation is seeded per stage (`biome x 1000 + stage`), so a stage looks the same every boot until you replace it.

Replacing a stage: build `Stage_07` by hand in Studio with a Checkpoint and its geometry, extend or re-lay the `Path` waypoints through it, and keep the folder names. Set `GameConfig.GenerateMissingBiomes = false` once every biome folder exists.

### 4.7 Playtest tuning loop

1. Record per stage: clear time, deaths, catches (deaths caused by the animal), and where players quit. `ChaserGap` is exposed as a player attribute for live inspection.
2. Compare to the targets table. A stage over its target time with few deaths is too long; under with many deaths is too hard.
3. Adjust hazards first (sizes, timings, density) and never the animal for a single stage.
4. If catches exceed 20% of deaths in a biome, raise `headStart` or `mercyGap` for that biome in `roster_mapping.json` and regenerate `Biomes.luau`. If catches are under 5% and the bar never pulses, lower `maxGap`.
5. Re-run with three player skill bands (new, mid, obby veteran) before locking a biome.

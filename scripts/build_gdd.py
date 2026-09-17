#!/usr/bin/env python3
"""Assemble docs/GDD.md from docs/gdd/*.md (handwritten sections, in filename order) and tables
generated from docs/roster.json, docs/roster_mapping.json, docs/names.json and the difficulty curve.
Placeholders inside section files: {{ROSTER_TABLE}} {{BIOME_SHEETS}} {{DIFFICULTY_TABLE}}
{{ANIMAL_CHECKLIST}} {{NAMES_TABLE}} {{UNUSED_ANIMALS}} {{MECHANIC_TABLE}} {{EGG_TABLE}}"""
import json
import math
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
roster = json.loads((ROOT / "docs" / "roster.json").read_text())
mapping = json.loads((ROOT / "docs" / "roster_mapping.json").read_text())
names = json.loads((ROOT / "docs" / "names.json").read_text())
biomes = roster["biomes"]

CURVE = {"gapMin": (3, 8), "gapMax": (5, 11), "platformMin": (8, 2.5), "platformMax": (12, 4), "killDensity": (0.05, 0.55), "moverSpeed": (6, 22), "timingWindow": (2.2, 0.7), "chunksPerStage": (8, 16), "heightVariance": (1, 8)}
MECH_NAMES = {"gapJump": "Gap jumps", "movingPlatform": "Moving platforms", "killLane": "Kill-brick lanes", "spinner": "Spinners", "conveyor": "Conveyors", "bouncePad": "Bounce pads", "wallHop": "Wall hops", "trussClimb": "Truss climbs", "fallingFloor": "Falling floors", "narrowBeam": "Narrow beams", "darkCorridor": "Dark corridors", "icePatch": "Ice", "shrinkingPlatform": "Sinking platforms", "windTunnel": "Wind tunnels", "crusher": "Crushers", "teleportPad": "Portal pads", "risingLava": "Rising lava", "rotatingBar": "Rotating bars", "fanLaunch": "Updraft fans", "laserGrid": "Beam grids"}
PROFILE_FEEL = {"steady": "steady cruise", "bursty": "burst and rest", "stalker": "idle punisher", "flyer": "flyer", "swimmer": "swimmer", "blinker": "pounce (teleport)", "roarer": "roar then sprint"}
HEX = re.compile(r"#([0-9A-Fa-f]{6})")


def lerp(a, b, t):
    return a + (b - a) * t


def diff(i):
    t = (i - 1) / 19
    return {k: lerp(v[0], v[1], t) for k, v in CURVE.items()}


def target_times(i):
    # design targets: path length per stage and clear time grow with the act
    t = (i - 1) / 19
    length = round(lerp(200, 430, t) / 10) * 10
    clear = round(lerp(40, 130, t) / 5) * 5
    deaths = round(lerp(0.3, 4.0, t), 1)
    return length, clear, deaths


def roster_table():
    rows = ["| # | Tier | Biome | Animal (folder) | Moves | Chase profile | Speed | Head start | New mechanic | Egg |", "|---|---|---|---|---|---|---|---|---|---|"]
    for b in biomes:
        m = mapping[str(b["index"])]
        rows.append(f"| {b['index']} | {b['difficultyLabel']} | {b['biomeName']} | {b['animal']} ({b['animalFolder']}) | {b['locomotion']} | {PROFILE_FEEL[m['profile']]} | {m['baseSpeed']} st/s | {m['headStart']} s | {MECH_NAMES[m['mechanic']]} (`{m['mechanic']}`) | {b['eggDesign'].split('.')[0].split(';')[0][:60]} |")
    return "\n".join(rows)


def biome_sheets():
    out = []
    for b in biomes:
        i = b["index"]
        m = mapping[str(i)]
        length, clear, deaths = target_times(i)
        c = b["chaseProfile"]
        hazards = "\n".join(f"- {h}" for h in b["signatureHazards"])
        alts = ", ".join(b.get("alternateAnimals", [])) or "none"
        params = ", ".join(f"{k} = {v}" for k, v in m.get("params", {}).items()) or "defaults"
        out.append(f"""### 3.{i} Biome {i}: {b['biomeName']} ({b['difficultyLabel']})

**Animal:** {b['animal']} from the `{b['animalFolder']}` folder, {b['locomotion']} locomotion. **Tier colour:** {m['tierColor']}.

**Theme.** {b['theme']}

**Why this animal.** {b['whyThisAnimal']}

**Chase feel.** Engine profile `{m['profile']}` ({PROFILE_FEEL[m['profile']]}), base speed {m['baseSpeed']} studs/s, head start {m['headStart']} s, profile params: {params}. Designed behaviour: {c['description']} Twist: {c['twist']}

**New mechanic ({MECH_NAMES[m['mechanic']]}, chunk key `{m['mechanic']}`).** {b['newMechanicIntroduced']} Stages 1-3 introduce it clean, stages 4-7 mix it with every earlier mechanic, stages 8-10 are the mastery test.

**Signature hazards.**
{hazards}

**Egg.** {b['eggDesign']}

**Palette.** {b['palette']}

**Music.** {b['musicVibe']}

**Targets.** Path length per stage about {length} studs, target clear time {clear} s per stage, expected deaths per stage about {deaths}, biome time about {round(clear * 10 / 60)} minutes for a competent player.

**Showpiece moment.** The thumbnail beat for this biome is the {b['animal']} at full speed on the biome's new mechanic: frame the player mid-air over the {MECH_NAMES[m['mechanic']].lower()} with the animal one body-length behind.

**Alternates if the model does not work out:** {alts}.
""")
    return "\n".join(out)


def difficulty_table():
    rows = ["| Biome | Gap (studs) | Platform (studs) | Kill density | Mover speed | Timing window | Chunks/stage | Height drift | Path/stage | Clear time | Deaths/stage |", "|---|---|---|---|---|---|---|---|---|---|---|"]
    for b in biomes:
        i = b["index"]
        d = diff(i)
        length, clear, deaths = target_times(i)
        rows.append(f"| {i} {b['biomeName']} | {d['gapMin']:.1f} - {d['gapMax']:.1f} | {d['platformMax']:.1f} - {d['platformMin']:.1f} | {d['killDensity']:.2f} | {d['moverSpeed']:.1f} st/s | {d['timingWindow']:.2f} s | {round(d['chunksPerStage'])} | {d['heightVariance']:.1f} | ~{length} studs | ~{clear} s | ~{deaths} |")
    return "\n".join(rows)


def mechanic_table():
    rows = ["| Unlock | Mechanic | Chunk key | Introduced by | Kills how | Scales with |", "|---|---|---|---|---|---|"]
    kills = {"gapJump": "falling", "movingPlatform": "falling (mistimed ride)", "killLane": "red neon tiles", "spinner": "rotating kill bar", "conveyor": "falling; lethal rails from biome 8", "bouncePad": "falling (missed landing)", "wallHop": "falling", "trussClimb": "falling", "fallingFloor": "falling after the tile drops", "narrowBeam": "falling", "darkCorridor": "lethal floor between lit pads", "icePatch": "sliding off", "shrinkingPlatform": "sinking under you", "windTunnel": "lethal edge rail on the push side", "crusher": "slamming block", "teleportPad": "falling; decoys send you back", "risingLava": "lava plane", "rotatingBar": "falling off the bar", "fanLaunch": "falling (missed ledge)", "laserGrid": "timed neon beams"}
    scales = {"gapJump": "gapMin/gapMax", "movingPlatform": "moverSpeed, travel", "killLane": "killDensity, tile size", "spinner": "moverSpeed (bar speed), radius", "conveyor": "moverSpeed", "bouncePad": "landing height", "wallHop": "ledge size", "trussClimb": "height", "fallingFloor": "tile size", "narrowBeam": "segment count, bends", "darkCorridor": "pad size, lateral drift", "icePatch": "length, exit gap", "shrinkingPlatform": "sink speed", "windTunnel": "moverSpeed (push)", "crusher": "timingWindow (period)", "teleportPad": "jump distance", "risingLava": "moverSpeed (rise rate)", "rotatingBar": "moverSpeed (spin)", "fanLaunch": "height", "laserGrid": "timingWindow"}
    for b in biomes:
        k = mapping[str(b["index"])]["mechanic"]
        rows.append(f"| {b['index']} | {MECH_NAMES[k]} | `{k}` | {b['biomeName']} | {kills[k]} | {scales[k]} |")
    return "\n".join(rows)


def animal_checklist():
    rows = ["| # | Model | Folder | Locomotion | Animations needed | Sounds needed | Notes |", "|---|---|---|---|---|---|---|"]
    for b in biomes:
        m = mapping[str(b["index"])]
        anims = "Idle, Run" if b["locomotion"] == "ground" else ("Idle, Fly" if b["locomotion"] == "flying" else ("Idle, Swim" if b["locomotion"] == "swimming" else "Idle, Hover"))
        extra = ", Roar" if m["profile"] == "roarer" else (", Pounce" if m["profile"] == "blinker" else "")
        rows.append(f"| {b['index']} | {b['animal']} | {b['animalFolder']} | {b['locomotion']} | {anims}{extra}, Defeated | vocalisation, footsteps/wingbeats, telegraph | PrimaryPart set; under 12 studs tall or it is auto-scaled |")
    return "\n".join(rows)


def egg_table():
    rows = ["| # | Biome | Egg design | Palette |", "|---|---|---|---|"]
    for b in biomes:
        rows.append(f"| {b['index']} | {b['biomeName']} | {b['eggDesign']} | {b['palette']} |")
    return "\n".join(rows)


def names_table():
    rows = ["| Name | Why | Tagline | Icon idea | Collision risk |", "|---|---|---|---|---|"]
    for n in names["top10"]:
        rows.append(f"| **{n['name']}** | {n['why']} | {n['tagline']} | {n['icon']} | {n['collision']} |")
    return "\n".join(rows)


def unused():
    return "\n".join(f"- **{u['animal']}**: {u['use']}" for u in roster["unusedNotableAnimals"] if u["use"] != "already used")


REPL = {"ROSTER_TABLE": roster_table, "BIOME_SHEETS": biome_sheets, "DIFFICULTY_TABLE": difficulty_table, "ANIMAL_CHECKLIST": animal_checklist, "NAMES_TABLE": names_table, "UNUSED_ANIMALS": unused, "MECHANIC_TABLE": mechanic_table, "EGG_TABLE": egg_table, "GAME_NAME": lambda: names["recommendation"], "ESCALATION": lambda: roster["escalationSummary"], "SPEED_CURVE": lambda: roster["speedCurveRationale"], "MECHANIC_SEQUENCE": lambda: roster["mechanicSequenceRationale"]}

parts = []
for f in sorted((ROOT / "docs" / "gdd").glob("*.md")):
    text = f.read_text(encoding="utf-8")
    for key, fn in REPL.items():
        text = text.replace("{{" + key + "}}", fn())
    parts.append(text.strip() + "\n")
header = f"# {names['recommendation']}: Game Design Document\n\nA Roblox difficulty-chart obby where every difficulty tier is a biome and every biome hatches an animal that chases you. 20 biomes, 200 stages, 20 eggs, 20 animals to outrun and tame.\n\n_Version 1.0. Source of truth for every number in this document: `docs/roster.json`, `docs/roster_mapping.json` and the generated `Biomes.luau`. Rebuild with `scripts/build_gdd.py`._\n"
(ROOT / "docs" / "GDD-full.md").write_text(header + "\n" + "\n".join(parts), encoding="utf-8")
print("wrote docs/GDD-full.md", sum(len(p) for p in parts) // 1024, "KB of sections")

#!/usr/bin/env python3
"""Generate src/ReplicatedStorage/Shared/Config/Biomes.luau from docs/roster.json.

The roster is the design source of truth (biome names, tiers, animals, chase feel, hazards,
palettes). docs/roster_mapping.json maps each biome's free-text chase style and mechanic to the
engine's fixed profile names and chunk keys, and holds per-biome tuning overrides.

Usage: scripts/gen_biomes.py [--check]
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ROSTER = ROOT / "docs" / "roster.json"
MAPPING = ROOT / "docs" / "roster_mapping.json"
OUT = ROOT / "src" / "ReplicatedStorage" / "Shared" / "Config" / "Biomes.luau"

PROFILES = {"steady", "bursty", "stalker", "flyer", "swimmer", "blinker", "roarer"}
CHUNKS = {
    "platformRun", "gapJump", "killLane", "movingPlatform", "spinner", "conveyor", "trussClimb",
    "wallHop", "icePatch", "windTunnel", "darkCorridor", "risingLava", "fallingFloor", "teleportPad",
    "fanLaunch", "shrinkingPlatform", "rotatingBar", "narrowBeam", "bouncePad", "laserGrid",
}
ANIMAL = {'Aardvark','Akita','Albatross','Amphiptere','Anglerfish','Anteater','Australian Cattle Dog','Badger','BichonFrise','Binturong','Blobfish','Boston Terrier','Bunyip','Caracal','Cassowary','Cavalier King Charles Spaniel','ChowChow','Chupacabra','Cuttlefish','Dingo','Dullahan','DumboOctopus','Emu','English Bulldog','FangtoothFish','Fenrir','Fossa','GiantIsopod','GoblinShark','Great Dane','HoneyBadger','Hyena','Jackal','Jackalope','Kappa','Kookaburra','LeafySeaDragon','Lindworm','Maltese','MantisShrimp','Muscovy Duck','Nautilus','Papillon','Quokka','Raiju','SecretaryBird','Serval','Shoebill','Tanuki','Yak'}
BASE = {'ARCHAEOPTERYX','ARGENTAVIS','AZHDARCHID','Ankylosaurus','Bat','Bear','Boxfish','Brachiosaurus','Bull','Bunny','Butterflyfish','CALADRIUS','CERBERUS','CHIREMA','CLASSICDRAGON','COCKATRICE','Capybara','Cat','Chicken','Cobra','CoralGoby','Cow','Crab','Crocodile','DIMETRODON','Elephant','FIREPHOENIX','Frog','GARGOYLE_BAT','GARUDA','GRIFFIN','Gallimimus','Giraffee','Goat','GoldenRetriver','Goldfish','Gorilla','GuiennaPig','HARPY','HYDRA','Hamster','Horse','Jellyfish','KRAKEN','Kangaroo','Kitsune','Koala','LEVIATHAN','Lion','Lionfish','Lizard','Llama','MANTICORE','MEGALODON','MICRORAPTOR','MINOTAUR','MOTHMAN','Mamoth','Mandarinfish','Moorish idol','Mosasaurus','Ostrich','Owl','PEGASUS','PLESIOSAUR','PREHISTORIC_DRAGONFLY','PREHISTORIC_MOTH','PTERANODON','PTERODACTYL','Parrot','Pigeon','Polar Bear','Pony','QILIN','QUETZALCOATLUS','ROC','Regal','SABER_TOOTHED_TIGER','SIMURGH','SPHINX','STEGOSAURUS','STYMPHALIANBIRD','Seahorse','Seal','Shark','Snail','Snake','Spinosaurus'}

HEX = re.compile(r"#?([0-9a-fA-F]{6})")


def lerp(a, b, t):
    return a + (b - a) * t


def hexes(text, n=4, fallback=("#7FB069", "#B5D99C", "#FFD166", "#6B8E4E")):
    found = ["#" + h.upper() for h in HEX.findall(text or "")]
    while len(found) < n:
        found.append(fallback[len(found)])
    return found[:n]


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", " ") + '"'


def fmt_num(x):
    if isinstance(x, bool):
        return "true" if x else "false"
    if float(x).is_integer():
        return str(int(x))
    return ("%.3f" % x).rstrip("0").rstrip(".")


def main():
    roster = json.loads(ROSTER.read_text())
    mapping = json.loads(MAPPING.read_text()) if MAPPING.exists() else {}
    biomes = roster["biomes"]
    assert len(biomes) == 20, "roster must have 20 biomes"
    seen = set()
    lines = []
    prev_speed = 0.0
    for b in biomes:
        i = b["index"]
        m = mapping.get(str(i), {})
        animal = m.get("animal", b["animal"])
        assert animal in ANIMAL or animal in BASE, f"biome {i}: unknown animal {animal}"
        assert animal not in seen, f"biome {i}: duplicate animal {animal}"
        seen.add(animal)
        folder = "Animal" if animal in ANIMAL else "BaseAnimals"
        profile = m.get("profile") or "steady"
        assert profile in PROFILES, f"biome {i}: bad profile {profile}"
        mechanic = m.get("mechanic")
        assert mechanic in CHUNKS, f"biome {i}: mechanic must be mapped to a chunk key, got {mechanic}"
        t = (i - 1) / 19.0
        chase = b["chaseProfile"]
        speed = float(m.get("baseSpeed", chase["baseSpeedStudsPerSec"]))
        speed = max(speed, prev_speed)  # never slower than the previous biome
        prev_speed = speed
        head = float(m.get("headStart", chase["headStartSeconds"]))
        tuning = {
            "profile": profile,
            "baseSpeed": speed,
            "headStart": head,
            "respawnHeadStart": m.get("respawnHeadStart", round(lerp(4.0, 2.5, t), 2)),
            "resetGap": m.get("resetGap", round(lerp(45, 30, t), 1)),
            "catchDistance": m.get("catchDistance", 3),
            "catchRadius": m.get("catchRadius", 6),
            "maxGap": m.get("maxGap", round(lerp(200, 140, t), 1)),
            "catchUpMultiplier": m.get("catchUpMultiplier", round(lerp(1.5, 1.8, t), 2)),
            "mercyGap": m.get("mercyGap", round(lerp(30, 18, t), 1)),
            "mercyMultiplier": m.get("mercyMultiplier", round(lerp(0.8, 0.9, t), 2)),
        }
        params = m.get("params", {})
        pal = hexes(b.get("palette", ""))
        tier_color = m.get("tierColor") or pal[2]
        hazards = b.get("signatureHazards", [])
        theme = b["theme"] + (" Chase twist: " + chase["twist"] if chase.get("twist") and chase["twist"].lower() != "none" else "")
        lines.append("\t{")
        lines.append(f"\t\tindex = {i},")
        lines.append(f"\t\tname = {lua_str(m.get('name', b['biomeName']))},")
        lines.append(f"\t\ttier = {lua_str(m.get('tier', b['difficultyLabel']))},")
        lines.append(f"\t\ttierColor = hex({lua_str(tier_color)}),")
        lines.append(f"\t\ttheme = {lua_str(theme)},")
        lines.append(f"\t\tanimal = {lua_str(animal)},")
        lines.append(f"\t\tanimalFolder = {lua_str(folder)},")
        lines.append(f"\t\tlocomotion = {lua_str(m.get('locomotion', b.get('locomotion', 'ground')))},")
        if m.get("eggModel"):
            lines.append(f"\t\teggModel = {lua_str(m['eggModel'])},")
        if m.get("renderImage"):
            lines.append(f"\t\trenderImage = {lua_str(m['renderImage'])},")
        lines.append(
            f"\t\tpalette = {{ primary = hex({lua_str(pal[0])}), secondary = hex({lua_str(pal[1])}), accent = hex({lua_str(pal[2])}), ground = hex({lua_str(pal[3])}) }},"
        )
        lines.append("\t\tchase = {")
        for k, v in tuning.items():
            lines.append(f"\t\t\t{k} = {lua_str(v) if isinstance(v, str) else fmt_num(v)},")
        if params:
            lines.append("\t\t\tparams = { " + ", ".join(f"{k} = {fmt_num(v)}" for k, v in params.items()) + " },")
        else:
            lines.append("\t\t\tparams = {},")
        lines.append("\t\t},")
        lines.append(f"\t\tmechanic = {lua_str(mechanic)},")
        lines.append("\t\thazards = { " + ", ".join(lua_str(h) for h in hazards) + " },")
        if m.get("music"):
            lines.append(f"\t\tmusic = {lua_str(m['music'])},")
        if m.get("musicChase"):
            lines.append(f"\t\tmusicChase = {lua_str(m['musicChase'])},")
        lines.append("\t},")
    body = "\n".join(lines)
    out = f"""--!strict
-- GENERATED FILE. Do not edit by hand.
-- Source: docs/roster.json (design) + docs/roster_mapping.json (engine tuning).
-- Regenerate with: python3 scripts/gen_biomes.py
--
-- One entry per biome, index == position. See Shared/Types.luau for the BiomeDef shape.
local Types = require(script.Parent.Parent.Types)

type BiomeDef = Types.BiomeDef

local function hex(h: string): Color3
	return Color3.fromHex(h)
end

local Biomes: {{ BiomeDef }} = {{
{body}
}}

for i, biome in Biomes do
	assert(biome.index == i, `Biomes[{{i}}] has index {{biome.index}}`)
end

return table.freeze(Biomes)
"""
    if "--check" in sys.argv:
        print("ok" if OUT.read_text() == out else "STALE: regenerate Biomes.luau")
        return
    OUT.write_text(out)
    print(f"wrote {OUT.relative_to(ROOT)} ({len(biomes)} biomes)")


if __name__ == "__main__":
    main()

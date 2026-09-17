--!strict
--[[
	Biomes (GENERATED PLACEHOLDER DATA)
	This file is generated data: it will be regenerated from the animal roster once the roster is
	final. Do not hand-tune values here; change the roster / generator instead.

	Owns the 20 BiomeDef entries indexed 1..20 (index == array position). Every entry, its palette,
	chase config, params and hazards list is frozen. Chase speeds rise linearly from 9 to 22 studs/s
	(player walkspeed is 16) and head starts fall from 8 to 4 s across the 20 biomes. Tier colours for
	the 14 standard tiers come from GameConfig.TierColors; the six custom tiers past "Nil" are defined
	here. Pure data, so it also loads under the CLI test harness.
]]

local GameConfig = require(script.Parent.GameConfig)
local Types = require(script.Parent.Parent.Types)

type BiomeDef = Types.BiomeDef
type ChaseConfig = Types.ChaseConfig
type ChaseProfileName = Types.ChaseProfileName
type Locomotion = Types.Locomotion
type Palette = Types.Palette

local BIOME_COUNT = GameConfig.BiomeCount
local SPEED_FIRST, SPEED_LAST = 9, 22
local HEAD_START_FIRST, HEAD_START_LAST = 8, 4

-- Tiers beyond the 14 standard difficulty-chart tiers (biomes 15..20).
local EXTRA_TIER_COLORS: { [string]: Color3 } = {
	Mythic = Color3.fromRGB(255, 105, 180),
	Legendary = Color3.fromRGB(255, 200, 40),
	Cosmic = Color3.fromRGB(120, 60, 220),
	Apocalyptic = Color3.fromRGB(255, 60, 0),
	Eternal = Color3.fromRGB(60, 220, 200),
	Impossible = Color3.fromRGB(20, 20, 20),
}

type Seed = {
	name: string,
	tier: string,
	theme: string,
	animal: string,
	animalFolder: "Animal" | "BaseAnimals",
	locomotion: Locomotion,
	profile: ChaseProfileName,
	params: { [string]: number },
	mechanic: string,
	hazards: { string },
	palette: Palette,
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function palette(primary: Color3, secondary: Color3, accent: Color3, ground: Color3): Palette
	return { primary = primary, secondary = secondary, accent = accent, ground = ground }
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function round1(value: number): number
	return math.round(value * 10) / 10
end

local function tierColor(tier: string): Color3
	local standard: Color3? = GameConfig.TierColors[tier]
	if standard ~= nil then
		return standard
	end
	local extra: Color3? = EXTRA_TIER_COLORS[tier]
	if extra ~= nil then
		return extra
	end
	error(("Biomes: no colour defined for tier %q"):format(tier))
end

local function chaseFor(index: number, seed: Seed): ChaseConfig
	local t = (index - 1) / (BIOME_COUNT - 1)
	return {
		profile = seed.profile,
		baseSpeed = round1(lerp(SPEED_FIRST, SPEED_LAST, t)),
		headStart = round1(lerp(HEAD_START_FIRST, HEAD_START_LAST, t)),
		respawnHeadStart = 3,
		resetGap = 40,
		catchDistance = 3,
		catchRadius = 6,
		maxGap = 180,
		catchUpMultiplier = 1.6,
		mercyGap = 25,
		mercyMultiplier = 0.85,
		params = seed.params,
	}
end

local SEEDS: { Seed } = {
	{
		name = "Meadow",
		tier = "Easy",
		theme = "grassland",
		animal = "Bunny",
		animalFolder = "BaseAnimals",
		locomotion = "ground",
		profile = "steady",
		params = { speedJitter = 0.05 },
		mechanic = "platformRun",
		hazards = { "KillBrick" },
		palette = palette(rgb(120, 200, 80), rgb(255, 240, 200), rgb(255, 105, 180), rgb(96, 170, 60)),
	},
	{
		name = "Farm",
		tier = "Medium",
		theme = "farmland",
		animal = "Chicken",
		animalFolder = "BaseAnimals",
		locomotion = "ground",
		profile = "bursty",
		params = { burstPeriod = 5, burstDuration = 1.5, burstMultiplier = 1.5, restMultiplier = 0.7 },
		mechanic = "gapJump",
		hazards = { "KillBrick", "Mud" },
		palette = palette(rgb(200, 60, 50), rgb(245, 222, 179), rgb(255, 215, 0), rgb(150, 110, 60)),
	},
	{
		name = "Backyard",
		tier = "Hard",
		theme = "suburban",
		animal = "GoldenRetriver",
		animalFolder = "BaseAnimals",
		locomotion = "ground",
		profile = "stalker",
		params = { idleThreshold = 1.5, stalkMultiplier = 1.6, prowlMultiplier = 0.9 },
		mechanic = "killLane",
		hazards = { "KillBrick", "Sprinkler" },
		palette = palette(rgb(90, 160, 210), rgb(230, 200, 150), rgb(255, 140, 0), rgb(100, 180, 90)),
	},
	{
		name = "Wetlands",
		tier = "Difficult",
		theme = "wetland",
		animal = "Capybara",
		animalFolder = "BaseAnimals",
		locomotion = "swimming",
		profile = "swimmer",
		params = {
			surgePeriod = 6,
			surgeDuration = 2,
			surgeMultiplier = 1.3,
			glideMultiplier = 0.85,
			bobAmplitude = 0.5,
			bobPeriod = 2,
		},
		mechanic = "movingPlatform",
		hazards = { "KillBrick", "Water" },
		palette = palette(rgb(60, 120, 90), rgb(150, 120, 80), rgb(100, 200, 220), rgb(70, 90, 60)),
	},
	{
		name = "Mountain",
		tier = "Challenging",
		theme = "alpine",
		animal = "Goat",
		animalFolder = "BaseAnimals",
		locomotion = "ground",
		profile = "steady",
		params = { speedJitter = 0.08 },
		mechanic = "spinner",
		hazards = { "KillBrick", "Rockfall" },
		palette = palette(rgb(130, 130, 140), rgb(235, 235, 245), rgb(60, 120, 200), rgb(110, 100, 90)),
	},
	{
		name = "Outback",
		tier = "Intense",
		theme = "desert",
		animal = "Kangaroo",
		animalFolder = "BaseAnimals",
		locomotion = "ground",
		profile = "bursty",
		params = { burstPeriod = 4, burstDuration = 1.5, burstMultiplier = 1.7, restMultiplier = 0.65 },
		mechanic = "conveyor",
		hazards = { "KillBrick", "Cactus" },
		palette = palette(rgb(210, 110, 40), rgb(240, 190, 120), rgb(255, 220, 70), rgb(190, 90, 40)),
	},
	{
		name = "Savanna",
		tier = "Remorseless",
		theme = "savanna",
		animal = "Hyena",
		animalFolder = "Animal",
		locomotion = "ground",
		profile = "stalker",
		params = { idleThreshold = 1.2, stalkMultiplier = 1.8, prowlMultiplier = 0.9 },
		mechanic = "trussClimb",
		hazards = { "KillBrick", "Thorns" },
		palette = palette(rgb(200, 170, 70), rgb(120, 80, 40), rgb(255, 100, 30), rgb(180, 150, 80)),
	},
	{
		name = "Swamp",
		tier = "Insane",
		theme = "swamp",
		animal = "Crocodile",
		animalFolder = "BaseAnimals",
		locomotion = "swimming",
		profile = "swimmer",
		params = {
			surgePeriod = 5,
			surgeDuration = 2,
			surgeMultiplier = 1.5,
			glideMultiplier = 0.8,
			bobAmplitude = 0.4,
			bobPeriod = 2.5,
		},
		mechanic = "wallHop",
		hazards = { "KillBrick", "Water", "Poison" },
		palette = palette(rgb(70, 100, 50), rgb(40, 60, 40), rgb(150, 255, 80), rgb(55, 70, 45)),
	},
	{
		name = "Jungle",
		tier = "Extreme",
		theme = "jungle",
		animal = "Gorilla",
		animalFolder = "BaseAnimals",
		locomotion = "ground",
		profile = "roarer",
		params = { roarEvery = 9, roarDuration = 1.3, sprintDuration = 2.5, sprintMultiplier = 1.8 },
		mechanic = "icePatch",
		hazards = { "KillBrick", "Vines" },
		palette = palette(rgb(30, 130, 60), rgb(110, 70, 40), rgb(255, 60, 90), rgb(40, 100, 50)),
	},
	{
		name = "Tundra",
		tier = "Terrifying",
		theme = "tundra",
		animal = "Polar Bear",
		animalFolder = "BaseAnimals",
		locomotion = "ground",
		profile = "steady",
		params = { speedJitter = 0.1 },
		mechanic = "windTunnel",
		hazards = { "KillBrick", "Ice", "Wind" },
		palette = palette(rgb(200, 220, 240), rgb(255, 255, 255), rgb(120, 200, 255), rgb(180, 200, 220)),
	},
	{
		name = "Ice Age",
		tier = "Catastrophic",
		theme = "glacial",
		animal = "SABER_TOOTHED_TIGER",
		animalFolder = "BaseAnimals",
		locomotion = "ground",
		profile = "stalker",
		params = { idleThreshold = 1, stalkMultiplier = 2, prowlMultiplier = 0.9 },
		mechanic = "darkCorridor",
		hazards = { "KillBrick", "Ice", "Dark" },
		palette = palette(rgb(150, 200, 255), rgb(220, 240, 255), rgb(255, 170, 60), rgb(170, 210, 240)),
	},
	{
		name = "Cretaceous",
		tier = "Horrific",
		theme = "prehistoric",
		animal = "Spinosaurus",
		animalFolder = "BaseAnimals",
		locomotion = "ground",
		profile = "roarer",
		params = { roarEvery = 8, roarDuration = 1.5, sprintDuration = 3, sprintMultiplier = 1.9 },
		mechanic = "risingLava",
		hazards = { "KillBrick", "Lava" },
		palette = palette(rgb(90, 120, 50), rgb(140, 100, 60), rgb(255, 90, 0), rgb(80, 80, 50)),
	},
	{
		name = "Sky Cliffs",
		tier = "Unreal",
		theme = "sky",
		animal = "PTERANODON",
		animalFolder = "BaseAnimals",
		locomotion = "flying",
		profile = "flyer",
		params = { bobAmplitude = 2.5, bobPeriod = 1.6, hoverHeight = 7, swoopPeriod = 9, swoopMultiplier = 1.4 },
		mechanic = "fallingFloor",
		hazards = { "KillBrick", "FallingFloor", "Wind" },
		palette = palette(rgb(170, 200, 230), rgb(250, 250, 255), rgb(255, 230, 120), rgb(140, 150, 170)),
	},
	{
		name = "Abyss",
		tier = "Nil",
		theme = "deep sea",
		animal = "MEGALODON",
		animalFolder = "BaseAnimals",
		locomotion = "swimming",
		profile = "swimmer",
		params = {
			surgePeriod = 5,
			surgeDuration = 2.5,
			surgeMultiplier = 1.6,
			glideMultiplier = 0.8,
			bobAmplitude = 1,
			bobPeriod = 3,
		},
		mechanic = "teleportPad",
		hazards = { "KillBrick", "Water", "Dark" },
		palette = palette(rgb(10, 30, 70), rgb(0, 60, 110), rgb(0, 220, 255), rgb(10, 20, 50)),
	},
	{
		name = "Ruins",
		tier = "Mythic",
		theme = "ancient ruins",
		animal = "GRIFFIN",
		animalFolder = "BaseAnimals",
		locomotion = "flying",
		profile = "flyer",
		params = { bobAmplitude = 3, bobPeriod = 1.4, hoverHeight = 8, swoopPeriod = 8, swoopMultiplier = 1.5 },
		mechanic = "fanLaunch",
		hazards = { "KillBrick", "Spikes", "Wind" },
		palette = palette(rgb(190, 180, 150), rgb(120, 110, 90), rgb(255, 200, 60), rgb(150, 140, 110)),
	},
	{
		name = "Underworld",
		tier = "Legendary",
		theme = "hellfire",
		animal = "CERBERUS",
		animalFolder = "BaseAnimals",
		locomotion = "ground",
		profile = "blinker",
		params = { blinkPeriod = 7, blinkStuds = 14, telegraphSeconds = 0.9, blinkMultiplier = 0.75 },
		mechanic = "shrinkingPlatform",
		hazards = { "KillBrick", "Lava", "ShrinkingPlatform" },
		palette = palette(rgb(80, 20, 20), rgb(30, 10, 10), rgb(255, 80, 0), rgb(50, 20, 20)),
	},
	{
		name = "Storm Sea",
		tier = "Cosmic",
		theme = "storm ocean",
		animal = "KRAKEN",
		animalFolder = "BaseAnimals",
		locomotion = "swimming",
		profile = "swimmer",
		params = {
			surgePeriod = 4,
			surgeDuration = 2,
			surgeMultiplier = 1.7,
			glideMultiplier = 0.8,
			bobAmplitude = 1.5,
			bobPeriod = 2.5,
		},
		mechanic = "rotatingBar",
		hazards = { "KillBrick", "Water", "Lightning" },
		palette = palette(rgb(40, 70, 110), rgb(90, 110, 140), rgb(200, 230, 255), rgb(30, 50, 80)),
	},
	{
		name = "Poison Marsh",
		tier = "Apocalyptic",
		theme = "toxic marsh",
		animal = "HYDRA",
		animalFolder = "BaseAnimals",
		locomotion = "ground",
		profile = "roarer",
		params = { roarEvery = 7, roarDuration = 1.2, sprintDuration = 3, sprintMultiplier = 2 },
		mechanic = "narrowBeam",
		hazards = { "KillBrick", "Poison", "NarrowBeam" },
		palette = palette(rgb(90, 40, 130), rgb(60, 90, 40), rgb(170, 255, 0), rgb(70, 50, 90)),
	},
	{
		name = "Dragon Peak",
		tier = "Eternal",
		theme = "volcanic peak",
		animal = "CLASSICDRAGON",
		animalFolder = "BaseAnimals",
		locomotion = "flying",
		profile = "flyer",
		params = { bobAmplitude = 3.5, bobPeriod = 1.2, hoverHeight = 9, swoopPeriod = 7, swoopMultiplier = 1.6 },
		mechanic = "bouncePad",
		hazards = { "KillBrick", "Lava", "Fire" },
		palette = palette(rgb(140, 30, 30), rgb(40, 40, 50), rgb(255, 160, 0), rgb(60, 50, 50)),
	},
	{
		name = "The Void",
		tier = "Impossible",
		theme = "void",
		animal = "LEVIATHAN",
		animalFolder = "BaseAnimals",
		locomotion = "hovering",
		profile = "blinker",
		params = { blinkPeriod = 5, blinkStuds = 18, telegraphSeconds = 0.8, blinkMultiplier = 0.8 },
		mechanic = "laserGrid",
		hazards = { "KillBrick", "Laser", "Void" },
		palette = palette(rgb(20, 0, 40), rgb(0, 0, 0), rgb(200, 100, 255), rgb(15, 5, 30)),
	},
}

assert(#SEEDS == BIOME_COUNT, ("Biomes: expected %d seeds, got %d"):format(BIOME_COUNT, #SEEDS))

local Biomes: { BiomeDef } = table.create(BIOME_COUNT)

for index, seed in SEEDS do
	local chase = chaseFor(index, seed)
	table.freeze(chase.params)
	table.freeze(chase)
	table.freeze(seed.palette)
	table.freeze(seed.hazards)
	local def: BiomeDef = {
		index = index,
		name = seed.name,
		tier = seed.tier,
		tierColor = tierColor(seed.tier),
		theme = seed.theme,
		animal = seed.animal,
		animalFolder = seed.animalFolder,
		locomotion = seed.locomotion,
		eggModel = nil,
		renderImage = nil,
		palette = seed.palette,
		chase = chase,
		mechanic = seed.mechanic,
		hazards = seed.hazards,
		music = nil,
		musicChase = nil,
	}
	Biomes[index] = table.freeze(def)
end

return table.freeze(Biomes)
